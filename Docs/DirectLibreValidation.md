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
changes are made at this checkpoint. The user subsequently reported that all
requested device tests passed, as recorded below.

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

### Second device result

The user reported all requested tests passed after the shared-protocol and NFC
credential changes, including cancellation/retry and reconnection. Automatic
recovery took under 30 seconds, with no manual intervention. This clears the
second phone checkpoint and permits shared Watch collector integration.

This is a measured result for the reported test, not a reconnect-time guarantee.
It does not independently reproduce the old prototype's retained non-default-code
scenario or establish the cause of the earlier installation failure.

## Shared collector checkpoint

`Libre2BluetoothTransmitter` now contains the existing F001/F002 notification,
unlock and 46-byte frame assembly path. Both platform adapters inherit the same
`BluetoothTransmitter` scanning, discovery, connection timeout, peripheral reuse,
disconnection and retry code. No reconnect policy or NFC commands changed here.

The boundary is intentionally small:

- `CGMLibre2Transmitter` retains NFC, the phone CGM interface and reading delegates.
  `Libre2PhoneSensor` uses the existing preferences, calibration guard and parser
  history. Suppressed unlocks still advance the phone counter, as in develop.
- `Libre2WatchSession` carries the session ID, sensor identity/credentials, native
  algorithm parameters and last reserved counter. `Libre2WatchSensor` loads it,
  saves each counter increment atomically before returning an unlock reservation,
  rejects replaced sessions, and owns a separate parser state. No raw-value Watch
  display path is introduced; the session requires matching native calibration.
- `Libre2WatchTransmitter` delivers readings through a main-thread callback. No
  Watch app startup, interface or connectivity handler constructs it yet. Session
  creation/replacement and collector activation will belong to the switching
  coordinator, not to the storage adapter. The stored ID check alone is not an
  ownership protocol or a complete stale-message guard.

Phone consumer-log submissions in `BluetoothTransmitter` are now iOS-only; their
order and entries are preserved. Watch uses system logging. The restoration name
reads the same bundle display-name value directly rather than depending on home
view constants. The shared Libre unlock trace reports the reserved counter;
phone metadata/calibration and generic Bluetooth write traces remain available.
The Watch target includes the shared dependency files and Bluetooth usage text.
This does not introduce a new background execution mode.

### Automated results

- 17 XCTest cases passed in a temporary host package using the actual shared
  collector/protocol sources and actual extracted phone preference accessors:
  10 existing protocol cases plus 7 collector/session cases. The new cases cover
  JSON restoration, persistence before returning an unlock, increment after a
  restart without readings, replaced-session rejection, atomic-save failure,
  exhaustion/overflow, invalid sensor metadata and phone suppression semantics.
  These tests do not simulate the Bluetooth radio or validate a handoff.
- The complete Watch collector and dependency closure typecheck against the real
  watchOS SDK without stand-ins. Phone collector/NFC adaptation also passes an
  iOS SDK typecheck with compile-only stand-ins for unrelated app dependencies.
- Target membership was checked for missing/duplicate dependencies and unintended
  phone/NFC sources in the Watch target. Project plist validation passed.
- Full generic iPhone and Watch builds were attempted. Both still stop in existing
  extension SwiftUI macro expansion because the compiler plugin sandbox cannot
  start here. A complete app build and device execution are not established by
  the scoped compiler checks. Build outputs are under `/tmp`; audit scripts/logs
  are outside the checkout in `validation/integrated-collector`.

### Next physical checkpoint

Build both apps in Xcode. The Watch should retain its ordinary relayed behaviour
and should not request Bluetooth permission merely because these files are now
included. On the phone, install over the last tested integrated build and repeat
ordinary NFC scan/cancel/retry, fresh readings and 2–3 minute signal-loss recovery.
Keep the old prototype Watch collector stopped. Direct Watch collection and its
reconnection test follow after safe phone-controlled activation is implemented.

### Shared collector phone device result

The user confirmed that the phone's NFC, fresh-reading and signal-loss recovery
checks all pass after commit `58f621a8`. This clears the phone regression gate
for the shared collector extraction. No new recovery-time measurement was
reported, and this result does not establish direct Watch collection or switching.

