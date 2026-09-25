# Direct Libre: maintainer review guide

Snapshot: 20 September 2026. Committed feature branch `feature/libre2-watch-integrated` at `91e15071`, compared with upstream `develop` at `03709376`.

Counts below describe that implementation snapshot, before this guide and its documentation links were added. Source links and reproduction commands stay pinned to those commits so the figures remain reproducible. For current branch totals, compare upstream `develop` with the branch head.

**61 changed files; 6,009 added lines, 517 deleted lines; net +5,492 lines.**

This is the Git three-dot comparison used for a pull request. Local signing/plist edits and workspace validation artifacts are excluded. It is a measured review map, not a fresh correctness audit or a new build result.

## Footprint by responsibility

| Review area | Files | Added | Deleted | Net |
| --- | ---: | ---: | ---: | ---: |
| Shared BLE, protocol and platform adaptation | 15 | 725 | 387 | +338 |
| Phone-controlled selection and handoff | 6 | 750 | 0 | +750 |
| Reading delivery, storage and phone processing | 8 | 1,049 | 62 | +987 |
| Display, trends and main settings | 10 | 357 | 68 | +289 |
| Optional background runtime | 5 | 430 | 0 | +430 |
| Diagnostic capture and export | 5 | 557 | 0 | +557 |
| Tests | 7 | 1,550 | 0 | +1,550 |
| Documentation | 3 | 352 | 0 | +352 |
| Xcode and capabilities | 2 | 239 | 0 | +239 |
| **Total** | **61** | **6,009** | **517** | **+5,492** |

The six implementation groups total **3,351 net Swift lines across 49 files**. Configuration adds **239 lines across two files**; tests add **1,550 lines across seven files**; documentation adds **352 lines across three files**. Tests and documentation account for about 35% of the net increase.

**36 new files contribute 5,087 lines. Changes to 25 existing files add 922 and remove 517 lines, a net increase of 405.** This does not mean the existing-code review is only 405 lines: those 25 files contain 1,439 changed lines, including shared Bluetooth, NFC completion and downstream processing.

Counts include comments and blank lines. Each file is assigned once by its primary responsibility. Cross-cutting hooks remain with their containing file: for example BluetoothTransmitter includes capture hooks, WatchStateModel routes runtime/capture messages, and WatchManager routes several protocols. These are whole-file accounting buckets, not an exact measure of removable modules. Extraction lowers net counts without eliminating the need to review moved behaviour.

## Recommended review sequence

1. **Shared collector and phone regression surface.** Read [BluetoothTransmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/Generic/BluetoothTransmitter.swift), [Libre2BluetoothTransmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2BluetoothTransmitter.swift), [CGMLibre2Transmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/CGMLibre2Transmitter.swift) and [Libre2BLEUtilities.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/Libre2BLEUtilities.swift) together with both sensor adapters. Check callback ordering, authentication/counter reservation, frame timestamps/parser state and behaviour when Direct Libre is unused. The small LibreNFC/LibreNFCDelegate diff matters: successful provisioning now supplies the actual unlock code, and the phone adapter performs the experimental reset when applicable.

2. **Switching and recovery.** Read [Libre2ConnectionStore.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2ConnectionStore.swift), [Libre2PhoneConnection.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneConnection.swift) and [Libre2WatchConnection.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/BluetoothTransmitter/Libre2WatchConnection.swift), with the session/message types. Check disconnect-before-activation, counter refresh during preparation, return ordering, persistence failures, stale replies, relaunch and authoritative NFC reset. Ordinary local restart and ownership transfer have different release requirements.

3. **Data integrity and phone actions.** Read [Libre2WatchHistorySync.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/BluetoothTransmitter/Libre2WatchHistorySync.swift), [Libre2HistoryQueue.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2HistoryQueue.swift), [Libre2PhoneHistorySync.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneHistorySync.swift) and [Libre2PhoneReadingProcessing.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneReadingProcessing.swift), followed by the RootApplicationCoordinator and WatchManager diffs. Check that latest delivery is independent of history acknowledgement; persisted data survives failed delivery; acknowledgements follow durable saves; duplicate/history imports do not act as fresh readings; and fresh imports reach the expected alerts, sharing and uploads.

