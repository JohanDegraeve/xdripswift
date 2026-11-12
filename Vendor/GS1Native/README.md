# GS1Native

This static XCFramework adapts the JugglucoNG V1.1.5G calculation core for use
from Swift. It contains arm64 slices for iOS devices and the iOS Simulator.
The application owns Bluetooth transport, sensor identity, warmup and reading
validation.

The five Kotlin files in [`Source/`](Source/) are the source for both slices.
The core accepts consecutive raw observations and returns a final correction
on the five-minute step. The app can serialize and restore an engine checkpoint
for the same sensor and factory sensitivity. See the
[`SwiftImportSmoke.swift`](Tests/SwiftImportSmoke.swift) example.

## Rebuild

Run from this directory on an Apple Silicon Mac with Xcode and Python 3.8 or
later. Set `DEVELOPER_DIR` if Xcode is installed outside `/Applications/Xcode.app`.

```sh
python3 rebuild.py
```

The recipe downloads Kotlin/Native 2.4.21 and Temurin JDK 21.0.13+9 from their
official releases and checks the pinned SHA-256 values before extracting them
into `build/toolchains/`. Kotlin/Native downloads its platform dependencies
into `build/konan-data/` on first use. The output is
`build/GS1Native.xcframework`. Choose a fresh path with `--output` for repeated
builds. The recipe checks the packaged files for machine-specific paths.

The included build used Xcode 27.0. Archive bytes may vary with the toolchain.
The pinned source and license terms are recorded in [`NOTICE.md`](NOTICE.md).
The framework is distributed with readable license notices in
[`licenses/`](licenses/). Keep the notices and GPL corresponding source
available when redistributing the compiled code.
