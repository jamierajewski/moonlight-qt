# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Moonlight PC is an open-source game streaming client for NVIDIA GameStream and Sunshine. It's a C++17/Qt (QML) desktop application that receives video/audio streams from a host PC and renders them locally with hardware-accelerated decoding. Targets Windows, macOS, Linux, Steam Link, and embedded ARM devices.

## Build Commands

### Prerequisites
- Qt 6.7+ SDK (Qt 5.12+ also supported on Linux; replace `qmake6` with `qmake`)
- Submodules: `git submodule update --init --recursive`
- Platform-specific deps listed in README.md

### Building (Linux/macOS development)
```bash
qmake6 moonlight-qt.pro
make debug    # or: make release
```
The binary lands at `app/moonlight`.

### Build variants
```bash
# Embedded (single-purpose device, no windowed mode)
qmake6 "CONFIG+=embedded" moonlight-qt.pro

# Prefer DRM direct rendering over GL/Vulkan on slow GPUs
qmake6 "CONFIG+=gpuslow" moonlight-qt.pro

# Disable specific features at qmake time
qmake6 "CONFIG+=disable-ffmpeg" moonlight-qt.pro
qmake6 "CONFIG+=disable-libva" moonlight-qt.pro
```

### Windows
Use `scripts/build-arch.bat` and `scripts/generate-bundle.bat` from a Qt command prompt with MSVC. Requires Visual Studio 2022.

### macOS
Use `scripts/generate-dmg.sh` with Qt's `bin` in `$PATH`.

### Steam Link
Set `STEAMLINK_SDK_PATH`, then run `scripts/build-steamlink-app.sh`.

## Build System

qmake-based (`moonlight-qt.pro`). The top-level `.pro` is a `SUBDIRS` template that builds four libraries in parallel, then the app:
- `moonlight-common-c` -- C streaming protocol library (git submodule)
- `qmdnsengine` -- mDNS discovery (git submodule)
- `h264bitstream` -- H.264 bitstream parser (git submodule)
- `AntiHooking` -- Windows-only DLL injection protection
- `app` -- the main application (depends on all of the above)

Feature detection is done via `CONFIG += <feature>` flags that are set conditionally based on `packagesExist()` checks in `app/app.pro`. Each feature guard (`ffmpeg`, `libva`, `libdrm`, `libplacebo`, `cuda`, `config_EGL`, `config_SL`, `wayland`) controls which source files are compiled and which `DEFINES` (e.g. `HAVE_FFMPEG`, `HAVE_DRM`, `HAVE_LIBPLACEBO_VULKAN`) are set.

## Architecture

### Streaming Pipeline (`app/streaming/`)

**Session** (`session.h/cpp`) is the central orchestrator. It owns the decoder, audio renderer, input handler, and overlay manager. It provides static C callbacks to `moonlight-common-c`'s Limelight API (`clStageStarting`, `drSetup`, `drSubmitDecodeUnit`, `arInit`, etc.) which forward to the singleton `s_ActiveSession`.

**Video decoding** follows a two-tier decoder/renderer pattern:
- `IVideoDecoder` (`decoder.h`) -- top-level interface. `FFmpegVideoDecoder` (`ffmpeg.h/cpp`) is the primary implementation; `SLVideoDecoder` is Steam Link-specific.
- `IFFmpegRenderer` (`ffmpeg-renderers/renderer.h`) -- rendering backend interface. FFmpegVideoDecoder selects a backend+frontend renderer pair during initialization via a multi-pass probe:
  - **Backend renderers** (hwaccel): VAAPI, VDPAU, CUDA, D3D11VA, DXVA2, DRM, VideoToolbox, Vulkan (libplacebo)
  - **Frontend renderers** (presentation): SDL, EGL, DRM direct, Vulkan, Metal, MMAL, D3D11VA
  - Selection logic is in `tryInitializeHwAccelDecoder()` / `tryInitializeNonHwAccelDecoder()` with fallback passes

**Pacer** (`ffmpeg-renderers/pacer/`) handles frame pacing and vsync. Platform-specific vsync sources: DX (Windows), Wayland.

**Audio** (`streaming/audio/`): `IAudioRenderer` interface with SDL and Steam Link implementations.

**Input** (`streaming/input/`): `SdlInputHandler` manages gamepad, keyboard, mouse, and touch input through SDL. Split across `gamepad.cpp`, `keyboard.cpp`, `mouse.cpp`, `abstouch.cpp`, `reltouch.cpp`.

### Backend (`app/backend/`)

Manages host PC discovery, pairing, and communication:
- `ComputerManager` -- orchestrates mDNS discovery and polling of known hosts
- `NvHTTP` -- HTTPS/HTTP API client for GameStream/Sunshine server info, app listing, pairing, launch/quit
- `NvComputer` -- model representing a discovered host PC
- `IdentityManager` -- client certificate/key management for pairing
- `BoxArtManager` -- caches game box art images

### GUI (`app/gui/`)

Qt Quick/QML UI. Entry point is `main.qml` with views:
- `PcView.qml` -- host PC list (discovery, add, pair, delete)
- `AppView.qml` -- app list for a selected host
- `SettingsView.qml` -- streaming preferences
- `StreamSegue.qml` / `QuitSegue.qml` -- stream launch/quit flows
- `GamepadMapper.qml` -- controller mapping

C++ models exposed to QML: `ComputerModel`, `AppModel`. Gamepad navigation: `SdlGamepadKeyNavigation`.

### Settings (`app/settings/`)

`StreamingPreferences` -- singleton (per QML engine) that persists all user-facing settings via `QSettings`. Enum values are stable (new entries appended at end to preserve existing user prefs). Exposed to QML via Q_PROPERTY.

### CLI (`app/cli/`)

Command-line interface for headless operation: `pair`, `startstream`, `quitstream`, `listapps`. Parsed by `CommandLineParser`.

## Key Conventions

- C++17 standard, Qt 6 preferred (Qt 5.12 compat maintained on Linux)
- Platform-specific code guarded by `#ifdef` on defines set by qmake: `HAVE_FFMPEG`, `HAVE_DRM`, `HAVE_LIBVA`, `HAVE_LIBPLACEBO_VULKAN`, `HAVE_CUDA`, `HAVE_EGL`, `HAVE_MMAL`, `HAVE_DISCORD`, `HAVE_LIBVDPAU`, `HAS_WAYLAND`, `HAS_X11`, `EMBEDDED_BUILD`, `STEAM_LINK`
- macOS rendering uses Objective-C++ (`.mm` files) for VideoToolbox/Metal
- SDL is used for window management, input, and audio -- not for rendering
- `SDL_compat.h` provides compatibility shims between SDL2 and SDL3
- The `moonlight-common-c` submodule provides the streaming protocol; its API is the `Limelight.h` header
- Version string comes from `app/version.txt` (currently 6.1.0)
- Translations managed via Weblate; `.ts` files in `app/languages/`
- Member variables use `m_PascalCase` prefix convention
- Static members use `s_PascalCase`, constants use `k_PascalCase`