4. **Display and existing Watch behaviour.** Read [WatchStateModel.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/DataModels/WatchStateModel.swift), GlucoseTrend and the small existing view diffs. Check units/limits across restart, stale phone payloads, graph/complication ordering, trend parity, antenna state and double-tap routing. Read the Advanced Settings page with the selection coordinator.

5. **Optional runtime and diagnostics as separate review areas.** Check opt-in location lifecycle and accuracy, notification-test claims, capability declarations and stopping on return. For capture, check event bounds, privacy, file/export handling and the cost when capture is disabled. Their dedicated files are separable review topics, although their integration hooks sit in shared files.

6. **Build graph, tests and documentation.** Inspect project membership and iOS guards to ensure Watch imports no phone-only NFC/Core Data dependencies. Read tests alongside each preceding area rather than treating them as an unrelated final block.

## Complete changed-file map

Links and table paths refer to the measured commit; the guides now live under lowercase `docs/direct-libre*.md`. “Existing” means a modified upstream file; “New” means a file added by this branch. Negative net counts generally reflect extraction into shared code.

### Shared BLE, protocol and platform adaptation

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip/BluetoothTransmitter/Generic/BluetoothTransmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/Generic/BluetoothTransmitter.swift) | Existing | 276 | 30 | +246 | Shared lifecycle: collection guards, release completion, connection-state callbacks and diagnostic hooks. Highest-impact common base to review. |
| [xDrip/BluetoothTransmitter/Generic/BluetoothTransmitterDelegate.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/Generic/BluetoothTransmitterDelegate.swift) | Existing | 4 | 0 | +4 | Additional connection-state delegate surface. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2BluetoothTransmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2BluetoothTransmitter.swift) | New | 174 | 0 | +174 | Shared F001/F002 subscription, unlock, frame assembly/decryption and delivery extracted from the phone transmitter. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Libre2/CGMLibre2Transmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/CGMLibre2Transmitter.swift) | Existing | 90 | 248 | -158 | Phone adapter, Direct Libre eligibility/session export and collection guards. NFC completion adopts the code actually provisioned and resets experimental selection when applicable. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2PhoneSensor.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2PhoneSensor.swift) | New | 56 | 0 | +56 | Phone preferences, counter and parser-state adapter; phone-only raw-history preference helpers. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2WatchSensor.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2WatchSensor.swift) | New | 44 | 0 | +44 | Watch sensor adapter and durable counter reservation before an unlock attempt. |
| [xDrip Watch App/BluetoothTransmitter/Libre2WatchTransmitter.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/BluetoothTransmitter/Libre2WatchTransmitter.swift) | New | 36 | 0 | +36 | Small Watch adapter around the shared Libre collector; forwards state, readings and diagnostics. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Utilities/Libre2BLEUtilities.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/Libre2BLEUtilities.swift) | Existing | 27 | 95 | -68 | Shared parser with explicit per-sensor state; phone-specific preference handling moved to the phone adapter. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Utilities/PreLibre2.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/PreLibre2.swift) | Existing | 0 | 4 | -4 | Removes the blanket CoreNFC compilation guard so existing crypto can compile for Watch. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreSensorType.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreSensorType.swift) | Existing | 2 | 0 | +2 | iOS compilation guard around phone-only helpers; shared sensor definitions stay available to Watch. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreNFC.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreNFC.swift) | Existing | 3 | 3 | +0 | Passes the NFC-provisioned unlock code through the existing completion delegate; NFC command sequence is not replaced. |
| [xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreNFCDelegate.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreNFCDelegate.swift) | Existing | 2 | 1 | +1 | Completion signature carries the unlock code used by the scan. |
| [xDrip/Extensions/Array.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Extensions/Array.swift) | Existing | 3 | 0 | +3 | iOS guards around extensions requiring phone reading models. |
| [xDrip/Extensions/Int.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Extensions/Int.swift) | Existing | 7 | 0 | +7 | Receives the existing UInt16 time-formatting helper to separate its dependencies from byte conversion. |
| [xDrip/Extensions/UInt16.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Extensions/UInt16.swift) | Existing | 1 | 6 | -5 | Time-formatting helper moved to Int.swift; byte-conversion helper remains. |

