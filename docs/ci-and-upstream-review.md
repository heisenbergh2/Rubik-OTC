# CI and upstream review — 2026-09-07

## Observed failures at 9430ac3

- Linux, run 34078471007: link fails on `Platform::getMacAddresses()`.
- macOS, same run: cpp-httplib imports CFNetwork/CoreFoundation and Apple's
  legacy `Size`, `Point`, `Rect` collide with client geometry aliases.
- Browser, same run: `browser/include/lua51/liblua.a` is absent, with no build rule.
- Android, run 34078471009: final Gradle failure is missing AndroidManifest.xml.
  Kotlin Activity/input bridge and XML resources were also absent. The IPO probe
  emits LLVMgold errors but is not the final cause of that run's failure.

Android sources are adapted from opentibiabr/otclient at
`dd5641492a71e966b96b8a91398b44bb3df67d88`, under the upstream MIT license.
Existing JNI symbols use com.otclient; generated binding namespace remains
com.github.otclient. XML ignore exceptions prevent recurrence. Application
backup is disabled; device launch, input and audio still require runtime tests.

## Cache and build-time decisions

GitHub reported 23 caches / 11,170,547,834 bytes during this review. This is
stored cache evidence, not a measured speedup. Keep compiler cache snapshots
incremental, but stop uploading identical complete vcpkg dependency snapshots
after every successful source-only build. Failed builds retain partial-package
snapshots; only successful builds produce the stable complete key. vcpkg still
checks each package ABI, including compiler identity. No unsafe compiler-cache
sloppiness, optimization-level reduction or release-feature removal is used.

Enable ccache for C as well as C++. Keep conservative parallelism until peak
memory is measured; large unity translation units can exhaust runners when
parallelism is raised blindly. Gradle dependencies use a stable configuration
key instead of a unique snapshot for every run.

One workflow with independent matrix jobs is valid and already runs platforms
in parallel (`fail-fast: false`). Manual dispatch now permits selecting one
platform. Splitting into three files is an organizational choice, not a build
speed improvement. If split later, prefer thin callers to a reusable workflow.

## PR triage (not an automatic merge list)

- https://github.com/opentibiabr/otclient/pull/1794 — high-priority candidate:
  invalidates negative Lua event lookup caches when handlers are connected.
  RubikOTC retains the old `m_events` logic. Requires regression tests covering
  late class handlers, instance handlers and inventory old/new item arguments.
  Not yet imported; not proven to explain the reported login freeze.
- https://github.com/opentibiabr/otclient/pull/1824 — less incremental benefit:
  RubikOTC already compiles AUTO_STAT out unless ENABLE_STATS is set. Do not
  replace that with unconditional runtime argument formatting.
- https://github.com/opentibiabr/otclient/pull/1825 — review for HTTPS correctness;
  the user's current localhost HTTP endpoint does not establish this as the
  cause of their world-login problem.
- https://github.com/opentibiabr/otclient/pull/1819 — walking cooldown candidate;
  compare against RubikOTC's existing movement fixes before porting.
- https://github.com/Mateuzkl/AstraClient/pull/144 — useful browser architecture
  reference, but a large unmerged port, not a drop-in patch. Its Lua 5.1 goto
  parser changes require error-recovery, scope/upvalue and reentrancy tests.
  Simply building stock Lua 5.1 would still reject RubikOTC's goto-bearing modules.
- https://github.com/Mateuzkl/AstraClient/pull/132 and
  https://github.com/Mateuzkl/AstraClient/pull/133 — open alternative HD minimap
  implementations; large changes to format, persistence and rendering. Evaluate
  separately, preserving classic minimap compatibility and memory budgets.
- https://github.com/Mateuzkl/AstraClient/pull/140 — closed without merge; do not
  assume this is an accepted, validated lifetime fix.

## Validation still required

### Live Windows login inspection (2026-09-07)

The downloaded client reached pending-game, enter-game acknowledgement and
completed game-start callbacks with a 64-byte asset identifier. Its log then
stopped, including the map transition timeout. Non-invasive CDB inspection of
PID 12568 found the main thread pacing frames and all three pool workers waiting
on an empty task queue. This strongly suggests the long-running map/event task
had exited; the original exception is not recoverable from those stacks alone.
The executable was distributed without its matching PDB, so exported-symbol
names in those stacks must not be treated as real function names.

The map/event loop now reports an uncaught exception and its processing phase
through the existing fatal logger rather than leaving a silent frozen window.
Parallel drawing and tile preparation retrieve their futures after waiting for
all workers, so worker exceptions are not discarded. Windows PDBs are uploaded
separately from the player download, with 14-day retention.

This fixes missing diagnostics, not a confirmed underlying login/rendering
error. A new build and reproduction are required to identify that error. No
game assets or server configuration were changed during this inspection.

Build fixes are candidates until new Actions results, artifacts and cache hits
are checked. Browser Lua integration remains unresolved. A green compile is
not evidence of successful login/rendering, Android device launch, or HD map
correctness. No upstream contribution is opened before those validations.
