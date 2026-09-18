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
post-refactor iPhone build encounters the same blocker. No successful linked app
build or hosted XCTest run is claimed. Full builds and device checks remain open.
Detailed logs and the one-off audit scripts are in the workspace's sibling
`validation/integrated-develop` directory, outside the source checkout.

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
