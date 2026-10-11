# Garmin Connect IQ glucose sharing

This opt-in integration sends the latest xDrip4iOS glucose reading from an iPhone
to a compatible Garmin receiver over Bluetooth. The phone-to-watch transfer does
not require Nightscout, a Mmolio server or watch Wi-Fi. Initial installation,
Garmin Connect setup and pairing may require internet access. A cloud-based
xDrip follower still needs its usual connection to obtain new readings.

This is a supplemental display, not a glucose sensor, dosing system or replacement
for the source application's alarms. A watch can display an old reading or miss a
transfer. Keep the receiver's measurement-age/stale indication visible.

## Architecture

```text
CGM / follower / calibration
    -> upstream stored finalValue + slopeOrdinal + measurement timestamp
    -> GarminManager: validated snapshot + persistent v1 sequence
    -> bounded GarminDeliveryQueue (Bridge, then optional DataField)
    -> Garmin Connect IQ Mobile SDK 1.8.0 -> Bluetooth
    -> Mmolio Bridge -> private complication -> Mmolio WatchFace
    -> Mmolio DataField (separate direct message, while running)
```

Garmin Connect authorizes/selects the paired devices through the `gcm-ciq` URL
scheme, returning to `xdrip-garmin`. The SDK handles the BLE connection. The sender
waits for `deviceCharacteristicsDiscovered`, not just a connected status.
Returned device lists **replace** the previous authorization list. A single watch
is automatically selected; with several watches, select one in the Watch menu.
The persisted identity uses the full UUID. Older personal builds stored a partial
numeric identity: users with multiple cached watches must select again once.

Only the Garmin sender, settings, URL handling, package dependency and publication
hooks are added. Existing calibration algorithms, G7 decoding, Core Data models,
HealthKit, backup handling and build/release workflows are unchanged. Trends use
the upstream calculation and may differ from personal builds with G7 overrides.

## Receiver installation

