# Direct Libre on Apple Watch (experimental)

The iPhone selects which xDrip app collects Libre 2 readings. The Watch uses the
phone's existing BLE protocol, crypto and parser, displays direct readings, and
synchronises them back to the phone. This branch integrates the earlier prototype
into upstream `develop`, updated through `03709376` (version 7.1.0, build 4232).
Other sensor types are outside this feature's scope.

## Setup

1. Build `xdrip.xcodeproj` using the normal project signing configuration; install
   matching iPhone and Watch builds. Minimum targets are iOS 16.2 and watchOS 10.
2. Use the same development team for the app and its extensions. Keep the resolved
   `APP_GROUP_IDENTIFIER` consistent in Build Settings, Signing & Capabilities and
   entitlements for the phone/widget and Watch/complication targets. Keep the
   `MAIN_APP_BUNDLE_IDENTIFIER` and Watch companion identifier consistent too.
   The feature reuses the project's existing app group; it does not add one.
3. Obtain fresh Libre 2 BLE readings on the phone first, with Libre Native Algorithm
   enabled and Suppress Unlock Payload disabled. Other apps must release their own
   sensor connections; xDrip can release only its own CoreBluetooth connection.
4. Open **Advanced Settings → Direct Libre (Experimental)** and keep the Watch app
   open. The checklist confirms configuration, a phone BLE reading within three
   minutes, phone connection and companion reachability.

Return collection to the phone before upgrading both apps. No routine sensor
removal, data wipe or reinstall is needed. The integrated branch does not migrate
prototype ownership journals or uploads. One early installation over the prototype
needed reinstalling; retained unlock-code mismatch was plausible, not proven.
The phone now saves the code actually provisioned by successful NFC scans.

## Daily workflow and recovery

- Switching requires a phone BLE reading less than three minutes old, received after
  a successful unlock-write callback on the current connection with unlock enabled.
  Enabling unlock alone does not qualify an earlier reading; if the connection was
  established with unlock suppressed, reconnect the phone and wait for a new reading.
- Press **Switch to Watch**. Keep both apps open until Watch is selected; the phone
  pauses its Libre collector and the Watch begins connecting.
- The antenna replaces the reading-age dot on every Watch page: **blinking orange**
  means scanning/manual restart, **solid orange** connecting, **green** BLE connected,
  and **grey** disconnected without an active attempt or Bluetooth unavailable.
  Green does not establish fresh glucose. Reading age remains visible separately.
  Pulsing pauses when dimmed/inactive or Reduce Motion is enabled.
- Double-tap the large reading to explicitly restart the direct collector. Ordinary
  signal-loss recovery retains its Bluetooth manager; a manual restart replaces it
  and scans afresh while preserving credentials and the attempted unlock counter.
- Press **Return to iPhone** on the phone to stop Watch collection and resume phone
  BLE. The same button handles an interrupted preparation. **Cancel transfer** stops
  the transaction, not the persisted selection, and does not grant phone BLE early.
- A successful ordinary phone **NFC scan** authoritatively resets collection. Failed
  or cancelled scans do not transfer control. An unavailable Watch stops when it
  receives the reset; do not assume an offline Watch has already processed it.
- **Troubleshooting → Unresolved Watch readings** inspects uploads whose original phone sensor cannot
  be found. Deletion requires confirming the current count/revision and affects only
  unresolved Watch records, not pending uploads or phone data.
- **Troubleshooting → Recent activity** opens a separate page showing events from
  the last hour, newest first. Older entries are removed when the app loads, records
  or refreshes activity; the visible activity page also updates when an entry expires,
  without background polling.
- **Troubleshooting → Help** separates switching from recovery, with recovery advice
  for each symptom, plus background location and notification-test guidance. Current
  transfer errors and recovery guidance remain beside the switching control.

### Recovery paths

Confirm recovery by a newly timestamped glucose reading. A green antenna confirms
BLE connection, not successful streaming. Brief grey during Bluetooth initialization
can occur; persistent grey means no active attempt is currently reported.

