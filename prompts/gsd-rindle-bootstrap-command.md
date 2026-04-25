# Rindle GSD Bootstrap Command

## Goal

Start a new GSD project in a fresh context window using the synthesized Rindle bootstrap brief.

## Preflight (quick)

Run from repository root:

```bash
cd "/Users/jon/projects/rindle"
```

Confirm the bootstrap artifacts exist:

```bash
ls prompts
```

Expected to include:

- `gsd-rindle-research-index.md`
- `gsd-rindle-elixir-oss-dna.md`
- `gsd-rindle-gsd-bootstrap-brief.md`
- `rindle-brand-book.md`
- `phoenix-media-uploads-lib-deep-research.md`

Optional safety check before initialization:

```bash
ls .planning
```

If `.planning` already exists, do not run new-project on top of it unless you explicitly want to re-initialize.

## Primary command (most environments)

```text
/gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

## Runtime-safe variants

Use the one that matches your runtime:

- Standard slash-command runtimes:

```text
/gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

- Codex runtime (as documented in GSD install runtime mapping):

```text
$gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

- Cursor skill invocation style (if slash commands are not active):

```text
gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

## One-copy command block for a clean window

If you want a single paste block in a fresh terminal/chat context:

```text
cd "/Users/jon/projects/rindle" && /gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

If your runtime requires the Codex prefix:

```text
cd "/Users/jon/projects/rindle" && $gsd-new-project --auto @prompts/gsd-rindle-gsd-bootstrap-brief.md
```

## What this command should do

In auto mode, GSD should:

1. read the brief as the idea document,
2. run research/requirements/roadmap flow with minimal interactive prompts,
3. initialize `.planning/` artifacts for Rindle with the locked defaults in the brief.
