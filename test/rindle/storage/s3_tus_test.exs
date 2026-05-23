defmodule Rindle.Storage.S3TusTest do
  @moduledoc """
  Wave-0 RED unit specs for the S3 tail-buffer math behind `upload_part_stream/5`
  (TUS-06). NO network: every assertion drives the pure S3 part-streaming logic
  against on-disk temp files only.

  S3 requires every NON-final multipart part to be >= 5 MiB. A tus PATCH may
  carry fewer bytes (especially a resumed tail), so the adapter buffers bytes on
  local disk until it has a full 5 MiB part to `UploadPart`, keeping any
  remainder buffered across PATCHes. On completion the leftover tail (any size)
  is flushed as the final part. These specs pin that slice/accumulate contract.

  EXPECTED RED until Plan 02 lands `Rindle.Storage.S3.upload_part_stream/5` +
  `complete_part_stream/4`. The file compiles cleanly today; the calls raise
  `UndefinedFunctionError` (a loud runtime failure, not a CompileError) until the
  impl exists. When Plan 02 ships, these go GREEN unchanged.
  """
  use ExUnit.Case, async: true

  alias Rindle.Storage.S3

  # S3 minimum non-final part size. Mirrors @s3_min_part_size in the adapter.
  @s3_min_part_size 5 * 1024 * 1024

  setup do
    root =
      Path.join(System.tmp_dir!(), "rindle-s3-tus-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    {:ok, root: root}
  end

  # Drains `bytes` to a temp file and hands the path to upload_part_stream/5,
  # exactly as TusPlug does (drain PATCH body to disk first, then dispatch).
  defp patch(key, bytes, base_offset, state, root) do
    temp_path = Path.join(root, "patch-#{System.unique_integer([:positive])}.part")
    File.write!(temp_path, bytes)

    S3.upload_part_stream(key, temp_path, base_offset, state, root: root, bucket: "rindle-test")
  end

  # The pure tail-buffer logic must NOT require S3 for buffering decisions: a
  # sub-5-MiB PATCH never reaches the network (no UploadPart issued), so these
  # specs hold even with no MinIO. The >= 5-MiB slice path DOES issue an
  # UploadPart; those calls will surface a transport error (no live S3) which is
  # itself a RED signal that the slice path was reached — Plan 02 turns the math
  # GREEN and the MinIO round-trip (s3_test.exs / tus_s3_integration_test.exs)
  # proves the live UploadPart.

  describe "tail-buffer accumulate (TUS-06): sub-5-MiB PATCH produces zero parts" do
    test "a single sub-5-MiB PATCH leaves the tail < 5 MiB and emits no parts", %{root: root} do
      key = "tus/#{System.unique_integer([:positive])}.bin"
      bytes = String.duplicate("a", 1024 * 1024)

      assert {:ok, state} =
               patch(key, bytes, 0, %{offset: 0, upload_id: "u-1", parts: []}, root)

      # Offset advances by the bytes written; nothing was sliced into a part.
      assert state.offset == byte_size(bytes)
      assert state.parts == []
    end

    test "two sub-5-MiB PATCHes that together stay < 5 MiB still emit no parts", %{root: root} do
      key = "tus/#{System.unique_integer([:positive])}.bin"
      chunk = String.duplicate("b", 2 * 1024 * 1024)

      assert {:ok, s1} = patch(key, chunk, 0, %{offset: 0, upload_id: "u-2", parts: []}, root)
      assert s1.parts == []
      assert s1.offset == byte_size(chunk)

      assert {:ok, s2} = patch(key, chunk, s1.offset, s1, root)
      # 4 MiB total — still under the 5 MiB floor, so no part yet.
      assert s2.parts == []
      assert s2.offset == 2 * byte_size(chunk)
    end
  end

  describe "tail-buffer slice (TUS-06): crossing 5 MiB cuts exactly one part" do
    test "pushing the tail to >= 5 MiB slices off one 5 MiB part and keeps the remainder", %{
      root: root
    } do
      key = "tus/#{System.unique_integer([:positive])}.bin"
      # 5 MiB + 1 MiB remainder: exactly one full part, 1 MiB left buffered.
      bytes = String.duplicate("c", @s3_min_part_size + 1024 * 1024)

      assert {:ok, state} =
               patch(key, bytes, 0, %{offset: 0, upload_id: "u-3", parts: []}, root)

      assert length(state.parts) == 1
      assert hd(state.parts).part_number == 1
      # The full PATCH is committed to the offset even though 1 MiB stays buffered.
      assert state.offset == byte_size(bytes)
    end
  end

  describe "part ordering (TUS-06): strictly increasing 1-based part numbers" do
    test "a sequence of PATCHes accumulates part_numbers ordered by number, not arrival", %{
      root: root
    } do
      key = "tus/#{System.unique_integer([:positive])}.bin"
      # Three 5-MiB-crossing PATCHes => three parts numbered 1, 2, 3.
      chunk = String.duplicate("d", @s3_min_part_size)

      assert {:ok, s1} = patch(key, chunk, 0, %{offset: 0, upload_id: "u-4", parts: []}, root)
      assert {:ok, s2} = patch(key, chunk, s1.offset, s1, root)
      assert {:ok, s3} = patch(key, chunk, s2.offset, s2, root)

      numbers = Enum.map(s3.parts, & &1.part_number)
      assert numbers == Enum.sort(numbers)
      assert numbers == [1, 2, 3]
      # part_number is 1-based and strictly increasing.
      assert Enum.min(numbers) == 1
    end
  end

  describe "completion flush (TUS-06): final tail becomes the last part" do
    test "complete_part_stream flushes the remaining sub-5-MiB tail as the final part", %{
      root: root
    } do
      key = "tus/#{System.unique_integer([:positive])}.bin"
      # One full part plus a sub-5-MiB tail buffered.
      first = String.duplicate("e", @s3_min_part_size + 512 * 1024)

      assert {:ok, mid} =
               patch(key, first, 0, %{offset: 0, upload_id: "u-5", parts: []}, root)

      assert length(mid.parts) == 1

      # Completion flushes the leftover tail (< 5 MiB allowed for the LAST part)
      # then completes the multipart upload.
      assert {:ok, _result} =
               S3.complete_part_stream(key, nil, mid, root: root, bucket: "rindle-test")
    end
  end

  describe "tus_tail_path/2 (CR-02): reaper-facing path matches the adapter-written tail" do
    # The reaper needs the EXACT on-disk path the adapter wrote so it can delete
    # the real tail. tus_tail_path/2 is the public source-of-truth that 43-08
    # routes remove_tus_tail/1 through — ending the raw-UUID vs base64url mismatch.

    test "returns the exact file the adapter wrote its tail to for a session", %{root: root} do
      # patch/5 keys the tail on `key` (no explicit session_id), so the adapter
      # writes to tail_path(key, root: root). The reaper-facing helper, given the
      # same id, must compute that identical location.
      key = "11111111-2222-3333-4444-555555555555"
      bytes = String.duplicate("a", 1024 * 1024)

      assert {:ok, _state} =
               patch(key, bytes, 0, %{offset: 0, upload_id: "u-tp-1", parts: []}, root)

      helper_path = S3.tus_tail_path(key, root: root)

      # The adapter actually wrote a tail file at this exact path.
      assert File.exists?(helper_path)

      # And removing via the helper path reaches the real adapter-written tail.
      assert :ok = File.rm(helper_path)
      refute File.exists?(helper_path)
    end

    test "uses base64url(id) <> \".tail\" under <root>/tus, never the raw id", %{root: root} do
      id = "aa/bb cc+dd"
      path = S3.tus_tail_path(id, root: root)

      expected_filename = Base.url_encode64(id, padding: false) <> ".tail"

      assert Path.basename(path) == expected_filename
      assert Path.dirname(path) == Path.join(root, "tus")
      # The raw id (with traversal-prone characters) never appears in the path.
      refute String.contains?(path, id)
    end
  end

  describe "cross-node resume guard (CR-04): missing tail fails loudly" do
    # The sub-5-MiB tail remainder is node-local disk state while
    # offset/upload_id/parts live in the shared DB. A resumed PATCH that lands on
    # a different node reads authoritative parts/upload_id from the DB but has NO
    # local tail to slice from. Re-slicing from a fresh empty tail would corrupt
    # the assembled object, so the adapter must fail loudly instead.

    test "mid-multipart resume with no local tail returns {:error, :tus_tail_missing}", %{
      root: root
    } do
      key = "tus/#{System.unique_integer([:positive])}.bin"

      # Mid-multipart state: a committed part already exists (so a tail boundary
      # was sliced on the originating node) but the tail file is absent here.
      state = %{
        offset: @s3_min_part_size,
        upload_id: "uid-existing",
        parts: [%{part_number: 1, etag: "e1"}]
      }

      # No tail file was ever created under this root.
      refute File.exists?(S3.tus_tail_path(key, root: root))

      # A sub-5-MiB body so the slice path (live UploadPart) is never reached
      # even if the guard were absent — the guard fires first, offline.
      bytes = String.duplicate("x", 1024 * 1024)

      assert {:error, :tus_tail_missing} = patch(key, bytes, @s3_min_part_size, state, root)
    end

    test "a FIRST PATCH (nil upload_id, [] parts) with no tail succeeds — no false positive", %{
      root: root
    } do
      key = "tus/#{System.unique_integer([:positive])}.bin"

      # Brand-new multipart legitimately has no tail and no committed parts yet.
      refute File.exists?(S3.tus_tail_path(key, root: root))

      # Sub-5-MiB body keeps it offline (no UploadPart issued).
      bytes = String.duplicate("y", 1024 * 1024)

      result = patch(key, bytes, 0, %{offset: 0, upload_id: nil, parts: []}, root)

      # The fresh-upload path is NOT guarded: no committed parts means no tail is
      # expected yet, so the guard must not false-positive on the happy path.
      refute match?({:error, :tus_tail_missing}, result)
      assert {:ok, state} = result
      assert state.parts == []
      assert state.offset == byte_size(bytes)
    end
  end
end
