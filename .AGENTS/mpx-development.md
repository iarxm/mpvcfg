# MPX development plan

## Purpose

Make mpx an understandable mpv client for the asurf analysis workflow without
turning copied third-party scripts, live configuration, and first-party code
into one indistinguishable codebase.

This is a design and migration plan. It does not itself move runtime files or
change how uview starts mpv.

## Ownership model

```text
asurf  -> analysis domain and file operations
mpx    -> mpv UI and adapter behavior
uview  -> nnn preview host and mpv lifecycle
```

`asurf` is the authority for filename tags, session data, rename decisions,
collision handling, dry runs, and future reports or exports. `mpx` collects
interactive input and applies the returned result to mpv state. `uview` remains
independent of tag formatting and owns only preview dispatch and embedding.

This creates a one-way domain boundary: mpx may call asurf; asurf must not need
to import Lua or uosc to perform a tag operation.

## Target components

```text
mpx repository
  profiles/mpx/                 live, promoted profile
    mpv.conf
    input.conf
    script-opts/
    scripts/                    only declared runtime entry points
  src/mpx/                      first-party mpv adapters
    analysis.lua
    navigation.lua
    capture.lua
    lib/
  vendor/                       reviewed imported sources
    uosc/
    blackbox/
    manifest.md
  tests/
    unit/
    integration/
  tools/
    dev-mpv
    check

asurf repository
  asurf                          workflow CLI
  utl/anotr                      tag implementation and CLI adapter
  tests/
    tag/
```

The exact directory names are a target, not an instruction to move files in
one step. Existing scripts remain in place until their replacement works in the
desktop workflow.

## Asurf tag API

Refactor the current interactive `anotr` command into a non-interactive API
before mpx relies on it. The terminal prompts can remain as a thin human CLI
layer over the same operation.

Proposed commands:

```text
asurf tag add --file FILE --surfer VALUE --rating VALUE --note VALUE
asurf tag remove --file FILE
asurf tag clone --file FILE
```

Required common options:

```text
--dry-run
--format json
--no-cluster
--cluster-by-id
```

`--no-cluster` is the mpx-safe default: change only the active file.
`--cluster-by-id` preserves the existing anotr behavior of applying a tag to
all matching files, but makes that broader effect explicit.

A successful machine-readable result must contain at least:

```json
{"old_path":"/media/S1234567.mp4","new_path":"/media/s1234567_Samy.mp4"}
```

Failures must leave the source file unchanged and return a non-zero status with
an actionable error message. The API must refuse accidental overwrite unless a
future explicit overwrite operation is designed and tested.

## MPX adapter contract

The first-party mpv analysis script should:

1. validate that the active item is a local file;
2. collect prompt values;
3. run the asurf tag command as an argument vector, not a shell string;
4. parse the structured result;
5. replace or refresh the active mpv playlist path; and
6. display a concise success or failure message.

It must not parse or construct the filename tag grammar itself once the asurf
API exists. Until then, the current Lua implementation is a compatibility
implementation and should receive regression tests before refactoring.

## Development without copy cycles

Use a development profile rather than copying changed files into the live
profile for each edit:

```text
mpx                 stable, promoted profile
mpx-dev             worktree-backed development profile
```

`tools/dev-mpv` should create a temporary or dedicated development config that
loads absolute script paths from the selected worktree. It may symlink static
configuration and vendor directories, but first-party scripts must be loaded
directly from the worktree. Restarting mpv is acceptable; manual copying is
not required.

The stable profile only receives promoted changes after checks pass. Do not
point the everyday uview profile at a dirty worktree by default.

## Verification layers

| Layer | Scope | Required evidence |
|---|---|---|
| Asurf unit | Tag grammar and filesystem behavior | Temporary fixtures, expected paths, no-overwrite and dry-run checks |
| MPX unit | Prompt-to-asurf adapter | Mocked mpv and fake asurf executable |
| MPX integration | Runtime bindings and refresh | Headless mpv, temporary media, IPC/key events |
| Desktop acceptance | Actual preview workflow | Real uview text, directory, image, media, and PDF transitions |

`make check` or `tools/check` should run syntax and unit checks without
touching user media. Integration fixtures must be created under a temporary
directory. Desktop acceptance is reported separately; it cannot be inferred
from a successful headless mpv run.

## Vendor policy

For every imported component, record in `vendor/manifest.md`:

- component and purpose;
- upstream URL;
- exact release or commit;
- license;
- import date and integrity value where available; and
- local changes or patches.

Vendor directories are not a place for first-party fixes. A vendor refresh is
a deliberate review operation with a diff, validation, and rollback point.
Disable or avoid vendor commands that fetch or install from floating upstream
state.

## Migration stages

### 1. Inventory and contracts

Classify every current script as first-party, vendor, legacy, or removal
candidate. Document current bindings, script options, source provenance, and
runtime dependencies. Specify the asurf tag JSON contract and fixture cases.

### 2. Testable asurf tag API

Implement non-interactive `asurf tag` commands with dry-run and structured
results. Retain the existing terminal interaction as a compatibility front end.
Add fixture tests before changing mpx.

### 3. Worktree-backed mpx development

Add `mpx-dev` and `tools/dev-mpv`. Add headless adapter tests. The stable mpx
profile remains unchanged except for opt-in development launch wiring.

### 4. Adapt mpx to asurf

Replace duplicated Lua tag grammar with the asurf API adapter. Preserve current
binding names and provide a reversible fallback until real uview transitions
pass.

### 5. Separate first-party and vendor code

Move one first-party feature at a time behind explicit loading. Add the vendor
manifest. Do not reorganize uosc or other imports during unrelated feature
work.

### 6. Promote and simplify

After desktop acceptance, promote the development implementation into the
stable profile, retain a rollback reference, then remove proven-obsolete shims.

## Immediate next task

Start stage 1 only: produce the script inventory, vendor provenance manifest,
and asurf tag API specification. Do not move scripts or alter uview runtime
behavior during this task.
