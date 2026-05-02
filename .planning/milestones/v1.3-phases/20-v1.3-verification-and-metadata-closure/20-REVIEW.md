---
phase: 20-v1.3-verification-and-metadata-closure
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/rindle/live_view.ex
  - test/rindle/live_view_test.exs
  - test/install_smoke/docs_parity_test.exs
  - README.md
  - guides/getting_started.md
findings:
  critical: 2
  warning: 5
  info: 3
  total: 10
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-05-01
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Plan 20-02 successfully routes `Rindle.LiveView`'s presign step through
`Rindle.Upload.Broker.sign_url/1`, which is the correct architectural fix.
The accompanying tests reach further (verifying broker-owned session/asset
state and end-to-end verification), and the docs-parity test pins the new
Phase 19 helpers and bang surface across both onboarding files.

However, the refactor introduces a new failure path that violates
Phoenix.LiveView's `:external` uploader protocol, the `consume_uploaded_entries`
wrapper has multiple correctness defects (silent bypass, swallowed errors,
non-idempotent re-runs), and the new README/guide controller example is a
copy-paste footgun. The moduledoc usage example also references a field that
does not exist on `Phoenix.LiveView.UploadEntry`.

## Critical Issues

### CR-01: BLOCKER — `handle_initiate_upload` returns invalid `{:error, term}` shape that crashes Phoenix.LiveView on `Broker.sign_url` failure

**File:** `lib/rindle/live_view.ex:97-99`

**Issue:** `Phoenix.LiveView.Upload.external_preflight/4`
(`deps/phoenix_live_view/lib/phoenix_live_view/upload.ex:416-428`) only
pattern-matches two shapes from the `:external` callback:

```elixir
case conf.external.(entry, acc) do
  {:ok, %{} = meta, new_socket} -> ...
  {:error, %{} = meta, new_socket} -> ...
end
```

`Rindle.LiveView.handle_initiate_upload/3` returns a bare `{:error, reason}`
(2-tuple, `reason` is a term, not a map) when `Broker.sign_url/1` fails:

```elixir
case Broker.sign_url(session.id) do
  {:ok, %{session: signed_session, presigned: presigned}} -> ...
  {:error, reason} -> {:error, reason}   # <-- CrashCaseClauseError in LiveView
end
```

This is a **regression introduced by Plan 20-02**: any production failure of
`Broker.sign_url` (storage adapter timeout, FSM rejection, capability
mis-config, repo lookup failure, profile resolution failure) will crash
Phoenix.LiveView with `CaseClauseError` rather than surfacing a structured
upload error to the client. The pre-Phase-20 code had the same bug shape on
the `presigned_put` branch, but the broker now has a wider failure surface
(FSM transition, profile-name lookup, expires_in path, multipart fan-out
checks) so the probability of hitting this in production goes up materially.

The same defect exists at `lib/rindle/live_view.ex:78-80` for the
`Rindle.initiate_upload` failure branch (pre-existing — see WR-01).

**Fix:**

```elixir
defp handle_initiate_upload(session, _profile, socket) do
  case Broker.sign_url(session.id) do
    {:ok, %{session: signed_session, presigned: presigned}} ->
      meta = %{
        uploader: "Rindle",
        url: presigned.url,
        method: Map.get(presigned, :method, "PUT"),
        headers: Map.get(presigned, :headers, %{}),
        session_id: signed_session.id,
        asset_id: signed_session.asset_id
      }

      {:ok, meta, socket}

    {:error, reason} ->
      # Phoenix.LiveView's external callback contract requires
      # {:error, %{} = meta, socket}. Pass the reason inside a map.
      {:error, %{reason: inspect(reason)}, socket}
  end
end
```

A test should cover this path (e.g., make `Rindle.StorageMock.presigned_put/3`
return `{:error, :timeout}` and assert the external_fn returns
`{:error, %{...}, socket}` rather than crashing).

---

