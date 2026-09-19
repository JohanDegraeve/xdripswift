# Direct Libre on Apple Watch (experimental)

The iPhone selects which xDrip app collects Libre 2 readings. The Watch uses the
phone's existing BLE protocol, crypto and parser, displays direct readings, and
synchronises them back to the phone. This branch integrates the earlier prototype
into upstream `develop` at `83009198dc5091398333f83aa832bbe3d99e3441`.
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
- **Unresolved Watch readings** inspects uploads whose original phone sensor cannot
  be found. Deletion requires confirming the current count/revision and affects only
  unresolved Watch records, not pending uploads or phone data.
- **Recent activity** displays five events initially and up to 80 with Show more.

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

## Architecture and code map

| Responsibility | Main source files |
| --- | --- |
| Shared BLE lifecycle / F001-F002 protocol | `BluetoothTransmitter`, `Libre2BluetoothTransmitter` |
| Existing crypto and parsing | `PreLibre2`, `Libre2BLEUtilities`; explicit parser state on Watch |
| Phone provisioning / adapter | `CGMLibre2Transmitter+NFC`, `CGMLibre2Transmitter`, `Libre2PhoneSensor` |
| Watch adapter / persisted credentials | `Libre2WatchTransmitter`, `Libre2WatchSensor`, `Libre2WatchSession` |
| Selection and handoff | `Libre2ConnectionStore`, `Libre2ConnectionMessage`, phone/Watch `Connection` coordinators |
| Reading messages / outbox / sensor mapping | `Libre2History`, `Libre2HistoryQueue`, `Libre2HistoryRegistry`, `Libre2JournalFile` |
| Delivery / phone import | phone/Watch `HistorySync`, `Libre2PhoneReadingProcessing` |
| Display / controls | `WatchStateModel`, `GlucoseTrend`, `Libre2ConnectionIndicator`, `DirectLibreSettingsView` |
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

### Readings and downstream actions

Each frame updates the existing Watch graph/complication path. Only the newest actual
measurement enters the durable outbox; interpolated graph points are not uploaded.
Units, limits and recent direct values restore from the existing complication cache;
stale relayed glucose cannot replace newer direct data. Trend arrows use shared
phone calculations.

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

### Implementation footprint

Snapshot on **2026-09-19**, comparing upstream develop baseline
`83009198dc5091398333f83aa832bbe3d99e3441` with feature commit
`ee9239ef47c540d4600c6a235741e67f8ee022f9`, before adding this section.
Net lines are additions minus deletions; files are grouped by their main
responsibility. Counts include comments and whitespace, exclude uncommitted local
settings, and do not measure complexity or executable size.

| Area | Net added lines | Share |
| --- | ---: | ---: |
| Tests | 1,279 | 28.2% |
| Synchronisation and phone processing | 986 | 21.8% |
| Shared collector and platform separation | 413 | 9.1% |
| Ownership and switching | 665 | 14.7% |
| Optional runtime features | 420 | 9.3% |
| Display and settings | 281 | 6.2% |
| Documentation | 265 | 5.8% |
| Xcode configuration | 222 | 4.9% |
| **Total** | **4,531** | **100%** |

Across 61 changed files, the snapshot contains 5,270 additions and 739 deletions.
Excluding tests, documentation and Xcode configuration, the production-source
increase is **2,765 lines**. Synchronisation and ownership switching contribute
1,651 of those lines, approximately 60%. Update this snapshot at significant
milestones, retaining the exact compared revisions.

## Status and remaining work

Phone NFC/recovery, both transfer directions, restart/double-tap, readings/history,
downstream services and display persistence have passed earlier device checkpoints.
Optional runtime features and this cleanup still require device validation. Controlled
interrupted-transfer testing, prolonged signal-loss timing, a representative water
session, battery profiling and extended diagnostic capture remain open. See the
[validation record and regression checklist](DirectLibreValidation.md).
