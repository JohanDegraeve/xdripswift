# macOS verification — 2026-10-11

Tested application commit: `77143e99d0d92742bde6269f0bd855f35bcf201e`.
Baseline: upstream develop `c268542e64626c564e626658fa9a6b90a059ada4`.
Environment: GitHub-hosted macOS 26.6.2 arm64, Xcode 26.2 (17C52), Swift 6.2.3.

## Build and Garmin tests

[Build run](https://github.com/sejkoramartin/xdripswift/actions/runs/38154744346):
all 40 standalone Garmin tests passed on macOS; real Connect IQ 1.8.0 package
resolution and the complete unsigned Debug iPhone build passed. No signing,
installation, archive distribution or TestFlight upload was performed.
The initial simulator attempt used iOS 26.4 with parallel runners and was cancelled
after prolonged execution; its overall run is cancelled, not successful.
Use the completed serial runs below as the XCTest evidence.

## Completed upstream XCTest comparison

Both runs used iPhone 17 Pro / iOS 26.2 arm64 simulators, serial testing and the
same timeout settings. No tests were excluded or marked as expected failures.

| Source | Tests | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: |
| [Garmin branch](https://github.com/sejkoramartin/xdripswift/actions/runs/38156434514) | 563 | 555 | 8 | 0 |
| [Upstream baseline](https://github.com/sejkoramartin/xdripswift/actions/runs/38156578760) | 563 | 554 | 9 | 0 |

The unmodified baseline could not build because of empty `OBJROOT`, `SYMROOT` and
`SHARED_PRECOMPS_DIR` overrides. For the baseline test run only, those six empty
Debug/Release entries were removed in the CI checkout, matching the existing PR
build-path fix. The exact patch is saved in the baseline artifact as
`baseline-build-path-only.diff`. No baseline application or test code was changed.
The failed initial unnormalized baseline is also visible in run 38156434514.

All eight failing Garmin-branch test identifiers also failed on the normalized
upstream baseline. No additional failing test was observed in the Garmin branch
in this comparison. This is not a claim that all tests pass or that regressions
are impossible. The one baseline-only failure may be environment/order dependent;
we do not claim Garmin fixes it.

Shared failures:

- `TroubleshootingLogTests/testActivityLogFilterMatchesRenderedMessagesAndRestoresFullListForBlankText()`
- `GlucoseRangeDistributionTests/testClinicalTIRBucketsShareWholePercentAndMinuteAllocation()`
- `DexcomG6SensorLabelTests/testDecodesAllObservedSensorLabels()`
- `GlucoseRangeDistributionTests/testLargestRemainderPreventsIndependentRoundingFromProducing101Percent()`
- `DexcomG6SensorLabelTests/testMigratesExistingSensorFromV26ToV27()`
- `TroubleshootingLogTests/testNamedBluetoothRecoveryIsKeptOnlyAfterFailure()`
- `DexcomG6SensorLabelTests/testRoundTripsDexcomG7LabelAndConnectionSettingsThroughCoreData()`
- `DexcomG6SensorLabelTests/testRoundTripsSensorStartMetadataThroughCoreData()`

Baseline-only failure: `DexcomG6SensorLabelTests/testFormatsDexcomG7ApplicatorDatesWithoutShiftingToPreviousDay()`.

## Remaining validation

Physical iPhone/watch delivery, locked-phone/background behavior, Bluetooth loss
and reconnect, switching watches, disable, calibration and unit changes on the
actual watch display remain untested for this branch. Simulator results cannot
verify the Bluetooth radio or Garmin firmware behavior. PR stays draft.

The workflows live on the fork's `codex/garmin-macos-verification` branch, outside
the upstream PR. Each completed run includes logs and an `.xcresult` artifact
with 14-day retention; download them before expiry. The tested application code
is unchanged by this documentation update.
