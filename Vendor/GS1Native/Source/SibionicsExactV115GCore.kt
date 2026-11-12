package tk.glucodata.drivers.sibionics

import gs1.compat.ByteArrayInputStream
import gs1.compat.ByteArrayOutputStream
import gs1.compat.DataInputStream
import gs1.compat.DataOutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow

/**
 * Managed port of the recovered Sibionics v1.1.5G conversion pipeline.
 *
 * The recovered conversion refreshes its correction output every five samples.
 * Callers must feed every one-minute raw sample in ascending sensor-index order;
 * the driver-facing wrapper turns those correction refreshes into one-minute
 * readings with the same delta-carry behavior as the legacy driver.
 */
internal class SibionicsExactV115GCore(
    decodedSensitivity: Float = DEFAULT_DECODED_SENSITIVITY,
) {
    data class DebugState(
        val flags: Int,
        val corrected: Float,
        val kalman: Float,
        val compensated: Float,
        val base: Float,
        val adjusted: Float,
        val stageCount: Int,
        val sensitivity: Float,
        val clipCompensation: Float,
        val esa: Float,
        val deconvolution: Float,
        val display: Float,
    )

    private class Kalman {
        var state = 0f
        var previous = 0f
        var pMinus = 0f
        var gain = 0f
        var mn = 1.2000000476837158f
        var pn = 0.5f
        var ec = 0.0001f

        fun update(measurement: Float, index: Int): Float {
            val m = f32(measurement)
            if (!m.isFinite()) return state
            if (index <= 1) {
                state = m
                return m
            }
            pMinus = f32(ec + pn)
            gain = f32(pMinus / f32(pMinus + mn))
            val next = f32(state + f32(gain * f32(m - state)))
            previous = state
            state = next
            ec = f32(pMinus * f32(1f - gain))
            return state
        }
    }

    private class Temperature {
        private val buffer = FloatArray(10)
        var last = 0f
        var average = 0f
        var sumAverage = 0f
        var runningAverage = 0f

        fun update(temperatureC: Float, value: Float, indexMinusOne: Int): Float {
            var temperature = f32(temperatureC)
            val input = f32(value)
            if (temperature >= 42f) temperature = last
            val old1 = buffer[1]
            val old9 = buffer[9]
            var total = old1.toDouble() + old9.toDouble() + temperature.toDouble()
            for (offset in 2..8) total += buffer[offset].toDouble()
            var avg = f32((total / 10.0).toFloat())
            if (indexMinusOne < 9) avg = temperature
            buffer[0] = old1
            for (offset in 1..8) buffer[offset] = buffer[offset + 1]
            buffer[9] = old9
            buffer[9] = temperature
            last = avg
            average = avg
            sumAverage = f32(sumAverage + avg)
            runningAverage = f32(sumAverage / (indexMinusOne + 1).toFloat())
            val t = avg.toDouble()
            val poly =
                t * -0.03786363 +
                    t * t * -0.7637396454811096 +
                    t.pow(3.0) * 0.061271119862794876 +
                    t.pow(4.0) * -0.0019132299348711967 +
                    t.pow(5.0) * 0.00002677628435776569 +
                    t.pow(6.0) * -0.00000013804908860493015 +
                    65.21018525
            return f32(input + f32(f32(input - 0.5f) * f32(f32(34f - f32(poly.toFloat())) * 0.04f)))
        }

        fun writeTo(output: DataOutputStream) {
            buffer.forEach(output::writeFloat)
            output.writeFloat(last)
            output.writeFloat(average)
            output.writeFloat(sumAverage)
            output.writeFloat(runningAverage)
        }

        fun readFrom(input: DataInputStream) {
            buffer.indices.forEach { buffer[it] = input.readFloat() }
            last = input.readFloat()
            average = input.readFloat()
            sumAverage = input.readFloat()
            runningAverage = input.readFloat()
        }
    }

    private class CurrentJudgment {
        var lastCurrent = 0f
        var abnormalFlag = 0
        val previous = FloatArray(2)
        var variance = 0f
        var lastAbnormalFlag = 0
        var maxCurrent = 0f

        fun evaluate(current: Float, index: Int): Int {
            var flag = if (current > 70f && index < 60) 1 else 0
            val mean = (previous[1].toDouble() + current.toDouble()) * 0.5
            val varianceValue = ((previous[1] - mean).pow(2.0) + (current - mean).pow(2.0)) * 0.5
            abnormalFlag = flag
            lastCurrent = previous[1]
            previous[1] = current
            variance = varianceValue.toFloat()
            if (
                (abs(previous[0] - current) > 3.5f && varianceValue > 1.0 && index > 20 && flag == 0) ||
                (current < 1f && index < 60) ||
                (current <= 0.01f && index < 2880) ||
                (current < 1f && index > 2879) ||
                (lastAbnormalFlag == 1 && maxCurrent > 0f && index > 20 && maxCurrent < current)
            ) {
                flag = 1
                abnormalFlag = 1
            }
            if ((maxCurrent < current && index > 20 && flag == 0) || (index < 21 && current < 10f && maxCurrent < current)) {
                maxCurrent = current
            }
            previous[0] = current
            lastAbnormalFlag = flag
            return flag
        }

        fun writeTo(output: DataOutputStream) {
            output.writeFloat(lastCurrent)
            output.writeInt(abnormalFlag)
            previous.forEach(output::writeFloat)
            output.writeFloat(variance)
            output.writeInt(lastAbnormalFlag)
            output.writeFloat(maxCurrent)
        }

        fun readFrom(input: DataInputStream) {
            lastCurrent = input.readFloat()
            abnormalFlag = input.readInt()
            previous.indices.forEach { previous[it] = input.readFloat() }
            variance = input.readFloat()
            lastAbnormalFlag = input.readInt()
            maxCurrent = input.readFloat()
        }
    }

    private class AbnormalJudgment {
        val flags = FloatArray(15)
        var zeroStreak = 0
        val current = CurrentJudgment()

        fun evaluate(raw: Float, temperatureC: Float, index: Int): Int {
            gs1.compat.arrayCopy(flags, 1, flags, 0, flags.lastIndex)
            flags[flags.lastIndex] = current.evaluate(raw, index).toFloat()
            var count = 0f
            if (index > 14) flags.forEach { if (it == 1f) count += 1f }
            zeroStreak = if (raw == 0f) zeroStreak + 1 else 0
            var output = when {
                temperatureC < 10f -> 1
                temperatureC > 42f -> 2
                else -> 0
            }
            if (zeroStreak >= 2) output = output or 0x10
            if (count >= 7f) output = output or 0x20
            return output
        }

        fun writeTo(output: DataOutputStream) {
            flags.forEach(output::writeFloat)
            output.writeInt(zeroStreak)
            current.writeTo(output)
        }

        fun readFrom(input: DataInputStream) {
            flags.indices.forEach { flags[it] = input.readFloat() }
            zeroStreak = input.readInt()
            current.readFrom(input)
        }
    }

    private class CurrentCorrection(var sensitivity: Float) {
        var lastS = 0f
        var sFlag = 0
        var previous2 = 0f
        var previous1 = 0f
        var current = 0f

        fun update(previousCorrected: Float, rawValue: Float, index: Int): Float {
            var raw = f32(rawValue)
            val older = previous1
            val previous = current
            val reference = if (previousCorrected != 0f) previousCorrected else 1f
            previous2 = older
            previous1 = previous
            current = raw
            val threshold = reference * 10f
            if (index > 0 && (threshold < abs(raw - previous) || threshold < abs(raw - older))) {
                if (threshold < raw - previous || threshold < raw - older) {
                    raw = f32(previous + 1f)
                } else if (raw - previous <= -threshold || raw - older <= -threshold) {
                    if (abs(raw - older) < 3f) {
                        current = older
                        return older
                    }
                    raw = f32(previous - 1f)
                }
                current = raw
            }
            return raw
        }

        fun writeTo(output: DataOutputStream) {
            output.writeFloat(sensitivity)
            output.writeFloat(lastS)
            output.writeInt(sFlag)
            output.writeFloat(previous2)
            output.writeFloat(previous1)
            output.writeFloat(current)
        }

        fun readFrom(input: DataInputStream) {
            sensitivity = input.readFloat()
            lastS = input.readFloat()
            sFlag = input.readInt()
            previous2 = input.readFloat()
            previous1 = input.readFloat()
            current = input.readFloat()
        }
    }

    private class FilterStage(
        private val a: FloatArray,
        private val b: FloatArray,
    ) {
        private val y = FloatArray(3)
        private val x = FloatArray(2)

        fun update(inputValue: Float, n: Int): Float {
            val input = f32(inputValue)
            if (n == 0) {
                y[0] = f32(b[0] * input)
                x[0] = input
                return y[0]
            }
            if (n == 1) {
                y[1] = f32(f32(b[0] * input + b[1] * x[0]) - a[1] * y[0])
                x[1] = input
                return y[1]
            }
            y[2] = f32(
                b[0] * input +
                    b[1] * x[1] +
                    b[2] * x[0] -
                    a[1] * y[1] -
                    a[2] * y[0],
            )
            val oldX1 = x[1]
            x[1] = input
            x[0] = oldX1
            y[0] = y[1]
            y[1] = y[2]
            return y[2]
        }

        fun writeTo(output: DataOutputStream) {
            y.forEach(output::writeFloat)
            x.forEach(output::writeFloat)
        }

        fun readFrom(input: DataInputStream) {
            y.indices.forEach { y[it] = input.readFloat() }
            x.indices.forEach { x[it] = input.readFloat() }
        }
    }

    private class Filters {
        private val stages = arrayOf(
            FilterStage(
                floatArrayOf(1f, 1.5610181093215942f, 0.6413515210151672f),
                floatArrayOf(0.8005924224853516f, 1.6011848449707031f, 0.8005924224853516f),
            ),
            FilterStage(
                floatArrayOf(1f, -1.7786318063735962f, 0.8008026480674744f),
                floatArrayOf(0.005542720202356577f, 0.011085440404713154f, 0.005542720202356577f),
            ),
            FilterStage(
                floatArrayOf(1f, -1.9644606113433838f, 0.9650811553001404f),
                floatArrayOf(0.00015515000268351287f, 0.00031030000536702573f, 0.00015515000268351287f),
            ),
            FilterStage(
                floatArrayOf(1f, -1.8226948976516724f, 0.8371816277503967f),
                floatArrayOf(0.003621679963544011f, 0.007243359927088022f, 0.003621679963544011f),
            ),
            FilterStage(
                floatArrayOf(1f, -1.5610181093215942f, 0.6413515210151672f),
                floatArrayOf(0.020083369687199593f, 0.040166739374399185f, 0.020083369687199593f),
            ),
        )

        fun update(adjusted: Float, index: Int): FloatArray {
            val n = index / 5 - 1
            return FloatArray(stages.size) { stage -> stages[stage].update(adjusted, n) }
        }

        fun writeTo(output: DataOutputStream) = stages.forEach { it.writeTo(output) }

        fun readFrom(input: DataInputStream) = stages.forEach { it.readFrom(input) }
    }

    private class Esa {
        private val buffer = FloatArray(5)

        /**
         * The additive sensor-state term ESA contributes, i.e. the mean of the
         * compensation history it holds. Equal to what [update] adds, so it can
         * be applied to off-stage minutes without re-running the stage.
         */
        fun compensationMean(): Float = f32(buffer.sum() / 5f)

        fun update(current: Float, compensation: Float): Float {
            val f1 = buffer[1]
            val f2 = buffer[2]
            val f3 = buffer[3]
            val f4 = buffer[4]
            buffer[0] = f1
            buffer[1] = f2
            buffer[2] = f3
            buffer[3] = f4
            buffer[4] = compensation
            return f32(current + f32(f32(f1 + f2 + f3 + f4 + compensation) / 5f))
        }

        fun writeTo(output: DataOutputStream) = buffer.forEach(output::writeFloat)

        fun readFrom(input: DataInputStream) = buffer.indices.forEach { buffer[it] = input.readFloat() }
    }

    private class Deconvolution {
        private val buffer = FloatArray(30)

        fun update(value: Float): Float {
            val input = f32(value)
            gs1.compat.arrayCopy(buffer, 1, buffer, 0, buffer.lastIndex)
            buffer[buffer.lastIndex] = input
            if (input > 15f || input < 3.5f) return input
            var accumulator = 0f
            COEFFICIENTS.indices.forEach { offset ->
                accumulator = f32(accumulator + f32(buffer[buffer.lastIndex - offset] * COEFFICIENTS[offset]))
            }
            return f32(accumulator * 6.7f)
        }

        fun writeTo(output: DataOutputStream) = buffer.forEach(output::writeFloat)

        fun readFrom(input: DataInputStream) = buffer.indices.forEach { buffer[it] = input.readFloat() }
    }

    private var decodedSensitivity = decodedSensitivity
    private var sensitivity = changeSensitivity(decodedSensitivity)
    private var lastIg = 0f
    private var ig = 0f
    private var calibrationCompensation = 0f
    private var abnormal = AbnormalJudgment()
    private var correction = CurrentCorrection(sensitivity)
    private var kalman = Kalman()
    private var temperature = Temperature()
    private var filters = Filters()
    private var clip = ExactV115GClip()
    private var esa = Esa()
    private var deconvolution = Deconvolution()
    private var temperatureUpCount = 0
    private var temperatureDownCount = 0
    private var temperatureUpSum = 0f
    private var temperatureDownSum = 0f

    var debug: DebugState? = null
        private set

    var latestChemicalSignal: SibionicsChemicalSignal? = null
        private set

    /**
     * Vendor sensor-state observation on the absolute glucose scale.
     *
     * The clip/ESA stage only runs every fifth minute, so its outputs are held
     * and re-applied to the minutes in between — the same convention the driver
     * already uses for the stock correction delta.
     */
    var latestSensorObservation: SibionicsSensorObservation? = null
        private set

    private var heldBase = 0f
    private var heldEsaCompensation = 0f
    private var hasStageState = false

    fun configure(decodedSensitivity: Float) {
        val normalized = decodedSensitivity.takeIf { it.isFinite() } ?: DEFAULT_DECODED_SENSITIVITY
        if (this.decodedSensitivity == normalized) return
        this.decodedSensitivity = normalized
        sensitivity = changeSensitivity(normalized)
        reset()
    }

    fun reset() {
        sensitivity = changeSensitivity(decodedSensitivity)
        lastIg = 0f
        ig = 0f
        calibrationCompensation = 0f
        abnormal = AbnormalJudgment()
        correction = CurrentCorrection(sensitivity)
        kalman = Kalman()
        temperature = Temperature()
        filters = Filters()
        clip = ExactV115GClip()
        esa = Esa()
        deconvolution = Deconvolution()
        temperatureUpCount = 0
        temperatureDownCount = 0
        temperatureUpSum = 0f
        temperatureDownSum = 0f
        debug = null
        latestChemicalSignal = null
        latestSensorObservation = null
        heldBase = 0f
        heldEsaCompensation = 0f
        hasStageState = false
    }

    fun process(rawMmol: Float, temperatureC: Float, index: Int): Float? {
        if (!rawMmol.isFinite() || rawMmol <= 0f) {
            latestChemicalSignal = null
            return null
        }
        val indexMinusOne = max(index - 1, 0)
        val flags = abnormal.evaluate(rawMmol, temperatureC, indexMinusOne)
        val corrected = correction.update(sensitivity, rawMmol, indexMinusOne)
        if ((flags and 0x30) != 0) {
            latestChemicalSignal = null
            return null
        }
        val filtered = kalman.update(corrected, index)
        val compensated = temperature.update(temperatureC, filtered, indexMinusOne)
        latestChemicalSignal = SibionicsChemicalSignal(
            mmol = (compensated / sensitivity).coerceAtLeast(0f),
            qualityFlags = flags,
        )
        publishSensorObservation(compensated, flags, index)
        lastIg = ig
        if (index % 5 != 0) return null

        val averageMinus20 = temperature.average - 20f
        val runningMinus20 = temperature.runningAverage - 20f
        when {
            averageMinus20 - runningMinus20 > 0f -> {
                temperatureUpCount++
                temperatureUpSum += averageMinus20
            }
            averageMinus20 - runningMinus20 < 0f -> {
                temperatureDownCount++
                temperatureDownSum += averageMinus20
            }
        }
        val upAverage = if (temperatureUpCount > 0) temperatureUpSum / temperatureUpCount else 0f
        val downAverage = if (temperatureDownCount > 0) temperatureDownSum / temperatureDownCount else 0f
        val base = adjustment(index, runningMinus20, downAverage)
        val initialSensitivity = clip.initialSensitivity
        val activeSensitivity = clip.activeSensitivity
        val adjusted = if (base < 0f && initialSensitivity * 0.95f > activeSensitivity) {
            (compensated - 0.2f) / sensitivity
        } else {
            (compensated - base) / sensitivity
        }
        val outputFilters = filters.update(adjusted, index)
        val stageCount = index / 5 - 1
        val clipResult = clip.update(
            adjusted = adjusted,
            filter1 = outputFilters[0],
            filter2 = outputFilters[1],
            filter3 = outputFilters[2],
            filter4 = outputFilters[3],
            filter5 = outputFilters[4],
            tempRunningM20 = runningMinus20,
            tempUpAverage = upAverage,
            tempDownAverage = downAverage,
            base = base,
            stageCount = stageCount,
        )
        sensitivity = clipResult.activeSensitivity
        val esaValue = esa.update(adjusted, clipResult.compensationSize)
        // Capture the stage's absolute sensor-state terms before deconvolution
        // so the minutes between stages can reuse them, then republish this
        // minute's observation now that they are current.
        heldBase = base
        heldEsaCompensation = esa.compensationMean()
        hasStageState = true
        publishSensorObservation(compensated, flags, index)
        ig = deconvolution.update(esaValue)
        val display = ig + calibrationCompensation
        debug = DebugState(
            flags = flags,
            corrected = corrected,
            kalman = filtered,
            compensated = compensated,
            base = base,
            adjusted = adjusted,
            stageCount = stageCount,
            sensitivity = sensitivity,
            clipCompensation = clipResult.compensationSize,
            esa = esaValue,
            deconvolution = ig,
            display = display,
        )
        return nativeRound(max(display, 0f))
    }

    /**
     * Rebuilds [latestSensorObservation] from the current front-end value and
     * the held stage terms.
     *
     * Before the first clip/ESA stage completes there is no sensor-state
     * compensation to apply, and the chemical signal on its own is not on the
     * absolute scale — so no observation is published rather than a
     * systematically low one.
     */
    private fun publishSensorObservation(compensated: Float, flags: Int, index: Int) {
        if (!hasStageState || !compensated.isFinite() || sensitivity <= 0f) {
            latestSensorObservation = null
            return
        }
        val adjusted = (compensated - heldBase) / sensitivity
        val calibrated = adjusted + heldEsaCompensation
        latestSensorObservation = SibionicsSensorObservation(
            calibratedMmol = calibrated,
            chemicalMmol = (compensated / sensitivity).coerceAtLeast(0f),
            sensorStateCompensationMmol = heldEsaCompensation,
            qualityFlags = flags,
            factorySensitivity = clip.initialSensitivity,
            activeSensitivity = sensitivity,
            sensorAgeMinutes = index,
            family = FAMILY_V115G,
        )
    }

    fun snapshot(): ByteArray = ByteArrayOutputStream().use { bytes ->
        DataOutputStream(bytes).use { output ->
            output.writeInt(SNAPSHOT_MAGIC)
            output.writeInt(SNAPSHOT_VERSION)
            output.writeFloat(decodedSensitivity)
            output.writeFloat(sensitivity)
            output.writeFloat(lastIg)
            output.writeFloat(ig)
            output.writeFloat(calibrationCompensation)
            abnormal.writeTo(output)
            correction.writeTo(output)
            writeKalman(output)
            temperature.writeTo(output)
            filters.writeTo(output)
            esa.writeTo(output)
            deconvolution.writeTo(output)
            output.writeInt(temperatureUpCount)
            output.writeInt(temperatureDownCount)
            output.writeFloat(temperatureUpSum)
            output.writeFloat(temperatureDownSum)
            output.writeFloat(heldBase)
            output.writeFloat(heldEsaCompensation)
            output.writeBoolean(hasStageState)
            val clipState = clip.snapshot()
            output.writeInt(clipState.size)
            output.write(clipState)
        }
        bytes.toByteArray()
    }

    fun restore(snapshot: ByteArray?): Boolean = runCatching {
        if (snapshot == null || snapshot.isEmpty()) return false
        DataInputStream(ByteArrayInputStream(snapshot)).use { input ->
            if (input.readInt() != SNAPSHOT_MAGIC) return false
            val version = input.readInt()
            if (version != SNAPSHOT_VERSION && version != PRE_OBSERVATION_SNAPSHOT_VERSION) return false
            if (input.readFloat().toRawBits() != decodedSensitivity.toRawBits()) return false
            sensitivity = input.readFloat()
            lastIg = input.readFloat()
            ig = input.readFloat()
            calibrationCompensation = input.readFloat()
            abnormal.readFrom(input)
            correction.readFrom(input)
            readKalman(input)
            temperature.readFrom(input)
            filters.readFrom(input)
            esa.readFrom(input)
            deconvolution.readFrom(input)
            temperatureUpCount = input.readInt()
            temperatureDownCount = input.readInt()
            temperatureUpSum = input.readFloat()
            temperatureDownSum = input.readFloat()
            if (version == SNAPSHOT_VERSION) {
                heldBase = input.readFloat()
                heldEsaCompensation = input.readFloat()
                hasStageState = input.readBoolean()
            } else {
                // A 1.1.x checkpoint predates the held stage terms. They only feed
                // the sensor observation, never the stock output, and the next
                // correction stage writes them again; rejecting the checkpoint
                // for them forced a replay of the sensor's whole life.
                heldBase = 0f
                heldEsaCompensation = 0f
                hasStageState = false
            }
            val clipSize = input.readInt()
            if (clipSize !in 1..MAX_CLIP_SNAPSHOT_BYTES) return false
            val clipState = ByteArray(clipSize)
            input.readFully(clipState)
            if (input.available() != 0 || !clip.restore(clipState)) return false
            debug = null
            latestSensorObservation = null
            true
        }
    }.getOrDefault(false)

    private fun writeKalman(output: DataOutputStream) {
        output.writeFloat(kalman.state)
        output.writeFloat(kalman.previous)
        output.writeFloat(kalman.pMinus)
        output.writeFloat(kalman.gain)
        output.writeFloat(kalman.mn)
        output.writeFloat(kalman.pn)
        output.writeFloat(kalman.ec)
    }

    private fun readKalman(input: DataInputStream) {
        kalman.state = input.readFloat()
        kalman.previous = input.readFloat()
        kalman.pMinus = input.readFloat()
        kalman.gain = input.readFloat()
        kalman.mn = input.readFloat()
        kalman.pn = input.readFloat()
        kalman.ec = input.readFloat()
    }

    private fun adjustment(index: Int, temperatureRunningMinus20: Float, temperatureDownAverage: Float): Float {
        fun clipFloat(absoluteOffset: Int): Float = clip.floatAt(absoluteOffset - 0x26c)
        fun clipInt(absoluteOffset: Int): Int = clip.intAt(absoluteOffset - 0x26c)

        val stageCount = index / 5 - 1
        if (stageCount <= 4) return 0.5f
        if (index < 0x442) {
            if (clipFloat(0x3b0) >= 18.5f) return hotAdjustment(index, temperatureRunningMinus20, temperatureDownAverage)
            val f4a0 = clipFloat(0x4a0)
            if (f4a0 >= 7.2f && (temperatureDownAverage >= 11f || f4a0 <= 7.8f) && clipFloat(0x414) - f4a0 >= 0.8f) return 0.3f
            val f444 = clipFloat(0x444)
            if (clipFloat(0x440) > 8.6f && (f444 > 9f || clipFloat(0x440) - f444 < 2f) && clipFloat(0x498) > 10f) return 0.2f
            if (temperatureDownAverage < 10.5f && f444 > 8.5f) return 0.3f
            if (clipInt(0x468) == 1 && clipFloat(0x3e4) < 2.8f) return 0.5f
            if (temperatureDownAverage < 11f && f4a0 <= 5f) {
                val delta = when {
                    temperatureRunningMinus20 < 9f -> temperatureRunningMinus20 + 20f - 32.5f
                    temperatureRunningMinus20 < 10f -> temperatureRunningMinus20 + 20f - 33.5f
                    temperatureRunningMinus20 < 11f -> temperatureRunningMinus20 + 20f - 34.5f
                    temperatureRunningMinus20 < 15f -> temperatureRunningMinus20 + 20f - 35f
                    else -> return 0.3f
                }
                return f32(delta * 0.2f + 0.3f)
            }
            val delta = when {
                temperatureRunningMinus20 < 9f -> temperatureRunningMinus20 + 20f - 32f
                temperatureRunningMinus20 < 10f -> temperatureRunningMinus20 + 20f - 33f
                temperatureRunningMinus20 < 11f -> temperatureRunningMinus20 + 20f - 34f
                temperatureRunningMinus20 < 12f -> temperatureRunningMinus20 + 20f - 32f
                temperatureRunningMinus20 < 13f -> temperatureRunningMinus20 + 20f - 35f
                temperatureRunningMinus20 < 14f -> temperatureRunningMinus20 + 20f - 36f
                temperatureRunningMinus20 < 14.5f -> temperatureRunningMinus20 + 20f - 35f
                temperatureRunningMinus20 < 15.5f -> temperatureRunningMinus20 + 20f - 36.5f
                else -> return 0.3f
            }
            return f32(delta * 0.2f + 0.3f)
        }
        if (index < 0x1685) return hotAdjustment(index, temperatureRunningMinus20, temperatureDownAverage)
        val f444 = clipFloat(0x444)
        if (f444 >= 8.5f) return lateHighAdjustment(index, temperatureRunningMinus20, f444)
        val delta = clipFloat(0x3a8) - clipFloat(0x3dc)
        if (delta >= 1.2f || clipInt(0x47c) < 1) return lateHighAdjustment(index, temperatureRunningMinus20, f444)
        val denominator = clipFloat(0x414) - clipFloat(0x4a0)
        val numerator = clipFloat(0x49c) - clipFloat(0x414)
        val ratio = if (denominator != 0f) {
            numerator / denominator
        } else if (numerator < 0f) {
            Float.NEGATIVE_INFINITY
        } else {
            Float.POSITIVE_INFINITY
        }
        if (clipFloat(0x4b8) <= -0.31f && clipFloat(0x4b8) + clipFloat(0x4b4) >= -0.05f && ratio <= 1.3f) return lateHighAdjustment(index, temperatureRunningMinus20, f444)
        if (clipFloat(0x4b4) >= 0.35f) return lateHighAdjustment(index, temperatureRunningMinus20, f444)
        if ((f444 > 7f && clipFloat(0x3dc) < 3.9f && delta > 0.85f && clipFloat(0x440) > 7f) || (clipFloat(0x4a0) > 5.5f && clipFloat(0x49c) < 8.5f)) return 0.3f
        val temperatureDelta = if (temperatureRunningMinus20 < 9f) {
            temperatureRunningMinus20 + 20f - 29.5f
        } else {
            lateTemperatureDelta(temperatureRunningMinus20) ?: return 0f
        }
        return f32(temperatureDelta * 0.2f + 0.3f)
    }

    private fun hotAdjustment(index: Int, temperatureRunningMinus20: Float, temperatureDownAverage: Float): Float {
        fun clipFloat(absoluteOffset: Int): Float = clip.floatAt(absoluteOffset - 0x26c)
        fun clipInt(absoluteOffset: Int): Int = clip.intAt(absoluteOffset - 0x26c)

        val f444 = clipFloat(0x444)
        if (clipFloat(0x440) > 8.6f && (f444 > 9f || clipFloat(0x440) - f444 < 2f) && clipFloat(0x498) > 10f) return 0.2f
        if (temperatureDownAverage < 10.5f && f444 > 8.5f) return 0.3f
        val i468 = clipInt(0x468)
        if (i468 == 1 && clipFloat(0x3e4) < 2.8f) return 0.5f
        if (index < 0x5a5) {
            if (f444 >= 9f || (i468 != 1 && temperatureDownAverage >= 11.5f && clipFloat(0x4a0) >= 5.3f)) return 0.3f
            val delta = when {
                temperatureRunningMinus20 < 9f -> temperatureRunningMinus20 + 20f - 31.7f
                temperatureRunningMinus20 < 10f -> temperatureRunningMinus20 + 20f - 32.7f
                temperatureRunningMinus20 < 11f -> temperatureRunningMinus20 + 20f - 33.7f
                temperatureRunningMinus20 < 12f -> temperatureRunningMinus20 + 20f - 34f
                temperatureRunningMinus20 < 13f -> temperatureRunningMinus20 + 20f - 34.3f
                temperatureRunningMinus20 < 14f -> temperatureRunningMinus20 + 20f - 34.7f
                temperatureRunningMinus20 < 14.5f -> temperatureRunningMinus20 + 20f - 35f
                temperatureRunningMinus20 < 15f -> temperatureRunningMinus20 + 20f - 35.2f
                temperatureRunningMinus20 < 15.5f -> temperatureRunningMinus20 + 20f - 35.7f
                else -> return 0f
            }
            return f32(delta * 0.2f + 0.3f)
        }
        if (clipFloat(0x4a0) >= 5.3f) {
            if (i468 != 1) return 0.3f
            val f3f8 = clipFloat(0x3f8)
            if (f3f8 >= 42f && f3f8 < 72f && clipFloat(0x498) > 9.5f) {
                if (f444 >= 9f || clipFloat(0x4e0) >= 3.9f) return 0.3f
                val gap = clipFloat(0x3c0) - clipFloat(0x3dc)
                if (clipFloat(0x3a8) - clipFloat(0x3c0) < 0.65f || gap > 1f || gap < 0.4f) return hotJoin(temperatureRunningMinus20)
            }
            return 0.3f
        }
        if (f444 >= 9f || (clipFloat(0x3c0) - clipFloat(0x3dc) <= 1f && clipFloat(0x3c0) - clipFloat(0x3dc) >= 0.4f)) {
            if (i468 != 1) return 0.3f
            val f3f8 = clipFloat(0x3f8)
            if (f3f8 >= 42f && f3f8 < 72f && clipFloat(0x498) > 9.5f) {
                if (f444 >= 9f || clipFloat(0x4e0) >= 3.9f) return 0.3f
                val gap = clipFloat(0x3c0) - clipFloat(0x3dc)
                if (clipFloat(0x3a8) - clipFloat(0x3c0) < 0.65f || gap > 1f || gap < 0.4f) return hotJoin(temperatureRunningMinus20)
            }
            return 0.3f
        }
        return hotJoin(temperatureRunningMinus20)
    }

    private fun hotJoin(temperatureRunningMinus20: Float): Float {
        val delta = when {
            temperatureRunningMinus20 < 9f -> temperatureRunningMinus20 + 20f - 31.2f
            temperatureRunningMinus20 < 10f -> temperatureRunningMinus20 + 20f - 32.2f
            temperatureRunningMinus20 < 11f -> temperatureRunningMinus20 + 20f - 33.2f
            temperatureRunningMinus20 < 12f -> temperatureRunningMinus20 + 20f - 33.7f
            temperatureRunningMinus20 < 13f -> temperatureRunningMinus20 + 20f - 34.2f
            temperatureRunningMinus20 < 14f -> temperatureRunningMinus20 + 20f - 34.7f
            temperatureRunningMinus20 < 14.5f -> temperatureRunningMinus20 + 20f - 35f
            temperatureRunningMinus20 < 15f -> temperatureRunningMinus20 + 20f - 35.2f
            temperatureRunningMinus20 < 15.5f -> temperatureRunningMinus20 + 20f - 35.7f
            else -> return 0f
        }
        return f32(delta * 0.2f + 0.3f)
    }

    private fun lateHighAdjustment(index: Int, temperatureRunningMinus20: Float, f444: Float): Float {
        fun clipFloat(absoluteOffset: Int): Float = clip.floatAt(absoluteOffset - 0x26c)
        fun clipInt(absoluteOffset: Int): Int = clip.intAt(absoluteOffset - 0x26c)

        if (clipInt(0x47c) == 1 && clipInt(0x4c0) == 1) {
            val f3dc = clipFloat(0x3dc)
            if ((f3dc >= 3.9f || f444 <= 7f || clipFloat(0x3a8) - f3dc <= 0.85f || clipFloat(0x440) <= 7f) && (f3dc >= 4.2f || f444 <= 7f || clipFloat(0x3a8) - f3dc <= 1.8f || clipFloat(0x440) <= 7f)) {
                val delta = if (temperatureRunningMinus20 < 9f) temperatureRunningMinus20 + 20f - 29.5f else lateTemperatureDelta(temperatureRunningMinus20) ?: return 0f
                return f32(delta * 0.25f + 0.3f)
            }
        } else if (
            (clipFloat(0x4a0) < 4.1f && -0.3f < clipFloat(0x4b8) && clipFloat(0x4b4) < 0.3f && clipFloat(0x4b4) - abs(clipFloat(0x4b8)) < 0.03f) ||
                (index / 5 > 0xd81 && f444 < 8.5f)
        ) {
            if ((clipFloat(0x3dc) >= 3.9f || f444 <= 7f || clipFloat(0x3a8) - clipFloat(0x3dc) <= 0.85f || clipFloat(0x440) <= 7f) && (clipInt(0x4c0) != 0 || clipFloat(0x4b8) >= -0.27f) && (f444 >= 6f || clipFloat(0x4a0) <= 5f || clipFloat(0x3f8) <= 72f)) {
                if (temperatureRunningMinus20 < 9f) return f32((temperatureRunningMinus20 + 20f - 31f) * 0.2f + 0.3f)
                val delta = lateTemperatureDelta(temperatureRunningMinus20) ?: return 0f
                return f32(delta * 0.2f + 0.3f)
            }
        } else if (clipInt(0x47c) < 1) {
            return if (clipInt(0x4c0) == 1) 0.3f else 0.5f
        }
        return 0.3f
    }

    private fun lateTemperatureDelta(temperatureRunningMinus20: Float): Float? = when {
        temperatureRunningMinus20 < 10f -> temperatureRunningMinus20 + 20f - 30.5f
        temperatureRunningMinus20 < 11f -> temperatureRunningMinus20 + 20f - 31.5f
        temperatureRunningMinus20 < 12f -> temperatureRunningMinus20 + 20f - 32.5f
        temperatureRunningMinus20 < 13f -> temperatureRunningMinus20 + 20f - 33.5f
        temperatureRunningMinus20 < 14f -> temperatureRunningMinus20 + 20f - 34f
        temperatureRunningMinus20 < 14.5f -> temperatureRunningMinus20 + 20f - 34.5f
        temperatureRunningMinus20 < 15f -> temperatureRunningMinus20 + 20f - 35f
        temperatureRunningMinus20 < 15.5f -> temperatureRunningMinus20 + 20f - 36f
        else -> null
    }

    private companion object {
        private const val DEFAULT_DECODED_SENSITIVITY = 1.27f
        private const val SNAPSHOT_MAGIC = 0x5349_4233
        const val FAMILY_V115G = 115
        private const val SNAPSHOT_VERSION = 3
        /** Written by 1.1.x: identical except for the held stage terms. */
        private const val PRE_OBSERVATION_SNAPSHOT_VERSION = 2
        private const val MAX_CLIP_SNAPSHOT_BYTES = 8 * 1024

        private val COEFFICIENTS = floatArrayOf(
            0.21298696100711823f, -0.015606919303536415f, -0.01163424551486969f,
            -0.008672798052430153f, -0.006465174723416567f, -0.004819491412490606f,
            -0.003592709545046091f, -0.002678199438378215f, -0.001996473176404834f,
            -0.0014882767572999f, -0.001109438482671976f, -0.0008270304533652961f,
            -0.00061650644056499f, -0.0004595680220518261f, -0.000342574407113716f,
            -0.0002553566882852465f, -0.00019033410353586078f, -0.00014185499458108097f,
            -0.00010570565791567788f, -0.00007874405855545774f, -0.00005862674879608676f,
            -0.00004360516686574556f, -0.000032373660360462964f, -0.00002395601404714398f,
            -0.00001762057945597917f, -0.000012816693015338387f, -0.000009126808436121792f,
            -0.0000062302096921484926f, -0.000003875128641084302f, -0.0000018568666746432427f,
        )

        private fun f32(value: Float): Float = value

        private fun nativeRound(value: Float): Float {
            if (!value.isFinite()) return Float.NaN
            var scaled = value * 10f
            if (value >= 4.2f) scaled += 0.5f
            return scaled.toInt() / 10f
        }

        private fun changeSensitivity(decoded: Float): Float = when {
            decoded < 0.8f -> 1.2000000476837158f
            decoded > 2.5f -> 1.4500000476837158f
            else -> decoded * 0.92f
        }
    }
}
