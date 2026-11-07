# xDripSwift fork — working notes

Fork of `JohanDegraeve/xdripswift` that adds **Sibionics 1 and Sibionics 2** CGM support,
ported from `ctqvva/JugglucoNG` (GPL-3.0, see `THIRD_PARTY_NOTICES.md`). JugglucoNG is the
reference for every Sibionics behaviour: when in doubt, read its code
(`Common/src/main/java/tk/glucodata/drivers/sibionics/`, `.../data/calibration/CalibrationMath.kt`)
and match it rather than inventing. User-facing docs: `docs/sibionics2-troubleshooting.md`.

## Build and verification

- No Swift/Xcode in cloud sessions: code cannot be compiled or tested locally. Build and tests run
  only in GitHub Actions (`.github/workflows/build_xdrip.yml`, macOS). Say so when reporting work.
- `Sibionics2Core` is a Kotlin Multiplatform XCFramework (vendored JugglucoNG V116A/V115G stock
  algorithms). CI builds it with `gradle -p Sibionics2Core assembleSibionics2CoreReleaseXCFramework`.
- Before adding numeric test expectations, verify them with a small Python port of the logic
  (done for calibration math, sensitivity decoding, label parsing). Never guess expected values.
- Avoid new source files where possible: adding files requires hand-editing
  `xdrip.xcodeproj/project.pbxproj`. Extending an existing file (e.g. the scanner lives in
  `SwiftUIViews/Sensor/SensorCodeScannerView.swift`) avoids that.
- Localised strings: update `Texts*.swift` defaults **and** `en.lproj` / `uk.lproj` `.strings`.

## Upstream sync

- `git remote add upstream https://github.com/JohanDegraeve/xdripswift.git`, merge `upstream/master`.
- Core Data: the fork keeps its own models `xdrip v33 Sibionics` / `xdrip v34 Sibionics` (needed to
  migrate installed fork builds). The current model is the latest upstream model **plus** the
  `Sibionics2` entity (`sensorVariant` Int16 default 2, relationship `blePeripheral`) and
  `BLEPeripheral.sibionics2` (optional, cascade). When upstream adds a version, create a new fork
  version = upstream latest + those additions, set it current in `.xccurrentversion` and in the
  pbxproj `XCVersionGroup`. Never edit an existing shipped model version.
- After merging, check every `switch` over `BluetoothPeripheralType`, `CGMTransmitterType` and
  troubleshooting sources lists both upstream's new cases and `Sibionics1Type`/`Sibionics2Type`/
  `.sibionics2`. The peripheral-loading loop in `BluetoothPeripheralManager` must
  `break bluetoothPeripheralTypeLoop` after the shared Sibionics entity (S1 and S2 share it;
  without the break each sensor is listed twice and two transmitters fight over one link).

## Sibionics architecture (`xDrip/BluetoothTransmitter/CGM/Sibionics2/`)

- One transmitter `CGMSibionics2Transmitter` for both variants (`SibionicsDeviceVariant`).
  BLE service FF30, notify FF31, write FF32 (prefer acknowledged writes: the 26-byte auth packet
  exceeds a 20-byte ATT payload). Also reads Device Information `180A` and Battery `180F`.
- **V120** (Sibionics 2, EU/Hematonix S1): RC4-encrypted handshake auth → activation → time sync
  → data request → streaming. Key groups Eco/Sijoy/Hematonix rotate when auth gets no answer
  (5 s); the group that produced readings is saved and tried first; order is frozen per connection.
  Streaming is pushed by the sensor — **no polling timer** (the user removed it on purpose).
- **Chinese S1** (AA55 plaintext): must be asked every 60 s (protocol requirement, not a setting),
  every 30 s until the first page. An AA55 07 echo or saved mode confirms Chinese; only the V120
  marker or no answer switches to V120.
- **Bluetooth MAC for auth**: iOS has no MAC API. Sibionics 2 publishes it in Device Information
  serial `2A25` as six raw bytes, least significant first (`32 5B D1 B0 71 C7` = `C7:71:B0:D1:5B:32`).
  Candidates (detected, unverified, zero) rotate one per connection; the one that yields readings
  is saved. A manual override always wins. Auth waits up to 3 s for Device Information.
- **Algorithm**: V116A for Sibionics 2 and EU/Hematonix, V115G for Chinese S1. Unusable minutes
  advance the cursor (do not filter by temperature/impedance — that stalled history).
- **Sensitivity**: S2 = probe code (14 chars) → label short code → BLE name → `0316015A`.
  S1 = label short code → `deriveShortCode(BLE name)` → family fallback
  (EU `YMWD016F` 1.58, Hematonix `YEZ1450H` 1.47, Chinese `GEPD802J` 1.27) → 1.27.
  GS1 label scanning (`SibionicsSensorLabel`) follows JugglucoNG `SibionicsRegistry`.
- **Lifetime / warm-up**: S1 = JugglucoNG `EXTENDED_CHINESE_LIFETIME_MS` (572 h − 19 min,
  `Sibionics1SensorProfile`), label 14 days; S2 = 23 days. `sensorWarmupDurationInMinutes()` is 0
  (JugglucoNG has no Sibionics warm-up; xDrip's 45-min default hid a new sensor's readings).
- **Name**: S1 and S2 share `CGMTransmitterType.sibionics2` (persisted raw value). Use
  `CGMSibionics2Transmitter.productName` / `SibionicsDeviceVariant.productName` wherever the
  product name is shown (active sensor description, Activity Log source, Loop, reports).
- **Reset**: manual for all variants (S2 encrypted `0x10`, EU/Hematonix `24 E7 6F 34`,
  Chinese `AA 55 10 F1`); automatic only for Sibionics 2. The post-reset session probe is one-shot.
- **Calibration** (`xDrip/Calibration/Sibionics2Calibrator.swift`): xDrip+ or JugglucoNG
  `CalibrationMath` (weighted OLS default, median slope, robust, elastic, ensemble) with
  Fresh/Balanced/Stable weighting, evaluated in the user's display unit. Mode raw value 1 must stay
  weighted OLS.

## Experimental features (`docs/experimental-features.md`)

Settings → Experimental features (`SettingsRootSection.experimental`,
`xDrip/SwiftUIViews/Settings/ExperimentalSettingsView.swift`). Models in
`xDrip/Managers/Therapy/ExperimentalTherapy.swift`: JugglucoNG `GlucosePredictionKernel` +
treatment model, `JournalInsulinCurveCatalogue` (22 insulins), `InsulinActivityStack`.
Drawn only on the Home main chart via `GlucoseChartView.experimentalPlots(_:)`; the chart types
it needs live in `GlucoseChartView.swift` because that file is also compiled into the widget,
watch and notification extensions. A treatment's insulin is named in its `notes`
(`InsulinProfile.matching(notes:)`); every per-dose choice must round-trip through its
`shortName`. All off by default; IOB/COB is untouched.

## Not ported (yet)

JugglucoNG alternative glucose models (Balanced, Responsive, Adaptive V2), manual sensitivity
override, GS3 variant.

## Git

Develop on the session's designated branch; a merged PR is finished — restart the branch from
`master` for follow-up work. Do not push to `master` unless the user asks.
