# Direct Libre validation

## First device checkpoint: NFC separation

This branch currently contains a structural phone refactor only. Direct Watch
switching, Watch collection and the prototype's optional features are not yet
integrated. They remain scheduled in [the roadmap](DirectLibreRoadmap.md).

### Changes under review

- `CGMLibre2Transmitter+NFC.swift` contains the original NFC session entry and NFC
  delegate methods. Only the phone target compiles this file.
- `CGMLibre2Transmitter.swift` retains BLE handling. Its phone scan entry forwards
  to the NFC extension, while the separate BLE entry still calls the superclass.
- The old empty non-CoreNFC placeholder is removed. This exposes the implementation
  for future sharing; the remaining phone dependencies are not yet decoupled.
- Six stored members become module-visible for the companion extension. Their
  storage and lifecycle are unchanged; no new state machine is introduced.
- Project edits only register the extension in the existing Libre2 group and
  phone Sources phase. Watch target membership and shared schemes are unchanged.

### Validation completed

- Compared all 24 original method bodies with develop: equivalent after accounting
  for the renamed NFC entry point and the iOS-only cleanup guard.
- Confirmed byte-identical NFC engine/delegate, generic Bluetooth lifecycle,
  unlock crypto and parsing utilities.
- Checked NFC target membership and project plist validity.
- Parsed the two transmitter files using the iOS and watchOS SDKs.
- Typechecked the actual transmitter, extension and NFC/Libre delegates against
  both SDKs with compile-only stand-ins for other app dependencies. This checks
  file access and conditional compilation, not full-app compatibility or radio
  behaviour. The stand-ins are validation artefacts outside the project.

Unmodified generic iPhone/Watch builds fail in existing extension macro expansion:
Xcode's plugin sandbox cannot start in the agent's execution environment. The
post-refactor iPhone build encounters the same blocker. Agent-driven full builds
and hosted XCTest execution remain unavailable. The user subsequently confirmed
a successful build in Xcode and the phone checks below on a clean installation.
Detailed logs and the one-off audit scripts are in the workspace's sibling
`validation/integrated-develop` directory, outside the source checkout.

### Device result and upgrade finding

The user confirmed that this checkout builds in Xcode and that ordinary NFC
scanning, fresh readings, cancellation/retry and reconnection work after removing
the installed app and installing this version. This clears the first phone device
checkpoint for a clean installation. It does not establish upgrade compatibility.

Installing over the previous Direct Libre prototype initially caused immediate
sensor disconnection. Collection had already been returned to the phone and the
Watch collector stopped. The saved state and failing trace were not captured
before removal, so the exact cause cannot be confirmed retrospectively.

Code inspection identified a specific credential mismatch that could explain it:

- The prototype's experimental NFC reset can persist a non-default unlock code
  in `UserDefaults.standard.libreActiveSensorUnlockCode`.
- Develop's `LibreNFC` provisions streaming with the fixed code `42`.
- Develop's BLE transmitter uses the saved unlock code; its NFC-success callback
  resets the counter but does not replace that code.
- With a non-default value left by the prototype, the two paths therefore use
  different credentials. Without that saved override, the getter returns `42`.

The integration must keep NFC-provisioned and BLE-used credentials consistent.
Carry this into the configuration/persistence work and add a retained-non-default-
code regression case. Distinguish normal upstream upgrades from the experimental
prototype transition; do not add a broad data wipe or make reinstallation part
of the supported workflow. No scan behaviour or recovery code was changed in
response to this report.

### Physical-device checks

Before replacing an installed prototype, return collection to the phone and stop
Direct Libre collection on the Watch. This intermediate branch does not contain
switching or revocation logic and cannot manage the old Watch collector.

Use your normal signing team and app-group setup. First confirm an unmodified
`develop` build on the device if it has not been tested on this setup. Then test
this branch with the same sensor and settings:

1. Build and launch the phone app; ensure the ordinary relayed Watch app builds.
2. Run the ordinary Libre NFC scan. Confirm the expected identity and existing
   messages, followed by BLE connection and fresh glucose readings.
