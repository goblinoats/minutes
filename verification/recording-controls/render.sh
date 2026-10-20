#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
probe_dir="$(mktemp -d /tmp/minutes-key.XXXXXX)"
xcrun swiftc -emit-library -emit-module -module-name MinutesCore Sources/MinutesCore/*.swift -o "$probe_dir/libMinutesCore.dylib" -emit-module-path "$probe_dir/MinutesCore.swiftmodule"
cat Sources/Minutes/RecordingView.swift verification/recording-controls/probe.swift > "$probe_dir/KeyPreview.swift"
xcrun swiftc -I "$probe_dir" -L "$probe_dir" -lMinutesCore -Xlinker -rpath -Xlinker "$probe_dir" Sources/Minutes/RecordingLevels.swift Sources/Minutes/RecordingIndicator.swift Sources/Minutes/InterfaceStyle.swift "$probe_dir/KeyPreview.swift" -o "$probe_dir/probe"
"$probe_dir/probe"
