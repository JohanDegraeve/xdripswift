# Integrated Direct Libre roadmap

## Baseline and objective

Start from JohanDegraeve/xdripswift `develop`, commit
`83009198dc5091398333f83aa832bbe3d99e3441` (Merge pull request #735).
The implementation branch is `feature/libre2-watch-integrated`.
The existing `experimental/libre2watch` prototype remains a separate reference.

Share the existing Libre 2 protocol and Bluetooth lifecycle between iPhone and
Watch. Preserve ordinary phone behaviour and retain the prototype's user-facing
features. Minimise duplicated logic, rather than hiding all changes in an add-on.
Do not introduce a general sensor framework or extend sensor compatibility in
this work. Upstream support for newer Libre variants does not establish that
those variants work with the experimental Watch collector.

Each milestone gets coherent commits. Separate structural changes from behaviour
changes, keep validation alongside the relevant change, and exclude incidental
Xcode metadata/signing changes. Physical-device checks gate further integration.

## Current checkpoint

The phone NFC extraction is committed. The user confirmed a successful Xcode
build and ordinary NFC/readings/cancellation/reconnection checks on a clean
installation. Shared protocol dependencies are now separated and checked against
upstream frames and both SDKs. NFC success now stores the code actually sent by
the scan. Next: the phone device checkpoint before integrating the shared collector
into Watch.

An installation over the prototype disconnected until the app was reinstalled.
A retained unlock-code mismatch is a plausible code-supported explanation, not a
confirmed diagnosis. Preserve this as an upgrade/configuration regression case;
see [validation findings](DirectLibreValidation.md). Existing user Xcode/signing
adjustments remain local and separate from feature commits.

## Milestones and acceptance

1. **Baseline and dependency audit.** Record the upstream revision, build targets,
   existing dependencies, and feature inventory. Attempt unchanged phone and Watch
   builds before editing. Document tool/environment failures separately from code
   failures. Keep generated outputs outside the checkout.
2. **Separate phone NFC provisioning.** Move NFC session creation and delegate
   methods into an iOS-only extension. Retain the original NFC commands, callbacks,
   preferences, warnings, retry behaviour and ordering. Remove the broad NFC guard
   around the BLE implementation. Validate source equivalence and compilation.
   **Device gate:** ordinary scan, serial identity, glucose, reconnect, cancellation
   and restart behave as they did on the unmodified baseline.
3. **Share protocol dependencies.** Use the original crypto, frame handling,
   calibration and parsing. Supply parser state/configuration explicitly where
   phone preferences currently prevent reuse. Verify unlock/decryption fixtures
   and equivalent parsed readings before adding Watch source membership.
4. **Share the collector.** Compile the same Bluetooth/Libre transmitter sources
   for Watch. Add only thin persistence, configuration and reading adapters. Keep
   the initial reconnect policy aligned with the phone; investigate prolonged
   pending connections separately. **Device gate:** Watch collects valid readings,
   and phone collection remains unchanged.
5. **Phone-controlled switching.** Persist selected device, session identifier,
   credentials and counter. Prepare/acknowledge before releasing the old collector;
   activate the new one only after confirmed release. Reserve/persist counters
   before unlock writes. Reject obsolete transactions. A successful ordinary NFC
   provisioning retires an existing experimental session without making the phone
   wait for an unreachable Watch. **Device gate:** both switching directions,
   interrupted transactions, restarts and NFC reset.
6. **Readings and synchronisation.** Use existing Watch presentation for direct and
   relayed readings; persist units/limits and reject older display values. Deliver
   latest readings independently of acknowledged history batches. Acknowledge
   only durable phone storage; deduplicate delivery. Feed current imports into
   ordinary downstream processing without presenting old backfill as current.
   Retain bounded unsynchronised history and explicit unresolved-reading deletion.
   **Device gate:** foreground/background delivery, missed-reading handling,
   configured uploads/sharing, restarts and disconnected history recovery.
7. **Interface.** Advanced Settings is the configuration entry. Retain one device
   switch, readiness checklist, compact recent activity and conditional recovery
   actions. Keep the Direct Libre antenna on the reading-age display, its scanning
   animation, connection states and explicit double-tap restart. Reuse display
   refreshes/state-change notifications rather than adding polling.
8. **Optional runtime features.** Restore opt-in location collection with its
   accuracy choices, underwater foreground support/manual Water Lock, and the
   background-delivery test notification in separate commits. Document platform
   limitations and the notification's observed benefit without promising delivery
   deadlines. These features must not control protocol or ownership correctness.
9. **Diagnostics and validation.** Keep compact default logging and bounded,
   opt-in extended capture. Cover counter persistence, interrupted switching,
   stale messages, independent latest delivery, durable history acknowledgements
   and ordinary-phone guards. Test short/prolonged signal loss, double tap,
   Bluetooth cycling, background operation and a representative water session.
10. **Integration audit.** Explain every changed original file, remove duplicates
    and obsolete compatibility code, consolidate setup/architecture/workflow docs,
    and report file/line counts, builds, tests and remaining limitations against
    the recorded upstream revision.

## Dependency map

| Existing source | Current coupling | Intended treatment |
| --- | --- | --- |
| `BluetoothTransmitter.swift` | Logging, delegates, saved peripheral identity, restoration and sensor-specific policies | Reuse lifecycle; isolate only platform dependencies; preserve other sensors |
| `CGMLibre2Transmitter.swift` | NFC, phone preferences, CGM delegates, calibration and reading delivery | Separate NFC first; then explicit configuration/persistence and platform adapters |
| `Libre2BLEUtilities.swift` | Previous raw-reading arrays in phone preferences; calibration and data helpers | Shared parser with explicit per-sensor state, preserving algorithm behaviour |
| `PreLibre2.swift` | Logging and byte helpers | Share original crypto and required helpers |
| `GlucoseData.swift` | Foundation-only reading representation | Reuse where appropriate |
| `CGMTransmitter.swift` | Other sensors, calibration/Core Data and phone-facing type metadata | Separate the phone-facing conformance from shared collection if needed; do not import the phone model graph into Watch |
| `LibreNFC.swift` and its delegate | CoreNFC and phone provisioning | iPhone only; no command or retry changes in the structural milestone |
| `WatchStateModel` / WatchConnectivity | Relayed display and phone preferences | Common reading/display entry; latest/history transport remains separate from BLE |

Target membership alone is insufficient: removing CoreNFC guards is only the
first separation. The shared class is not yet a Watch-ready API at milestone 2.

## Initial build environment

Inspected with Xcode 27.0 (27A266a). Targets: xdrip, phone widget, Watch app,
Watch complication, notification context extension and xdripTests. Deployment
minimums are iOS 16.2 (notification extension 17.4) and watchOS 10.0.

Unmodified Debug builds for generic iOS and watchOS were attempted without code
signing. Both failed in existing extension SwiftUI macro expansion: the compiler
plugin process could not apply its sandbox (`Operation not permitted`, malformed
plugin response). CoreSimulator access also failed in this execution environment.
These are baseline blockers; a complete build is not yet established.

The upstream project explicitly sets empty OBJROOT/SYMROOT. Validation commands
supply absolute paths under /tmp to prevent root-level outputs and repository
build artefacts. This does not alter tracked project settings. Device builds and
NFC verification must be completed in the user's Xcode environment before the
Watch integration milestone proceeds.