### CR-02: BLOCKER — `do_consume/3` silently bypasses verification when `session_id` is missing from meta

**File:** `lib/rindle/live_view.ex:128-142`

**Issue:** When the client-side meta map does not contain a `session_id`
key (string or atom), the helper falls through and invokes the user
callback **without calling `Rindle.verify_completion/2`**:

```elixir
if session_id do
  case Rindle.verify_completion(session_id) do ... end
else
  func.(entry, meta)   # <-- silent bypass of verification
end
```

The moduledoc explicitly promises the opposite: "For each completed entry,
calls `Rindle.verify_completion/2` to confirm the object landed in storage,
**then** invokes the user-provided function" (lines 102-107). This is a
correctness/security defect:

1. An adopter who forgets to wire `session_id` into meta (or whose
   client-side flow strips it) will silently get callbacks invoked on
   entries that were never verified by Rindle. The asset row never
   transitions to `validating` and Oban promote/process is never enqueued
   — but the adopter's callback fires as if everything succeeded.

2. There is no telemetry, no log, and no error to indicate the
   verification was skipped. The adopter cannot detect the bypass except
   by spotting that the post-callback state is wrong.

3. The moduledoc usage example (`{:ok, entry.asset_id}`) cannot work in
   the bypass branch (entry has no asset_id — see CR-03 below), so any
   adopter actually exercising this path will see a confusing
   `KeyError`/`UndefinedFunctionError` rather than the documented
   verification failure.

**Fix:** Either (a) require `session_id` and return a structured error
when absent (preferred), or (b) raise loudly. Silent fall-through is the
wrong default for a verification helper.

```elixir
defp do_consume(meta, entry, func) do
  case Map.get(meta, "session_id") || Map.get(meta, :session_id) do
    nil ->
      raise ArgumentError,
            "Rindle.LiveView.consume_uploaded_entries/3 requires :session_id " <>
              "in upload meta. Got: #{inspect(Map.keys(meta))}"

    session_id ->
      case Rindle.verify_completion(session_id) do
        {:ok, %{asset: _asset}} ->
          func.(entry, meta)

        {:error, reason} ->
          # See WR-02: this also needs a Phoenix-LV-conformant return shape.
          {:postpone, {:error, reason}}
      end
  end
end
```

A regression test should assert this raises (or returns a structured
postpone) when meta lacks `session_id`.

---

## Warnings

### WR-01: WARNING — `do_allow_upload/3` returns invalid `{:error, term}` shape on initiate failure

**File:** `lib/rindle/live_view.ex:78-80`

**Issue:** Same Phoenix-LV protocol violation as CR-01, on the
`Rindle.initiate_upload` failure branch. Pre-existing (not introduced by
Phase 20), but every Plan 20-02 review touchpoint passes through this
function, so it should be fixed in the same patch:

```elixir
case Rindle.initiate_upload(profile, filename: filename) do
  {:ok, session} -> handle_initiate_upload(session, profile, socket)
  {:error, reason} -> {:error, reason}   # <-- 2-tuple; LV expects 3-tuple
end
```

**Fix:**

```elixir
{:error, reason} ->
  {:error, %{reason: inspect(reason)}, socket}
```

---

### WR-02: WARNING — `do_consume/3` returns `{:error, reason}` on verification failure, which Phoenix.LiveView treats as malformed return

**File:** `lib/rindle/live_view.ex:136-137`

**Issue:** `Phoenix.LiveView.Upload.consume_entries`
(`deps/phoenix_live_view/lib/phoenix_live_view/upload.ex:298-317`) only
recognises `{:ok, value}` and `{:postpone, value}` from the user
callback. Anything else triggers an `IO.warn`:

```elixir
case result do
  {:ok, return} -> {entry.ref, return}
  {:postpone, return} -> {:postpone, return}
  return ->
    IO.warn("""
    consuming uploads requires a return signature matching:
        {:ok, value} | {:postpone, value}
    got: #{inspect(return)}
    """)
    {entry.ref, return}
end
```