The next implementation checkpoint is phone-controlled switching. The shared
Bluetooth class normally reconnects after a disconnect, so the transaction needs
an explicit collection suspension that guards scanning, reconnects, subscription
and unlock writes, followed by confirmed release before activating the other
device. Preserve the ordinary phone path when the experiment is not in use.
Validate counter changes during preparation, interrupted transactions and NFC
reset before enabling direct collection through the phone's experimental page.

## Phone-controlled switching checkpoint

### Implemented transaction

The phone's Advanced Settings now contains **Direct Libre (Experimental)**.
The page has a device switch, preparation checklist, progress/error text and a
cancel action while a transfer is pending. It requires a connected Libre with a
BLE reading less than three minutes old, matching native-algorithm parameters,
unlock transmission enabled and a reachable Watch before starting a transfer.
No additional refresh requests or background polling are sent by the checklist.
Its state refreshes on readings, reachability changes and page entry; the switch
rechecks freshness when pressed.

Forward transfer:

1. Phone persists a preparation record and sends PREPARE with credentials/counter.
   Its existing sensor connection remains active while Watch prepares.
2. Watch validates and saves the session, then returns READY without starting BLE.
3. Phone persists Watch selection, suspends scanning/reconnect/subscription/write
   paths, and requests disconnection on the BLE queue. It does not wait for the
   disconnect callback before proceeding. The final counter snapshot follows that
   queued suspension, so pending phone callbacks cannot reserve another counter.
4. It snapshots the final counter. If that changed during preparation, it refreshes
   the prepared Watch before sending ACTIVATE. Watch persists active selection
   before constructing the collector and acknowledging activation.

Return is also initiated on the phone. The wire sequence intentionally freezes
Watch collection **before** reporting the final counter, avoiding a counter change
between preparation and disconnection:

1. Phone persists return intent and sends RETURN_PREPARE. Its BLE remains disabled.
2. Watch persists return intent, disables new attempts, confirms release, and replies
   READY with final counter M. A restarted, interrupted return recreates a disabled
   collector to query/release its remembered peripheral before replying.
3. Phone saves M durably and sends RETURN_COMMIT. Watch persists phone selection
   and acknowledges. Only then does phone restore its counter and resume BLE.
   The next attempt advances to M+1 (or beyond if the phone already reserved more).

Duplicate activation/commit messages are idempotent within the current transaction;
retired IDs and wrong-phase requests are rejected. Cancel interrupts the local
operation, not the other device's ownership. Lost replies leave the phone disabled
where Watch may have activated; retry the return or provision with NFC. Counter
exhaustion on return requires NFC rather than resuming into an overflow.

A successful ordinary NFC enable-streaming retires the experimental selection
without waiting for Watch connectivity. Starting NFC also cancels any in-flight
local transfer. Cancelled/failed NFC does not grant phone ownership. Reset IDs are
sent live when reachable and retained in WatchConnectivity application context.
An unreachable Watch cannot be physically disconnected by the phone: it stops
when the reset reaches it. Test this recovery explicitly on hardware. Outside an
existing experimental selection, the NFC commands, callbacks, code/counter reset
and original scanning/retry path retain their prior behaviour.

### Shared BLE and display boundary

The generic Bluetooth class has an opt-in suspension operation and a default-on
connection guard. Only Libre adapters add persisted-selection guards. Queued
writes and late notification callbacks recheck the guard. Suspension waits for
release by default; forward transfer explicitly skips that wait. Ordinary
timeout/cancel/reconnect choices are unchanged. Watch uses
the existing local Bluetooth identity keys to reuse its known peripheral after a
restart; it never treats the phone's peripheral UUID as a Watch UUID. Its central
restoration identifier is stable from the sensor UID even before first discovery;
ordinary phone restoration identifiers keep their existing behaviour.

Direct Watch readings enter the existing chart/complication update path. Relayed
phone glucose is ignored while Watch owns collection, and older queued phone
values cannot overwrite newer displayed direct values after a return. The antenna
is green for an actual radio connection, orange while direct mode is selected
without a connection. Reading age remains independently visible. This initial
display shows values and a five-minute delta; direct trend computation, full
settings persistence, detailed indicator states and double-tap restart are still
part of the later readings/interface milestones.

