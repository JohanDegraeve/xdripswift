# Third-party notices

## JugglucoNG Sibionics V116A stock algorithm

The stock Sibionics V1.1.6A algorithm is adapted from [ctqvva/JugglucoNG](https://github.com/ctqvva/JugglucoNG), pinned to commit `34ad7bbdcf3b53d1690347738a6a70f6a985b251`, and licensed under the GNU General Public License version 3 (GPL-3.0). See the upstream revision's [LICENSE.txt](https://github.com/ctqvva/JugglucoNG/blob/34ad7bbdcf3b53d1690347738a6a70f6a985b251/LICENSE.txt). The repository is distributed under GPL-3.0 as well.

Adapted upstream source:
- `Sibionics2Core/src/commonMain/kotlin/tk/glucodata/drivers/sibionics/v116a/SibionicsExactV116A.kt` is the complete V116A state machine from `Common/src/main/java/tk/glucodata/drivers/sibionics/v116a/SibionicsExactV116A.kt`.
- `Sibionics2Core/src/commonMain/kotlin/tk/glucodata/drivers/sibionics/SibionicsNativeModels.kt` contains the two minimal DTOs used by that source.
- `Sibionics2Core/src/commonMain/kotlin/tk/glucodata/drivers/sibionics/Sibionics2V116AFacade.kt` is a new primitive-only Kotlin/Native bridge.

The algorithm source was adapted to common Kotlin: Java unsigned integer comparison became a sign-bit ordered comparison; Java unsigned decimal Long conversion became Kotlin ULong-to-Double conversion; `Math.pow` became `kotlin.math.pow`; and JVM-only hexadecimal formatting became common string formatting. Algorithm branches, constants, state layout, and outputs were not intentionally changed. The facade uses NaN to signal that the stock algorithm has not produced an exact correction.

The Sibionics probe sensitivity decoder in `xDrip/BluetoothTransmitter/CGM/Sibionics2/Sibionics2FactorySensitivity.swift` is behavior-adapted from JugglucoNG's `SibionicsProbeSensitivity.kt` and `SibionicsProtocol.kt`; the short decoder retains the original A/P-base checksum rules. No iGlucco source code is included.

The `JugglucoNG` calibration profile and V120 maintenance-reset command in `xDrip/BluetoothTransmitter/CGM/Sibionics2/Sibionics2Configuration.swift` and `Sibionics2Protocol.swift` are behavior-adapted from ctqvva/JugglucoNG commit `da788a73f897a19707adf3111e39f2735cfc2cad` (`Common/src/main/java/tk/glucodata/data/calibration/CalibrationMath.kt` and `Common/src/main/java/tk/glucodata/drivers/sibionics/SibionicsProtocol.kt`). JugglucoNG is licensed under GPL-3.0; this repository is distributed under GPL-3.0 as well.

## JugglucoNG V116A conformance fixture

The startup fixture and native-state vectors are adapted from the same pinned revision:
- `Common/src/test/resources/sibionics_exact_v116a_startup.csv`
- `Common/src/test/java/tk/glucodata/drivers/sibionics/SibionicsExactV116ACoreTest.kt`

`xDrip Tests/Fixtures/sibionics2_v116a_startup.csv` renames the CSV and adds attribution comments; all 130 numeric data rows are unchanged. Kotlin/JVM tests assert every exact-core row and selected state hashes/snapshot continuation. Swift XCTest specifies the xDrip wrapper behavior for every row in both live and replay modes, including the documented held-stock-delta rule. Timestamps, impedance, trend, and reindex are synthetic metadata because the source fixture does not contain them.

## JugglucoNG Sibionics V115G stock algorithm and replay

The Chinese Sibionics 1 V1.1.5G core and generated clip state machine are adapted from [ctqvva/JugglucoNG](https://github.com/ctqvva/JugglucoNG), pinned to commit `a2070a6b7af03cc255e0b32f124c3200b13da30f`, under GPL-3.0. See that revision's [LICENSE.txt](https://github.com/ctqvva/JugglucoNG/blob/a2070a6b7af03cc255e0b32f124c3200b13da30f/LICENSE.txt).

Adapted source and test data:
- `Common/src/main/java/tk/glucodata/drivers/sibionics/SibionicsExactV115GCore.kt` and `SibionicsExactV115GClip.kt` are preserved under `Sibionics2Core/src/commonMain/kotlin/tk/glucodata/drivers/sibionics/`.
- `Common/src/test/java/tk/glucodata/drivers/sibionics/SibionicsExactV115GCoreTest.kt` supplies the replay and snapshot conformance cases.
- `Common/src/test/resources/sibionics_exact_v115g_replay.csv` is copied byte-for-byte to `xDrip Tests/Fixtures/sibionics1_v115g_replay.csv`. As in the upstream tests, `vendor_mmol` is the proprietary conformance target (3,153 five-minute outputs); the CSV's `exact_mmol` column is an older comparison, not the expected output.

Common Kotlin adaptations replace Java data streams with big-endian snapshot primitives (including Java's canonical NaN encoding), overlapping array shifts with `copyInto`, unsigned Int comparisons with sign-bit ordering, and unsigned Long decimal conversion with common Kotlin's ULong decimal conversion. Algorithm arithmetic, branches, constants, core snapshot versions, and serialized layout are preserved. `Sibionics1V115GFacade.kt` adds the primitive Kotlin/Native bridge. The Swift wrapper applies the upstream S1 startup raw-value and held-correction rules and uses a distinct `S1GP` snapshot envelope. Existing V116A uses its unchanged `S2GP` envelope. No iGlucco source code is included.

## JugglucoNG glucose prediction and insulin curves

The experimental glucose prediction, insulin action curves and insulin activity band in `xDrip/Managers/Therapy/ExperimentalTherapy.swift` are adapted from [ctqvva/JugglucoNG](https://github.com/ctqvva/JugglucoNG) commit `ab40075db18c105cbf6cfa4f361cf3dac2444889` (`Common/src/main/java/tk/glucodata/data/prediction/GlucosePredictionKernel.kt`, `Common/src/mobile/java/tk/glucodata/data/prediction/GlucosePrediction.kt`, `Common/src/mobile/java/tk/glucodata/data/journal/JournalInsulinCurveCatalogue.kt`, `JournalModels.kt`, `Common/src/mobile/java/tk/glucodata/ui/InsulinActivityStack.kt` and `Common/src/main/java/tk/glucodata/GlucoseChartGap.kt`). JugglucoNG is licensed under GPL-3.0; this repository is distributed under GPL-3.0 as well.
