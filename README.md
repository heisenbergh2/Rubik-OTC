# RubikOTC

A game client for the Open Tibia Server (protocol 15.30). 

- **Custom Vulkan renderer** - atlas-batched sprite pipeline: one 2D-array atlas,
  content-hash deduplication, chunked storage for oversized textures, and a
  MAILBOX-first presentation mode (uncapped FPS without tearing). The client can
  start in pure-Vulkan mode without ever creating an OpenGL context.
- **Memory-optimized asset lifecycle** - lazy module UI construction, batched GL
  texture deletion, pixel-copy garbage collection with disk reload on first draw,
  heap trimming after the appearances parse, and live memory diagnostics
  (`[mem]` / `[boot]` / `[gc]` log lines).
- **Protocol 15.30 support** with protobuf appearances in
  `assets/things/assets/`.

## Game assets (`assets/things`)

The client assets (sprites/appearances) are **not** part of this repository -
`assets/things/` is gitignored because of its size.

- `assets/things/assets/` - protocol 15.30 assets (`catalog-content.json`,
  protobuf appearances, and sprite sheets), matching the client-nine layout.
- `assets/things/assets.json.sha256` - shared asset identifier used at login.

Cyclopedia Map satellite tiles can be supplied separately if that feature is used.

## Building (Windows)

Requirements: Visual Studio 2022 (v143 toolset), [vcpkg](https://github.com/microsoft/vcpkg)
with `VCPKG_ROOT` set. Dependencies are restored automatically from `vcpkg.json`.

```
msbuild vc18\otclient.vcxproj /p:Configuration=DirectX /p:Platform=x64
```

The executable is produced as `RubikOTC.exe` in the repository root.
Select the renderer with `renderBackend = vulkan` or `gl` in `config.ini`
(also available in-game under Options -> Graphics).

## Building (Linux / Docker / Android)

The upstream CMake build is preserved - see `CMakeLists.txt`, `Dockerfile`
and the scripts in the repository root. The Vulkan renderer is currently
Windows-only; other platforms use the OpenGL path.

## License

Licensed under the MIT License - see [LICENSE](LICENSE).
