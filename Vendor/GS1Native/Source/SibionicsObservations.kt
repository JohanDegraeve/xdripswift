package tk.glucodata.drivers.sibionics

internal data class SibionicsChemicalSignal(
    val mmol: Float,
    val qualityFlags: Int,
)

/**
 * Sensor-specific state extracted from the vendor front end, on the absolute
 * glucose scale, without using the vendor's final output.
 *
 * This exists because [SibionicsChemicalSignal] is *not* absolute glucose, and
 * treating it as such is what made Adaptive V2 read ~2 mmol/L low on real
 * sensors. The vendor pipeline continues past that point:
 *
 * ```
 *   chemical = compensated / activeSensitivity
 *   adjusted = (compensated - base) / activeSensitivity
 *   esa      = adjusted + mean(last five clip compensationSize values)   <-- absolute
 *   deconv   = 30-tap FIR(esa) * 6.7                                     <-- dynamics
 *   display  = deconv + calibrationCompensation
 * ```
 *
 * The ESA term is the manufacturer's own estimate of how far the chemical
 * signal sits from real glucose given sensor sensitivity, drift, age and
 * pathological state. On a realistic trace it averages +1.2 mmol/L and reaches
 * +2.8. Discarding it does not make an estimator independent, it makes it
 * wrong.
 *
 * [calibratedMmol] therefore stops one stage short of the vendor's estimator:
 * it keeps the sensor-state calibration and drops the five history filters, the
 * deconvolution FIR and the display rounding — which are exactly the parts
 * Adaptive V2 replaces. Final stock glucose is still never used.
 */
internal data class SibionicsSensorObservation(
    /** Vendor-calibrated observation in mmol/L, before display filtering and deconvolution. */
    val calibratedMmol: Float,
    /** The uncalibrated pre-compensation signal. Diagnostics only. */
    val chemicalMmol: Float,
    /** Absolute sensor-state compensation the vendor applies via ESA, in mmol/L. */
    val sensorStateCompensationMmol: Float,
    val qualityFlags: Int,
    /** Factory/QR sensitivity as decoded at pairing. */
    val factorySensitivity: Float,
    /** The vendor's current running sensitivity estimate, which tracks drift. */
    val activeSensitivity: Float,
    /** Sensor minute index; doubles as sensor age. */
    val sensorAgeMinutes: Int,
    /** Algorithm family that produced this observation (115 or 116). */
    val family: Int,
) {
    val isUsable: Boolean
        get() = calibratedMmol.isFinite() && calibratedMmol > 0f &&
            activeSensitivity.isFinite() && activeSensitivity > 0f
}