| Situation | Recovery |
| --- | --- |
| Watch loses connection | Bring the Watch within sensor range, open xDrip and interact with it by swiping between pages. Allow the existing attempt to recover; if it remains disconnected, double-tap the large reading to restart the collector. |
| Double-tap does not restore collection | Turn Bluetooth off and back on **on the Watch**, reopen xDrip, then double-tap if needed. If still unsuccessful, close and relaunch the Watch app. Saved selection, credentials and attempted counter are retained. |
| Switching to Watch stalls | Keep both apps open and check the transfer status on the phone. If the iPhone appears to retain the sensor connection, cycling **iPhone Bluetooth** may help release it. Reopen both apps, check the saved transfer state and retry the switch/return control as appropriate. |
| Returning to iPhone stalls | Keep both apps open and retry **Return to iPhone**. If necessary, cycle Bluetooth on the device apparently retaining the sensor connection, reopen both apps and retry. |
| Transfer was interrupted | Reopen both apps and use the phone's switch/return control to resolve the saved selection. **Cancel transfer** does not itself enable phone collection. |
| Normal return cannot complete | Perform a successful ordinary sensor NFC scan on the iPhone to reset selection. A failed or cancelled scan does not reclaim collection. An unreachable Watch stops its old collection only after it receives the revocation. |
| Watch has fresh readings but phone delivery lags | Open both apps and try **Test Watch notification** under **Background connection**, following the instructions below. This has helped background delivery in testing; it does not reset the sensor connection. |

In device testing, opening the Watch app alone was not always sufficient; swiping
between pages appeared to help recovery. This observation does not establish that
watchOS background limits were reset.

Bluetooth cycling is a fallback, not a routine handoff requirement: clean device
checks passed in both directions without it. Cycling iPhone Bluetooth also disrupts
phone–Watch communication, so restore communication before retrying the transfer.
Other apps must release their own sensor connections; xDrip cannot disconnect them.
A collector reset forces a new attempt, not a successful connection.

