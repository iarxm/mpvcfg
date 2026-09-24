# mpv configuration repository

`profiles/mpx` is the live mpv profile. Keep it usable while development work
is in progress. Do not turn a working live profile into an implicit build or
deployment target.

## Architecture direction

The intended ownership boundary is:

- `asurf` owns analysis-domain behavior: session context, tag schema, rename
  planning and application, and file-oriented workflow rules.
- `mpx` owns mpv behavior: prompts, key bindings, uosc menus, OSD, playback
  state, and refreshing the active playlist item after an asurf operation.
- `uview` owns preview hosting: nnn/FIFO dispatch, tabbed embedding, and mpv
  process lifecycle.

Do not duplicate filename-tag rules in Lua when a stable non-interactive asurf
API can provide them. Lua is the adapter from mpv UI events to that API.

## Change rules

- Keep `mpv.conf`, `input.conf`, and `script-opts/` declarative and focused on
  profile composition.
- Keep first-party mpx code separate from imported scripts. Record imported
  code's upstream source, pinned version or commit, license, and local patch
  status before upgrading it.
- Do not use vendor self-updaters or floating `HEAD` updates in the live
  profile. Review and promote vendor changes deliberately.
- Preserve existing bindings unless the requested workflow explicitly changes
  them. Menu comments in `input.conf` are part of the uosc Analysis menu.
- Use argument-vector subprocess calls from Lua; never concatenate prompt text
  into shell commands.
- Do not move or delete live scripts as part of documentation or planning work.
  Migrate with compatibility shims and a verified rollback path.

## Testing and promotion

- Test asurf tag behavior in temporary filesystem fixtures first.
- Test mpx adapter behavior with Lua/mpv mocks and a fake asurf executable.
- Test bindings in headless mpv with temporary media and IPC/key events.
- Test uview transitions in the real desktop session. Static or headless tests
  do not prove tabbed embedding, focus, or preview behavior.
- Develop through a separate `mpx-dev` profile that loads worktree sources
  directly. Promote reviewed files into `mpx`; do not copy files manually for
  each test iteration.

See `.AGENTS/mpx-development.md` for the staged plan and proposed interfaces.