Returning `{:error, reason}` therefore (a) emits an `IO.warn` to stderr in
production, (b) swallows the verification failure into the result list as
if it were a happy-path value, and (c) **removes the entry from the
upload config** (because Phoenix LV treats the warned path as "consumed").
The adopter cannot distinguish a verification failure from a successful
`{:error, value}` user-callback return.

**Fix:** Use `:postpone` for retryable failures so the entry stays in
the upload config, and wrap the error in a tagged tuple so callers can
match on it:

```elixir
{:error, reason} ->
  {:postpone, {:error, {:rindle_verify_failed, reason}}}
```

Or, if non-idempotency (CR/WR-03 below) makes retry pointless, raise so
the adopter sees the failure:

```elixir
{:error, reason} ->
  raise Rindle.Error,
    action: :verify_completion,
    reason: reason
```

---

### WR-03: WARNING — `consume_uploaded_entries/3` is non-idempotent and second-pass calls fail FSM transition

**File:** `lib/rindle/live_view.ex:122-142`, `lib/rindle/domain/upload_session_fsm.ex:11`

**Issue:** `Rindle.verify_completion/2` transitions the session through
`signed → verifying → completed` and Oban-enqueues a promote job. The FSM
table at `lib/rindle/domain/upload_session_fsm.ex:11` defines
`"completed" => []` — i.e., no outgoing transitions. Therefore a second
call to `consume_uploaded_entries` for the same `session_id` always fails
the FSM step with `{:error, {:invalid_transition, ...}}`.

This matters because Phoenix LV does **not** guarantee
`consume_uploaded_entries` is called exactly once per entry. Adopters who
re-render or invoke the helper twice in a single LiveView lifecycle
(e.g., once to read meta and again in a save handler, or under a
rebroadcast/retry) will see verification failures on the second pass.
Combined with WR-02 (silent error swallow), the adopter sees an `IO.warn`
and a misleading "completed" callback result on retry.

The pre-Phase-20 implementation called `presigned_put` directly (no
FSM transition in consume), so this is also a regression introduced by
Plan 20-02 — the new lifecycle is correct in principle but the LV
integration does not guard against re-entry.

**Fix:** Short-circuit when the session is already `completed` and treat
that as success rather than an error:

```elixir
defp do_consume(meta, entry, func) do
  with session_id when is_binary(session_id) <-
         Map.get(meta, "session_id") || Map.get(meta, :session_id),
       :ok <- ensure_verified(session_id) do
    func.(entry, meta)
  else
    nil -> raise ArgumentError, "missing :session_id in upload meta"
    {:error, reason} -> {:postpone, {:error, reason}}
  end
end

defp ensure_verified(session_id) do
  repo = Rindle.repo()

  case repo.get(Rindle.Domain.MediaUploadSession, session_id) do
    %{state: "completed"} -> :ok
    %{} = _session ->
      with {:ok, _} <- Rindle.verify_completion(session_id), do: :ok
    nil -> {:error, :not_found}
  end
end
```

A regression test should call the helper twice on the same socket and
assert both calls succeed (or that the second is a no-op rather than an
FSM error).

---

### WR-04: WARNING — README controller example crashes when adopter has no avatar attached

**File:** `README.md:130-143`, `guides/getting_started.md:222-232`

**Issue:** Both onboarding docs introduce `Rindle.attachment_for/2` with
the explicit annotation that the return value can be `nil`:

```elixir
avatar = Rindle.attachment_for(user, "avatar")
# %Rindle.Domain.MediaAttachment{} | nil — :asset is preloaded by default

thumbs = Rindle.ready_variants_for(avatar.asset)   # <-- raises on nil
```