If [diagnostic capture](#watch-connection-diagnostics) is running, leave it enabled
through recovery and note the time of each action. Resetting the collector or cycling
Bluetooth does not deliberately clear the capture. Once recovered, stop/download
and share the report before starting a replacement capture.

## Optional runtime support

All controls are in **Background connection** on the same experimental page.
They do not change authentication, sensor selection or BLE retry policy.

**Location:** enable while the Watch app is open, allow location access there, then
press **Refresh runtime status**. The reply distinguishes waiting for selection or
permission, starting, and receiving location updates. It is a last-confirmed status,
not a live guarantee. A fresh installation defaults to off and 100 m accuracy.
The three buttons request **100 m / 1 km / 3 km**, not a polling interval; coarser
accuracy may save energy but requires device comparison. Coordinates are not saved
or shared. Opt-in/accuracy persist, but updates run only with Watch selected and a
session started in the foreground. Return, received NFC reset, disable or permission
revocation stops updates. Open the Watch app after relaunch to restart them.

**Underwater:** the minimal `underwater-depth` declaration restores foreground support
on compatible watches. Enable Water Lock manually before entering water and disable
it manually afterwards. There is no depth reader, automatic Water Lock, workout or
app-managed extended runtime session. Apple documents 30 minutes frontmost after
launch from the declaration alone; unlimited underwater execution is not promised.
Staying frontmost does not establish radio reception through water.

**Test Watch notification:** in prototype testing, an alert appearing on the Watch
restored immediate phone delivery while both apps were backgrounded; updates continued
after it closed without tapping it. This is an observed workaround, not a delivery
guarantee or established diagnosis. Open both apps, press the test button and allow
notifications if asked. After scheduling is confirmed, return to the Watch face and
lock the phone. One Watch-local test alert is scheduled 30 seconds later. Let it
appear, then compare subsequent reading times without opening either app. Focus and
notification settings can prevent presentation. Confirmation means scheduled, not
shown; a lost reply may still produce an alert. Another press replaces the pending
test. No automatic notification, retry loop or real-alarm change is introduced.

Location uses extra battery. Neither background collection nor a fixed phone-delivery
latency is guaranteed. See Apple's [background location guidance](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
and [underwater foreground behaviour](https://developer.apple.com/documentation/coremotion/accessing-submersion-data).

## Watch connection diagnostics

Open **Advanced Settings → Direct Libre → Troubleshooting → Connection diagnostics** with both apps
open. Refresh status, then **Start capture** and wait for confirmation. The Watch
records locally without the phone; closing this page does not stop the capture.
After the test, reopen both apps, **Stop and download**, then **Share report**.
A stopped capture can be downloaded again. Starting another requires confirming
replacement; a failed download leaves the last complete phone report intact.

New captures are bounded to 24 hours, 100,000 events or 10 MB, whichever is reached first.
An existing capture keeps its original expiry time. Larger reports take longer to
download; Watch restoration and export read the archive in small chunks.
The duration limit is checked on the next event/status request; no timer wakes the
Watch. A bounded file queue keeps disk work off Bluetooth and UI callbacks. Capacity,
queue overload and storage errors are explicitly reported. Relaunch resumes an
unexpired capture; abrupt termination can lose events still queued in memory.

The report records collector/request IDs, event-origin UTC/uptime, Bluetooth state,
scan/connect/cancel requests and callbacks, existing timeout execution, reset
acceptance/rejection, service/subscription setup, unlock reservation/write results,
packet lengths/parser outcomes and reading delivery timing. Lifecycle/dimming and
location status/callback timing provide execution context. Location callback samples
are coalesced to at most one per minute without requesting extra updates. There is
no automatic water-entry detection, RSSI polling, new reconnect timer or log upload.
Credentials, raw sensor packets, glucose values and coordinates are omitted.

For a recovery test, note the time reliable range returns. First wait without
interacting, then open xDrip without double-tapping, then double-tap if needed.
Record Bluetooth cycling separately; the capture records the resulting system state
callbacks but cannot identify who caused them. Brief grey during manager startup is
different from persistent grey: the trace distinguishes reset, initialization,
powered-on, scan and UI state transitions.

Explicit background-notification-budget errors are labelled. Silence, a pending
request or recovery after interaction does not prove Apple throttling, suspension
or radio loss. Callback association can be ambiguous when connection requests overlap;
write acknowledgement alone does not establish streaming. This is a diagnostic
capture, not additional background execution permission or a recovery fix.

## Architecture and code map

| Responsibility | Main source files |
| --- | --- |
| Shared BLE lifecycle / F001-F002 protocol | `BluetoothTransmitter`, `Libre2BluetoothTransmitter` |
| Existing crypto and parsing | `PreLibre2`, `Libre2BLEUtilities`; explicit parser state on Watch |
| Phone provisioning / adapter | `CGMLibre2Transmitter` (including NFC), `Libre2PhoneSensor` |
| Watch adapter / persisted credentials | `Libre2WatchTransmitter`, `Libre2WatchSensor`, `Libre2WatchSession` |
| Selection and handoff | `Libre2ConnectionStore`, `Libre2ConnectionMessage`, phone/Watch `Connection` coordinators |
| Reading messages / outbox / sensor mapping | `Libre2History`, `Libre2HistoryQueue`, `Libre2JournalFile`; registry in `Libre2PhoneHistorySync` |
| Delivery / phone import | phone/Watch `HistorySync`, `Libre2PhoneReadingProcessing` |
| Display / controls | `WatchStateModel`, `GlucoseTrend`, `Libre2ConnectionIndicator`, `DirectLibreSettingsView` |
| Watch capture / phone export | `Libre2DiagnosticCapture` / `Libre2DiagnosticRecorder`, `Libre2WatchDiagnostics`, `Libre2CaptureController`, `DirectLibreDiagnosticsView` |
| Optional runtime | `Libre2RuntimeMessages`, `DirectLibreRuntimeSettingsView`, Watch location/notification helpers |

Shared protocol files remain under `xDrip/BluetoothTransmitter/CGM/Libre`; shared and
phone orchestration lives under `xDrip/Managers/Libre2`. Watch adapters and runtime
helpers are in the corresponding Watch target directories. Target membership, not
parallel protocol implementations, selects what compiles for each device. CoreNFC
stays on the phone. The shared Bluetooth base adds selection guards, local release
confirmation and presentation events; its ordinary phone retry/setup policies remain.
Watch discovery intentionally uses service FDE3 and advertised-name fallback.

### Switching and persistence

The phone registers the current database sensor, persists preparation and sends
PREPARE. Watch validates/persists the session and replies READY without connecting.
The phone disables reconnect, waits for its own disconnect, refreshes PREPARE if its
counter advanced meanwhile, then sends ACTIVATE. Only persisted Watch selection
permits Watch BLE. On return, Watch freezes reconnect, waits for local release and
reports its final counter; phone persists it, obtains RETURN_COMMIT acknowledgement,
then enables phone collection. The next phone attempt advances the counter.

Watch reserves and saves each unlock counter **before** writing F001; failed attempts
are never reused. Session IDs, credentials and retired IDs reject stale transfers.
These are current transaction safeguards, not support for obsolete protocol versions.
The four phases remain `phone`, `preparingWatch`, `watch`, `returningToPhone`.

The shared collector follows upstream's immediate unlock after requesting the F002
subscription, without waiting for its notification-state callback. The Watch still
persists the next counter before writing F001. Both targets use upstream's frame
assembler: complete buffers clear immediately and incomplete frames expire after
three seconds using a monotonic clock. Parsing/history and application delivery run
on main with the captured frame arrival time, so scheduling delays do not make a
reading appear newer.

### Readings and downstream actions

Each frame updates the existing Watch graph/complication path. Only the newest actual
measurement enters the durable outbox; interpolated graph points are not uploaded.
Units, limits and recent direct values restore from the existing complication cache;
stale relayed glucose cannot replace newer direct data. Trend arrows use shared
phone calculations, using the nearest older reading at least four minutes before
the current reading. Gaps over 21 minutes hide the arrow.

Latest delivery uses live messaging when reachable plus replaceable application
context, independently of immutable history batches of up to 120 readings. Latest
replies never delete history. Queued history remains with WatchConnectivity; a
five-minute reservation limits resubmission, not latest delivery. Collection,
activation and reachability events drive retries without new polling timers.

Phone imports match the registered session/UID to the original database sensor,
deduplicate by UID/sensor minute and retain phone readings within 30 seconds of a
switch boundary. Child, main and persistent-store saves precede acknowledgement.
The phone finishes its current save, then prefers the newest waiting latest reading.
A rejected unknown-sensor subset becomes unresolved on Watch so other uploads proceed.

`RootApplicationCoordinator.processStoredGlucoseData` handles phone readings and
imports: post-processing, displays, configured uploads/sharing and fresh-reading
side effects follow existing settings. History does not impersonate fresh glucose;
active sensor/latest/freshness are rechecked after post-processing. NFC behaviour
and BLE receipt timestamps are not fabricated by an import.

The outbox keeps up to 22,000 unacknowledged/unresolved measurements across restart,
return and NFC reset. It does not silently evict data when full: further upload
collection reports a storage error until space is freed, although the display can
still receive frames. Saved formats remain unchanged by consolidation.

### Maintainer review

The [maintainer review guide](direct-libre-maintainer-review.md) maps each changed file
to its responsibility, recommends a review order and separates implementation,
tests, documentation and configuration line counts against upstream `develop`.
Its counts and source links are pinned to the stated implementation snapshot.

## Status and remaining work

Phone NFC/recovery, both transfer directions, restart/double-tap, readings/history,
downstream services and display persistence have passed earlier device checkpoints.
Optional runtime features and this cleanup still require device validation. Controlled
interrupted-transfer testing, prolonged signal-loss timing, a representative water
session, battery profiling and physical-device capture acceptance remain open. See the
[validation record and regression checklist](direct-libre-validation.md).
