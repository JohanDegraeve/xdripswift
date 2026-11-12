# GS1 Chinese wire protocol — isolated component

Port of public GPL-3.0-or-later JugglucoNG `11e6e29db7d9055c8fd2e96261812e16f2095f3d`, files `SibionicsProtocol.kt`, `SibionicsConstants.kt`. Raw signals are not glucose. No Bluetooth operation, sensor activation, local app database write or Trio publication occurs in this package.

Implemented: strict MAC/code parsing, per-sensor sensitivity without default, AA55 request/parser, fragmented-response assembly, ordered history gate. Explicit Chinese variant selection remains an app-level requirement: AA55 does not identify algorithm115G versus116A.

V120 challenge is recognized and rejected as an unsupported data transport. The Kotlin V120 sample-count parser and the newer C++ packet-tail/reindex contract differ; no V120 glucose decoding is enabled without verifying real frame layout. A raw status word is retained as opaque data; no invented healthy-status whitelist is applied.

The first AA55 request may start an unused sensor, so app integration must issue it only after an explicit user action. No reset or extension operation is implemented in this wire component. The full stateful115G algorithm, warmup/time/quality gates, persistent identity-bound checkpoint, BLE background lifecycle and app integration are separate components.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