Direct readings are currently local, with in-memory chart history. There is no
Watch-to-phone reading synchronisation or additional continuous background runtime
in this integrated checkpoint. Phone graphs, uploads/sharing and missed-reading
handling therefore do not yet consume Watch readings. Keep the Watch app visible
for these connection tests.

### Validation

- 26 host XCTest cases pass using actual shared sources/preferences: the previous
  17 protocol/counter cases plus 9 selection/persistence cases. New coverage includes
  ordinary no-file defaults, prepared/active/return guards, persistence across
  restart, duplicate commits, stale IDs, NFC retirement, delayed old revocations,
  corrupt state and failed saves. These tests do not simulate CoreBluetooth or
  WatchConnectivity delivery.
- The actual Watch collector/coordinator/transport and the WatchStateModel/direct
  indicator dependency closure pass watchOS SDK typechecking. The display check
  uses Xcode-generated asset symbols; unrelated macro-bearing screens are excluded.
- The actual phone coordinator, settings page, Libre/NFC adapter and transport pass
  iOS SDK typechecking, with compile-only stand-ins for unrelated app dependencies.
- Full iPhone and Watch builds were attempted and still stop in existing extension
  SwiftUI macro expansion because this environment cannot start the compiler plugin
  sandbox. Full device builds and radio tests remain required in the user's Xcode.
- Build outputs are outside the checkout under `/tmp`; scoped checks and logs are
  in the workspace's `validation/integrated-switching` directory. Personal signing,
  scheme and phone Info.plist edits remain separate from feature commits.

### Physical-device gate

Install the matching integrated build on **both** devices, with the old prototype
collector stopped. Use the ordinary phone NFC path and wait for a fresh BLE reading.

1. Open both apps. On the phone, open Advanced Settings → Direct Libre (Experimental).
   Check the prerequisites and press **Switch to Watch**. Expect an orange antenna
   followed by green when connected, then fresh Watch glucose/chart/complication.
   The phone must stop processing its own BLE frames before Watch activation.
   If the physical phone link persists, cycle Bluetooth in iPhone Settings.
   Watch selection alone does not confirm a Watch radio connection.
2. Press **Return to iPhone** on that same phone page. Expect Watch release first,
   then fresh phone readings without NFC or Bluetooth cycling. Repeat both ways.
3. While Watch owns collection, restart each app separately. Phone must stay disabled;
   Watch should resume its saved session/counter. Test a 2–3 minute signal loss and
   automatic recovery while the Watch is visible.
4. Interrupt preparation/activation/return by closing an app or losing reachability.
   Reopen both apps and retry the available switch/return. Cancel must not silently
   re-enable phone BLE after uncertain activation. If recovery cannot finish, use
   the ordinary NFC path and report the displayed state/error.
5. With Watch selected, perform a successful ordinary phone NFC scan, including
   with Watch unreachable. Confirm phone glucose returns. Reopen/reconnect Watch
   and confirm it retires the old session and does not resume direct collection.
   Also check that cancelling NFC alone does not reclaim an active Watch session.
6. Repeat ordinary phone scan/cancel/retry and signal-loss recovery after returning
   to the phone. Report any deviations and which device/app was open at the time.

### Forward-transfer callback wait removed

The first switching test reported “Watch / transfer pending” and a need to cycle
iPhone Bluetooth. That header also appeared after successful activation, so it
could not identify where the transaction was waiting. It now distinguishes
preparation, Watch selection and return; the separate status text shows progress.
At the user's request, forward transfer no longer waits for a disconnect callback.
The phone still disables collection before activating Watch and requests radio
release, but does not claim the system released the physical link. Return to phone
retains confirmed Watch release. Hardware validation of this revision is pending.

Validation after removing the wait: all 26 existing host tests pass, as do the
actual Watch collector/coordinator SDK check and the scoped phone SDK check
(with unrelated app dependencies stubbed). These tests do not exercise physical
disconnection or callback timing. Full Xcode builds were not repeated; the
previous compiler-plugin sandbox limitation still applies to this environment.
