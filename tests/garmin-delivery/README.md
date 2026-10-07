# Garmin verification

## Standalone tests

```sh
bash tests/garmin-delivery/run.sh
```

Requires a Swift compiler. The script compiles the **production** models, sequence
policy, queue, connection state, transport interface/fallback and GarminManager
with `-swift-version 5 -warnings-as-errors`. It uses a fake clock, fake transport
and the small app/background-work stand-ins in `AppDependencies.swift`. No extra
Swift packages, glucose files, network or signing keys are needed.

Coverage includes packet bounds/trends, UUID identity, replacement/revocation of
authorization, several watches, default-off/enable/disable, readiness transitions,
reconnect, queue coalescing, per-destination duplicates and retries, corrected
same-timestamp readings, persisted sequences, forced resend, late/double/missing
callbacks, deadlines (including suspension), iOS-expiration forwarding and
background-work completion. The tests do not execute the proprietary SDK, UIKit,
Core Data, settings UI or a Bluetooth radio. The fallback adapter is compiled on
Linux; the `canImport(ConnectIQ)` branch requires the Xcode check below.

Linux example (official Swift image; source mounted read-only, network disabled):

```sh
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD:/src:ro" -w /src swift:6.3.3-noble bash tests/garmin-delivery/run.sh
```

## macOS / real SDK build — pending for this branch

```sh
bash tests/garmin-delivery/run-macos.sh
```

This runs the same tests, resolves the pinned Connect IQ 1.8.0 package and builds
the whole application unsigned for a generic iOS device. It retains its logs and
DerivedData in a printed temporary directory. It neither uploads nor installs.
It may need internet access for package resolution. For the existing upstream
XCTest suite, select an installed simulator using `xcrun simctl list devices
available` and set `GARMIN_TEST_DESTINATION='platform=iOS Simulator,id=…'` before
running the script. Record the exact Xcode/Swift versions, commit, build log,
XCTest results and any simulator limitations of the binary SDK.

An unsigned build is not enough for physical testing. Use a signing configuration
and test device suitable for upstream xDrip4iOS. The personal Garmin/G7 fork used
Core Data v33; this branch retains upstream v32. **Do not install this as a downgrade
over that personal database.** Use a separate test device/install and separately
verify upgrade from an official upstream build. Do not launch the repository's
release/TestFlight workflows merely to run a build check.

## Physical checklist — all pending for this branch

Record for each run: xDrip commit/build, iPhone model, iOS version, Garmin Connect
version, watch product ID/firmware, receiver commit/build/signing identity, source
mode and pass/fail with times. Avoid sharing raw glucose traces or device UUIDs.

| Scenario | Required observation |
| --- | --- |
| Sharing disabled at first launch | Existing xDrip functions work; Garmin SDK is not initialized by GarminManager |
| Initial setup, one watch | GCM authorization returns, receiver becomes ready, actual value/trend/age match |
| Two watches; A to B during transfer | New submissions target B; old callback cannot change B's status or start A's field send |
| GCM revokes A / returns empty list | A disappears; no new submissions to it |
| Toggle off with pending work | No further destination is submitted; background tasks end; already-submitted packet may arrive |
| Re-enable / restart app | Saved authorized watches restore; send waits for characteristics discovery |
| Out of range / Bluetooth off then on | Readiness loss is shown; discovery triggers one latest-packet resend without falsifying its age |
| Screen locked / sustained background | Measure actual delivery, gaps and battery effect; do not infer continuous operation from one success |
| No internet, Bluetooth on | A local CGM reading already present in xDrip reaches the watch; cloud follower availability is tested separately |
| Optional DataField absent/not running | Bridge status is independent; document field mailbox behavior on the exact firmware |
| Missing Bridge | Meaningful transfer error, no claim that a value was displayed |
| Manual resend and duplicate | Original timestamp/sequence retained; Bridge may ignore duplicate; sender records actual SDK transfer |
| Calibration changes latest value | Higher q with unchanged m is accepted and shown; no artificial freshness |
| Repeated corrections / app relaunch | Sequence remains increasing; unchanged packet is stable |
| Stale/future timestamp at receiver | Old/future readings are not shown as current; test receiver settings explicitly |
| iOS expiration / delayed SDK callback | Logical work ends, no later destination from expired work; no overlapping SDK sends |
| SDK callback never returns | Requests end within application deadline; document SDK recovery/app restart; no transfer-stall recovery claim without evidence |
| Force quit / OS termination / reboot / low power | Record what resumes automatically and what needs reopening; these are not guaranteed |
| Direct CGM and follower | Stored final value is sent from both publication paths |
| Upgrade from official upstream | Existing database/settings load; calibration, alerts, widgets, HealthKit, backup import/export and other BLE peripherals still work |

Receiver compilation/simulator results and earlier personal-phone tests are useful
background only. Do not check off these rows based on those older results.

## Current evidence

On 2026-10-07 the standalone suite passed on Linux with the official
`swift:6.3.3-noble` image (Swift 5 language mode). The container image digest was
`sha256:cd45c27b3abc42310c33cfaf3008b18156cbdc9187834c9617e8f43a26d2675c`.
Xcode package resolution, full iOS compilation, upstream XCTest and all physical
scenarios above remain pending. No GitHub workflow was started for this branch.