### Phone-controlled selection and handoff

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2WatchSession.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Libre/Libre2/Libre2WatchSession.swift) | New | 47 | 0 | +47 | Codable sensor credentials, calibration, identity and unlock counter with validation/persistence. |
| [xDrip/Managers/Libre2/Libre2ConnectionMessage.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2ConnectionMessage.swift) | New | 46 | 0 | +46 | Typed selection/handoff messages and decoding. |
| [xDrip/Managers/Libre2/Libre2ConnectionStore.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2ConnectionStore.swift) | New | 102 | 0 | +102 | Persisted selection phases and session IDs; phone/Watch connection permission and stale-session rejection. |
| [xDrip/Managers/Libre2/Libre2PhoneConnection.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneConnection.swift) | New | 313 | 0 | +313 | Phone transaction coordinator, eligibility, disconnect-before-activation, return and NFC reset/revocation. |
| [xDrip Watch App/BluetoothTransmitter/Libre2WatchConnection.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/BluetoothTransmitter/Libre2WatchConnection.swift) | New | 239 | 0 | +239 | Watch transaction coordinator, collector lifecycle and explicit double-tap restart. |
| [xDrip/Managers/BluetoothPeripheral/BluetoothPeripheralManager+BluetoothTransmitterDelegate.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/BluetoothPeripheral/BluetoothPeripheralManager%2BBluetoothTransmitterDelegate.swift) | Existing | 3 | 0 | +3 | Routes transmitter connection events into the phone selection coordinator. |

### Reading delivery, storage and phone processing

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip/Managers/Libre2/Libre2History.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2History.swift) | New | 181 | 0 | +181 | Reading, batch and acknowledgement types; identity, limits and validation. |
| [xDrip/Managers/Libre2/Libre2HistoryQueue.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2HistoryQueue.swift) | New | 123 | 0 | +123 | Durable Watch outbox, immutable in-flight batch and acknowledgement/retry bookkeeping. |
| [xDrip/Managers/Libre2/Libre2JournalFile.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2JournalFile.swift) | New | 24 | 0 | +24 | Small shared atomic JSON persistence helper used beyond history as well. |
| [xDrip Watch App/BluetoothTransmitter/Libre2WatchHistorySync.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/BluetoothTransmitter/Libre2WatchHistorySync.swift) | New | 218 | 0 | +218 | Independent latest-reading delivery and acknowledged historical batch delivery through WatchConnectivity. |
| [xDrip/Managers/Libre2/Libre2PhoneHistorySync.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneHistorySync.swift) | New | 302 | 0 | +302 | Phone import scheduling, Core Data save/acknowledgement, deduplication and sensor registry (registry is in this file). |
| [xDrip/Managers/Libre2/Libre2PhoneReadingProcessing.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2PhoneReadingProcessing.swift) | New | 73 | 0 | +73 | Imported-reading freshness/eligibility and integration with downstream reading processing. |
| [xDrip/Managers/Application/RootApplicationCoordinator.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Application/RootApplicationCoordinator.swift) | Existing | 99 | 61 | +38 | Common downstream processing for stored sensor readings and Watch imports; review alerts, sharing and upload routing. |
| [xDrip/Managers/Watch/WatchManager.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Watch/WatchManager.swift) | Existing | 29 | 1 | +28 | Phone WatchConnectivity routing for handoff, readings, runtime and capture messages. |