3. Observe several subsequent readings, graph updates and the configured upload
   or sharing path. No new Direct Libre UI should appear at this stage.
4. Cancel a scan and retry through the ordinary interface. Compare with develop;
   the refactor intentionally does not fix pre-existing scan/retry behaviour.
5. Reopen the app and test normal reconnection after a brief signal loss. Confirm
   subsequent readings rather than relying only on Bluetooth's connected state.
6. Report build errors or a behavioural difference before the next milestone.

### Build locations

Upstream's Debug and Release project settings have empty OBJROOT and SYMROOT.
They are intentionally not changed by the NFC refactor. For command-line checks,
provide absolute output locations along with DerivedData, for example from the
checkout root:

```sh
xcodebuild -project xdrip.xcodeproj -scheme xdrip \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/xdrip-integrated-check \
  OBJROOT=/tmp/xdrip-integrated-check/Build/Intermediates.noindex \
  SYMROOT=/tmp/xdrip-integrated-check/Build/Products \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Use the `xDrip Watch App` scheme and `generic/platform=watchOS` for the Watch.
The unsigned command checks compilation only; device installation requires your
usual signing setup. In Xcode, review the project Build Locations before building
if output resolves to `/Debug-iphoneos`; use local output locations rather than
committing personal paths. Keep signing and local Xcode settings out of feature
commits.

## Shared protocol checkpoint

The parser now accepts `Libre2BLEUtilities.ParserState` explicitly. A phone-only
`Libre2BLEUtilities+UserDefaults` overload preserves the existing history keys and
phone call site. It saves changed state after parsing; repeated frames leave the
cache untouched. Each frame now uses one timestamp anchor rather than sampling
`Date()` separately for every historical value.

The original database-array helpers and logged FRAM helpers have moved into
`Array+BgReading` and `LibreSensorType+Data`. Their bodies are unchanged. The
UInt16 time-formatting helper moved beside its Int implementation so byte helpers
can compile without UI constants. Unused log declarations were removed from
crypto/protocol files. No duplicate crypto or glucose algorithm was introduced.

Validation:

- 10 committed `Libre2ProtocolTests` pass in a temporary macOS host package using
  actual production protocol, calibration, model and array source files. Only
  the relevant real phone UserDefaults accessors are extracted to avoid importing
  the whole app; Foundation persistence is not mocked.
- All 176 captured upstream frames match develop in both calibrated and raw
  modes: decrypted bytes, glucose values, sensor ages and retained history.
  Timestamp comparisons allow elapsed execution time between the two parsers.
- The complete 12-file shared protocol dependency closure typechecks for iOS 16.2
  and watchOS 10.0 with their real SDKs and no stand-in types.
- Database/FRAM helper extraction was checked against the original method bodies.

Test/audit runners and logs live outside the checkout in
`validation/integrated-protocol`. The committed tests are registered with the
existing `xdripTests` target. No Watch source membership or connection behaviour
changes are made at this checkpoint. A full device build and ordinary readings
check remain necessary after these edits.

### NFC credential consistency

The NFC delegate now reports the unlock code sent by the scan. On success the
phone stores that code before resetting the unlock counter; on failure it leaves
both values unchanged. NFC commands still use the original code `42`, and scan
ordering, cancellation/retry, messages and Bluetooth reconnection are unchanged.
This closes the code mismatch identified after the prototype installation, but
does not retrospectively prove the cause of that particular disconnection.

Three host checks passed for the actual result-handler body: replacing a retained
prototype code after success, preserving credentials after failure, and adopting
a reported non-default code. The next unlock payload uses the reported code plus
counter one. These checks extract the handler for macOS execution with a logging
stand-in and real Foundation preferences; they do not simulate CoreNFC or BLE.
The updated transmitter/NFC delegate boundary also passes limited SDK typechecks.

For the next physical checkpoint, install over the current working installation
without deleting its data. Check several readings and graph updates before and
after an ordinary NFC scan, cancellation/retry, and reconnection. If immediate
disconnection recurs, retain the failure log before resetting or reinstalling.
The Watch remains the ordinary upstream relayed app until the next milestone.
