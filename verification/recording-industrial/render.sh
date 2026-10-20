#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
preview_dir="$(mktemp -d /tmp/minutes-instrument.XXXXXX)"
xcrun swiftc -emit-library -emit-module -module-name MinutesCore Sources/MinutesCore/*.swift \
  -o "$preview_dir/libMinutesCore.dylib" -emit-module-path "$preview_dir/MinutesCore.swiftmodule"
for probe in probe motion interaction; do
  xcrun swiftc -I "$preview_dir" -L "$preview_dir" -lMinutesCore \
    -Xlinker -rpath -Xlinker "$preview_dir" \
    Sources/Minutes/RecordingLevels.swift Sources/Minutes/RecordingView.swift \
    "verification/recording-industrial/$probe.swift" -o "$preview_dir/$probe"
  "$preview_dir/$probe"
done