### Display, trends and main settings

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip Watch App/DataModels/WatchStateModel.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/DataModels/WatchStateModel.swift) | Existing | 117 | 7 | +110 | Direct readings use existing graph/complication updates; cache/units/limits, relayed-reading guards, message routing and lifecycle hooks. |
| [xDrip/BluetoothTransmitter/CGM/Generic/GlucoseTrend.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/BluetoothTransmitter/CGM/Generic/GlucoseTrend.swift) | New | 26 | 0 | +26 | Shared trend calculations extracted for use on phone and Watch. |
| [xDrip/Core Data/classes/BgReading+CoreDataClass.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Core%20Data/classes/BgReading%2BCoreDataClass.swift) | Existing | 4 | 50 | -46 | Delegates existing trend calculations to GlucoseTrend; extraction explains the negative net count. |
| [xDrip Watch App/Views/Libre2ConnectionIndicator.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Views/Libre2ConnectionIndicator.swift) | New | 32 | 0 | +32 | Antenna colour and animation for direct connection states. |
| [xDrip Watch App/Views/BigNumberView/BigNumberView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Views/BigNumberView/BigNumberView.swift) | Existing | 2 | 5 | -3 | Uses shared direct indicator and connection-reset double-tap action. |
| [xDrip Watch App/Views/MainView/MainView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Views/MainView/MainView.swift) | Existing | 1 | 1 | +0 | Routes double tap through the selected-source retry action. |
| [xDrip Watch App/Views/MainView/SubViews/MainViewInfoView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Views/MainView/SubViews/MainViewInfoView.swift) | Existing | 1 | 4 | -3 | Uses the shared connection indicator. |
| [xDrip/SwiftUIViews/Settings/DirectLibreSettingsView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/SwiftUIViews/Settings/DirectLibreSettingsView.swift) | New | 165 | 0 | +165 | Advanced Settings entry page: selected device, switching/checklist, activity and unresolved-reading action. |
| [xDrip/SwiftUIViews/Settings/Models/SettingsViewDevelopmentSettingsViewModel.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/SwiftUIViews/Settings/Models/SettingsViewDevelopmentSettingsViewModel.swift) | Existing | 1 | 0 | +1 | Adds Direct Libre to the existing Advanced Settings model. |
| [xDrip/SwiftUIViews/Settings/SettingsSharedUtilities.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/SwiftUIViews/Settings/SettingsSharedUtilities.swift) | Existing | 8 | 1 | +7 | Settings destination routing and label. |

### Optional background runtime

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip Watch App/Managers/Libre2WatchLocationSession.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Managers/Libre2WatchLocationSession.swift) | New | 162 | 0 | +162 | Opt-in location-backed collection, permission/lifecycle management and three accuracy choices. |
| [xDrip Watch App/Managers/Libre2WatchNotificationTest.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Managers/Libre2WatchNotificationTest.swift) | New | 80 | 0 | +80 | User-requested test notification and Watch presentation; observed background-delivery startup aid, not a delivery guarantee. |
| [xDrip/Managers/Libre2/Libre2RuntimeMessages.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2RuntimeMessages.swift) | New | 37 | 0 | +37 | Location and notification command/status messages. |
| [xDrip/SwiftUIViews/Settings/DirectLibreRuntimeSettingsView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/SwiftUIViews/Settings/DirectLibreRuntimeSettingsView.swift) | New | 150 | 0 | +150 | Background settings, status and notification-test controls. |
| [xDrip Watch App/xDripWatchApp.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/xDripWatchApp.swift) | Existing | 1 | 0 | +1 | Registers the experimental test-notification scene. |

### Diagnostic capture and export

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip/Managers/Libre2/Libre2DiagnosticCapture.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2DiagnosticCapture.swift) | New | 316 | 0 | +316 | Bounded capture model, recorder, persistence and chunked-export protocol. |
| [xDrip/Managers/Libre2/Libre2CaptureController.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/Managers/Libre2/Libre2CaptureController.swift) | New | 129 | 0 | +129 | Phone capture commands, status and retrieval of the Watch report. |
| [xDrip Watch App/Managers/Libre2WatchDiagnostics.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Managers/Libre2WatchDiagnostics.swift) | New | 48 | 0 | +48 | Watch lifecycle/system context and connection snapshots for capture. |
| [xDrip/SwiftUIViews/Settings/DirectLibreDiagnosticsView.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip/SwiftUIViews/Settings/DirectLibreDiagnosticsView.swift) | New | 54 | 0 | +54 | Capture start/status/stop/export interface in Advanced Settings. |
| [xDrip Watch App/Utilities/Trace.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Watch%20App/Utilities/Trace.swift) | New | 10 | 0 | +10 | Watch logging shim needed by shared source files; classified here as logging support. |