The existing receiver is the public [Mmolio project](https://github.com/sejkoramartin/Mmolio).
Open **Install Mmolio on Your Watch** in Garmin settings for the
[installation guide](https://github.com/sejkoramartin/Mmolio/blob/main/docs/GARMIN-INSTALL.md),
including a Czech translation and model-specific release downloads.
[Receiver prerelease 2026.10.11-rc1](https://github.com/sejkoramartin/Mmolio/releases/tag/garmin-2026.10.11-rc1)
provides installation ZIPs for `fr165`, `fenix7xpro` and `fenix7xpronowifi`.
These are build-verified candidates; physical validation remains pending for all
three targets. Each ZIP includes instructions, license, disclaimers and checksums.

See its [Garmin source and guide](https://github.com/sejkoramartin/Mmolio/tree/main/garmin),
[license](https://github.com/sejkoramartin/Mmolio/blob/main/LICENSE) and
[disclaimer](https://github.com/sejkoramartin/Mmolio/blob/main/docs/DISCLAIMER.md).
No server, Cloudflare account or Nightscout secret is required for this route.

The receiver candidate corresponds to source revision
`7489307642bf22eb5a0e9357dac6fc915b549cb8`. The iOS sender has no watch-model allow-list; actual support requires a receiver build
and testing for the exact Garmin product ID. Do not infer compatibility from a
similar model name or Wi-Fi availability.

1. Install Garmin Connect on the iPhone, pair the watch and allow Bluetooth access.
2. Download and unpack the ZIP for the exact model from the receiver prerelease.
   Use its `apps/` files in step 3; users do not need to compile anything.
   Alternatively, developers can reproduce a Forerunner 165 build with Connect IQ
   SDK 9.2.0 and the matching device definitions:

   ```sh
   git clone https://github.com/sejkoramartin/Mmolio.git
   cd Mmolio
   git checkout 7489307642bf22eb5a0e9357dac6fc915b549cb8
   export CONNECTIQ_SDK="/absolute/path/to/connect-iq-sdk"
   export DEVELOPER_KEY="/absolute/path/to/your/developer_key.der"
   ./garmin/scripts/build-fr165.sh
   ```

   Generate your own developer key using Garmin's SDK instructions. Sign Bridge
   and WatchFace with **the same key**: the private complication is only shared
   between apps signed by that developer. Keep the key private. Do not change
   the application IDs when building a compatible receiver.
3. Connect the watch by USB and copy `MmolioBridge.prg` and
   `MmolioWatchFace.prg` from the ZIP's `apps/` folder (or `build/fr165/release/`
   when compiling yourself) into the watch's `GARMIN/APPS`
   folder. Copy `MmolioDataField.prg` too if activity display is wanted. Use the
   receiver's device-specific instructions for existing installations/filenames;
   do not install files compiled for another product.
4. Disconnect USB, open Mmolio Bridge once, then select Mmolio WatchFace. To use
   the data field, add Mmolio DataField to an activity data screen. It receives
   direct messages while the field is running; it is not a complication subscriber.
5. In xDrip4iOS open **Settings -> Sharing and Services -> Garmin Watch**. Enable
   sharing, choose **Find / Change Watch**, authorize in Garmin Connect, then
   choose the watch in the Watch menu if more than one was returned.
6. When the status reads **Ready for Transfer**, choose **Resend Latest Reading**.
   Compare the watch's value, trend and measurement age with xDrip. **Last Bridge
   Transfer** only records an SDK success; it does not prove the receiver displayed
   that reading. The original reading's timestamp is retained on every resend.

There is no Connect IQ Store listing promised by this PR. The receiver's release
and distribution process must be agreed with maintainers before calling this a
turnkey feature. Other watch faces do not automatically understand this protocol.
A separately published receiver with another app ID would require a corresponding
sender change; arbitrary IDs are not exposed in settings in this implementation.

## Wire protocol v1

The SDK serializes a dictionary with string keys and signed 32-bit-compatible
integer values. Glucose is always mg/dL on the wire, regardless of phone units.

| Key | Meaning | Sender constraint |
| --- | --- | --- |
| `v` | Wire version | `1` |
| `g` | Final glucose, rounded to whole mg/dL | `1...1000`; non-finite inputs rejected |
| `t` | Trend | `0` unknown; `1` rapidly falling, `2` falling, `3` gently falling, `4` flat, `5` gently rising, `6` rising, `7` rapidly rising |
| `m` | Original measurement time, Unix seconds | `1...2147483647` |
| `s` | Source identifier | `3` for xDrip4iOS |
| `q` | Increasing sequence within source | Initially `m`; see corrections below |

Example: `{"v":1,"g":123,"t":4,"m":1700000000,"s":3,"q":1700000000}`.
The trend mapping is `8 - slopeOrdinal()` for upstream ordinals 1...7; otherwise 0.

Destination IDs (preserved for compatibility):

- Bridge: `a1b2c3d4e5f647589a0b1c2d3e4f5061`
- DataField: `7ca56fd800634cab90f28d5e72be2e05`

The existing receiver accepts a packet from the same source only when
`q > previous.q` and `m >= previous.m`. This allows a corrected glucose/trend for
the same measurement time: the sender assigns `max(m, previous.q + 1)` when the
packet content changes. Unchanged resends retain both `q` and `m`. The latest
packet is persisted locally in UserDefaults to preserve ordering across launches.
An older measurement is not allowed to replace the latest prepared packet.

The receiver ignores duplicate/out-of-order packets. There is no application-level
ACK, history synchronization or remote deletion command. Sending a correction
cannot make an old measurement fresh. The signed integer timestamp limit requires
a protocol update before January 2038. Sequence exhaustion fails closed.

## Lifecycle, failure and background behavior

- Sharing defaults to off. Disabled startup does not initialize Garmin's SDK.
  Switching off unregisters device listeners and cancels active/queued application
  work. It cannot retract a packet already handed to the SDK, erase watch data or
  promise that an SDK-owned BLE connection closes immediately.
- The queue holds at most one active and one newest pending request. Each has a
  20-second deadline including queue wait. A monotonic deadline check also rejects
  late callbacks after suspension, even if the timer has not run yet.
- Bridge and DataField calls are serialized. Optional field failure does not
  replace Bridge success. Failed sends do not count as delivered duplicates.
- Timeout, selection change, revoked authorization, disconnect and iOS expiration
  invalidate relevant work. Late or duplicate callbacks cannot update a new
  session or start the old packet's remaining destination.
- The SDK exposes no cancellation API. After a logical timeout/cancellation the
  wire slot remains occupied until that SDK callback returns, to avoid concurrent
  SDK transfers. New pending requests also have deadlines. If a callback never
  returns, no further SDK call is attempted in that process: reopening a fully
  restarted application is the recovery path. Reconnection alone cannot guarantee
  recovery from a stuck SDK operation. This condition still needs hardware testing.
- A selected watch becoming ready triggers one latest-packet resend. There is no
  retry loop or new background polling service. Automatic sends also follow stored
  CGM/follower updates and accepted calibration changes.
- `UIBackgroundTask` requests finite time to complete work; expiration cancels the
  transfer work and ends the task. The app does not send if the OS denies that
  background task. Existing upstream Bluetooth background modes are retained.
  State restoration is configured, but force-quit, reboot, low-power operation,
  OS termination and long offline recovery are not guaranteed and need device tests.
- The receiver computes freshness from `m`. Mmolio's reviewed default stale threshold
  is 15 minutes, configurable on the watch. The iPhone may resend an old last reading;
  it never rewrites its time. No fresh data can be inferred from a recent transfer time.

## Data and dependencies

The sender adds no server endpoint, authentication secret or glucose debug log.
Garmin Connect/SDK remain third-party dependencies. Local preferences contain the
authorized watch UUID/name/model, selected UUID, sharing flag and latest glucose
packet (value, trend, measurement time and sequence). Disabling stops sharing but
retains this state for later use. The wire packet does not contain a patient name,
account identifier, sensor ID or location. Device diagnostics use SDK result codes.

The SDK is pinned to **1.8.0** via Swift Package Manager. It is Garmin's prebuilt
XCFramework, not code covered by the receiver's license. See the
[SDK README and license link](https://github.com/garmin/connectiq-companion-app-sdk-ios/blob/1.8.0/README.md).
Upstream maintainers should review that dependency and its distribution terms.
Existing repository licensing is not changed.

## Validation

Run `tests/garmin-delivery/run.sh` for deterministic Swift tests of the production
packet/sequence/queue/lifecycle code and manager with fake app dependencies. Run
`tests/garmin-delivery/run-macos.sh` on macOS to resolve the real SDK and build the
whole iOS application. The latter script does not upload, sign or install a build.
See [the test and hardware checklist](../tests/garmin-delivery/README.md).

The current clean branch has not yet been built with Xcode or run on a physical
iPhone/Garmin pair. Earlier personal-branch successes are not evidence for this
branch. In particular, physical Fenix behavior and unattended background delivery
remain unverified.

## References

- [Garmin iOS SDK guide, version 1.8.0](https://github.com/garmin/connectiq-companion-app-sdk-ios/blob/1.8.0/documentation/ConnectIQ_iOS_SDK.html)
- [Garmin SDK delegate and send API](https://github.com/garmin/connectiq-companion-app-sdk-ios/blob/1.8.0/ConnectIQ.xcframework/ios-arm64/ConnectIQ.framework/Headers/ConnectIQ.h)
- [Apple Core Bluetooth background processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
- [Apple finite background execution time](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time)
- [Receiver ordering implementation](https://github.com/sejkoramartin/Mmolio/blob/68ab835ac7f9f79ae5b07aca367c88de414c1072/garmin/MmolioBridge/source/GlucoseReading.mc)
