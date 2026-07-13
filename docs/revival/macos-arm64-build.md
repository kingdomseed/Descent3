# Legacy M4 reference build

- Status: archived procedure
- Last verified: July 13, 2026
- Authority: non-normative; not a product build

## Purpose

This procedure rebuilds the released C++ engine when a specific format or campaign question requires an executable reference. The Swift/Metal product does not use CMake, vcpkg, SDL, OpenGL, this application bundle, or its generated script modules.

Do not run this build as a prerequisite for ordinary product work. The current architecture and roadmap start from a new Swift workspace.

## Reference environment

- Mac mini `Mac16,10`
- Apple M4, 10 CPU cores, 10 GPU cores
- 16 GB unified memory
- macOS 26.5.2
- Xcode 26.6 and AppleClang 21
- source commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`

## Tools

The legacy Brewfile supplied CMake, Ninja, and pkg-config. Verified versions were:

```text
CMake 4.4.0
Ninja 1.13.2
pkg-config 2.5.1
AppleClang 21.0.0
```

Historical installation command:

```sh
rtk proxy /opt/homebrew/bin/brew bundle install
```

These tools are not selected for the new Swift product.

## Pinned vcpkg

The reference build used an external checkout pinned to the manifest baseline:

```sh
rtk mkdir -p /Users/jasonholt/.cache/descent3
rtk git clone --filter=blob:none https://github.com/microsoft/vcpkg.git /Users/jasonholt/.cache/descent3/vcpkg
rtk git -C /Users/jasonholt/.cache/descent3/vcpkg checkout --detach 84bab45d415d22042bd0b9081aea57f362da3f35
rtk proxy /Users/jasonholt/.cache/descent3/vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

The legacy manifest resolved SDL3 3.2.6, cpp-httplib, glm, plog, zlib, GoogleTest, and transitive dependencies.

## Configure, build, test, and install

Run from the repository root:

```sh
rtk proxy env PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin VCPKG_ROOT=/Users/jasonholt/.cache/descent3/vcpkg /opt/homebrew/bin/cmake --preset mac --fresh -DVCPKG_TARGET_TRIPLET=arm64-osx -DCMAKE_OSX_ARCHITECTURES=arm64 -DBUILD_TESTING=ON -DENABLE_LOGGER=ON -DFORCE_PORTABLE_INSTALL=ON
rtk proxy env PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin VCPKG_ROOT=/Users/jasonholt/.cache/descent3/vcpkg /opt/homebrew/bin/cmake --build --preset mac --config Debug --verbose
rtk proxy env PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin /opt/homebrew/bin/ctest --preset mac -C Debug
rtk proxy env PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin /opt/homebrew/bin/cmake --install builds/mac --config Debug
```

Verified result:

```text
Build: 532/532 steps completed
Tests: 12/12 passed
Architecture: arm64
```

Outputs:

```text
builds/mac/build/Debug/Descent3.app
builds/mac/build/Debug/d3-osx.hog
builds/mac/installed/Descent3.app
builds/mac/installed/d3-osx.hog
builds/mac/installed/netgames/
builds/mac/installed/online/
```

## Local source corrections

Xcode 26.6 rejected `fix/fix.h` because it used global `size_t` without including its defining header. The working tree adds `<cstddef>` and uses `std::size_t`.

The working tree also keeps the POSIX signal handler async-signal-safe. The historical handler attempted logging, SDL cleanup, and `sync()` after a signal; an interrupted log write could deadlock recursively on the logger mutex. The correction exits directly with status `128 + signal`. The installed reference build exited with status 143 after `SIGTERM`.

These are local legacy-reference fixes. They are unrelated to the Swift product architecture.

## Running against owned data

The ignored retail tree and reference helper remain available for focused research:

```sh
rtk proxy tools/run-descent3-macos --check
rtk proxy tools/run-descent3-macos -windowed -width 1280 -height 720 -nointro
```

The helper mounts ignored retail files and the generated `d3-osx.hog` through the old engine's `-additionaldir` option. The Swift game will not use that lookup path. It will start from a canonical package produced by `D3Import`.

Normal player data for the reference executable goes to `~/Library/Application Support/Outrage Entertainment/Descent 3/`. That location and the old application's signing state do not define the new application's identity or storage.

## Packaging limit

The local legacy install has a linker-generated ad hoc signature and fails strict bundle verification because its resources are not sealed. Upstream's delivery workflow performs full signing, notarization, and DMG packaging.

Do not package or distribute this reference application as the Revival product. The future Swift application receives its own bundle identity, signing, notarization, and import experience.