### Tests

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xDrip Tests/GlucoseTrendTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/GlucoseTrendTests.swift) | New | 46 | 0 | +46 | Shared trend arithmetic and boundary cases. |
| [xDrip Tests/Libre2CollectorTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2CollectorTests.swift) | New | 109 | 0 | +109 | Collector policy, counter and delivery invariants. |
| [xDrip Tests/Libre2ConnectionTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2ConnectionTests.swift) | New | 141 | 0 | +141 | Selection/session persistence and transition validation. |
| [xDrip Tests/Libre2DiagnosticCaptureTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2DiagnosticCaptureTests.swift) | New | 251 | 0 | +251 | Capture bounds, persistence and export behaviour. |
| [xDrip Tests/Libre2HistoryTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2HistoryTests.swift) | New | 449 | 0 | +449 | Reading/batch validation, durable queue and acknowledgements. |
| [xDrip Tests/Libre2PhoneHistorySyncTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2PhoneHistorySyncTests.swift) | New | 404 | 0 | +404 | Phone import scheduling and reading-processing decisions. |
| [xDrip Tests/Libre2ProtocolTests.swift](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip%20Tests/Libre2ProtocolTests.swift) | New | 150 | 0 | +150 | Shared parser/protocol behaviour. |

### Documentation

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [Docs/DirectLibre.md](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/Docs/DirectLibre.md) | New | 257 | 0 | +257 | Feature workflow, recovery, architecture and footprint. |
| [Docs/DirectLibreValidation.md](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/Docs/DirectLibreValidation.md) | New | 93 | 0 | +93 | Reviewable validation scope, device checks and remaining limits. |
| [README.md](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/README.md) | Existing | 2 | 0 | +2 | Entry link to the feature documentation. |

### Xcode and capabilities

| File | Kind | Added | Deleted | Net | Review focus |
| --- | --- | ---: | ---: | ---: | --- |
| [xdrip.xcodeproj/project.pbxproj](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xdrip.xcodeproj/project.pbxproj) | Existing | 226 | 0 | +226 | Source/target membership, build entries and target configuration. Count reflects the committed project only, excluding local signing overrides. |
| [xDrip-Watch-App-Info.plist](https://github.com/rnederstigt/xdripswift/blob/91e15071a3c0cc41d8fefae18426d18872c59098/xDrip-Watch-App-Info.plist) | Existing | 13 | 0 | +13 | Bluetooth/location background declarations and permission text; underwater foreground declaration. |

## Reused source that does not appear in the changed-file count

The Watch target also compiles existing source without modifying it. In particular, the upstream Libre2FrameAssembler is reused; its inclusion is visible in project membership, not as an added protocol implementation. Existing crypto/algorithm helpers are similarly reused. Review the project diff to see the complete dependency set. The main extraction pairs are CGMLibre2Transmitter → Libre2BluetoothTransmitter, preference-dependent parsing → Libre2PhoneSensor, and BgReading trend calculations → GlucoseTrend.

There is no separate CGMLibre2Transmitter+NFC file in this snapshot: NFC methods live in CGMLibre2Transmitter. Libre2HistoryRegistry is a type inside Libre2PhoneHistorySync, not a separate source file.

## Validation status and review limits

See the [validation record and device regression checklist](direct-libre-validation.md) for automated coverage, build-environment limitations and outstanding acceptance checks. Platform doubles and targeted type-checks do not establish real Bluetooth recovery or WatchConnectivity scheduling behaviour.

## Reproducing the totals

```sh
git diff --shortstat 0370937605a59f520f2d4eb6bec79fcc3cc3af88...91e15071a3c0cc41d8fefae18426d18872c59098
git diff --numstat 0370937605a59f520f2d4eb6bec79fcc3cc3af88...91e15071a3c0cc41d8fefae18426d18872c59098
```
