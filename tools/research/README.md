# Phase 0 Training evidence replay

- Status: temporary, nonshipping Phase 0 evidence
- Source checkpoint: `90dcd45ffcde4a45aac80d192cc4c6553cafc972`
- Deletion gate: use these captures to author the first D3Import red assertions, then delete this directory before production import implementation begins

These commands require the ignored owned file `retail-data/descent3/missions/training.mn3`, the existing legacy reference build, and a local pilot. They never produce canonical content and none of these files enter a product target. Run from the repository root. Keep all captures and temporary content ignored.

## Raw Training audit

```sh
rtk mkdir -p runtime-data/revival-evidence
rtk ruby tools/research/training_d3l_audit.rb \
  retail-data/descent3/missions/training.mn3 \
  | rtk tee runtime-data/revival-evidence/training-d3l-audit.txt
rtk shasum -a 256 runtime-data/revival-evidence/training-d3l-audit.txt
```

Expected capture SHA-256: `d20d6c34a5ac9f20eee3c500648d9a4514de668ad6af9984f7f8ce1e534e6ea4`.

## Post-load runtime capture

The additional-directory order below is intentional and matches the retained capture: the Debug build directory first, then the owned retail root.

```sh
(
  set -euo pipefail
  repo="$(pwd -P)"
  patch="$repo/tools/research/training_reference_runtime_trace.patch"
  cleanup() {
    if rtk git apply -R --check "$patch"; then
      rtk git apply -R "$patch"
    fi
  }
  trap cleanup EXIT HUP INT TERM

  rtk mkdir -p "$repo/runtime-data/revival-evidence/cache"
  rtk git apply "$patch"
  rtk cmake --build builds/mac --target Descent3 -j 8
  (
    cd "$repo/builds/mac/build/Debug"
    rtk proxy ./Descent3.app/Contents/MacOS/Descent3 \
      -additionaldir "$repo/builds/mac/build/Debug" \
      -additionaldir "$repo/retail-data/descent3" \
      -windowed -Width 640 -Height 480 \
      -nointro -nonetwork -nomousegrab \
      -pilot codex -mission training.mn3 -loadlevel 1 \
      -tempdir "$repo/runtime-data/revival-evidence/cache" \
      -revivalroomtrace
  ) 2>&1 | rtk tee "$repo/runtime-data/revival-evidence/training-room-runtime-trace.log"

  cleanup
  trap - EXIT HUP INT TERM
  rtk git diff --exit-code -- Descent3/Mission.cpp Descent3/gamesequence.cpp
)
```

Retained capture SHA-256: `349e68ed340e8f18cd4a8b86193ea11b4b54b4dcffa38b648f154525f9b737dd`. The instrumented binary used for it had SHA-256 `269cd2250124fed581938e651063db631cb1f0e5da885aded480496cc3ed4a44`. A replay compares the `REVIVAL_*` records semantically and receives a new byte hash because the surrounding log contains timestamps, thread IDs, and absolute paths.

The `codex` pilot is a local launch prerequisite, not product data. The room/topology/object result is independent of its selected ship.

## Eager-dependency capture

This capture uses the same directory order and local pilot. Its summary must report `ship_index=0`; another ship is a different historical eager baseline.

```sh
(
  set -euo pipefail
  repo="$(pwd -P)"
  patch="$repo/tools/research/training_reference_dependency_trace.patch"
  cleanup() {
    if rtk git apply -R --check "$patch"; then
      rtk git apply -R "$patch"
    fi
  }
  trap cleanup EXIT HUP INT TERM

  rtk mkdir -p "$repo/runtime-data/revival-evidence/cache"
  rtk git apply "$patch"
  rtk cmake --build builds/mac --target Descent3 -j 8
  (
    cd "$repo/builds/mac/build/Debug"
    rtk proxy ./Descent3.app/Contents/MacOS/Descent3 \
      -additionaldir "$repo/builds/mac/build/Debug" \
      -additionaldir "$repo/retail-data/descent3" \
      -windowed -Width 640 -Height 480 \
      -nointro -nonetwork -nomousegrab \
      -pilot codex -mission training.mn3 -loadlevel 1 \
      -tempdir "$repo/runtime-data/revival-evidence/cache" \
      -revivaldependencytrace
  ) 2>&1 | rtk tee "$repo/runtime-data/revival-evidence/training-dependency-trace.log"

  cleanup
  trap - EXIT HUP INT TERM
  rtk git diff --exit-code -- Descent3/Mission.cpp Descent3/gamesequence.cpp
)
```

Retained capture SHA-256: `32aada64f1ccdbdc9f37289806ab986edb91b3c2c342b885a9ae22e09a8ac2aa`. The instrumented binary used for it had SHA-256 `49be8216c866304d4d4a98c03e627cf16d0c05ed3644f8596aa5bdfb277d98b9`. A replay compares the `REVIVAL_*` records semantically and receives a new byte hash because the surrounding log contains timestamps, thread IDs, and absolute paths.

After either runtime probe, rebuild the clean reference source if that local binary will be used again. The repository closure check is the source diff command above; build products and captures remain ignored.