The very next line dereferences `avatar.asset` without a nil-guard. An
adopter copying this snippet into a controller — which is what the
prose explicitly invites them to do ("you'll typically render it from a
Phoenix controller or LiveView") — will get a `BadMapError` /
`KeyError` for every user who has not yet uploaded an avatar. This is
exactly the user-facing "render the variants that are safe to display"
case the helper is supposed to make safe. The example actively teaches
the wrong pattern.

**Fix:** Guard the example or use `case`/pattern-match:

```elixir
def show(conn, _params) do
  user = conn.assigns.current_user

  {avatar, thumbs} =
    case Rindle.attachment_for(user, "avatar") do
      nil -> {nil, []}
      avatar -> {avatar, Rindle.ready_variants_for(avatar.asset)}
    end

  render(conn, :show, avatar: avatar, thumbs: thumbs)
end
```

The guide (`guides/getting_started.md:222-232`) has the same defect and
should be patched in lockstep.

---

### WR-05: WARNING — `Rindle.LiveView` moduledoc example references nonexistent `entry.asset_id` field

**File:** `lib/rindle/live_view.ex:25-30`

**Issue:** The moduledoc usage block teaches:

```elixir
def handle_event("save", _params, socket) do
  results =
    Rindle.LiveView.consume_uploaded_entries(socket, :avatar, fn entry, _meta ->
      {:ok, entry.asset_id}
    end)

  {:noreply, socket}
end
```

`entry` is `%Phoenix.LiveView.UploadEntry{}`, whose defstruct
(`deps/phoenix_live_view/lib/phoenix_live_view/upload_config.ex:8-22`) is
`progress, preflighted?, upload_config, upload_ref, ref, uuid, valid?,
done?, cancelled?, client_name, client_relative_path, client_size,
client_type, client_last_modified, client_meta`. There is no
`:asset_id` field. The documented snippet raises `KeyError` if executed
verbatim.

The `:asset_id` lives on `meta` (set by `handle_initiate_upload`), so the
example should be:

```elixir
fn _entry, meta -> {:ok, meta.asset_id} end
```

This also conflicts with the `_meta` underscore prefix, which suggests
the meta is unused. Adopters reading the docs will reach for
`entry.client_name` etc. and never find `asset_id`.

**Fix:**

```elixir
def handle_event("save", _params, socket) do
  results =
    Rindle.LiveView.consume_uploaded_entries(socket, :avatar, fn _entry, meta ->
      {:ok, meta.asset_id}
    end)

  {:noreply, socket}
end
```

---

## Info

### IN-01: `consume_uploaded_entries/3` typespec is too loose

**File:** `lib/rindle/live_view.ex:121`

**Issue:** `@spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), atom(), function()) :: list()`
uses `function()` and `list()` without a more specific arrow type. This
hides the Phoenix LV contract (`{:ok, value} | {:postpone, value}`) from
adopters and from Dialyzer.

**Fix:**

```elixir
@type consume_func ::
        (Phoenix.LiveView.UploadEntry.t(), map() ->
           {:ok, term()} | {:postpone, term()})

@spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), atom(), consume_func()) ::
        [term()]
```

---

### IN-02: `Code.ensure_loaded?(Rindle.LiveView)` at module level discards return value

**File:** `test/rindle/live_view_test.exs:5`

**Issue:** `Code.ensure_loaded?/1` returns a boolean but the result is
discarded. If the intent is to force-load the module before the
`Code.fetch_docs` call later, use `Code.ensure_loaded!/1` (raises on
failure) so a misconfigured environment surfaces a clear error rather
than a downstream `function_exported?/3` returning false.

**Fix:**

```elixir
Code.ensure_loaded!(Rindle.LiveView)
```

---

### IN-03: `consume_uploaded_entries/3` describe block contains an unrelated moduledoc test

**File:** `test/rindle/live_view_test.exs:143-149`

**Issue:** The test "module docs teach verify_completion/2 as the
verification path" is grouped under `describe "consume_uploaded_entries/3"`
but exercises the moduledoc string, not the function. This makes the
suite output misleading. Move it to `describe "moduledoc"` or `describe
"module availability"`.

---

_Reviewed: 2026-05-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
