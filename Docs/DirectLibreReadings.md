# Watch readings and phone synchronisation

The shared Libre collector supplies the same converted `GlucoseData` on both
platforms. On Watch, each frame updates the existing display/complication path.
Only its newest actual measurement is added to the upload queue; interpolated
points used for the Watch graph are not uploaded as additional measurements.
Direct Watch trend arrows use the shared phone slope calculation and arrow
thresholds, based on the newest two readings. Equal timestamps, insufficient
history or gaps over 21 minutes leave the trend unknown. Existing stale-display
rules still apply.

## Delivery

Before PREPARE, the phone saves the current sensor and a mapping from the handoff
ID/Libre UID to that specific database sensor. Delayed readings keep that mapping
after returning to the phone or changing sensors. Import never changes selection
or grants permission to connect over Bluetooth.

The Watch persists a measurement before offering it to WatchConnectivity:

- **Latest:** one measurement through live request/reply when reachable, plus a
  replaceable application context. Each new measurement bypasses any history
  batch waiting for delivery or acknowledgement. Latest replies do not delete
  saved history.
- **History:** immutable batches of at most 120 readings, delivered interactively
  or through queued background user info. Only an acknowledgement of the exact
  batch and reading IDs removes it from the Watch queue. WatchConnectivity
  transfer completion alone is not an acknowledgement of database storage.

The phone finishes its current save, then imports the newest waiting latest
reading before further history. It validates sensor identity, deduplicates by
Libre UID/sensor minute, and preserves existing phone measurements within 30
seconds of a switch boundary. It saves the child, main and persistent-store
contexts before acknowledging. A failed save leaves Watch history available for
retry.

Collection, activation and reachability events drive delivery; there is no new
polling timer. Existing queued history is left with WatchConnectivity while
restored reachability can send the latest value immediately. A five-minute
reservation limits resubmission of an unacknowledged background batch; it does
not delay new latest values or promise an OS delivery deadline.

## Phone processing

Imports enter `RootApplicationCoordinator.processStoredGlucoseData`, the same
post-storage function now used by ordinary phone sensor readings. This retains
post processing, noise calculation, displays, configured Nightscout/HealthKit/
Dexcom uploads, and current-reading alerts, speech, peripheral/calendar/contact
updates and OS-AID sharing. Those consumers retain their existing settings,
filtering and upload policies; this is not a new independent export engine.

Historical imports update storage/displays and invoke configured uploads without
announcing old data as a fresh reading. Before current-reading effects, freshness,
active sensor and the latest visible database value are checked again after post
processing. BLE receipt timestamps and NFC behavior are not fabricated or changed.

## Retention and recovery

The Watch retains up to 22,000 unacknowledged/unresolved measurements (over two
weeks at one per minute), including across app restart and return/NFC reset.
It does not silently evict measurements: if full, new history collection reports
a storage error to the system log until space is freed. The display can continue
receiving BLE frames, but new measurements cannot enter synchronisation until
storage succeeds.

A batch containing an unknown/deleted phone sensor is rejected only for those
measurements. The Watch saves them separately as unresolved and continues with
other sensors. **Advanced Settings → Direct Libre (Experimental) → Unresolved Watch readings**
can inspect and explicitly delete unresolved readings while the Watch is
reachable. Confirmation applies to exactly the inspected revision/count; a
restart or newly unresolved readings requires inspection again. It never deletes
pending uploads or phone records.

The Watch restores units, limits and recent experimental display data from its
existing complication cache before receiving new data. Direct collection ignores
relayed glucose and stale phone sensor status; returning to relay does not replace
a newer displayed measurement with an older one.

The Direct Libre antenna pulses orange during scanning and manual restart, is
solid orange during a connection attempt, and turns solid green on Bluetooth
connection (without waiting for glucose). When disconnected and inactive or
Bluetooth is unavailable it is grey. Pulsing stops when the app is inactive,
the display is dimmed or Reduce Motion is enabled. Reading age remains separate;
an old value does not change a connected antenna to orange.

## Milestone 6 device check

Return collection to the phone before upgrading both apps. After installation,
start a **new** phone-to-Watch transfer. Previous milestone sessions predate the
history registry and are not automatically assigned to a database sensor. No
sensor deletion, reinstall or NFC scan is required for this upgrade.

1. Keep both apps open. Verify new Watch readings enter the phone graph, the
   newest timestamp advances, and duplicate messages do not create extra points.
2. With configured services enabled, verify current-reading alerts/missed-reading
   scheduling, uploads and sharing. Check their own normal cadence/settings.
3. Collect several minutes with the phone unavailable, then reconnect. The latest
   value should not wait for history; older saved values should subsequently fill
   the graph. Restart each app during this check and confirm the queue survives.
4. Restart Watch with phone unreachable: units, limits and recent displayed data
   should persist. Return to phone and check that the display does not jump back
   to an older value.
5. Repeat ordinary phone NFC/readings and switching in both directions.

Background delivery remains scheduled by watchOS/iOS. Optional location runtime,
notification testing and explicit WatchConnectivity background-task handling are
later runtime work, not part of this checkpoint. Neither timely background
collection nor a fixed delivery latency is established by the host tests.
