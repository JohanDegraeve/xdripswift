@file:Suppress("UNUSED_VARIABLE", "UNUSED_PARAMETER", "LocalVariableName")

package tk.glucodata.drivers.sibionics

private data class Ptr(val bytes: ByteArray, val off: Int = 0) {
    fun plus(delta: Int): Ptr = Ptr(bytes, off + delta)
}
private fun b(value: Boolean): Int = if (value) 1 else 0
private const val C_DONE = -1
private fun f32(value: Double): Double = value.toFloat().toDouble()
private fun uLt(a: Int, b: Int): Boolean = gs1.compat.compareUnsigned(a, b) < 0
private fun uLe(a: Int, b: Int): Boolean = gs1.compat.compareUnsigned(a, b) <= 0
private fun uGt(a: Int, b: Int): Boolean = gs1.compat.compareUnsigned(a, b) > 0
private fun uGe(a: Int, b: Int): Boolean = gs1.compat.compareUnsigned(a, b) >= 0
private fun u64ToDouble(value: Long): Double = value.toULong().toString().toDouble()
private fun sBorrow4(a: Int, b: Int): Boolean { val r = a - b; return ((a xor b) and (a xor r)) < 0 }
private fun readI32(p: Ptr): Int =
    (p.bytes[p.off].toInt() and 0xff) or ((p.bytes[p.off + 1].toInt() and 0xff) shl 8) or
        ((p.bytes[p.off + 2].toInt() and 0xff) shl 16) or (p.bytes[p.off + 3].toInt() shl 24)
private fun writeI32(p: Ptr, value: Int) { for (i in 0..3) p.bytes[p.off + i] = (value ushr (8 * i)).toByte() }
private fun readI64(p: Ptr): Long = (0..7).fold(0L) { a, i -> a or ((p.bytes[p.off + i].toLong() and 0xffL) shl (8 * i)) }
private fun writeI64(p: Ptr, value: Long) { for (i in 0..7) p.bytes[p.off + i] = (value ushr (8 * i)).toByte() }
private fun readF32(p: Ptr): Double = Float.fromBits(readI32(p)).toDouble()
private fun writeF32(p: Ptr, value: Double) = writeI32(p, value.toFloat().toRawBits())
private fun readF64(p: Ptr): Double = Double.fromBits(readI64(p))
private fun writeF64(p: Ptr, value: Double) = writeI64(p, value.toRawBits())

private fun initClipContext(p: Ptr) {
    p.bytes.fill(0)
    writeI64(p.plus(0x000), 0x4120000042c80000L)
    writeI64(p.plus(0x134), 0x4120000041c80000L)
    writeI64(p.plus(0x13c), 0x4120000000000000L)
    for (off in intArrayOf(0x158, 0x15c, 0x160, 0x164, 0x178, 0x180)) writeF32(p.plus(off), 10.0)
    // 0x270 is an integer counter; the constructor's trailing 10.0f is at 0x274.
    writeF32(p.plus(0x274), 10.0)
    writeF32(p.plus(0x1e4), 100.0)
    // The clipping seed is fixed and independent of the decoded per-sensor sensitivity.
    writeF32(p.plus(0x208), 1.5)
    writeF32(p.plus(0x20c), 1.5)
    writeI64(p.plus(0x214), 0x4248000000000000L)
    writeF32(p.plus(0x21c), 50.0)
    writeF32(p.plus(0x268), 100.0)
}

private fun initCalibrationContext(p: Ptr) {
    p.bytes.fill(0)
    writeI64(p.plus(0x44), 0x0000000041a00000L)
}


private val ARR_0012d070 = doubleArrayOf(-5.2, -4.7)
private val ARR_0012d080 = doubleArrayOf(0.9, 0.4)
private val ARR_0012d090 = doubleArrayOf(0.8, 0.4)
private const val DAT_0012cc40: Double = 0.8
private const val DAT_0012cc78: Double = -0.05
private const val DAT_0012cc80: Double = 1.3
private const val DAT_0012cc88: Double = 0.03
private const val DAT_0012cc90: Double = -0.27
private const val DAT_0012cc98: Double = 0.2
private const val DAT_0012cca0: Double = 4.2
private const val DAT_0012cca8: Double = 1.8
private const val DAT_0012ccb0: Double = 0.4
private const val DAT_0012ccb8: Double = 0.65
private const val DAT_0012cd18: Double = 7.2
private const val DAT_0012cdc0: Double = 0.55
private const val DAT_0012cdc8: Double = 0.1
private const val DAT_0012cdd0: Double = -0.1
private const val DAT_0012cdd8: Double = 0.01
private const val DAT_0012cde0: Double = 3.2
private const val DAT_0012cde8: Double = 2.7
private const val DAT_0012cdf0: Double = 0.45
private const val DAT_0012cdf8: Double = 3.6
private const val DAT_0012ce00: Double = 3.7
private const val DAT_0012ce08: Double = 0.83
private const val DAT_0012ce10: Double = 2.6
private const val DAT_0012ce18: Double = 2.2
private const val DAT_0012ce20: Double = 3.1
private const val DAT_0012ce28: Double = 1.11
private const val DAT_0012ce30: Double = 5.9
private const val DAT_0012ce38: Double = 1.1
private const val DAT_0012ce40: Double = 1.6
private const val DAT_0012ce48: Double = 4.4
private const val DAT_0012ce50: Double = -3.2
private const val DAT_0012ce58: Double = -4.7
private const val DAT_0012ce60: Double = 4.7
private const val DAT_0012ce68: Double = 8.8
private const val DAT_0012ce70: Double = -0.01
private const val DAT_0012ce78: Double = 0.93
private const val DAT_0012ce80: Double = 0.97
private const val DAT_0012ce88: Double = 0.9
private const val DAT_0012ce90: Double = 11.8
private const val DAT_0012ce98: Double = -0.4
private const val DAT_0012cea0: Double = 0.065
private const val DAT_0012cea8: Double = -12.8
private const val DAT_0012ceb0: Double = 10.8
private const val DAT_0012ceb8: Double = 11.3
private const val DAT_0012cec0: Double = 12.3
private const val DAT_0012cec8: Double = 13.3
private const val DAT_0012ced0: Double = -0.32
private const val DAT_0012ced8: Double = -13.4
private const val DAT_0012cee0: Double = -11.8
private const val DAT_0012cee8: Double = -12.3
private const val DAT_0012cef0: Double = -13.3
private const val DAT_0012cef8: Double = 2.1
private const val DAT_0012cf00: Double = -0.39
private const val DAT_0012cf08: Double = 8.3
private const val DAT_0012cf10: Double = -0.37
private const val DAT_0012cf18: Double = 5.2
private const val DAT_0012cf20: Double = -5.2
private const val DAT_0012cf28: Double = 6.2
private const val DAT_0012cf30: Double = -5.7
private const val DAT_0012cf38: Double = 4.9
private const val DAT_0012cf40: Double = -4.9
private const val DAT_0012cf48: Double = -0.29
private const val DAT_0012cf50: Double = 0.29
private const val DAT_0012cf58: Double = -3.6
private const val DAT_0012cf60: Double = -0.04
private const val DAT_0012cf68: Double = -0.08
private const val DAT_0012cf70: Double = -0.28
private const val DAT_0012cf78: Double = 0.27
private const val DAT_0012cf80: Double = 0.02
private const val DAT_0012cf88: Double = 0.37
private const val DAT_0012cf90: Double = 5.7
private const val DAT_0012cf98: Double = -0.8
private const val DAT_0012cfa0: Long = 0x41200000L
private const val DAT_0012cfa8: Double = -0.03
private const val DAT_0012cfb0: Double = 0.025
private const val DAT_0012cfb8: Double = 0.08
private const val DAT_0012cfc0: Double = -0.33
private const val DAT_0012cfc8: Double = 0.28
private const val DAT_0012cfd0: Double = 12.8
private const val DAT_0012cfd8: Double = -0.34
private const val DAT_0012cfe0: Double = 0.33
private const val DAT_0012cfe8: Double = -0.06
private const val DAT_0012cff0: Double = 0.05
private const val DAT_0012cff8: Double = 0.32
private const val DAT_0012d000: Double = 0.31
private const val DAT_0012d008: Double = 9.4
private const val DAT_0012d010: Double = 6.4
private const val DAT_0012d018: Double = -2.2
private const val DAT_0012d020: Double = -2.7
private const val DAT_0012d028: Double = 5.4
private const val DAT_0012d030: Double = -3.7
private const val DAT_0012d038: Double = 7.4
private const val DAT_0012d040: Double = -4.2
private const val DAT_0012d048: Double = 8.4
private const val DAT_0012d050: Double = 9.8
private const val DAT_0012d058: Double = -0.02
private const val DAT_0012d060: Double = -0.36
private const val DAT_0012d068: Double = -0.032

private class CalibrationbaselineFrame(var param_1: Ptr, var param_2: Double, var param_3: Double, var param_4: Double, var param_5: Double, var param_6: Double, var param_7: Double, var param_8: Double, var param_9: Int) {
    var iVar1: Int = 0
    var bVar2: Int = 0
    var fVar3: Double = 0.0
    var fVar4: Double = 0.0
    var fVar5: Double = 0.0
    var fVar6: Double = 0.0
    var result: Int = 0
}

private fun CalibrationbaselineStep0(f: CalibrationbaselineFrame, pc: Int): Int {
    return when (pc) {
        0 -> {
            30
        }
        1 -> {
            24
        }
        2 -> {
            14
        }
        3 -> {
            5
        }
        4 -> {
            f.result = readI32(f.param_1.plus(0x28))
            C_DONE
        }
        5 -> {
            writeF32(f.param_1.plus(4), f32(f.fVar3))
            4
        }
        6 -> {
            writeI32(f.param_1.plus(0x40), 0)
            3
        }
        7 -> {
            writeI32(f.param_1.plus(0x48), ((readI32(f.param_1.plus(0x48))) + (1)))
            6
        }
        8 -> {
            if ((b((4.0) < (readF32(f.param_1.plus(0x40))))) != 0) 7 else 6
        }
        9 -> {
            writeF32(f.param_1.plus(0x40), f32(((f.fVar3) * (30.0))))
            3
        }
        10 -> {
            if ((b((((f.fVar3) * (30.0))) <= (readF32(f.param_1.plus(0x40))))) != 0) 8 else 9
        }
        11 -> {
            if ((b(((b((0.0) < (f.fVar5))) != 0) && ((b((f.fVar5) < (f.fVar3))) != 0))) != 0) 10 else 3
        }
        12 -> {
            f.fVar5 = f32(readF32(f.param_1.plus(4)))
            11
        }
        13 -> {
            3
        }
        14 -> {
            if ((b((f.fVar3) <= (0.0))) != 0) 13 else 12
        }
        15 -> {
            writeI32(f.param_1.plus(0x34), 0)
            2
        }
        16 -> {
            writeI32(f.param_1.plus(0x20), 0)
            15
        }
        17 -> {
            writeI32(f.param_1.plus(0x18), 0)
            16
        }
        18 -> {
            1
        }
        19 -> {
            f.fVar6 = f32(((f.param_4) - (readF32(f.param_1.plus(0x20)))))
            18
        }
        20 -> {
            if ((b(((b((0x11f) < (f.param_9))) != 0) && ((b((4.0) < (((readF32(f.param_1.plus(0x3c))) - (readF32(f.param_1.plus(0x38))))))) != 0))) != 0) 19 else 17
        }
        21 -> {
            2
        }
        22 -> {
            writeI64(f.param_1.plus(0x30), (0).toLong())
            21
        }
        23 -> {
            writeI32(f.param_1.plus(8), 1)
            22
        }
        24 -> {
            if ((b((f.fVar6) < (1.0))) != 0) 23 else 17
        }
        25 -> {
            f.fVar6 = f32(((f.param_3) - (readF32(f.param_1.plus(0x20)))))
            1
        }
        26 -> {
            if ((b(((b((0x11f) < (f.param_9))) != 0) || ((b((((readF32(f.param_1.plus(0x3c))) - (readF32(f.param_1.plus(0x38))))) <= (4.0))) != 0))) != 0) 20 else 25
        }
        27 -> {
            if ((b(((b(!((b(((b((0.0) <= (f.fVar3))).or((f.bVar2).xor(1))) != 0)) != 0))) != 0) && ((b((0.0) < (readF32(f.param_1.plus(4))))) != 0))) != 0) 26 else 2
        }
        28 -> {
            writeF32(f.param_1.plus(0x30), f32(((f.fVar3) * (30.0))))
            2
        }
        29 -> {
            if ((b((((f.fVar3) * (30.0))) < (readF32(f.param_1.plus(0x30))))) != 0) 28 else 2
        }
        30 -> {
            if ((b(((b(((b((0.0) <= (f.fVar3))) != 0) || ((b((readI32(f.param_1.plus(8))) != (1))) != 0))) != 0) || ((b((0.0) <= (readF32(f.param_1.plus(4))))) != 0))) != 0) 27 else 29
        }
        31 -> {
            f.bVar2 = b((b((readI32(f.param_1.plus(0x34))) == (1))) != 0)
            0
        }
        else -> error("bad C state: $pc")
    }
}

private fun CalibrationbaselineStep1(f: CalibrationbaselineFrame, pc: Int): Int {
    return when (pc) {
        32 -> {
            writeF32(f.param_1.plus(0x3c), f32(((f.fVar3) * (30.0))))
            11
        }
        33 -> {
            if ((b((readF32(f.param_1.plus(0x3c))) < (((f.fVar3) * (30.0))))) != 0) 32 else 11
        }
        34 -> {
            0
        }
        35 -> {
            if ((b(((b(((b((f.fVar3) <= (0.0))) != 0) || ((b((readI32(f.param_1.plus(0x34))) != (1))) != 0))) != 0) || ((run { run { f.fVar5 = f32(readF32(f.param_1.plus(4))); f32(readF32(f.param_1.plus(4))) }; b((f.fVar5) <= (0.0)) }) != 0))) != 0) 34 else 33
        }
        36 -> {
            f.bVar2 = b((b((readI32(f.param_1.plus(0x34))) == (1))) != 0)
            35
        }
        37 -> {
            writeI32(f.param_1.plus(0x3c), 0)
            11
        }
        38 -> {
            writeI32(f.param_1.plus(0x34), 1)
            37
        }
        39 -> {
            writeI32(f.param_1.plus(0x18), ((f.param_9) + (-(1))))
            38
        }
        40 -> {
            writeF32(f.param_1.plus(0x38), f32(f.fVar5))
            39
        }
        41 -> {
            writeF32(f.param_1.plus(0x20), f32(f.fVar6))
            40
        }
        42 -> {
            if ((b(((b((0.0) < (f.fVar5))) != 0) || ((b((readI32(f.param_1.plus(0x34))) != (0))) != 0))) != 0) 36 else 41
        }
        43 -> {
            writeI32(f.param_1.plus(0x2c), 1)
            11
        }
        44 -> {
            writeF32(f.param_1.plus(0x44), f32(f.fVar6))
            43
        }
        45 -> {
            if ((b(((b((f.param_5) < (f.fVar6))) != 0) && ((b((f.fVar6) < (f.param_8))) != 0))) != 0) 44 else 11
        }
        46 -> {
            writeF32(f.param_1.plus(0x28), f32(((f.fVar4) / (f32((((f.iVar1) + (1))).toDouble())))))
            45
        }
        47 -> {
            writeI32(f.param_1.plus(0xc), ((f.iVar1) + (1)))
            46
        }
        48 -> {
            writeI32(f.param_1.plus(8), 0)
            47
        }
        49 -> {
            writeF32(f.param_1.plus(0x1c), f32(f.fVar6))
            48
        }
        50 -> {
            writeF32(f.param_1.plus(0x10), f32(f.fVar4))
            49
        }
        51 -> {
            f.fVar4 = f32(((((readF32(f.param_1.plus(0x10))) + (f32((((f.param_9) + (-(1)))).toDouble())))) - (f32((readI32(f.param_1.plus(0x18))).toDouble()))))
            50
        }
        52 -> {
            writeI32(f.param_1.plus(0x14), ((f.param_9) + (-(1))))
            51
        }
        53 -> {
            f.iVar1 = readI32(f.param_1.plus(0xc))
            52
        }
        54 -> {
            if ((b(((b(((b((f.fVar4) < (-(5.0)))) != 0) || ((b((kotlin.math.abs(((f.fVar6) - (readF32(f.param_1.plus(0x20)))))) < (2.0))) != 0))) != 0) && ((b((f.fVar6) < (((f.param_6) * (DAT_0012cc40))))) != 0))) != 0) 53 else 11
        }
        55 -> {
            writeF32(f.param_1.plus(0x28), f32(((f.fVar6) / (f32((((f.iVar1) + (1))).toDouble())))))
            11
        }
        56 -> {
            writeI32(f.param_1.plus(0xc), ((f.iVar1) + (1)))
            55
        }
        57 -> {
            writeI32(f.param_1.plus(8), 0)
            56
        }
        58 -> {
            writeF32(f.param_1.plus(0x10), f32(f.fVar6))
            57
        }
        59 -> {
            f.fVar6 = f32(((((readF32(f.param_1.plus(0x10))) + (f32((((f.param_9) + (-(1)))).toDouble())))) - (f32((readI32(f.param_1.plus(0x18))).toDouble()))))
            58
        }
        60 -> {
            writeF32(f.param_1.plus(0x1c), f32(f.fVar6))
            59
        }
        61 -> {
            writeI32(f.param_1.plus(0x14), ((f.param_9) + (-(1))))
            60
        }
        62 -> {
            f.iVar1 = readI32(f.param_1.plus(0xc))
            61
        }
        63 -> {
            if ((b(((b(((b((f.fVar4) < (-(5.0)))) != 0) || ((b((kotlin.math.abs(((f.fVar6) - (readF32(f.param_1.plus(0x20)))))) < (1.5))) != 0))) != 0) && ((b(((b(((b((f.fVar4) < (-(2.0)))) != 0) && ((b((f.fVar6) < (((f.param_7) * (0.7))))) != 0))) != 0) || ((b(((b(((b((f.fVar4) < (-(5.0)))) != 0) && ((b((f.fVar4) < (-(2.0)))) != 0))) != 0) && ((b((((f.fVar6) - (readF32(f.param_1.plus(0x20))))) < (1.5))) != 0))) != 0))) != 0))) != 0) 62 else 11
        }
        else -> error("bad C state: $pc")
    }
}

private fun CalibrationbaselineStep2(f: CalibrationbaselineFrame, pc: Int): Int {
    return when (pc) {
        64 -> {
            if ((b((f.param_9) < (0x240))) != 0) 54 else 63
        }
        65 -> {
            f.fVar4 = f32(((readF32(f.param_1.plus(0x30))) - (f.fVar3)))
            64
        }
        66 -> {
            if ((b(((b((0.0) <= (f.fVar5))) != 0) || ((b((readI32(f.param_1.plus(8))) != (1))) != 0))) != 0) 42 else 65
        }
        67 -> {
            f.fVar5 = f32(readF32(f.param_1.plus(4)))
            66
        }
        68 -> {
            if ((b((f.fVar3) <= (0.0))) != 0) 31 else 67
        }
        69 -> {
            3
        }
        70 -> {
            if ((b((f.param_9) < (6))) != 0) 69 else 68
        }
        71 -> {
            writeF32(f.param_1, f32(f.fVar3))
            70
        }
        72 -> {
            f.fVar3 = f32(((f.param_2) - (f.fVar6)))
            71
        }
        73 -> {
            f.fVar6 = f32(readF32(f.param_1.plus(0x24)))
            72
        }
        74 -> {
            3
        }
        75 -> {
            writeI32(f.param_1, 0)
            74
        }
        76 -> {
            f.fVar3 = f32(0.0)
            75
        }
        77 -> {
            if ((b((f.param_9) < (1))) != 0) 76 else 73
        }
        78 -> {
            writeI32(f.param_1, 0)
            77
        }
        79 -> {
            writeI32(f.param_1.plus(0x2c), 0)
            78
        }
        else -> error("bad C state: $pc")
    }
}

private fun Calibration_baseline(param_1: Ptr, param_2: Double, param_3: Double, param_4: Double, param_5: Double, param_6: Double, param_7: Double, param_8: Double, param_9: Int): Int {
    val f = CalibrationbaselineFrame(param_1, f32(param_2), f32(param_3), f32(param_4), f32(param_5), f32(param_6), f32(param_7), f32(param_8), param_9)
    var pc = 79
    while (true) {
        pc = when (pc / 32) {
            0 -> CalibrationbaselineStep0(f, pc)
            1 -> CalibrationbaselineStep1(f, pc)
            2 -> CalibrationbaselineStep2(f, pc)
            else -> error("bad C chunk: $pc")
        }
        if (pc == C_DONE) {
            return f.result
        }
    }
}

private class adjustmentrangeFrame(var param_1: Ptr, var param_2: Double, var param_3: Double, var param_4: Double, var param_5: Double, var param_6: Double, var param_7: Double, var param_8: Double, var param_9: Double, var param_10: Double, var param_11: Double, var param_12: Double, var param_13: Double, var param_14: Int, var param_15: Double, var param_16: Double, var param_17: Double, var param_18: Double, var param_19: Double, var param_20: Double, var param_21: Double, var param_22: Double, var param_23: Double, var param_24: Double, var param_25: Double, var param_26: Int, var param_27: Double, var param_28: Double, var param_29: Double, var param_30: Double) {
    var iVar1: Int = 0
    var bVar2: Int = 0
    var bVar3: Int = 0
    var bVar4: Int = 0
    var bVar5: Int = 0
    var bVar6: Int = 0
    var bVar7: Int = 0
    var bVar8: Int = 0
    var bVar9: Int = 0
    var fVar10: Double = 0.0
    var fVar11: Double = 0.0
    var fVar12: Double = 0.0
    var fVar13: Double = 0.0
    var fVar14: Double = 0.0
    var fVar15: Double = 0.0
    var fVar16: Double = 0.0
    var fVar17: Double = 0.0
    var fVar18: Double = 0.0
    var fVar19: Double = 0.0
    var fVar20: Double = 0.0
    var fVar21: Double = 0.0
    var fVar22: Double = 0.0
    var fVar23: Double = 0.0
    var dVar24: Double = 0.0
    var fVar25: Double = 0.0
    var dVar26: Double = 0.0
    var fVar27: Double = 0.0
    var dVar28: Double = 0.0
    var fVar29: Double = 0.0
    var dVar30: Double = 0.0
    var fVar31: Double = 0.0
    var fVar32: Double = 0.0
    var fVar33: Double = 0.0
    var dVar34: Double = 0.0
    var fVar35: Double = 0.0
    var fVar36: Double = 0.0
    var fVar37: Double = 0.0
    var fVar38: Double = 0.0
    var dVar39: Double = 0.0
    var dVar40: Double = 0.0
    var fVar41: Double = 0.0
    var fVar42: Double = 0.0
    var dVar43: Double = 0.0
    var dVar44: Double = 0.0
    var fVar45: Double = 0.0
    var fVar46: Double = 0.0
    var fVar47: Double = 0.0
    var dVar48: Double = 0.0
    var fVar49: Double = 0.0
    var dVar50: Double = 0.0
    var dVar51: Double = 0.0
    var dVar52: Double = 0.0
    var result: Double = 0.0
}

private fun adjustmentrangeStep0(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        0 -> {
            935
        }
        1 -> {
            944
        }
        2 -> {
            934
        }
        3 -> {
            893
        }
        4 -> {
            714
        }
        5 -> {
            471
        }
        6 -> {
            482
        }
        7 -> {
            500
        }
        8 -> {
            506
        }
        9 -> {
            541
        }
        10 -> {
            539
        }
        11 -> {
            572
        }
        12 -> {
            618
        }
        13 -> {
            630
        }
        14 -> {
            638
        }
        15 -> {
            655
        }
        16 -> {
            468
        }
        17 -> {
            448
        }
        18 -> {
            435
        }
        19 -> {
            403
        }
        20 -> {
            402
        }
        21 -> {
            397
        }
        22 -> {
            398
        }
        23 -> {
            298
        }
        24 -> {
            312
        }
        25 -> {
            294
        }
        26 -> {
            44
        }
        27 -> {
            43
        }
        28 -> {
            288
        }
        29 -> {
            258
        }
        30 -> {
            257
        }
        31 -> {
            189
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep1(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        32 -> {
            188
        }
        33 -> {
            152
        }
        34 -> {
            170
        }
        35 -> {
            80
        }
        36 -> {
            76
        }
        37 -> {
            60
        }
        38 -> {
            41
        }
        39 -> {
            40
        }
        40 -> {
            f.result = f32(((f.fVar38) * (f.fVar31)))
            C_DONE
        }
        41 -> {
            f.fVar31 = f32(0.5)
            39
        }
        42 -> {
            39
        }
        43 -> {
            f.fVar31 = f32(0.25)
            42
        }
        44 -> {
            if ((b((1.5) <= (f.param_3))) != 0) 27 else 38
        }
        45 -> {
            29
        }
        46 -> {
            f.bVar2 = b((b((f.fVar13) < (3.5))) != 0)
            45
        }
        47 -> {
            if ((b(((b((f.fVar31) < (3.5))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar13).isNaN())) != 0)) }) != 0))) != 0) 46 else 45
        }
        48 -> {
            f.bVar2 = b((0) != 0)
            47
        }
        49 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        50 -> {
            if ((b(((b((f.fVar42) <= (2.0))) != 0) && ((b((f.param_23) <= (9.0))) != 0))) != 0) 49 else 48
        }
        51 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        52 -> {
            if ((b((DAT_0012cde0) <= (f.dVar39))) != 0) 51 else 50
        }
        53 -> {
            if ((b((f.fVar13) < (3.9))) != 0) 52 else 38
        }
        54 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        55 -> {
            if ((b((f.fVar13) < (4.5))) != 0) 54 else 53
        }
        56 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        57 -> {
            if ((b((72.0) < (f.param_20))) != 0) 56 else 55
        }
        58 -> {
            if ((b(((b((f.param_23) < (8.5))) != 0) && ((b(((b((f.param_19) < (8.0))) != 0) || ((b((f.param_30) < (54.0))) != 0))) != 0))) != 0) 57 else 53
        }
        59 -> {
            27
        }
        60 -> {
            f.result = f32(f32(f.dVar51))
            C_DONE
        }
        61 -> {
            if ((b(((b(((b((f.dVar44) < (3.9))) != 0) && ((b((f.param_16) < (4.5))) != 0))) != 0) && ((b(((b((3.0) <= (f.param_5))) != 0) || ((b((f.dVar26) <= (6.3))) != 0))) != 0))) != 0) 37 else 59
        }
        62 -> {
            27
        }
        63 -> {
            36
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep2(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        64 -> {
            if ((b(((b(((b((42.0) < (f.param_20))) != 0) && ((b((f.dVar39) < (DAT_0012cde0))) != 0))) != 0) && ((b((11.0) < (f.param_19))) != 0))) != 0) 63 else 62
        }
        65 -> {
            36
        }
        66 -> {
            37
        }
        67 -> {
            if ((b(((b(((b((2.0) < (f.fVar42))) != 0) && ((b((f.dVar39) < (2.8))) != 0))) != 0) && ((b((42.0) < (f.param_20))) != 0))) != 0) 66 else 65
        }
        68 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        69 -> {
            if ((b(((b((f.param_16) < (3.5))) != 0) && ((b(((b(((b(((b((f.param_3) < (2.5))) != 0) && ((b((f.param_4) < (2.5))) != 0))) != 0) && ((b((f.param_19) < (12.0))) != 0))) != 0) && ((b(((b((54.0) < (f.param_20))) != 0) || ((b((((f.dVar52) + (f.param_2))) < (3.0))) != 0))) != 0))) != 0))) != 0) 68 else 67
        }
        70 -> {
            if ((b(((b((f.dVar40) <= (2.4))) != 0) || ((b((f.param_21) <= (11.0))) != 0))) != 0) 69 else 64
        }
        71 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        72 -> {
            if ((b((f.dVar50) <= (DAT_0012ce08))) != 0) 71 else 70
        }
        73 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        74 -> {
            if ((b((48.0) < (f.param_20))) != 0) 73 else 72
        }
        75 -> {
            if ((b(((b((60.0) < (f.param_20))) != 0) || ((b((f.dVar50) <= (DAT_0012ce38))) != 0))) != 0) 74 else 70
        }
        76 -> {
            f.result = f32(f32(f.dVar52))
            C_DONE
        }
        77 -> {
            if ((b((60.0) < (f.param_20))) != 0) 36 else 75
        }
        78 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        79 -> {
            f.result = f32(f.fVar31)
            C_DONE
        }
        80 -> {
            if ((b(((b(!((f.bVar6) != 0))) != 0) && ((b((f.bVar2) == (f.bVar3))) != 0))) != 0) 79 else 78
        }
        81 -> {
            f.fVar31 = f32(f32(f.dVar52))
            35
        }
        82 -> {
            f.bVar3 = b((0) != 0)
            81
        }
        83 -> {
            f.bVar6 = b((b((f.param_16) == (3.0))) != 0)
            82
        }
        84 -> {
            f.bVar2 = b((b((f.param_16) < (3.0))) != 0)
            83
        }
        85 -> {
            if ((b(!((b((f.param_16).isNaN())) != 0))) != 0) 84 else 81
        }
        86 -> {
            f.bVar3 = b((1) != 0)
            85
        }
        87 -> {
            f.bVar6 = b((0) != 0)
            86
        }
        88 -> {
            f.bVar2 = b((0) != 0)
            87
        }
        89 -> {
            if ((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar4) == (f.bVar7))) != 0))) != 0) 88 else 81
        }
        90 -> {
            f.bVar3 = b((0) != 0)
            89
        }
        91 -> {
            f.bVar6 = b((1) != 0)
            90
        }
        92 -> {
            f.bVar2 = b((0) != 0)
            91
        }
        93 -> {
            f.bVar7 = b((0) != 0)
            92
        }
        94 -> {
            f.bVar5 = b((b((f.fVar42) == (1.5))) != 0)
            93
        }
        95 -> {
            f.bVar4 = b((b((f.fVar42) < (1.5))) != 0)
            94
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep3(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        96 -> {
            if ((b(!((b((f.fVar42).isNaN())) != 0))) != 0) 95 else 92
        }
        97 -> {
            f.bVar7 = b((1) != 0)
            96
        }
        98 -> {
            f.bVar5 = b((0) != 0)
            97
        }
        99 -> {
            f.bVar4 = b((0) != 0)
            98
        }
        100 -> {
            if ((b((f.param_20) < (42.0))) != 0) 99 else 92
        }
        101 -> {
            f.bVar7 = b((0) != 0)
            100
        }
        102 -> {
            f.bVar5 = b((1) != 0)
            101
        }
        103 -> {
            f.bVar4 = b((0) != 0)
            102
        }
        104 -> {
            36
        }
        105 -> {
            if ((b(((b(((b(((b(((b((3.5) < (f.param_3))) != 0) && ((b((3.5) < (f.param_4))) != 0))) != 0) && ((b((f.param_5) < (3.0))) != 0))) != 0) && ((b((0.5) < (((kotlin.math.abs(f.fVar32)) - (kotlin.math.abs(f.fVar11)))))) != 0))) != 0) || ((b(((b(((b((f.param_5) < (3.0))) != 0) && ((b((0.5) < (f.fVar31))) != 0))) != 0) && ((b(((b(((b((f.fVar10) < (0.3))) != 0) && ((b(((b((f.param_16) < (3.0))) != 0) && ((b((DAT_0012ccb0) < (f.fVar37))) != 0))) != 0))) != 0) || ((b(((b((3.0) < (f.param_3))) != 0) && ((b(((b((2.3) < (f.dVar39))) != 0) && ((b(((b(((b((1.2) < (f.dVar24))) != 0) || ((b((0.35) < (f.fVar37))) != 0))) != 0) || ((b((8.5) < (f.param_22))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) 104 else 103
        }
        106 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        107 -> {
            if ((b((-(0.5)) <= (f.fVar32))) != 0) 106 else 105
        }
        108 -> {
            37
        }
        109 -> {
            36
        }
        110 -> {
            33
        }
        111 -> {
            if ((b(((b(((b((f.param_3) < (f.param_4))) != 0) && ((b((f.param_4) < (f.param_5))) != 0))) != 0) && ((b(((b((f.param_5) < (2.5))) != 0) || ((b((f.param_22) < (7.5))) != 0))) != 0))) != 0) 110 else 109
        }
        112 -> {
            f.result = f32(0.0)
            C_DONE
        }
        113 -> {
            if ((b(((b((3.5) < (f.param_16))) != 0) && ((b((2.0) < (f.fVar42))) != 0))) != 0) 112 else 111
        }
        114 -> {
            if ((b(((b(((b((f.dVar43) < (2.4))) != 0) || ((b(((b((f.dVar40) < (2.4))) != 0) || ((b((f.dVar44) < (2.4))) != 0))) != 0))) != 0) && ((b((2.9) < (f.dVar39))) != 0))) != 0) 113 else 108
        }
        115 -> {
            if ((b(((b(((b(((b(((b((f.dVar39) < (3.9))) != 0) && ((b((10.0) < (f.param_19))) != 0))) != 0) && ((b((DAT_0012cca8) < (f.dVar24))) != 0))) != 0) && ((b((7.5) < (f.param_23))) != 0))) != 0) && ((b(((b(((b((f.param_4) < (3.0))) != 0) || ((b((f.param_3) < (3.0))) != 0))) != 0) || ((b((f.param_5) < (3.0))) != 0))) != 0))) != 0) 114 else 103
        }
        116 -> {
            37
        }
        117 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        118 -> {
            if ((b((f.param_19) < (10.0))) != 0) 117 else 116
        }
        119 -> {
            36
        }
        120 -> {
            if ((b(((b(((b((f.param_4) <= (f.param_3))) != 0) || ((b((f.param_5) <= (f.param_4))) != 0))) != 0) || ((b((7.5) <= (f.param_22))) != 0))) != 0) 119 else 118
        }
        121 -> {
            if ((b(((b(((b((f.dVar43) < (2.8))) != 0) && ((b((0.5) < (f.fVar32))) != 0))) != 0) && ((b(((b((0.6) < (f.fVar32))) != 0) && ((b(((b(((b((60.0) < (f.param_20))) != 0) && ((b((f.param_19) < (11.0))) != 0))) != 0) && ((b(((b((3.9) < (f.dVar39))) != 0) && ((b((6.0) < (f.param_22))) != 0))) != 0))) != 0))) != 0))) != 0) 120 else 115
        }
        122 -> {
            36
        }
        123 -> {
            if ((b(((b(((b(((b((0.6) < (f.fVar32))) != 0) && ((b((f.param_16) < (3.0))) != 0))) != 0) && ((b((11.0) < (f.param_19))) != 0))) != 0) && ((b((8.6) < (f.dVar26))) != 0))) != 0) 122 else 121
        }
        124 -> {
            37
        }
        125 -> {
            if ((b(((b(((b((f.param_19) < (9.0))) != 0) && ((b((0.6) < (f.fVar11))) != 0))) != 0) && ((b(((b((f.param_16) < (3.0))) != 0) && ((b((6.0) < (f.param_22))) != 0))) != 0))) != 0) 124 else 123
        }
        126 -> {
            if ((b((0.5) < (f.fVar32))) != 0) 125 else 121
        }
        127 -> {
            37
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep4(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        128 -> {
            36
        }
        129 -> {
            if ((b(((b((11.0) <= (f.param_19))) != 0) || ((b((7.5) <= (f.param_22))) != 0))) != 0) 128 else 127
        }
        130 -> {
            if ((b(((b(((b((DAT_0012ce08) < (f.fVar32))) != 0) && ((b((0.6) < (f.fVar11))) != 0))) != 0) && ((b((3.0) < (f.param_16))) != 0))) != 0) 129 else 126
        }
        131 -> {
            if ((b((f.param_4) < (2.5))) != 0) 130 else 121
        }
        132 -> {
            37
        }
        133 -> {
            36
        }
        134 -> {
            if ((b((10.5) <= (f.param_19))) != 0) 133 else 132
        }
        135 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        136 -> {
            if ((b((f.fVar31) <= (1.0))) != 0) 135 else 132
        }
        137 -> {
            if ((b(((b((f.param_5) <= (f.param_4))) != 0) || ((b((2.4) <= (f.dVar44))) != 0))) != 0) 134 else 136
        }
        138 -> {
            if ((b(((b(((b((f.param_4) < (3.0))) != 0) && ((b((f.param_5) < (3.0))) != 0))) != 0) && ((b(((b((0.5) < (f.fVar31))) != 0) && ((b(((b((f.param_16) < (3.0))) != 0) && ((b((DAT_0012ccb0) < (f.fVar37))) != 0))) != 0))) != 0))) != 0) 137 else 131
        }
        139 -> {
            36
        }
        140 -> {
            if ((b(((b(((b(((b(((b((3.5) < (f.param_3))) != 0) && ((b((3.5) < (f.param_5))) != 0))) != 0) && ((b((f.param_4) < (3.0))) != 0))) != 0) && ((b((0.5) < (((f.fVar31) - (kotlin.math.abs(((f.param_3) - (f.param_5)))))))) != 0))) != 0) || ((b(((b(((b((DAT_0012ccb8) < (f.fVar31))) != 0) && ((b((3.5) < (f.param_3))) != 0))) != 0) && ((b(((b((3.5) < (f.param_5))) != 0) && ((b(((b(((b((f.dVar43) < (DAT_0012ce20))) != 0) && ((b((DAT_0012ce40) < (f.dVar24))) != 0))) != 0) && ((b((8.5) < (f.param_23))) != 0))) != 0))) != 0))) != 0))) != 0) 139 else 138
        }
        141 -> {
            if ((b((-(0.5)) <= (f.fVar12))) != 0) 107 else 140
        }
        142 -> {
            f.fVar31 = f32(kotlin.math.abs(f.fVar12))
            141
        }
        143 -> {
            36
        }
        144 -> {
            37
        }
        145 -> {
            36
        }
        146 -> {
            if ((b(((b((2.8) <= (f.dVar39))) != 0) || ((b((DAT_0012cde0) <= (f.fVar35))) != 0))) != 0) 145 else 144
        }
        147 -> {
            f.result = f32(f32(f.dVar51))
            C_DONE
        }
        148 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        149 -> {
            if ((f.bVar2) != 0) 148 else 147
        }
        150 -> {
            f.bVar2 = b((b((f.param_5) < (2.5))) != 0)
            149
        }
        151 -> {
            if ((b(((b((f.param_20) <= (60.0))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_5).isNaN())) != 0)) }) != 0))) != 0) 150 else 149
        }
        152 -> {
            f.bVar2 = b((1) != 0)
            151
        }
        153 -> {
            if ((b(((b(((b((f.param_3) < (f.param_4))) != 0) && ((b((f.param_4) < (f.param_5))) != 0))) != 0) && ((b(((b((f.param_5) < (2.5))) != 0) || ((b((f.param_22) < (7.5))) != 0))) != 0))) != 0) 33 else 146
        }
        154 -> {
            f.result = f32(0.0)
            C_DONE
        }
        155 -> {
            if ((b(((b((3.5) < (f.param_16))) != 0) && ((b((2.0) < (f.fVar42))) != 0))) != 0) 154 else 153
        }
        156 -> {
            if ((b(((b(((b((f.dVar43) < (2.4))) != 0) || ((b((f.dVar40) < (2.4))) != 0))) != 0) || ((b((f.dVar44) < (2.4))) != 0))) != 0) 155 else 144
        }
        157 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        158 -> {
            if ((b(((b(((b((DAT_0012cde8) <= (f.dVar43))) != 0) && ((b((DAT_0012cde8) <= (f.dVar40))) != 0))) != 0) && ((b((DAT_0012cde8) <= (f.dVar44))) != 0))) != 0) 157 else 156
        }
        159 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep5(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        160 -> {
            if ((b((f.param_23) <= (7.5))) != 0) 159 else 158
        }
        161 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        162 -> {
            if ((b((f.dVar24) <= (DAT_0012cc40))) != 0) 161 else 160
        }
        163 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        164 -> {
            if ((b((f.param_19) <= (10.0))) != 0) 163 else 162
        }
        165 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        166 -> {
            if ((b((3.9) <= (f.dVar39))) != 0) 165 else 164
        }
        167 -> {
            if ((b(((b(((b(((b((f.dVar43) <= (DAT_0012ce48))) != 0) || ((b((3.9) <= (f.dVar40))) != 0))) != 0) || ((b(((b((f.dVar44) <= (DAT_0012ce48))) != 0) || ((b((f.dVar39) <= (3.9))) != 0))) != 0))) != 0) && ((b(((b(((b(((b(((b((f.dVar43) <= (3.9))) != 0) || ((b((DAT_0012cdf8) <= (f.dVar40))) != 0))) != 0) || ((b((f.dVar44) <= (3.9))) != 0))) != 0) || ((b((f.dVar39) <= (3.9))) != 0))) != 0) && ((b(((b(((b((f.param_16) <= (3.0))) != 0) || ((b((f.fVar42) <= (1.5))) != 0))) != 0) || ((b((42.0) <= (f.param_20))) != 0))) != 0))) != 0))) != 0) 166 else 143
        }
        168 -> {
            f.result = f32(f32(f.dVar51))
            C_DONE
        }
        169 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        170 -> {
            if ((f.bVar2) != 0) 169 else 168
        }
        171 -> {
            f.bVar2 = b((b((f.param_5) < (2.5))) != 0)
            34
        }
        172 -> {
            if ((b(((b((f.param_20) <= (60.0))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_5).isNaN())) != 0)) }) != 0))) != 0) 171 else 34
        }
        173 -> {
            f.bVar2 = b((1) != 0)
            172
        }
        174 -> {
            if ((b(((b((f.param_3) < (f.param_4))) != 0) && ((b(((b((f.param_4) < (f.param_5))) != 0) && ((b(((b((f.param_5) < (2.5))) != 0) || ((b((f.param_22) < (7.5))) != 0))) != 0))) != 0))) != 0) 173 else 143
        }
        175 -> {
            if ((b(((b(((b(((b((f.param_4) <= (3.5))) != 0) || ((b((f.param_5) <= (3.5))) != 0))) != 0) || ((b((3.0) <= (f.param_3))) != 0))) != 0) || ((b((((kotlin.math.abs(f.fVar11)) - (f.fVar19))) <= (0.5))) != 0))) != 0) 167 else 174
        }
        176 -> {
            if ((b((f.fVar11) < (-(0.5)))) != 0) 175 else 142
        }
        177 -> {
            if ((b(((b(((b((f.dVar39) <= (2.4))) != 0) || ((b(((b(((b((DAT_0012ce18) <= (f.dVar40))) != 0) && ((b((DAT_0012ce18) <= (f.dVar43))) != 0))) != 0) && ((b((DAT_0012ce18) <= (f.dVar44))) != 0))) != 0))) != 0) || ((b(((b((f.dVar48) <= (DAT_0012ce08))) != 0) && ((b(((b((f.dVar34) <= (DAT_0012ce08))) != 0) && ((b((f.dVar30) <= (DAT_0012ce08))) != 0))) != 0))) != 0))) != 0) 176 else 77
        }
        178 -> {
            28
        }
        179 -> {
            if ((b(((b((1.2) < (f.dVar34))) != 0) && ((b((7.0) < (f.param_22))) != 0))) != 0) 178 else 62
        }
        180 -> {
            36
        }
        181 -> {
            if ((b(((b((f.dVar39) <= (4.3))) != 0) || ((b((f.param_19) <= (8.0))) != 0))) != 0) 180 else 179
        }
        182 -> {
            if ((b(((b(((b(((b((f.param_29) <= (5.0))) != 0) || ((b(((b(((b((f.dVar48) <= (0.6))) != 0) && ((b((f.dVar34) <= (0.6))) != 0))) != 0) && ((b((f.dVar30) <= (0.6))) != 0))) != 0))) != 0) || ((b(((b(((b((3.9) <= (f.dVar40))) != 0) && ((b((3.9) <= (f.dVar43))) != 0))) != 0) && ((b((3.9) <= (f.dVar44))) != 0))) != 0))) != 0) || ((b(((b(((b((f.dVar39) <= (4.1))) != 0) && ((b(((b((f.dVar39) <= (DAT_0012cdf8))) != 0) || ((b((f.param_23) <= (8.0))) != 0))) != 0))) != 0) || ((b((f.param_20) <= (60.0))) != 0))) != 0))) != 0) 177 else 181
        }
        183 -> {
            31
        }
        184 -> {
            if ((b(((b(((b(((b((f.dVar43) < (2.8))) != 0) && ((b((15.0) < (f.param_21))) != 0))) != 0) && ((b((DAT_0012cca8) < (f.dVar24))) != 0))) != 0) && ((b((8.0) < (f.param_22))) != 0))) != 0) 183 else 182
        }
        185 -> {
            27
        }
        186 -> {
            36
        }
        187 -> {
            if ((b(((b(((b(((b((f.dVar39) < (4.3))) != 0) && ((b((f.dVar40) < (2.8))) != 0))) != 0) && ((b((f.param_19) < (11.0))) != 0))) != 0) || ((b(((b((f.fVar31) < (3.8))) != 0) && ((b((f.fVar13) < (3.8))) != 0))) != 0))) != 0) 186 else 185
        }
        188 -> {
            f.result = f32(f32(f.dVar51))
            C_DONE
        }
        189 -> {
            if ((b((f.param_16) <= (3.5))) != 0) 32 else 187
        }
        190 -> {
            if ((b((f.dVar43) < (2.8))) != 0) 31 else 182
        }
        191 -> {
            if ((b((f.dVar39) <= (3.3))) != 0) 184 else 190
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep6(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        192 -> {
            if ((b((48.0) < (f.param_20))) != 0) 191 else 182
        }
        193 -> {
            36
        }
        194 -> {
            if ((b(((b((8.5) < (f.param_21))) != 0) && ((b(((b((f.dVar43) < (DAT_0012cde0))) != 0) && ((b(((b((7.0) < (f.param_22))) != 0) || ((b((7.0) < (f.param_23))) != 0))) != 0))) != 0))) != 0) 193 else 192
        }
        195 -> {
            27
        }
        196 -> {
            36
        }
        197 -> {
            if ((b(((b((f.param_3) < (3.0))) != 0) && ((b((f.param_5) < (3.0))) != 0))) != 0) 196 else 195
        }
        198 -> {
            if ((b(((b((8.5) < (f.param_21))) != 0) && ((b(((b(((b(((b((6.0) < (f.param_22))) != 0) && ((b((f.dVar43) < (3.3))) != 0))) != 0) && ((b((6.0) < (f.param_23))) != 0))) != 0) && ((b(((b((2.0) < (((((f.param_10) - (f.param_4))) / (f.fVar42))))) != 0) || ((b((DAT_0012ccb8) < (f.dVar24))) != 0))) != 0))) != 0))) != 0) 197 else 194
        }
        199 -> {
            if ((b(((b((3.0) < (f.param_16))) != 0) && ((b((72.0) < (f.param_20))) != 0))) != 0) 198 else 192
        }
        200 -> {
            if ((b(((b(((b(((b((f.dVar39) <= (DAT_0012cca0))) != 0) || ((b((f.param_20) <= (60.0))) != 0))) != 0) || ((b(((b(((b((3.5) <= (f.param_3))) != 0) && ((b((3.5) <= (f.param_4))) != 0))) != 0) && ((b((3.5) <= (f.param_5))) != 0))) != 0))) != 0) || ((b(((b(((b((0.25) <= (f.fVar37))) != 0) || ((b((10.0) <= (f.param_19))) != 0))) != 0) || ((b(((b((f.dVar28) <= (6.8))) != 0) || ((b((f.dVar26) <= (6.8))) != 0))) != 0))) != 0))) != 0) 199 else 61
        }
        201 -> {
            if ((b(((b((f.dVar39) <= (3.9))) != 0) || ((b(((b(((b((f.param_20) <= (60.0))) != 0) || ((b(((b(((b((DAT_0012cde0) <= (f.dVar40))) != 0) && ((b((DAT_0012cde0) <= (f.dVar43))) != 0))) != 0) && ((b((DAT_0012cde0) <= (f.dVar44))) != 0))) != 0))) != 0) || ((b((0.25) <= (f.fVar37))) != 0))) != 0))) != 0) 200 else 61
        }
        202 -> {
            37
        }
        203 -> {
            36
        }
        204 -> {
            if ((b(((b((DAT_0012ce18) <= (f.dVar40))) != 0) || ((b((3.5) <= (f.fVar13))) != 0))) != 0) 203 else 202
        }
        205 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        206 -> {
            if ((b((f.fVar37) <= (0.35))) != 0) 205 else 204
        }
        207 -> {
            if ((b(((b(((b(((b(((b((f.dVar39) < (DAT_0012cde0))) != 0) && ((b((f.dVar44) < (DAT_0012cde0))) != 0))) != 0) && ((b((f.dVar40) < (DAT_0012cde0))) != 0))) != 0) && ((b(((b((f.dVar43) < (DAT_0012cde0))) != 0) && ((b((f.param_19) < (11.0))) != 0))) != 0))) != 0) && ((b(((b((54.0) < (f.param_20))) != 0) || ((b((((f.dVar52) + (f.param_2))) < (3.9))) != 0))) != 0))) != 0) 206 else 201
        }
        208 -> {
            f.dVar52 = ((f.dVar50) * (0.5))
            207
        }
        209 -> {
            if ((b(((b((DAT_0012ce18) <= (f.dVar40))) != 0) || ((b(((b((DAT_0012ce18) <= (f.dVar43))) != 0) || ((b((DAT_0012ce18) <= (f.dVar44))) != 0))) != 0))) != 0) 208 else 58
        }
        210 -> {
            32
        }
        211 -> {
            if ((b(((b((12.0) < (f.param_19))) != 0) && ((b((f.param_23) < (8.0))) != 0))) != 0) 210 else 38
        }
        212 -> {
            27
        }
        213 -> {
            if ((b(((b(((b((DAT_0012cca8) <= (f.dVar43))) != 0) && ((b(((b((DAT_0012cca8) <= (f.dVar40))) != 0) && ((b((DAT_0012cca8) <= (f.dVar44))) != 0))) != 0))) != 0) && ((b((2.8) <= (f.dVar39))) != 0))) != 0) 212 else 211
        }
        214 -> {
            if ((b(((b(((b(((b((42.0) <= (f.param_20))) != 0) || ((b((f.fVar42) <= (2.0))) != 0))) != 0) || ((b((f.fVar38) <= (0.5))) != 0))) != 0) || ((b(((b((f.param_16) <= (3.0))) != 0) && ((b(((b((f.dVar39) <= (2.4))) != 0) || ((b((f.fVar42) <= (3.0))) != 0))) != 0))) != 0))) != 0) 209 else 213
        }
        215 -> {
            if ((b(((b(((b(((b(((b((f.param_22) <= (7.0))) != 0) || ((b((0.3) <= (kotlin.math.abs(((f.param_23) - (f.param_22)))))) != 0))) != 0) || ((b((f.param_16) <= (3.0))) != 0))) != 0) || ((b(((b(((b((f.fVar42) <= (1.0))) != 0) || ((b((3.5) <= (f.param_16))) != 0))) != 0) || ((b((12.0) <= (f.param_19))) != 0))) != 0))) != 0) && ((b(((b(((b((f.fVar13) <= (5.0))) != 0) || ((b((4.1) <= (f.dVar40))) != 0))) != 0) || ((b((f.dVar50) <= (DAT_0012ce08))) != 0))) != 0))) != 0) 214 else 38
        }
        216 -> {
            34
        }
        217 -> {
            f.bVar2 = b((b((f.dVar43) < (DAT_0012ce18))) != 0)
            216
        }
        218 -> {
            if ((b(((f.bVar4) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar43).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce18).isNaN())) != 0))) != 0)) }) != 0))) != 0) 217 else 216
        }
        219 -> {
            f.bVar2 = b((0) != 0)
            218
        }
        220 -> {
            f.bVar4 = b((b((f.dVar40) < (DAT_0012ce18))) != 0)
            219
        }
        221 -> {
            if ((b(((f.bVar2) != 0) && ((run { run { f.bVar4 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar40).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce18).isNaN())) != 0))) != 0)) }) != 0))) != 0) 220 else 219
        }
        222 -> {
            f.bVar4 = b((0) != 0)
            221
        }
        223 -> {
            f.bVar2 = b((b((f.fVar13) < (3.5))) != 0)
            222
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep7(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        224 -> {
            if ((b(((b((f.fVar31) < (3.5))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar13).isNaN())) != 0)) }) != 0))) != 0) 223 else 222
        }
        225 -> {
            f.bVar2 = b((0) != 0)
            224
        }
        226 -> {
            if ((b(((b((f.param_16) < (3.5))) != 0) && ((b((((f.dVar51) + (f.dVar40))) < (3.5))) != 0))) != 0) 225 else 215
        }
        227 -> {
            f.dVar51 = ((f.dVar50) * (0.75))
            226
        }
        228 -> {
            30
        }
        229 -> {
            f.fVar31 = f32(0.75)
            228
        }
        230 -> {
            f.bVar2 = b((b((f.dVar43) < (DAT_0012ce18))) != 0)
            229
        }
        231 -> {
            if ((b(((f.bVar4) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar43).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce18).isNaN())) != 0))) != 0)) }) != 0))) != 0) 230 else 229
        }
        232 -> {
            f.bVar2 = b((0) != 0)
            231
        }
        233 -> {
            f.bVar4 = b((b((f.dVar40) < (DAT_0012ce18))) != 0)
            232
        }
        234 -> {
            if ((b(((f.bVar2) != 0) && ((run { run { f.bVar4 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar40).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce18).isNaN())) != 0))) != 0)) }) != 0))) != 0) 233 else 232
        }
        235 -> {
            f.bVar4 = b((0) != 0)
            234
        }
        236 -> {
            f.bVar2 = b((b((f.fVar13) < (3.5))) != 0)
            235
        }
        237 -> {
            if ((b(((b((f.fVar31) < (3.5))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar13).isNaN())) != 0)) }) != 0))) != 0) 236 else 235
        }
        238 -> {
            f.bVar2 = b((0) != 0)
            237
        }
        239 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        240 -> {
            if ((b((f.dVar39) < (2.8))) != 0) 239 else 238
        }
        241 -> {
            if ((b(((b((f.fVar13) < (3.9))) != 0) && ((b(((b((f.fVar31) < (3.9))) != 0) && ((b((((f.fVar38) + (f.param_5))) < (3.9))) != 0))) != 0))) != 0) 240 else 227
        }
        242 -> {
            if ((b(((b(((b((DAT_0012cca8) <= (f.dVar44))) != 0) || ((b(((b(((b((DAT_0012cca8) <= (f.dVar40))) != 0) || ((b((f.param_22) <= (7.5))) != 0))) != 0) || ((b((f.param_23) <= (7.5))) != 0))) != 0))) != 0) || ((b(((b((DAT_0012cca8) <= (f.dVar43))) != 0) || ((b((f.fVar38) <= (2.0))) != 0))) != 0))) != 0) 241 else 38
        }
        243 -> {
            27
        }
        244 -> {
            if ((b((4.5) <= (f.fVar13))) != 0) 243 else 38
        }
        245 -> {
            if ((b(((b(((b(((b((3.9) <= (f.dVar40))) != 0) || ((b(((b((2.8) <= (f.dVar44))) != 0) || ((b((f.fVar22) <= (DAT_0012ce08))) != 0))) != 0))) != 0) || ((b((3.5) <= (f.param_16))) != 0))) != 0) || ((b(((b((f.param_23) <= (7.0))) != 0) || ((b((f.fVar13) <= (3.8))) != 0))) != 0))) != 0) 242 else 244
        }
        246 -> {
            27
        }
        247 -> {
            if ((b(((b((4.5) <= (f.fVar13))) != 0) || ((b((f.dVar40) < (3.3))) != 0))) != 0) 246 else 38
        }
        248 -> {
            if ((b(((b(((b(((b(((b((3.9) <= (f.dVar40))) != 0) || ((b((2.8) <= (f.dVar43))) != 0))) != 0) || ((b((f.fVar11) <= (DAT_0012ce08))) != 0))) != 0) || ((b((3.5) <= (f.param_16))) != 0))) != 0) || ((b(((b((f.param_23) <= (7.0))) != 0) || ((b((f.fVar13) <= (3.8))) != 0))) != 0))) != 0) 245 else 247
        }
        249 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        250 -> {
            if ((b((((((f.dVar50) + (0.3))) - (f.param_15))) <= (0.5))) != 0) 249 else 248
        }
        251 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        252 -> {
            if ((b((f.param_14) < (0x241))) != 0) 251 else 250
        }
        253 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        254 -> {
            if ((b((1) < (f.bVar8))) != 0) 253 else 252
        }
        255 -> {
            f.result = f32(((f.fVar38) * (f.fVar31)))
            C_DONE
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep8(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        256 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        257 -> {
            if ((f.bVar2) != 0) 256 else 255
        }
        258 -> {
            f.fVar31 = f32(0.5)
            30
        }
        259 -> {
            f.bVar2 = b((b((f.dVar40) < (2.8))) != 0)
            29
        }
        260 -> {
            if ((b(((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar3) == (f.bVar7))) != 0))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar40).isNaN())) != 0)) }) != 0))) != 0) 259 else 29
        }
        261 -> {
            f.bVar2 = b((0) != 0)
            260
        }
        262 -> {
            f.bVar7 = b((0) != 0)
            261
        }
        263 -> {
            f.bVar5 = b((b((f.param_4) == (f.param_3))) != 0)
            262
        }
        264 -> {
            f.bVar3 = b((b((f.param_4) < (f.param_3))) != 0)
            263
        }
        265 -> {
            if ((b(((b(!((b((f.param_4).isNaN())) != 0))) != 0) && ((b(!((b((f.param_3).isNaN())) != 0))) != 0))) != 0) 264 else 261
        }
        266 -> {
            f.bVar7 = b((1) != 0)
            265
        }
        267 -> {
            f.bVar5 = b((0) != 0)
            266
        }
        268 -> {
            f.bVar3 = b((0) != 0)
            267
        }
        269 -> {
            if ((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) 268 else 261
        }
        270 -> {
            f.bVar7 = b((0) != 0)
            269
        }
        271 -> {
            f.bVar5 = b((1) != 0)
            270
        }
        272 -> {
            f.bVar3 = b((0) != 0)
            271
        }
        273 -> {
            f.bVar6 = b((0) != 0)
            272
        }
        274 -> {
            f.bVar4 = b((b((f.param_5) == (f.param_4))) != 0)
            273
        }
        275 -> {
            f.bVar2 = b((b((f.param_5) < (f.param_4))) != 0)
            274
        }
        276 -> {
            if ((b(((b(!((b((f.param_5).isNaN())) != 0))) != 0) && ((b(!((b((f.param_4).isNaN())) != 0))) != 0))) != 0) 275 else 272
        }
        277 -> {
            f.bVar6 = b((1) != 0)
            276
        }
        278 -> {
            f.bVar4 = b((0) != 0)
            277
        }
        279 -> {
            f.bVar2 = b((0) != 0)
            278
        }
        280 -> {
            if ((b((f.fVar13) < (3.5))) != 0) 279 else 272
        }
        281 -> {
            f.bVar6 = b((0) != 0)
            280
        }
        282 -> {
            f.bVar4 = b((1) != 0)
            281
        }
        283 -> {
            f.bVar2 = b((0) != 0)
            282
        }
        284 -> {
            if ((b(((b(((b(((b((3.5) < (f.param_16))) != 0) && ((b((48.0) <= (f.param_20))) != 0))) != 0) && ((b(((b((f.dVar40) < (DAT_0012cde0))) != 0) || ((b(((b((f.dVar43) < (DAT_0012cde0))) != 0) || ((b((f.dVar44) < (DAT_0012cde0))) != 0))) != 0))) != 0))) != 0) && ((b(((b((8.5) < (f.param_21))) != 0) && ((b(((b((6.0) < (f.param_22))) != 0) || ((b(((b((6.0) < (f.param_23))) != 0) && ((b(((b((1.0) < (f.fVar20))) != 0) || ((b((1.0) < (f.fVar19))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) 283 else 254
        }
        285 -> {
            26
        }
        286 -> {
            if ((b(((b(((b(((b((f.param_20) < (45.0))) != 0) && ((b((f.param_16) < (2.5))) != 0))) != 0) && ((b(((b((2.0) < (f.param_16))) != 0) && ((b(((b((0.5) < (f.fVar42))) != 0) && ((b((1.0) < (f.fVar38))) != 0))) != 0))) != 0))) != 0) && ((b(((b((9.0) < (f.param_22))) != 0) || ((b((9.0) < (f.param_23))) != 0))) != 0))) != 0) 285 else 284
        }
        287 -> {
            39
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep9(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        288 -> {
            f.fVar31 = f32(0.0)
            287
        }
        289 -> {
            38
        }
        290 -> {
            if ((b((1.5) <= (f.param_3))) != 0) 289 else 28
        }
        291 -> {
            if ((b(((b(((b(((b((f.param_20) < (42.0))) != 0) && ((b(((b((0.85) < (f.dVar24))) != 0) && ((b((10.0) < (f.param_23))) != 0))) != 0))) != 0) && ((b((f.param_16) < (3.0))) != 0))) != 0) && ((b(((b(((b((10.0) < (f.param_22))) != 0) && ((b((2.0) < (f.param_16))) != 0))) != 0) && ((b((0.5) < (f.fVar38))) != 0))) != 0))) != 0) 290 else 286
        }
        292 -> {
            if ((b(((b(((b(((b((DAT_0012cde8) < (f.dVar39))) != 0) && ((b((2.5) < (f.fVar42))) != 0))) != 0) && ((b(((b((f.param_20) < (42.0))) != 0) && ((b(((b((0.3) < (f.dVar50))) != 0) && ((b(((b((9.0) < (f.param_22))) != 0) || ((b((9.0) < (f.param_23))) != 0))) != 0))) != 0))) != 0))) != 0) || ((b(((b((f.param_20) < (39.0))) != 0) && ((b(((b(((b(((b((DAT_0012ce38) < (f.dVar24))) != 0) && ((b((0.3) < (f.dVar50))) != 0))) != 0) && ((b((f.dVar39) < (DAT_0012cdf8))) != 0))) != 0) && ((b(((b((DAT_0012cde8) < (f.dVar39))) != 0) && ((b((7.0) < (f.param_22))) != 0))) != 0))) != 0))) != 0))) != 0) 26 else 291
        }
        293 -> {
            38
        }
        294 -> {
            if ((b(((b(((b(((b(((b((f.param_20) < (48.0))) != 0) && ((b((f.param_16) < (4.5))) != 0))) != 0) && ((b((7.0) < (f.param_23))) != 0))) != 0) && ((b(((b((f.param_30) < (60.0))) != 0) && ((b((f.param_29) < (4.6))) != 0))) != 0))) != 0) && ((b(((b((3.0) < (f.param_16))) != 0) && ((b((DAT_0012ce08) < (f.dVar50))) != 0))) != 0))) != 0) 293 else 292
        }
        295 -> {
            27
        }
        296 -> {
            23
        }
        297 -> {
            if ((b(((b((DAT_0012cde0) <= (f.dVar39))) != 0) || ((b(((b((f.dVar40) <= (2.4))) != 0) || ((b((f.dVar24) <= (1.2))) != 0))) != 0))) != 0) 296 else 295
        }
        298 -> {
            f.result = f32(((f.fVar38) * (0.5)))
            C_DONE
        }
        299 -> {
            24
        }
        300 -> {
            if ((b(((b((((f.dVar50) + (f.dVar40))) < (3.5))) != 0) && ((b((((f.dVar50) + (f.dVar43))) < (3.9))) != 0))) != 0) 299 else 23
        }
        301 -> {
            f.dVar50 = ((f.dVar50) * (0.75))
            300
        }
        302 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        303 -> {
            if ((b(((b((f.fVar13) < (3.9))) != 0) && ((b(((b((42.0) < (f.param_20))) != 0) && ((b((f.fVar31) < (3.9))) != 0))) != 0))) != 0) 302 else 301
        }
        304 -> {
            if ((b(((b((f.dVar40) < (2.8))) != 0) || ((b((f.dVar43) < (2.8))) != 0))) != 0) 303 else 297
        }
        305 -> {
            24
        }
        306 -> {
            f.result = f32(((f.fVar38) * (0.5)))
            C_DONE
        }
        307 -> {
            if ((b(((b(((b((3.9) <= (((f.dVar50) + (f.dVar44))))) != 0) || ((b((3.9) <= (((f.dVar50) + (f.dVar40))))) != 0))) != 0) || ((b((3.9) <= (((f.dVar50) + (f.dVar43))))) != 0))) != 0) 306 else 305
        }
        308 -> {
            f.dVar50 = ((f.dVar50) * (0.75))
            307
        }
        309 -> {
            if ((b(((b(((b((DAT_0012cde0) <= (f.dVar39))) != 0) || ((b((f.dVar40) <= (2.4))) != 0))) != 0) || ((b((f.dVar24) <= (1.2))) != 0))) != 0) 308 else 295
        }
        310 -> {
            39
        }
        311 -> {
            f.fVar31 = f32(0.75)
            310
        }
        312 -> {
            f.result = f32(f32(f.dVar50))
            C_DONE
        }
        313 -> {
            if ((b(((b(((b((3.9) <= (((f.dVar50) + (f.dVar44))))) != 0) || ((b((3.5) <= (((f.dVar50) + (f.dVar40))))) != 0))) != 0) || ((b((3.9) <= (((f.dVar50) + (f.dVar43))))) != 0))) != 0) 24 else 311
        }
        314 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        315 -> {
            if ((b(((b(((b((((f.dVar50) + (f.dVar44))) < (DAT_0012cde0))) != 0) && ((b((((f.dVar50) + (f.dVar40))) < (3.0))) != 0))) != 0) && ((b((((f.dVar50) + (f.dVar43))) < (DAT_0012cde0))) != 0))) != 0) 314 else 313
        }
        316 -> {
            f.dVar50 = ((f.dVar50) * (0.5))
            315
        }
        317 -> {
            if ((b(((b(((b((f.param_3) < (2.5))) != 0) || ((b((f.param_4) < (2.5))) != 0))) != 0) || ((b((f.param_5) < (2.5))) != 0))) != 0) 316 else 309
        }
        318 -> {
            if ((b((f.param_14) < (0x240))) != 0) 304 else 317
        }
        319 -> {
            25
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep10(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        320 -> {
            if ((b(((b(((b(((b((60.0) <= (f.param_30))) != 0) || ((b(((b((10.0) <= (f.param_19))) != 0) && ((b((54.0) <= (f.param_30))) != 0))) != 0))) != 0) || ((b((f.dVar39) <= (DAT_0012ce10))) != 0))) != 0) || ((b((f.dVar50) <= (DAT_0012ccb8))) != 0))) != 0) 319 else 318
        }
        321 -> {
            if ((b(((b((f.dVar39) < (3.9))) != 0) && ((b((6.5) < (f.param_23))) != 0))) != 0) 320 else 25
        }
        322 -> {
            38
        }
        323 -> {
            24
        }
        324 -> {
            if ((b(((b((48.0) < (f.param_20))) != 0) && ((run { run { f.dVar50 = ((f.dVar50) * (0.75)); ((f.dVar50) * (0.75)) }; b((((f.dVar50) + (f.dVar40))) < (3.9)) }) != 0))) != 0) 323 else 322
        }
        325 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        326 -> {
            if ((b((f.fVar13) <= (3.5))) != 0) 325 else 324
        }
        327 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        328 -> {
            if ((b(((b((f.param_22) <= (7.0))) != 0) && ((b((f.param_23) <= (7.0))) != 0))) != 0) 327 else 326
        }
        329 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        330 -> {
            if ((b((f.dVar24) <= (DAT_0012cc80))) != 0) 329 else 328
        }
        331 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        332 -> {
            if ((b(((b((3.9) <= (f.dVar43))) != 0) && ((b(((b(((b((3.9) <= (f.dVar40))) != 0) && ((b((DAT_0012cde0) <= (f.dVar39))) != 0))) != 0) && ((b((DAT_0012cca0) <= (f.dVar39))) != 0))) != 0))) != 0) 331 else 330
        }
        333 -> {
            if ((b(((b((0x59f) < (f.param_14))) != 0) || ((b(((b(((b(((b((3.9) <= (f.dVar43))) != 0) && ((b((3.9) <= (f.dVar40))) != 0))) != 0) && ((b(((b((DAT_0012cde0) <= (f.dVar39))) != 0) && ((b((DAT_0012cca0) <= (f.dVar39))) != 0))) != 0))) != 0) || ((b(((b(((b((f.param_22) <= (7.0))) != 0) && ((b((f.param_23) <= (7.0))) != 0))) != 0) || ((b((f.fVar13) <= (3.0))) != 0))) != 0))) != 0))) != 0) 332 else 322
        }
        334 -> {
            35
        }
        335 -> {
            f.fVar31 = f32(((f.fVar38) * (0.5)))
            334
        }
        336 -> {
            f.bVar3 = b((0) != 0)
            335
        }
        337 -> {
            f.bVar6 = b((b((f.dVar24) == (DAT_0012cc80))) != 0)
            336
        }
        338 -> {
            f.bVar2 = b((b((f.dVar24) < (DAT_0012cc80))) != 0)
            337
        }
        339 -> {
            if ((b(((b(!((b((f.dVar24).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012cc80).isNaN())) != 0))) != 0))) != 0) 338 else 335
        }
        340 -> {
            f.bVar3 = b((1) != 0)
            339
        }
        341 -> {
            f.bVar6 = b((0) != 0)
            340
        }
        342 -> {
            f.bVar2 = b((0) != 0)
            341
        }
        343 -> {
            if ((b((f.param_20) < (42.0))) != 0) 342 else 335
        }
        344 -> {
            f.bVar3 = b((0) != 0)
            343
        }
        345 -> {
            f.bVar6 = b((1) != 0)
            344
        }
        346 -> {
            f.bVar2 = b((0) != 0)
            345
        }
        347 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        348 -> {
            if ((b((f.fVar13) <= (3.5))) != 0) 347 else 346
        }
        349 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        350 -> {
            if ((b(((b((f.param_22) <= (7.0))) != 0) && ((b((f.param_23) <= (7.0))) != 0))) != 0) 349 else 348
        }
        351 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep11(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        352 -> {
            if ((b(((b(((b(((b((3.9) <= (f.dVar43))) != 0) && ((b((3.9) <= (f.dVar40))) != 0))) != 0) && ((b((DAT_0012cde0) <= (f.dVar39))) != 0))) != 0) && ((b((DAT_0012cca0) <= (f.dVar39))) != 0))) != 0) 351 else 350
        }
        353 -> {
            if ((b(((b(((b((f.dVar44) < (((f.param_11) - (f.param_5))))) != 0) || ((b((f.dVar44) < (((f.param_10) - (f.param_4))))) != 0))) != 0) || ((b((f.dVar44) < (((f.param_9) - (f.param_3))))) != 0))) != 0) 352 else 333
        }
        354 -> {
            f.dVar44 = ((f.dVar24) + (0.75))
            353
        }
        355 -> {
            if ((b(((b(((b(((b(((b((f.param_16) < (3.5))) != 0) && ((b((DAT_0012ce08) < (f.dVar50))) != 0))) != 0) && ((b((0x360) < (f.param_14))) != 0))) != 0) && ((b(((b((1.5) < (f.fVar42))) != 0) && ((b(((b((f.param_3) < (3.5))) != 0) || ((b((f.param_4) < (3.5))) != 0))) != 0))) != 0))) != 0) && ((b((3.9) < (f.fVar13))) != 0))) != 0) 354 else 321
        }
        356 -> {
            25
        }
        357 -> {
            if ((b((60.0) <= (f.param_20))) != 0) 356 else 355
        }
        358 -> {
            f.fVar31 = f32(((f.fVar38) + (f.param_4)))
            357
        }
        359 -> {
            f.fVar13 = f32(((f.fVar38) + (f.param_3)))
            358
        }
        360 -> {
            f.dVar24 = f.fVar42
            359
        }
        361 -> {
            f.dVar50 = f.fVar38
            360
        }
        362 -> {
            38
        }
        363 -> {
            35
        }
        364 -> {
            f.fVar31 = f32(((f.fVar38) * (0.5)))
            363
        }
        365 -> {
            f.bVar3 = b((0) != 0)
            364
        }
        366 -> {
            f.bVar6 = b((b((f.fVar42) == (0.5))) != 0)
            365
        }
        367 -> {
            f.bVar2 = b((b((f.fVar42) < (0.5))) != 0)
            366
        }
        368 -> {
            if ((b(!((b((f.fVar42).isNaN())) != 0))) != 0) 367 else 364
        }
        369 -> {
            f.bVar3 = b((1) != 0)
            368
        }
        370 -> {
            f.bVar6 = b((0) != 0)
            369
        }
        371 -> {
            f.bVar2 = b((0) != 0)
            370
        }
        372 -> {
            if ((f.bVar4) != 0) 371 else 364
        }
        373 -> {
            f.bVar3 = b((0) != 0)
            372
        }
        374 -> {
            f.bVar6 = b((1) != 0)
            373
        }
        375 -> {
            f.bVar2 = b((0) != 0)
            374
        }
        376 -> {
            f.bVar4 = b((b((f.dVar40) < (3.3))) != 0)
            375
        }
        377 -> {
            if ((b(((b(!((f.bVar2) != 0))) != 0) && ((run { run { f.bVar4 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar40).isNaN())) != 0)) }) != 0))) != 0) 376 else 375
        }
        378 -> {
            f.bVar4 = b((1) != 0)
            377
        }
        379 -> {
            f.bVar2 = b((b((f.dVar43) < (3.3))) != 0)
            378
        }
        380 -> {
            if ((b(((b((3.3) <= (f.dVar44))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar43).isNaN())) != 0)) }) != 0))) != 0) 379 else 378
        }
        381 -> {
            f.bVar2 = b((1) != 0)
            380
        }
        382 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        383 -> {
            if ((b(((b(((b((f.fVar10) <= (DAT_0012ce08))) != 0) && ((b((kotlin.math.abs(((f.param_5) - (f.param_3)))) <= (DAT_0012ce08))) != 0))) != 0) && ((b((f.fVar21) <= (DAT_0012ce08))) != 0))) != 0) 382 else 381
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep12(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        384 -> {
            f.result = f32(((f.fVar38) * (0.5)))
            C_DONE
        }
        385 -> {
            if ((b(((b(((b((f.fVar15) < (0.0))) != 0) || ((b((f.fVar13) < (0.0))) != 0))) != 0) || ((b((f.fVar14) < (0.0))) != 0))) != 0) 384 else 383
        }
        386 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        387 -> {
            if ((b(((b(((b((f.param_6) < (f.param_7))) != 0) && ((b((f.param_7) < (f.param_8))) != 0))) != 0) && ((b(((b((0.0) < (f.fVar16))) != 0) && ((b(((b((0.0) < (f.fVar17))) != 0) && ((b((0.0) < (f.fVar18))) != 0))) != 0))) != 0))) != 0) 386 else 385
        }
        388 -> {
            f.result = f32(f.fVar38)
            C_DONE
        }
        389 -> {
            if ((b(((b(((b((6.0) < (f.param_3))) != 0) && ((b((6.0) < (f.param_4))) != 0))) != 0) && ((b((6.0) < (f.param_5))) != 0))) != 0) 388 else 387
        }
        390 -> {
            if ((b(((b(((b((0.0) < (f.fVar15))) != 0) && ((b((0.0) < (f.fVar13))) != 0))) != 0) && ((b((0.0) < (f.fVar14))) != 0))) != 0) 389 else 362
        }
        391 -> {
            if ((b(((b(((b(((b((1.0) < (f.fVar38))) != 0) && ((b((f.dVar40) < (3.9))) != 0))) != 0) && ((b((f.param_20) < (48.0))) != 0))) != 0) && ((b(((b(((b((4.5) < (f.param_16))) != 0) && ((b(((b((DAT_0012ce08) < (f.dVar48))) != 0) || ((b(((b((DAT_0012ce08) < (f.dVar34))) != 0) || ((b((DAT_0012ce08) < (f.dVar30))) != 0))) != 0))) != 0))) != 0) && ((b(((b((0x240) < (f.param_14))) != 0) && ((b((3.5) < (f.fVar35))) != 0))) != 0))) != 0))) != 0) 390 else 361
        }
        392 -> {
            22
        }
        393 -> {
            21
        }
        394 -> {
            if ((b(((b((4.5) <= (f.fVar31))) != 0) && ((b((3.9) <= (((((f.dVar50) * (0.5))) + (f.dVar40))))) != 0))) != 0) 393 else 392
        }
        395 -> {
            if ((b(((b(((b((f.dVar40) < (3.9))) != 0) && ((b(((b(((b((f.dVar44) < (2.8))) != 0) && ((b((DAT_0012ce08) < (f.fVar22))) != 0))) != 0) && ((b(((b((f.param_16) < (3.5))) != 0) && ((b((7.0) < (f.param_23))) != 0))) != 0))) != 0))) != 0) && ((b(((b((3.8) < (f.fVar31))) != 0) || ((b(((b((1.5) < (f.fVar42))) != 0) && ((b((3.5) < (f.fVar31))) != 0))) != 0))) != 0))) != 0) 394 else 391
        }
        396 -> {
            f.fVar38 = f32(((f.fVar38) * (f.fVar31)))
            391
        }
        397 -> {
            f.fVar31 = f32(0.25)
            396
        }
        398 -> {
            f.fVar31 = f32(0.5)
            396
        }
        399 -> {
            if ((b(((b(((b((4.5) <= (f.fVar31))) != 0) && ((b((3.9) <= (((((f.dVar50) * (0.5))) + (f.dVar40))))) != 0))) != 0) || ((b(((b((f.dVar40) < (3.3))) != 0) && ((b((3.9) < (((((f.dVar50) * (0.5))) + (f.dVar40))))) != 0))) != 0))) != 0) 21 else 22
        }
        400 -> {
            if ((b(((b(((b(((b(((b(((b((3.9) <= (f.dVar40))) != 0) || ((b((2.8) <= (f.dVar43))) != 0))) != 0) || ((b((f.fVar11) <= (DAT_0012ce08))) != 0))) != 0) || ((b((3.5) <= (f.param_16))) != 0))) != 0) || ((b((f.param_23) <= (7.0))) != 0))) != 0) || ((b(((b((f.fVar31) <= (3.8))) != 0) && ((b(((b((f.fVar42) <= (1.5))) != 0) || ((b((f.fVar31) <= (3.5))) != 0))) != 0))) != 0))) != 0) 395 else 399
        }
        401 -> {
            f.dVar50 = f.fVar38
            400
        }
        402 -> {
            f.fVar31 = f32(((f.fVar38) + (f.param_3)))
            401
        }
        403 -> {
            f.bVar8 = 1
            20
        }
        404 -> {
            f.bVar8 = 1
            20
        }
        405 -> {
            if ((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar3) == (f.bVar7))) != 0))) != 0) 404 else 20
        }
        406 -> {
            f.bVar7 = b((0) != 0)
            405
        }
        407 -> {
            f.bVar5 = b((b((f.fVar42) == (1.0))) != 0)
            406
        }
        408 -> {
            f.bVar3 = b((b((f.fVar42) < (1.0))) != 0)
            407
        }
        409 -> {
            if ((b(!((b((f.fVar42).isNaN())) != 0))) != 0) 408 else 405
        }
        410 -> {
            f.bVar7 = b((1) != 0)
            409
        }
        411 -> {
            f.bVar5 = b((0) != 0)
            410
        }
        412 -> {
            f.bVar3 = b((0) != 0)
            411
        }
        413 -> {
            if ((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) 412 else 405
        }
        414 -> {
            f.bVar7 = b((0) != 0)
            413
        }
        415 -> {
            f.bVar5 = b((1) != 0)
            414
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep13(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        416 -> {
            f.bVar3 = b((0) != 0)
            415
        }
        417 -> {
            f.bVar6 = b((0) != 0)
            416
        }
        418 -> {
            f.bVar4 = b((b((f.param_19) == (10.0))) != 0)
            417
        }
        419 -> {
            f.bVar2 = b((b((f.param_19) < (10.0))) != 0)
            418
        }
        420 -> {
            if ((b(!((b((f.param_19).isNaN())) != 0))) != 0) 419 else 416
        }
        421 -> {
            f.bVar6 = b((1) != 0)
            420
        }
        422 -> {
            f.bVar4 = b((0) != 0)
            421
        }
        423 -> {
            f.bVar2 = b((0) != 0)
            422
        }
        424 -> {
            if ((b((6.5) < (f.param_23))) != 0) 423 else 416
        }
        425 -> {
            f.bVar6 = b((0) != 0)
            424
        }
        426 -> {
            f.bVar4 = b((1) != 0)
            425
        }
        427 -> {
            f.bVar2 = b((0) != 0)
            426
        }
        428 -> {
            if ((b(((b(((b(((b(((b((f.param_3) < (3.5))) != 0) && ((b((3.9) < (f.dVar39))) != 0))) != 0) && ((b(((b((0.7) < (f.fVar10))) != 0) || ((b((0.7) < (f.fVar19))) != 0))) != 0))) != 0) && ((b(((b((0.35) < (f.fVar37))) != 0) && ((b((f.param_20) < (48.0))) != 0))) != 0))) != 0) && ((b((6.5) < (f.param_22))) != 0))) != 0) 427 else 20
        }
        429 -> {
            20
        }
        430 -> {
            if ((b((f.bVar8) < (2))) != 0) 429 else 428
        }
        431 -> {
            19
        }
        432 -> {
            if ((b(((b(((b((2.5) < (f.param_3))) != 0) && ((b((DAT_0012ce30) < (f.dVar26))) != 0))) != 0) && ((b((6.0) < (f.param_23))) != 0))) != 0) 431 else 428
        }
        433 -> {
            if ((b(((b(((b(((b((f.param_16) <= (4.0))) != 0) || ((b((f.bVar8) < (2))) != 0))) != 0) || ((b(((b((DAT_0012cde0) <= (f.dVar40))) != 0) && ((b(((b((DAT_0012cde0) <= (f.dVar43))) != 0) && ((b((DAT_0012cde0) <= (f.dVar44))) != 0))) != 0))) != 0))) != 0) || ((b(((b(((b((f.fVar10) <= (DAT_0012ce08))) != 0) && ((b((f.fVar19) <= (DAT_0012ce08))) != 0))) != 0) || ((b(((b((DAT_0012cdf0) <= (f.fVar37))) != 0) || ((b((f.param_20) <= (60.0))) != 0))) != 0))) != 0))) != 0) 430 else 432
        }
        434 -> {
            if ((b(((b(((b(((b((f.dVar40) < (3.9))) != 0) && ((b((1) < (f.bVar8))) != 0))) != 0) && ((b(((b(((b((0.7) < (f.fVar11))) != 0) && ((b(((b(((b((f.param_4) < (2.5))) != 0) && ((b((0.7) < (f.fVar32))) != 0))) != 0) && ((b((f.dVar39) < (DAT_0012cdf8))) != 0))) != 0))) != 0) || ((b(((b(((b((0.7) < (f.fVar12))) != 0) && ((b((f.param_5) < (2.5))) != 0))) != 0) && ((b((0.7) < (f.fVar22))) != 0))) != 0))) != 0))) != 0) || ((b(((b(((b((f.param_3) < (3.0))) != 0) && ((b((1) < (f.bVar8))) != 0))) != 0) && ((b(((b((DAT_0012ce08) < (f.fVar20))) != 0) && ((b(((b(((b((f.param_4) < (2.5))) != 0) && ((b((DAT_0012ce08) < (((f.param_5) - (f.param_3))))) != 0))) != 0) && ((b((f.fVar21) < (0.7))) != 0))) != 0))) != 0))) != 0))) != 0) 19 else 433
        }
        435 -> {
            f.bVar8 = ((f.bVar8) + (b(((b((f.fVar42) < (1.0))) != 0) && ((b(((b((f.dVar39) < (3.3))) != 0) && ((b(((b((60.0) < (f.param_20))) != 0) && ((b((f.param_21) < (12.0))) != 0))) != 0))) != 0))))
            434
        }
        436 -> {
            f.bVar8 = 0
            18
        }
        437 -> {
            f.bVar8 = 0
            18
        }
        438 -> {
            if ((b(!((f.bVar2) != 0))) != 0) 437 else 18
        }
        439 -> {
            f.bVar2 = b((b((f.fVar37) < (0.25))) != 0)
            438
        }
        440 -> {
            if ((b(((b((f.param_19) < (9.0))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar37).isNaN())) != 0)) }) != 0))) != 0) 439 else 438
        }
        441 -> {
            f.bVar2 = b((0) != 0)
            440
        }
        442 -> {
            if ((b(((b(((b((DAT_0012ce20) < (f.dVar39))) != 0) && ((b(((b(((b((f.dVar39) < (DAT_0012cdf8))) != 0) && ((b((4.0) < (f.fVar35))) != 0))) != 0) && ((b(((b(((b((f.param_3) < (2.5))) != 0) || ((b((f.param_4) < (2.5))) != 0))) != 0) || ((b((f.param_5) < (2.5))) != 0))) != 0))) != 0))) != 0) && ((b(((b(((b((60.0) < (f.param_20))) != 0) && ((b((f.fVar42) < (1.2))) != 0))) != 0) && ((b((6.3) < (f.dVar28))) != 0))) != 0))) != 0) 441 else 18
        }
        443 -> {
            f.bVar8 = f.bVar9
            442
        }
        444 -> {
            17
        }
        445 -> {
            if ((b(((b(((b((f.param_16) < (3.0))) != 0) && ((b((f.dVar39) < (2.8))) != 0))) != 0) && ((b((1.2) < (f.fVar42))) != 0))) != 0) 444 else 443
        }
        446 -> {
            18
        }
        447 -> {
            if ((b(((b((f.dVar40) < (2.8))) != 0) || ((b((f.dVar43) < (2.8))) != 0))) != 0) 446 else 443
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep14(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        448 -> {
            f.bVar8 = 0
            447
        }
        449 -> {
            if ((b((f.param_16) < (3.0))) != 0) 17 else 443
        }
        450 -> {
            if ((b((f.fVar42) <= (1.5))) != 0) 445 else 449
        }
        451 -> {
            if ((b(((b(((b((60.0) < (f.param_20))) != 0) && ((b((6.5) < (f.param_22))) != 0))) != 0) && ((b((f.param_30) < (48.0))) != 0))) != 0) 450 else 443
        }
        452 -> {
            if ((b(((b(((b((f.param_4) < (2.5))) != 0) && ((b((((kotlin.math.abs(((f.param_3) - (f.param_5)))) + (DAT_0012ce28))) < (f.fVar19))) != 0))) != 0) || ((b(((b(((b((f.param_5) < (2.5))) != 0) && ((b((((f.fVar10) + (DAT_0012ce28))) < (f.fVar21))) != 0))) != 0) || ((b(((b((f.param_3) < (2.5))) != 0) && ((b((((f.fVar19) + (DAT_0012ce28))) < (kotlin.math.abs(((f.param_3) - (f.param_4)))))) != 0))) != 0))) != 0))) != 0) 436 else 451
        }
        453 -> {
            if ((b((1) < (f.bVar9))) != 0) 452 else 18
        }
        454 -> {
            f.bVar8 = f.bVar9
            453
        }
        455 -> {
            f.bVar9 = ((f.bVar9) + (1))
            454
        }
        456 -> {
            if ((b(((b(((b(((b(((b((f.param_5) < (3.5))) != 0) && ((b((0.3) < (f.dVar48))) != 0))) != 0) && ((b(((b((f.fVar42) <= (1.5))) != 0) || ((b(((b(((b((f.param_16) <= (2.5))) != 0) || ((b((2.8) <= (f.dVar44))) != 0))) != 0) || ((b((f.param_30) <= (60.0))) != 0))) != 0))) != 0))) != 0) && ((b(((b((f.dVar26) <= (DAT_0012cd18))) != 0) || ((b(((b(((b(((b((3.0) <= (f.param_16))) != 0) || ((b((f.dVar28) <= (DAT_0012cd18))) != 0))) != 0) || ((b(((b((2.8) <= (f.dVar40))) != 0) || ((b((f.param_30) <= (60.0))) != 0))) != 0))) != 0) && ((b(((b(((b(((b(((b((DAT_0012ce00) <= (f.param_16))) != 0) || ((b((f.dVar28) <= (DAT_0012cd18))) != 0))) != 0) || ((b((2.4) <= (f.dVar44))) != 0))) != 0) || ((b((72.0) <= (f.param_20))) != 0))) != 0) || ((b(((b((f.param_30) <= (60.0))) != 0) && ((b(((b((DAT_0012ce18) <= (f.dVar44))) != 0) || ((b((f.param_22) <= (7.0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) && ((b(((b(((b((f.param_16) <= (3.3))) != 0) || ((b((f.param_23) <= (9.0))) != 0))) != 0) && ((b(((b(((b(((b(((b((f.param_16) <= (DAT_0012ce00))) != 0) || ((b((f.param_20) <= (54.0))) != 0))) != 0) || ((b((1.2) <= (f.fVar42))) != 0))) != 0) || ((b(((b((f.param_23) <= (7.0))) != 0) || ((b((DAT_0012ce20) <= (f.dVar44))) != 0))) != 0))) != 0) || ((b((f.param_30) <= (56.0))) != 0))) != 0))) != 0))) != 0) 455 else 454
        }
        457 -> {
            f.dVar48 = f.fVar15
            456
        }
        458 -> {
            f.bVar9 = ((f.bVar9) + (1))
            457
        }
        459 -> {
            if ((b(((b(((b(((b(((b((f.param_4) < (3.5))) != 0) && ((b((0.3) < (f.dVar30))) != 0))) != 0) && ((b(((b((f.fVar42) <= (1.5))) != 0) || ((b(((b(((b((f.param_16) <= (2.5))) != 0) || ((b((2.8) <= (f.dVar43))) != 0))) != 0) || ((b((f.param_30) <= (60.0))) != 0))) != 0))) != 0))) != 0) && ((b(((b((f.dVar26) <= (DAT_0012cd18))) != 0) || ((b(((b(((b(((b((3.0) < (f.param_16))) != 0) || ((b((f.dVar28) <= (DAT_0012cd18))) != 0))) != 0) || ((b(((b((2.8) <= (f.dVar40))) != 0) || ((b((f.param_30) <= (60.0))) != 0))) != 0))) != 0) && ((b(((b(((b((f.dVar28) <= (DAT_0012cd18))) != 0) || ((b((f.param_16) <= (3.0))) != 0))) != 0) || ((b(((b((DAT_0012ce00) <= (f.param_16))) != 0) || ((b(((b(((b((2.4) <= (f.dVar43))) != 0) || ((b((72.0) <= (f.param_20))) != 0))) != 0) || ((b(((b((f.param_30) <= (60.0))) != 0) && ((b(((b((DAT_0012ce18) <= (f.dVar43))) != 0) || ((b((f.param_22) <= (7.0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) && ((b(((b(((b((f.param_16) <= (3.3))) != 0) || ((b((f.param_23) <= (9.0))) != 0))) != 0) && ((b(((b(((b(((b(((b((f.param_16) <= (DAT_0012ce00))) != 0) || ((b((f.param_20) <= (54.0))) != 0))) != 0) || ((b((1.2) <= (f.fVar42))) != 0))) != 0) || ((b(((b((f.param_23) <= (7.0))) != 0) || ((b((DAT_0012ce20) <= (f.dVar43))) != 0))) != 0))) != 0) || ((b((f.param_30) <= (56.0))) != 0))) != 0))) != 0))) != 0) 458 else 457
        }
        460 -> {
            f.dVar30 = f.fVar14
            459
        }
        461 -> {
            f.bVar9 = 0
            460
        }
        462 -> {
            f.bVar9 = 1
            460
        }
        463 -> {
            if ((b(((b(((b(((b(((b((1.5) < (f.fVar42))) != 0) && ((b(((b(((b((2.5) < (f.param_16))) != 0) && ((b((f.dVar40) < (2.8))) != 0))) != 0) && ((b((60.0) < (f.param_30))) != 0))) != 0))) != 0) || ((b(((b((DAT_0012cd18) < (f.dVar26))) != 0) && ((b(((b(((b(((b((f.param_16) <= (3.0))) != 0) && ((b((DAT_0012cd18) < (f.dVar28))) != 0))) != 0) && ((b(((b((f.dVar40) < (2.8))) != 0) && ((b((60.0) < (f.param_30))) != 0))) != 0))) != 0) || ((b(((b(((b((DAT_0012cd18) < (f.dVar28))) != 0) && ((b((3.0) < (f.param_16))) != 0))) != 0) && ((b(((b((f.param_16) < (DAT_0012ce00))) != 0) && ((b(((b(((b((f.dVar40) < (2.4))) != 0) && ((b((f.param_20) < (72.0))) != 0))) != 0) && ((b(((b((60.0) < (f.param_30))) != 0) || ((b(((b((f.dVar40) < (DAT_0012ce18))) != 0) && ((b((7.0) < (f.param_22))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) || ((b(((b((3.3) < (f.param_16))) != 0) && ((b((9.0) < (f.param_23))) != 0))) != 0))) != 0) || ((b(((b(((b(((b(((b((DAT_0012ce00) < (f.param_16))) != 0) && ((b((54.0) < (f.param_20))) != 0))) != 0) && ((b((f.fVar42) < (1.2))) != 0))) != 0) && ((b(((b((7.0) < (f.param_23))) != 0) && ((b((f.dVar40) < (DAT_0012ce20))) != 0))) != 0))) != 0) && ((b((56.0) < (f.param_30))) != 0))) != 0))) != 0) 461 else 462
        }
        464 -> {
            if ((b(((b((f.param_3) < (3.5))) != 0) && ((b((0.3) < (f.dVar34))) != 0))) != 0) 463 else 460
        }
        465 -> {
            f.dVar28 = f.param_23
            464
        }
        466 -> {
            f.dVar34 = f.fVar13
            465
        }
        467 -> {
            f.dVar26 = f.param_22
            466
        }
        468 -> {
            f.bVar9 = 0
            467
        }
        469 -> {
            f.fVar38 = f32(((f.fVar35) - (f.param_16)))
            16
        }
        470 -> {
            if ((b((f.param_16) < (f.fVar47))) != 0) 469 else 16
        }
        471 -> {
            f.fVar38 = f32(f.fVar31)
            470
        }
        472 -> {
            6
        }
        473 -> {
            if ((b(((b((f.fVar27) < (0.5))) != 0) && ((b((DAT_0012cc40) < (f.fVar13))) != 0))) != 0) 472 else 5
        }
        474 -> {
            f.fVar47 = f32(f.param_3)
            473
        }
        475 -> {
            f.fVar31 = f32(f.fVar47)
            474
        }
        476 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            16
        }
        477 -> {
            f.fVar38 = f32(((((f.fVar35) - (f.param_16))) * (0.5)))
            16
        }
        478 -> {
            if ((b((f.param_4) <= (f.param_16))) != 0) 476 else 477
        }
        479 -> {
            5
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep15(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        480 -> {
            if ((b(((b((f.fVar11) <= (0.5))) != 0) || ((b((0x35f) < (f.param_14))) != 0))) != 0) 479 else 478
        }
        481 -> {
            f.fVar47 = f32(f.param_4)
            480
        }
        482 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.fVar29))) - (f.param_16))) * (0.5)))
            16
        }
        483 -> {
            if ((b(((b((0.5) <= (f.fVar27))) != 0) || ((run { run { f.fVar29 = f32(f.param_4); f32(f.param_4) }; b((f.fVar14) <= (DAT_0012cc40)) }) != 0))) != 0) 481 else 6
        }
        484 -> {
            if ((b((f.param_3) <= (f.param_4))) != 0) 475 else 483
        }
        485 -> {
            if ((b(((b(((b((f.fVar46) < (0.5))) != 0) && ((b((1.0) < (f.param_4))) != 0))) != 0) && ((b((0.5) <= (f.fVar41))) != 0))) != 0) 484 else 16
        }
        486 -> {
            7
        }
        487 -> {
            if ((b((f.param_2) < (f.fVar35))) != 0) 486 else 16
        }
        488 -> {
            f.fVar31 = f32(f.param_3)
            487
        }
        489 -> {
            f.fVar47 = f32(f.param_2)
            488
        }
        490 -> {
            f.fVar38 = f32(((((((f.fVar31) - (f.param_16))) - (f.param_2))) / (3.0)))
            16
        }
        491 -> {
            14
        }
        492 -> {
            f.fVar31 = f32(((f.fVar31) - (f.param_2)))
            491
        }
        493 -> {
            if ((b((f.param_3) < (f.fVar35))) != 0) 492 else 490
        }
        494 -> {
            f.fVar31 = f32(((((f.fVar35) * (3.0))) - (f.param_3)))
            493
        }
        495 -> {
            6
        }
        496 -> {
            if ((b((f.fVar35) <= (f.param_2))) != 0) 495 else 494
        }
        497 -> {
            if ((b(((b((f.param_16) <= (1.0))) != 0) || ((b((0.5) <= (f.fVar27))) != 0))) != 0) 489 else 496
        }
        498 -> {
            if ((b(((b(((b((0.5) <= (f.fVar23))) != 0) || ((b((f.param_3) <= (1.0))) != 0))) != 0) || ((b((f.fVar33) < (0.5))) != 0))) != 0) 485 else 497
        }
        499 -> {
            f.fVar29 = f32(f.param_3)
            498
        }
        500 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.fVar31))) - (f.fVar47))) * (0.5)))
            16
        }
        501 -> {
            if ((b((((f.param_11) - (f.fVar35))) < (0.5))) != 0) 7 else 16
        }
        502 -> {
            f.fVar31 = f32(f.param_11)
            501
        }
        503 -> {
            f.fVar47 = f32(f.param_8)
            502
        }
        504 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        505 -> {
            if ((b((b((f.iVar1) < (0))) == (f.bVar2))) != 0) 504 else 16
        }
        506 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            505
        }
        507 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            8
        }
        508 -> {
            f.iVar1 = ((f.param_14) + (-(0x360)))
            507
        }
        509 -> {
            f.bVar2 = b((b(sBorrow4(f.param_14, 0x360))) != 0)
            508
        }
        510 -> {
            if ((b(((b((f.param_13) <= (f.fVar49))) != 0) || ((b((0.5) <= (((f.param_5) - (f.fVar35))))) != 0))) != 0) 503 else 509
        }
        511 -> {
            if ((b(((b(((b((f.param_3) <= (f.param_5))) != 0) || ((b((f.param_4) <= (f.param_5))) != 0))) != 0) || ((b((0.5) <= (f.fVar29))) != 0))) != 0) 499 else 510
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep16(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        512 -> {
            f.fVar38 = f32(((f.fVar35) - (f.param_7)))
            16
        }
        513 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        514 -> {
            if ((b((0x35f) < (f.param_14))) != 0) 513 else 16
        }
        515 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            514
        }
        516 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_10))) - (f.param_7))) * (0.5)))
            515
        }
        517 -> {
            if ((b((0.5) <= (f.fVar36))) != 0) 512 else 516
        }
        518 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        519 -> {
            if ((b(((f.bVar4) != 0) || ((b((f.bVar2) != (f.bVar6))) != 0))) != 0) 518 else 16
        }
        520 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            519
        }
        521 -> {
            f.bVar6 = b((0) != 0)
            520
        }
        522 -> {
            f.bVar4 = b((b((f.fVar11) == (0.5))) != 0)
            521
        }
        523 -> {
            f.bVar2 = b((b((f.fVar11) < (0.5))) != 0)
            522
        }
        524 -> {
            if ((b(!((b((f.fVar11).isNaN())) != 0))) != 0) 523 else 520
        }
        525 -> {
            f.bVar6 = b((1) != 0)
            524
        }
        526 -> {
            f.bVar4 = b((0) != 0)
            525
        }
        527 -> {
            f.bVar2 = b((0) != 0)
            526
        }
        528 -> {
            if ((b((f.param_14) < (0x360))) != 0) 527 else 520
        }
        529 -> {
            f.bVar6 = b((0) != 0)
            528
        }
        530 -> {
            f.bVar4 = b((1) != 0)
            529
        }
        531 -> {
            f.bVar2 = b((0) != 0)
            530
        }
        532 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_7))) - (f.param_4))) * (0.5)))
            531
        }
        533 -> {
            if ((b((f.param_13) <= (f.fVar45))) != 0) 517 else 532
        }
        534 -> {
            f.fVar38 = f32(((((f.fVar31) - (f.param_16))) / (3.0)))
            16
        }
        535 -> {
            f.fVar31 = f32(((((((f.fVar35) * (3.0))) - (f.param_10))) - (f.param_7)))
            534
        }
        536 -> {
            9
        }
        537 -> {
            f.fVar31 = f32(((((f.fVar25) - (f.param_7))) - (f.param_16)))
            536
        }
        538 -> {
            if ((b((0.5) <= (f.fVar36))) != 0) 537 else 535
        }
        539 -> {
            f.fVar31 = f32(((((((f.fVar35) * (3.0))) - (f.param_7))) - (f.param_4)))
            534
        }
        540 -> {
            16
        }
        541 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            540
        }
        542 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_7))) - (f.param_4))) * (0.5)))
            9
        }
        543 -> {
            if ((b((f.param_14) < (0x360))) != 0) 542 else 10
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep17(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        544 -> {
            if ((b((f.param_13) <= (f.fVar45))) != 0) 538 else 543
        }
        545 -> {
            if ((b(((b((f.param_4) <= (f.param_16))) != 0) || ((b((f.param_16) <= (1.0))) != 0))) != 0) 533 else 544
        }
        546 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        547 -> {
            if ((b((0x47f) < (f.param_14))) != 0) 546 else 16
        }
        548 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            547
        }
        549 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            548
        }
        550 -> {
            if ((b(((b(((b(((b((f.param_4) <= (f.param_5))) != 0) || ((b((f.param_13) <= (f.fVar49))) != 0))) != 0) || ((b((f.param_7) <= (f.param_8))) != 0))) != 0) || ((b((0.5) <= (f.fVar29))) != 0))) != 0) 545 else 549
        }
        551 -> {
            if ((b(((b(((b((f.param_3) <= (f.param_4))) != 0) || ((b((0.5) <= (f.fVar41))) != 0))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0) 511 else 550
        }
        552 -> {
            f.fVar38 = f32(((f.fVar35) - (f.param_6)))
            16
        }
        553 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_6))) - (f.param_2))) * (0.5)))
            16
        }
        554 -> {
            11
        }
        555 -> {
            if ((b((0.5) < (f.fVar11))) != 0) 554 else 16
        }
        556 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_3))) - (f.param_2))) * (0.5)))
            555
        }
        557 -> {
            if ((b((f.fVar35) <= (f.param_3))) != 0) 553 else 556
        }
        558 -> {
            if ((b((f.fVar35) <= (f.param_2))) != 0) 552 else 557
        }
        559 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        560 -> {
            if ((b((0x35f) < (f.param_14))) != 0) 559 else 16
        }
        561 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            560
        }
        562 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_6))) - (f.param_16))) * (0.5)))
            561
        }
        563 -> {
            f.fVar31 = f32(((((((((((f.fVar35) * (3.0))) - (f.param_6))) - (f.param_16))) - (f.param_2))) / (3.0)))
            561
        }
        564 -> {
            16
        }
        565 -> {
            f.fVar38 = f32(f.fVar31)
            564
        }
        566 -> {
            if ((b(((b((f.param_3) <= (f.param_16))) != 0) || ((b((0x35f) < (f.param_14))) != 0))) != 0) 565 else 564
        }
        567 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            566
        }
        568 -> {
            f.fVar31 = f32(((((((((((f.fVar35) * (3.0))) - (f.param_3))) - (f.param_2))) - (f.param_16))) / (3.0)))
            567
        }
        569 -> {
            if ((b((f.param_3) < (f.fVar35))) != 0) 568 else 563
        }
        570 -> {
            if ((b((f.fVar35) <= (f.param_2))) != 0) 562 else 569
        }
        571 -> {
            if ((b(((b(((b((0.5) <= (f.fVar27))) != 0) || ((b((f.param_16) <= (1.0))) != 0))) != 0) || ((b((f.param_13) <= (f.fVar37))) != 0))) != 0) 558 else 570
        }
        572 -> {
            f.fVar38 = f32(((f.fVar38) * (0.5)))
            16
        }
        573 -> {
            if ((b((DAT_0012ce08) < (f.fVar22))) != 0) 11 else 16
        }
        574 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            573
        }
        575 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            16
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep18(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        576 -> {
            if ((b((f.param_14) < (0x480))) != 0) 574 else 575
        }
        577 -> {
            if ((b(((b(((b((0.5) <= (((f.param_5) - (f.fVar35))))) != 0) || ((b((f.param_13) <= (f.fVar49))) != 0))) != 0) || ((b(((b((f.param_6) <= (f.param_8))) != 0) || ((b((0.5) <= (f.fVar29))) != 0))) != 0))) != 0) 571 else 576
        }
        578 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        579 -> {
            if ((b(((f.bVar4) != 0) || ((b((f.bVar2) != (f.bVar6))) != 0))) != 0) 578 else 16
        }
        580 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            579
        }
        581 -> {
            f.bVar6 = b((0) != 0)
            580
        }
        582 -> {
            f.bVar4 = b((b((f.fVar11) == (0.5))) != 0)
            581
        }
        583 -> {
            f.bVar2 = b((b((f.fVar11) < (0.5))) != 0)
            582
        }
        584 -> {
            if ((b(!((b((f.fVar11).isNaN())) != 0))) != 0) 583 else 580
        }
        585 -> {
            f.bVar6 = b((1) != 0)
            584
        }
        586 -> {
            f.bVar4 = b((0) != 0)
            585
        }
        587 -> {
            f.bVar2 = b((0) != 0)
            586
        }
        588 -> {
            if ((b((f.param_14) < (0x480))) != 0) 587 else 580
        }
        589 -> {
            f.bVar6 = b((0) != 0)
            588
        }
        590 -> {
            f.bVar4 = b((1) != 0)
            589
        }
        591 -> {
            f.bVar2 = b((0) != 0)
            590
        }
        592 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_7))) - (f.param_4))) * (0.5)))
            591
        }
        593 -> {
            if ((b(((b(((b((f.param_6) <= (f.param_7))) != 0) || ((b(((b(((b((0.5) <= (f.fVar46))) != 0) || ((b((f.param_13) <= (f.fVar45))) != 0))) != 0) || ((b((f.param_8) <= (f.param_7))) != 0))) != 0))) != 0) || ((b((0.5) <= (f.fVar41))) != 0))) != 0) 577 else 592
        }
        594 -> {
            f.fVar38 = f32(((f.fVar47) * (0.5)))
            16
        }
        595 -> {
            12
        }
        596 -> {
            if ((b(((b((f.fVar33) <= (0.0))) != 0) || ((b((0.0) <= (f.fVar23))) != 0))) != 0) 595 else 594
        }
        597 -> {
            8
        }
        598 -> {
            f.iVar1 = ((f.param_14) + (-(0x480)))
            597
        }
        599 -> {
            f.bVar2 = b((b(sBorrow4(f.param_14, 0x480))) != 0)
            598
        }
        600 -> {
            f.fVar31 = f32(((((((((((f.fVar35) * (3.0))) - (f.param_16))) - (f.param_6))) - (f.param_3))) / (3.0)))
            599
        }
        601 -> {
            if ((b(((b((f.param_16) < (f.param_3))) != 0) && ((b((1.0) < (f.param_16))) != 0))) != 0) 600 else 596
        }
        602 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        603 -> {
            if ((b(((f.bVar4) != 0) || ((b((f.bVar2) != (f.bVar6))) != 0))) != 0) 602 else 16
        }
        604 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            603
        }
        605 -> {
            f.bVar6 = b((0) != 0)
            604
        }
        606 -> {
            f.bVar4 = b((b((f.fVar22) == (0.5))) != 0)
            605
        }
        607 -> {
            f.bVar2 = b((b((f.fVar22) < (0.5))) != 0)
            606
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep19(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        608 -> {
            if ((b(!((b((f.fVar22).isNaN())) != 0))) != 0) 607 else 604
        }
        609 -> {
            f.bVar6 = b((1) != 0)
            608
        }
        610 -> {
            f.bVar4 = b((0) != 0)
            609
        }
        611 -> {
            f.bVar2 = b((0) != 0)
            610
        }
        612 -> {
            if ((b((f.param_14) < (0x480))) != 0) 611 else 604
        }
        613 -> {
            f.bVar6 = b((0) != 0)
            612
        }
        614 -> {
            f.bVar4 = b((1) != 0)
            613
        }
        615 -> {
            f.bVar2 = b((0) != 0)
            614
        }
        616 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            615
        }
        617 -> {
            if ((b(((b((f.param_16) <= (f.param_5))) != 0) || ((b(((b(((b((f.param_13) <= (f.fVar49))) != 0) || ((b((f.param_3) <= (f.param_5))) != 0))) != 0) || ((b((0.5) <= (f.fVar29))) != 0))) != 0))) != 0) 601 else 616
        }
        618 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_6))) - (f.param_3))) * (0.5)))
            16
        }
        619 -> {
            13
        }
        620 -> {
            f.fVar31 = f32(((((((f.fVar35) * (3.0))) - (f.param_6))) - (f.param_3)))
            619
        }
        621 -> {
            if ((b(((b((f.param_16) < (f.param_3))) != 0) && ((b((1.0) < (f.param_16))) != 0))) != 0) 620 else 12
        }
        622 -> {
            f.fVar38 = f32(((f.fVar38) * (0.5)))
            16
        }
        623 -> {
            if ((b((0.5) <= (((f.param_6) - (f.param_8))))) != 0) 622 else 16
        }
        624 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            623
        }
        625 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_8))) - (f.param_5))) * (0.5)))
            16
        }
        626 -> {
            if ((b((f.param_14) < (0x480))) != 0) 624 else 625
        }
        627 -> {
            f.fVar38 = f32(f.fVar31)
            16
        }
        628 -> {
            if ((b((0x47f) < (f.param_14))) != 0) 627 else 16
        }
        629 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            628
        }
        630 -> {
            f.fVar31 = f32(((((f.fVar31) - (f.param_16))) / (3.0)))
            629
        }
        631 -> {
            f.fVar31 = f32(((((((f.fVar35) * (3.0))) - (f.param_8))) - (f.param_5)))
            13
        }
        632 -> {
            if ((b(((b((f.param_5) <= (f.param_16))) != 0) || ((b((f.param_16) <= (1.0))) != 0))) != 0) 626 else 631
        }
        633 -> {
            if ((b(((b((f.param_13) <= (f.fVar49))) != 0) || ((b(((b((f.param_4) <= (f.param_5))) != 0) || ((b((0.5) <= (f.fVar29))) != 0))) != 0))) != 0) 621 else 632
        }
        634 -> {
            f.fVar38 = f32(((f.fVar38) * (0.6)))
            16
        }
        635 -> {
            if ((b((f.param_14) < (0x360))) != 0) 634 else 16
        }
        636 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_10))) - (f.param_7))) * (0.5)))
            635
        }
        637 -> {
            f.fVar38 = f32(((((((f.fVar25) - (f.param_6))) - (f.param_3))) * (0.5)))
            16
        }
        638 -> {
            f.fVar38 = f32(((((f.fVar31) - (f.param_16))) / (3.0)))
            16
        }
        639 -> {
            f.fVar31 = f32(((((((f.fVar35) * (3.0))) - (f.param_6))) - (f.param_3)))
            14
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep20(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        640 -> {
            if ((b(((b((f.param_3) <= (f.param_16))) != 0) || ((b((f.param_16) <= (0.0))) != 0))) != 0) 637 else 639
        }
        641 -> {
            if ((b((f.fVar36) < (0.5))) != 0) 636 else 640
        }
        642 -> {
            f.fVar38 = f32(((f.fVar31) * (0.5)))
            16
        }
        643 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_7))) - (f.param_4))) * (0.5)))
            642
        }
        644 -> {
            f.fVar31 = f32(((((((((((f.fVar35) * (3.0))) - (f.param_7))) - (f.param_4))) - (f.param_16))) / (3.0)))
            642
        }
        645 -> {
            if ((b(((b((f.param_4) <= (f.param_16))) != 0) || ((b((f.param_16) <= (1.0))) != 0))) != 0) 643 else 644
        }
        646 -> {
            15
        }
        647 -> {
            if ((b((((f.param_6) - (f.param_7))) <= (DAT_0012ccb0))) != 0) 646 else 645
        }
        648 -> {
            16
        }
        649 -> {
            f.fVar38 = f32(((f.fVar31) * (0.75)))
            648
        }
        650 -> {
            if ((b((f.fVar11) < (DAT_0012ce08))) != 0) 649 else 642
        }
        651 -> {
            f.fVar31 = f32(((((((f.fVar25) - (f.param_7))) - (f.param_4))) * (0.5)))
            650
        }
        652 -> {
            if ((b((((f.param_6) - (f.param_7))) <= (DAT_0012cc98))) != 0) 647 else 651
        }
        653 -> {
            f.fVar31 = f32(((((f.fVar25) - (f.param_7))) - (f.param_4)))
            642
        }
        654 -> {
            10
        }
        655 -> {
            if ((b(((b((f.param_16) < (f.param_4))) != 0) && ((b((1.0) < (f.param_16))) != 0))) != 0) 654 else 653
        }
        656 -> {
            if ((b((f.param_14) < (0x360))) != 0) 652 else 15
        }
        657 -> {
            if ((b(((b((f.param_13) <= (f.fVar45))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0) 641 else 656
        }
        658 -> {
            if ((b(((b((f.param_5) <= (f.param_4))) != 0) || ((b((f.param_6) <= (f.param_7))) != 0))) != 0) 633 else 657
        }
        659 -> {
            if ((b(((b((0.5) <= (f.fVar41))) != 0) || ((b(((b((f.param_3) <= (f.param_4))) != 0) && ((b((f.param_6) <= (f.param_7))) != 0))) != 0))) != 0) 617 else 658
        }
        660 -> {
            if ((b(((b((f.param_13) <= (((f.param_6) - (f.param_3))))) != 0) || ((b((0.5) <= (f.fVar23))) != 0))) != 0) 593 else 659
        }
        661 -> {
            if ((b((0.5) <= (f.fVar33))) != 0) 551 else 660
        }
        662 -> {
            f.fVar36 = f32(((f.param_10) - (f.fVar35)))
            661
        }
        663 -> {
            f.fVar25 = f32(((f.fVar35) + (f.fVar35)))
            662
        }
        664 -> {
            f.fVar49 = f32(((f.param_8) - (f.param_5)))
            663
        }
        665 -> {
            f.fVar29 = f32(((f.param_8) - (f.fVar35)))
            664
        }
        666 -> {
            f.fVar46 = f32(((f.param_4) - (f.fVar35)))
            665
        }
        667 -> {
            f.fVar45 = f32(((f.param_7) - (f.param_4)))
            666
        }
        668 -> {
            f.fVar41 = f32(((f.param_7) - (f.fVar35)))
            667
        }
        669 -> {
            f.fVar23 = f32(((f.param_3) - (f.fVar35)))
            668
        }
        670 -> {
            f.fVar33 = f32(((f.param_6) - (f.fVar35)))
            669
        }
        671 -> {
            16
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep21(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        672 -> {
            if ((b(((b(((b((5.5) < (f.fVar35))) != 0) && ((b(((b((1.5) < (((f.fVar35) - (f.param_5))))) != 0) || ((b(((b((1.5) < (f.fVar47))) != 0) || ((b((1.5) < (f.fVar31))) != 0))) != 0))) != 0))) != 0) || ((run { run { f.fVar27 = f32(((f.param_16) - (f.fVar35))); f32(((f.param_16) - (f.fVar35))) }; b(((b((f.param_16) < (0.0))) != 0) && ((b((2.0) < (f.fVar27))) != 0)) }) != 0))) != 0) 671 else 670
        }
        673 -> {
            f.fVar38 = f32(0.0)
            672
        }
        674 -> {
            f.fVar22 = f32(((f.param_3) - (f.param_5)))
            673
        }
        675 -> {
            f.fVar31 = f32(((f.fVar35) - (f.param_4)))
            674
        }
        676 -> {
            f.fVar47 = f32(((f.fVar35) - (f.param_3)))
            675
        }
        677 -> {
            4
        }
        678 -> {
            f.bVar3 = b((b((f.param_30) < (48.0))) != 0)
            677
        }
        679 -> {
            if ((b(((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) && ((run { run { f.bVar3 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_30).isNaN())) != 0)) }) != 0))) != 0) 678 else 677
        }
        680 -> {
            f.bVar3 = b((0) != 0)
            679
        }
        681 -> {
            f.fVar38 = f32(3.2)
            680
        }
        682 -> {
            f.bVar6 = b((0) != 0)
            681
        }
        683 -> {
            f.bVar4 = b((b((f.param_22) == (9.0))) != 0)
            682
        }
        684 -> {
            f.bVar2 = b((b((f.param_22) < (9.0))) != 0)
            683
        }
        685 -> {
            if ((b(!((b((f.param_22).isNaN())) != 0))) != 0) 684 else 681
        }
        686 -> {
            f.bVar6 = b((1) != 0)
            685
        }
        687 -> {
            f.bVar4 = b((0) != 0)
            686
        }
        688 -> {
            f.bVar2 = b((0) != 0)
            687
        }
        689 -> {
            if ((b((f.param_23) <= (9.0))) != 0) 688 else 681
        }
        690 -> {
            f.bVar6 = b((0) != 0)
            689
        }
        691 -> {
            f.bVar4 = b((0) != 0)
            690
        }
        692 -> {
            f.bVar2 = b((0) != 0)
            691
        }
        693 -> {
            if ((b(((b(((b((42.0) < (f.param_20))) != 0) && ((b((f.dVar26) < (2.8))) != 0))) != 0) && ((b(((b(((b((f.param_16) <= (2.5))) != 0) || ((b(((b((f.fVar42) <= (2.0))) != 0) || ((b(((b((f.param_22) <= (9.0))) != 0) && ((b((f.param_23) <= (9.0))) != 0))) != 0))) != 0))) != 0) && ((b(((b((f.dVar39) <= (DAT_0012ce18))) != 0) || ((b(((b(((b(((b((3.0) <= (f.param_16))) != 0) || ((b((48.0) <= (f.param_20))) != 0))) != 0) || ((b((f.param_22) <= (10.0))) != 0))) != 0) || ((b((f.param_23) <= (10.0))) != 0))) != 0))) != 0))) != 0))) != 0) 692 else 676
        }
        694 -> {
            f.fVar35 = f32(f.fVar31)
            693
        }
        695 -> {
            f.fVar35 = f32(3.2)
            676
        }
        696 -> {
            f.fVar35 = f32(3.0)
            676
        }
        697 -> {
            if ((b(!((f.bVar2) != 0))) != 0) 696 else 676
        }
        698 -> {
            f.fVar35 = f32(3.2)
            697
        }
        699 -> {
            f.bVar2 = b((b((f.dVar39) < (DAT_0012ce10))) != 0)
            698
        }
        700 -> {
            if ((b(((b((3.9) <= (f.param_18))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar39).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce10).isNaN())) != 0))) != 0)) }) != 0))) != 0) 699 else 698
        }
        701 -> {
            f.bVar2 = b((1) != 0)
            700
        }
        702 -> {
            f.fVar35 = f32(2.7)
            676
        }
        703 -> {
            if ((b(((b(((b(((b((f.dVar39) <= (DAT_0012ce18))) != 0) || ((b((DAT_0012cde8) <= (f.dVar39))) != 0))) != 0) || ((b((f.param_22) <= (9.0))) != 0))) != 0) || ((b(((b((f.fVar42) <= (2.0))) != 0) || ((b((f.param_23) <= (9.0))) != 0))) != 0))) != 0) 701 else 702
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep22(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        704 -> {
            f.fVar35 = f32(2.8)
            676
        }
        705 -> {
            if ((b((f.param_20) <= (42.0))) != 0) 704 else 676
        }
        706 -> {
            f.fVar35 = f32(3.0)
            705
        }
        707 -> {
            if ((b(((b((DAT_0012ce18) <= (f.dVar39))) != 0) || ((b(((b(((b((f.dVar39) <= (2.4))) != 0) || ((b((f.param_18) <= (3.9))) != 0))) != 0) && ((b(((b((f.fVar42) <= (DAT_0012cc80))) != 0) || ((b((f.param_23) <= (7.0))) != 0))) != 0))) != 0))) != 0) 703 else 706
        }
        708 -> {
            if ((b((72.0) < (f.param_20))) != 0) 695 else 707
        }
        709 -> {
            if ((b(((b(((b((f.param_20) <= (42.0))) != 0) || ((b((0x23f) < (f.param_14))) != 0))) != 0) || ((b((9.5) <= (f.param_19))) != 0))) != 0) 708 else 676
        }
        710 -> {
            if ((b(((b(((b((2.9) <= (f.dVar43))) != 0) || ((b((f.fVar31) < (3.0))) != 0))) != 0) || ((b(((b(((b(((b((DAT_0012ce10) <= (f.dVar40))) != 0) && ((b((DAT_0012ce10) <= (f.dVar44))) != 0))) != 0) || ((b(((b((DAT_0012cde8) <= (f.dVar39))) != 0) && ((b(((b((3.3) <= (f.dVar39))) != 0) || ((b((f.fVar42) <= (DAT_0012cc80))) != 0))) != 0))) != 0))) != 0) || ((b(((b((f.fVar42) <= (1.0))) != 0) || ((b((f.param_23) <= (6.5))) != 0))) != 0))) != 0))) != 0) 694 else 709
        }
        711 -> {
            if ((b(((b(((b(((b(((b((f.fVar31) <= (3.5))) != 0) || ((b(((b(((b((2.9) <= (f.dVar40))) != 0) && ((b((2.9) <= (f.dVar43))) != 0))) != 0) && ((b((2.9) <= (f.dVar44))) != 0))) != 0))) != 0) || ((b(((b(((b((f.param_19) <= (10.0))) != 0) || ((b((45.0) <= (f.param_20))) != 0))) != 0) || ((b((f.param_22) <= (7.0))) != 0))) != 0))) != 0) || ((b((f.param_23) <= (7.0))) != 0))) != 0) || ((b(((b(((b((f.fVar10) <= (DAT_0012ce08))) != 0) && ((b((kotlin.math.abs(((f.param_5) - (f.param_3)))) <= (DAT_0012ce08))) != 0))) != 0) && ((b((f.fVar21) <= (DAT_0012ce08))) != 0))) != 0))) != 0) 710 else 676
        }
        712 -> {
            f.fVar35 = f32(f.fVar38)
            676
        }
        713 -> {
            if ((b(!((f.bVar3) != 0))) != 0) 712 else 676
        }
        714 -> {
            f.fVar35 = f32(f.fVar31)
            713
        }
        715 -> {
            f.fVar38 = f32(3.5)
            4
        }
        716 -> {
            f.bVar3 = b((b((f.fVar31) < (4.5))) != 0)
            715
        }
        717 -> {
            if ((b(((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) && ((run { run { f.bVar3 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar31).isNaN())) != 0)) }) != 0))) != 0) 716 else 715
        }
        718 -> {
            f.bVar3 = b((0) != 0)
            717
        }
        719 -> {
            f.bVar6 = b((0) != 0)
            718
        }
        720 -> {
            f.bVar4 = b((b((f.param_20) == (84.0))) != 0)
            719
        }
        721 -> {
            f.bVar2 = b((b((f.param_20) < (84.0))) != 0)
            720
        }
        722 -> {
            if ((b(!((b((f.param_20).isNaN())) != 0))) != 0) 721 else 718
        }
        723 -> {
            f.bVar6 = b((1) != 0)
            722
        }
        724 -> {
            f.bVar4 = b((0) != 0)
            723
        }
        725 -> {
            f.bVar2 = b((0) != 0)
            724
        }
        726 -> {
            if ((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar3) == (f.bVar7))) != 0))) != 0) 725 else 718
        }
        727 -> {
            f.bVar6 = b((0) != 0)
            726
        }
        728 -> {
            f.bVar4 = b((1) != 0)
            727
        }
        729 -> {
            f.bVar2 = b((0) != 0)
            728
        }
        730 -> {
            f.bVar7 = b((0) != 0)
            729
        }
        731 -> {
            f.bVar5 = b((b((f.dVar40) == (3.4))) != 0)
            730
        }
        732 -> {
            f.bVar3 = b((b((f.dVar40) < (3.4))) != 0)
            731
        }
        733 -> {
            if ((b(!((b((f.dVar40).isNaN())) != 0))) != 0) 732 else 729
        }
        734 -> {
            f.bVar7 = b((1) != 0)
            733
        }
        735 -> {
            f.bVar5 = b((0) != 0)
            734
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep23(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        736 -> {
            f.bVar3 = b((0) != 0)
            735
        }
        737 -> {
            if ((b(((f.bVar4) != 0) || ((b((f.bVar2) != (f.bVar6))) != 0))) != 0) 736 else 729
        }
        738 -> {
            f.bVar7 = b((0) != 0)
            737
        }
        739 -> {
            f.bVar5 = b((0) != 0)
            738
        }
        740 -> {
            f.bVar3 = b((0) != 0)
            739
        }
        741 -> {
            f.bVar6 = b((0) != 0)
            740
        }
        742 -> {
            f.bVar4 = b((b((f.dVar43) == (3.4))) != 0)
            741
        }
        743 -> {
            f.bVar2 = b((b((f.dVar43) < (3.4))) != 0)
            742
        }
        744 -> {
            if ((b(!((b((f.dVar43).isNaN())) != 0))) != 0) 743 else 740
        }
        745 -> {
            f.bVar6 = b((1) != 0)
            744
        }
        746 -> {
            f.bVar4 = b((0) != 0)
            745
        }
        747 -> {
            f.bVar2 = b((0) != 0)
            746
        }
        748 -> {
            if ((b((f.dVar44) <= (3.4))) != 0) 747 else 740
        }
        749 -> {
            f.bVar6 = b((0) != 0)
            748
        }
        750 -> {
            f.bVar4 = b((0) != 0)
            749
        }
        751 -> {
            f.bVar2 = b((0) != 0)
            750
        }
        752 -> {
            if ((b(((b(((b(((b(((b((2.4) <= (f.dVar40))) != 0) && ((b((2.4) <= (f.dVar43))) != 0))) != 0) && ((b((2.4) <= (f.dVar44))) != 0))) != 0) && ((b((f.dVar39) <= (DAT_0012cdf8))) != 0))) != 0) || ((b(((b((f.param_20) <= (54.0))) != 0) || ((run { run { f.fVar35 = f32(f.fVar31); f32(f.fVar31) }; b((7.0) <= (f.param_23)) }) != 0))) != 0))) != 0) 751 else 676
        }
        753 -> {
            f.fVar35 = f32(3.2)
            676
        }
        754 -> {
            if ((b(((f.bVar5) != 0) || ((b((f.bVar3) != (f.bVar7))) != 0))) != 0) 753 else 676
        }
        755 -> {
            f.fVar35 = f32(f.fVar31)
            754
        }
        756 -> {
            f.bVar7 = b((0) != 0)
            755
        }
        757 -> {
            f.bVar5 = b((b((f.param_16) == (3.5))) != 0)
            756
        }
        758 -> {
            f.bVar3 = b((b((f.param_16) < (3.5))) != 0)
            757
        }
        759 -> {
            if ((b(!((b((f.param_16).isNaN())) != 0))) != 0) 758 else 755
        }
        760 -> {
            f.bVar7 = b((1) != 0)
            759
        }
        761 -> {
            f.bVar5 = b((0) != 0)
            760
        }
        762 -> {
            f.bVar3 = b((0) != 0)
            761
        }
        763 -> {
            if ((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) 762 else 755
        }
        764 -> {
            f.bVar7 = b((0) != 0)
            763
        }
        765 -> {
            f.bVar5 = b((1) != 0)
            764
        }
        766 -> {
            f.bVar3 = b((0) != 0)
            765
        }
        767 -> {
            f.bVar6 = b((0) != 0)
            766
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep24(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        768 -> {
            f.bVar4 = b((b((f.param_20) == (48.0))) != 0)
            767
        }
        769 -> {
            f.bVar2 = b((b((f.param_20) < (48.0))) != 0)
            768
        }
        770 -> {
            if ((b(!((b((f.param_20).isNaN())) != 0))) != 0) 769 else 766
        }
        771 -> {
            f.bVar6 = b((1) != 0)
            770
        }
        772 -> {
            f.bVar4 = b((0) != 0)
            771
        }
        773 -> {
            f.bVar2 = b((0) != 0)
            772
        }
        774 -> {
            if ((b((f.dVar26) < (4.1))) != 0) 773 else 766
        }
        775 -> {
            f.bVar6 = b((0) != 0)
            774
        }
        776 -> {
            f.bVar4 = b((1) != 0)
            775
        }
        777 -> {
            f.bVar2 = b((0) != 0)
            776
        }
        778 -> {
            if ((b(((b(((b((3.9) <= (f.dVar39))) != 0) || ((b(((b((f.dVar39) <= (DAT_0012cde0))) != 0) || ((run { run { f.fVar35 = f32(f.param_16); f32(f.param_16) }; b((6.5) <= (f.param_23)) }) != 0))) != 0))) != 0) && ((b(((b((0.5) <= (f.fVar37))) != 0) || ((b(((b((f.param_20) <= (45.0))) != 0) || ((run { run { f.fVar35 = f32(f.fVar31); f32(f.fVar31) }; b((DAT_0012ce00) <= (f.dVar26)) }) != 0))) != 0))) != 0))) != 0) 777 else 676
        }
        779 -> {
            f.fVar35 = f32(3.5)
            676
        }
        780 -> {
            if ((f.bVar2) != 0) 779 else 676
        }
        781 -> {
            f.fVar35 = f32(f.fVar31)
            780
        }
        782 -> {
            f.bVar2 = b((b((f.dVar39) < (DAT_0012cde0))) != 0)
            781
        }
        783 -> {
            if ((b(((b((DAT_0012cdc0) < (f.fVar42))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar39).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012cde0).isNaN())) != 0))) != 0)) }) != 0))) != 0) 782 else 781
        }
        784 -> {
            f.bVar2 = b((0) != 0)
            783
        }
        785 -> {
            if ((b(((b((0.35) <= (f.fVar37))) != 0) || ((b(((b((2.8) < (f.dVar39))) != 0) && ((b((1.5) < (f.fVar42))) != 0))) != 0))) != 0) 778 else 784
        }
        786 -> {
            if ((b(((b(((b((0.25) < (f.fVar37))) != 0) && ((b((f.fVar37) <= (0.35))) != 0))) != 0) || ((b(((b((f.param_16) < (3.5))) != 0) && ((b((f.param_19) < (10.0))) != 0))) != 0))) != 0) 752 else 785
        }
        787 -> {
            if ((b(((b(((b((f.dVar26) <= (3.4))) != 0) || ((b(((b(((b(((b((f.fVar19) <= (0.6))) != 0) && ((b((f.fVar20) <= (0.6))) != 0))) != 0) || ((b(((b((3.3) <= (f.dVar40))) != 0) && ((b(((b((3.3) <= (f.dVar43))) != 0) && ((b((3.3) <= (f.dVar44))) != 0))) != 0))) != 0))) != 0) && ((b(((b((DAT_0012ce00) <= (f.dVar40))) != 0) || ((b(((b((DAT_0012ce00) <= (f.dVar43))) != 0) || ((b((DAT_0012ce00) <= (f.dVar44))) != 0))) != 0))) != 0))) != 0))) != 0) || ((b(((b(((b((DAT_0012cca0) <= (f.dVar39))) != 0) || ((b(((b((f.fVar42) <= (DAT_0012cdc0))) != 0) && ((b((39.0) <= (f.param_20))) != 0))) != 0))) != 0) || ((b(((b((f.param_22) < (6.0))) != 0) && ((b((f.param_23) < (6.0))) != 0))) != 0))) != 0))) != 0) 711 else 786
        }
        788 -> {
            f.fVar35 = f32(3.5)
            676
        }
        789 -> {
            if ((b(((f.bVar6) != 0) || ((b((f.bVar4) != (f.bVar3))) != 0))) != 0) 788 else 676
        }
        790 -> {
            f.fVar35 = f32(f.param_16)
            789
        }
        791 -> {
            f.bVar3 = b((0) != 0)
            790
        }
        792 -> {
            f.bVar6 = b((b((f.param_5) == (3.5))) != 0)
            791
        }
        793 -> {
            f.bVar4 = b((b((f.param_5) < (3.5))) != 0)
            792
        }
        794 -> {
            if ((b(!((b((f.param_5).isNaN())) != 0))) != 0) 793 else 790
        }
        795 -> {
            f.bVar3 = b((1) != 0)
            794
        }
        796 -> {
            f.bVar6 = b((0) != 0)
            795
        }
        797 -> {
            f.bVar4 = b((0) != 0)
            796
        }
        798 -> {
            if ((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar2) == (f.bVar7))) != 0))) != 0) 797 else 790
        }
        799 -> {
            f.bVar3 = b((0) != 0)
            798
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep25(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        800 -> {
            f.bVar6 = b((1) != 0)
            799
        }
        801 -> {
            f.bVar4 = b((0) != 0)
            800
        }
        802 -> {
            f.bVar7 = b((0) != 0)
            801
        }
        803 -> {
            f.bVar5 = b((b((f.param_4) == (3.5))) != 0)
            802
        }
        804 -> {
            f.bVar2 = b((b((f.param_4) < (3.5))) != 0)
            803
        }
        805 -> {
            if ((b(!((b((f.param_4).isNaN())) != 0))) != 0) 804 else 801
        }
        806 -> {
            f.bVar7 = b((1) != 0)
            805
        }
        807 -> {
            f.bVar5 = b((0) != 0)
            806
        }
        808 -> {
            f.bVar2 = b((0) != 0)
            807
        }
        809 -> {
            if ((b(((b(!((f.bVar6) != 0))) != 0) && ((b((f.bVar4) == (f.bVar3))) != 0))) != 0) 808 else 801
        }
        810 -> {
            f.bVar7 = b((0) != 0)
            809
        }
        811 -> {
            f.bVar5 = b((1) != 0)
            810
        }
        812 -> {
            f.bVar2 = b((0) != 0)
            811
        }
        813 -> {
            f.bVar3 = b((0) != 0)
            812
        }
        814 -> {
            f.bVar6 = b((b((f.param_3) == (3.5))) != 0)
            813
        }
        815 -> {
            f.bVar4 = b((b((f.param_3) < (3.5))) != 0)
            814
        }
        816 -> {
            if ((b(!((b((f.param_3).isNaN())) != 0))) != 0) 815 else 812
        }
        817 -> {
            f.bVar3 = b((1) != 0)
            816
        }
        818 -> {
            f.bVar6 = b((0) != 0)
            817
        }
        819 -> {
            f.bVar4 = b((0) != 0)
            818
        }
        820 -> {
            if ((f.bVar2) != 0) 819 else 812
        }
        821 -> {
            f.bVar3 = b((0) != 0)
            820
        }
        822 -> {
            f.bVar6 = b((1) != 0)
            821
        }
        823 -> {
            f.bVar4 = b((0) != 0)
            822
        }
        824 -> {
            f.bVar2 = b((b((f.param_16) < (4.5))) != 0)
            823
        }
        825 -> {
            if ((b(((b((3.5) < (f.param_16))) != 0) && ((run { run { f.bVar2 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_16).isNaN())) != 0)) }) != 0))) != 0) 824 else 823
        }
        826 -> {
            f.bVar2 = b((0) != 0)
            825
        }
        827 -> {
            if ((b(((b((4.0) <= (f.param_16))) != 0) || ((run { run { f.fVar35 = f32(f.param_16); f32(f.param_16) }; b((f.param_16) <= (3.5)) }) != 0))) != 0) 826 else 676
        }
        828 -> {
            f.fVar35 = f32(4.2)
            676
        }
        829 -> {
            if ((b((0.25) <= (f.fVar37))) != 0) 827 else 828
        }
        830 -> {
            if ((b(((b(((b(((b(((b(((b((f.dVar40) <= (2.9))) != 0) || ((b((f.dVar43) <= (2.9))) != 0))) != 0) || ((b((f.dVar44) <= (2.9))) != 0))) != 0) || ((b((7.5) <= (f.param_22))) != 0))) != 0) && ((b(((b(((b((f.dVar40) <= (3.3))) != 0) || ((b((f.dVar43) <= (3.3))) != 0))) != 0) || ((b((f.dVar44) <= (3.3))) != 0))) != 0))) != 0) || ((b(((b((f.param_20) <= (42.0))) != 0) || ((b((3.9) <= (f.dVar26))) != 0))) != 0))) != 0) 787 else 829
        }
        831 -> {
            f.dVar26 = f.fVar31
            830
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep26(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        832 -> {
            f.fVar35 = f32(4.2)
            676
        }
        833 -> {
            if ((b((0.3) <= (f.fVar37))) != 0) 832 else 676
        }
        834 -> {
            f.fVar35 = f32(4.7)
            833
        }
        835 -> {
            if ((b(((b(((b(((b(((b((DAT_0012cca0) <= (f.dVar26))) != 0) || ((run { run { f.fVar35 = f32(f.fVar31); f32(f.fVar31) }; b((f.fVar42) <= (2.0)) }) != 0))) != 0) && ((b(((b((DAT_0012cca0) <= (f.dVar26))) != 0) || ((b(((b(((b((f.fVar42) <= (0.85))) != 0) || ((b((10.0) <= (f.param_19))) != 0))) != 0) || ((run { run { f.fVar35 = f32(f.fVar31); f32(f.fVar31) }; b((f.param_23) <= (6.5)) }) != 0))) != 0))) != 0))) != 0) && ((b(((b(((b((54.0) <= (f.param_20))) != 0) || ((b((5.0) <= (f.param_16))) != 0))) != 0) || ((run { run { f.fVar35 = f32(f.param_16); f32(f.param_16) }; b((f.dVar26) <= (3.9)) }) != 0))) != 0))) != 0) && ((b(((b(((b((0x23f) < (f.param_14))) != 0) || ((b((f.param_22) <= (8.0))) != 0))) != 0) || ((run { run { f.fVar35 = f32(f.fVar31); f32(f.fVar31) }; b((f.param_23) <= (8.0)) }) != 0))) != 0))) != 0) 834 else 676
        }
        836 -> {
            f.dVar26 = f.param_16
            835
        }
        837 -> {
            if ((b(((b(((b((f.dVar40) <= (DAT_0012cdf8))) != 0) || ((b((f.dVar43) <= (DAT_0012cdf8))) != 0))) != 0) || ((b(((b((f.dVar44) <= (DAT_0012cdf8))) != 0) || ((b(((b(((b((f.param_20) <= (54.0))) != 0) && ((b(((b((f.param_16) <= (DAT_0012ce00))) != 0) || ((b((f.param_20) <= (42.0))) != 0))) != 0))) != 0) || ((b((4.0) <= (f.fVar31))) != 0))) != 0))) != 0))) != 0) 831 else 836
        }
        838 -> {
            f.fVar21 = f32(kotlin.math.abs(((f.param_5) - (f.param_4))))
            837
        }
        839 -> {
            f.fVar20 = f32(((f.param_4) - (f.param_3)))
            838
        }
        840 -> {
            f.fVar19 = f32(kotlin.math.abs(((f.param_4) - (f.param_5))))
            839
        }
        841 -> {
            f.fVar31 = f32(2.7)
            840
        }
        842 -> {
            if ((b((DAT_0012cde8) <= (f.fVar31))) != 0) 841 else 840
        }
        843 -> {
            f.fVar31 = f32(((((f.param_12) + (f.param_16))) * (0.5)))
            842
        }
        844 -> {
            if ((b((15.0) < (f.param_21))) != 0) 843 else 840
        }
        845 -> {
            f.fVar31 = f32(3.0)
            840
        }
        846 -> {
            if ((b(((b((f.param_12) <= (3.5))) != 0) || ((b((f.param_12) <= (f.param_16))) != 0))) != 0) 844 else 845
        }
        847 -> {
            if ((b(((b(((b((f.dVar39) < (DAT_0012cde0))) != 0) && ((b(((b(((b((1.5) < (f.fVar15))) != 0) || ((b((1.5) < (f.fVar13))) != 0))) != 0) || ((b((1.5) < (f.fVar14))) != 0))) != 0))) != 0) && ((b(((b((f.param_4) < (f.param_3))) != 0) || ((b(((b((f.param_5) < (f.param_4))) != 0) && ((b((8.0) < (f.param_22))) != 0))) != 0))) != 0))) != 0) 846 else 840
        }
        848 -> {
            f.fVar31 = f32(f.param_12)
            840
        }
        849 -> {
            if ((b(((f.bVar5) != 0) || ((b((f.bVar3) != (f.bVar7))) != 0))) != 0) 848 else 840
        }
        850 -> {
            f.bVar7 = b((0) != 0)
            849
        }
        851 -> {
            f.bVar5 = b((b((f.param_3) == (6.0))) != 0)
            850
        }
        852 -> {
            f.bVar3 = b((b((f.param_3) < (6.0))) != 0)
            851
        }
        853 -> {
            if ((b(!((b((f.param_3).isNaN())) != 0))) != 0) 852 else 849
        }
        854 -> {
            f.bVar7 = b((1) != 0)
            853
        }
        855 -> {
            f.bVar5 = b((0) != 0)
            854
        }
        856 -> {
            f.bVar3 = b((0) != 0)
            855
        }
        857 -> {
            if ((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) 856 else 849
        }
        858 -> {
            f.bVar7 = b((0) != 0)
            857
        }
        859 -> {
            f.bVar5 = b((1) != 0)
            858
        }
        860 -> {
            f.bVar3 = b((0) != 0)
            859
        }
        861 -> {
            f.bVar6 = b((0) != 0)
            860
        }
        862 -> {
            f.bVar4 = b((b((f.param_4) == (6.0))) != 0)
            861
        }
        863 -> {
            f.bVar2 = b((b((f.param_4) < (6.0))) != 0)
            862
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep27(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        864 -> {
            if ((b(!((b((f.param_4).isNaN())) != 0))) != 0) 863 else 860
        }
        865 -> {
            f.bVar6 = b((1) != 0)
            864
        }
        866 -> {
            f.bVar4 = b((0) != 0)
            865
        }
        867 -> {
            f.bVar2 = b((0) != 0)
            866
        }
        868 -> {
            if ((b((6.0) < (f.param_5))) != 0) 867 else 860
        }
        869 -> {
            f.bVar6 = b((0) != 0)
            868
        }
        870 -> {
            f.bVar4 = b((1) != 0)
            869
        }
        871 -> {
            f.bVar2 = b((0) != 0)
            870
        }
        872 -> {
            f.fVar31 = f32(f.fVar19)
            840
        }
        873 -> {
            if ((b(!((f.bVar3) != 0))) != 0) 872 else 840
        }
        874 -> {
            f.fVar31 = f32(2.7)
            873
        }
        875 -> {
            f.bVar3 = b((b((f.param_16) < (DAT_0012cde8))) != 0)
            874
        }
        876 -> {
            if ((b(((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) && ((run { run { f.bVar3 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.param_16).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012cde8).isNaN())) != 0))) != 0)) }) != 0))) != 0) 875 else 874
        }
        877 -> {
            f.bVar3 = b((0) != 0)
            876
        }
        878 -> {
            f.bVar6 = b((0) != 0)
            877
        }
        879 -> {
            f.bVar4 = b((b((f.param_21) == (15.0))) != 0)
            878
        }
        880 -> {
            f.bVar2 = b((b((f.param_21) < (15.0))) != 0)
            879
        }
        881 -> {
            if ((b(!((b((f.param_21).isNaN())) != 0))) != 0) 880 else 877
        }
        882 -> {
            f.bVar6 = b((1) != 0)
            881
        }
        883 -> {
            f.bVar4 = b((0) != 0)
            882
        }
        884 -> {
            f.bVar2 = b((0) != 0)
            883
        }
        885 -> {
            if ((b((((f.param_24) + (f.param_25))) < (0.0))) != 0) 884 else 877
        }
        886 -> {
            f.bVar6 = b((0) != 0)
            885
        }
        887 -> {
            f.bVar4 = b((1) != 0)
            886
        }
        888 -> {
            f.bVar2 = b((0) != 0)
            887
        }
        889 -> {
            3
        }
        890 -> {
            if ((b(((b((f.param_26) < (1))) != 0) && ((b(((b(((b((60.0) < (f.param_20))) != 0) && ((b((f.param_16) < (f.fVar19))) != 0))) != 0) && ((b((3.0) < (f.fVar19))) != 0))) != 0))) != 0) 889 else 888
        }
        891 -> {
            if ((b(((b((f.fVar32) <= (0.5))) != 0) || ((b((((f.param_5) - (f.param_3))) <= (0.5))) != 0))) != 0) 890 else 840
        }
        892 -> {
            if ((b((kotlin.math.abs(((f.fVar10) - (f.fVar32)))) <= (0.5))) != 0) 871 else 891
        }
        893 -> {
            f.fVar31 = f32(2.7)
            840
        }
        894 -> {
            f.fVar31 = f32(f.fVar19)
            840
        }
        895 -> {
            if ((b(((f.bVar4) != 0) || ((b((f.bVar2) != (f.bVar6))) != 0))) != 0) 894 else 840
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep28(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        896 -> {
            f.fVar31 = f32(2.8)
            895
        }
        897 -> {
            f.bVar6 = b((0) != 0)
            896
        }
        898 -> {
            f.bVar4 = b((b((f.dVar40) == (2.8))) != 0)
            897
        }
        899 -> {
            f.bVar2 = b((b((f.dVar40) < (2.8))) != 0)
            898
        }
        900 -> {
            if ((b(!((b((f.dVar40).isNaN())) != 0))) != 0) 899 else 896
        }
        901 -> {
            f.bVar6 = b((1) != 0)
            900
        }
        902 -> {
            f.bVar4 = b((0) != 0)
            901
        }
        903 -> {
            f.bVar2 = b((0) != 0)
            902
        }
        904 -> {
            if ((b(((b(!((f.bVar5) != 0))) != 0) && ((b((f.bVar3) == (f.bVar7))) != 0))) != 0) 903 else 896
        }
        905 -> {
            f.bVar6 = b((0) != 0)
            904
        }
        906 -> {
            f.bVar4 = b((1) != 0)
            905
        }
        907 -> {
            f.bVar2 = b((0) != 0)
            906
        }
        908 -> {
            f.bVar7 = b((0) != 0)
            907
        }
        909 -> {
            f.bVar5 = b((b((f.dVar43) == (2.8))) != 0)
            908
        }
        910 -> {
            f.bVar3 = b((b((f.dVar43) < (2.8))) != 0)
            909
        }
        911 -> {
            if ((b(!((b((f.dVar43).isNaN())) != 0))) != 0) 910 else 907
        }
        912 -> {
            f.bVar7 = b((1) != 0)
            911
        }
        913 -> {
            f.bVar5 = b((0) != 0)
            912
        }
        914 -> {
            f.bVar3 = b((0) != 0)
            913
        }
        915 -> {
            if ((b(((b(!((f.bVar4) != 0))) != 0) && ((b((f.bVar2) == (f.bVar6))) != 0))) != 0) 914 else 907
        }
        916 -> {
            f.bVar7 = b((0) != 0)
            915
        }
        917 -> {
            f.bVar5 = b((1) != 0)
            916
        }
        918 -> {
            f.bVar3 = b((0) != 0)
            917
        }
        919 -> {
            f.bVar6 = b((0) != 0)
            918
        }
        920 -> {
            f.bVar4 = b((b((f.param_16) == (3.3))) != 0)
            919
        }
        921 -> {
            f.bVar2 = b((b((f.param_16) < (3.3))) != 0)
            920
        }
        922 -> {
            if ((b(!((b((f.param_16).isNaN())) != 0))) != 0) 921 else 918
        }
        923 -> {
            f.bVar6 = b((1) != 0)
            922
        }
        924 -> {
            f.bVar4 = b((0) != 0)
            923
        }
        925 -> {
            f.bVar2 = b((0) != 0)
            924
        }
        926 -> {
            if ((b((7.5) < (f.param_19))) != 0) 925 else 918
        }
        927 -> {
            f.bVar6 = b((0) != 0)
            926
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep29(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        928 -> {
            f.bVar4 = b((1) != 0)
            927
        }
        929 -> {
            f.bVar2 = b((0) != 0)
            928
        }
        930 -> {
            if ((b(((b((72.0) < (f.param_20))) != 0) && ((b(((b(((b((1.2) < (f.fVar14))) != 0) || ((b((1.2) < (f.fVar15))) != 0))) != 0) || ((b((1.2) < (f.fVar13))) != 0))) != 0))) != 0) 929 else 840
        }
        931 -> {
            if ((b(((b(((b(((b((4.0) < (f.param_5))) != 0) && ((b((f.param_16) < (f.fVar19))) != 0))) != 0) && ((b((3.0) < (f.fVar19))) != 0))) != 0) || ((b(((b(((b((15.0) < (f.param_21))) != 0) && ((b((f.param_16) < (3.3))) != 0))) != 0) && ((b((((((((f.param_28) - (f.param_27))) - (f.param_27))) + (f.param_29))) < (1.0))) != 0))) != 0))) != 0) 3 else 930
        }
        932 -> {
            if ((b(((b(((b((f.param_3) <= (f.param_4))) != 0) && ((b((f.param_4) <= (f.param_5))) != 0))) != 0) || ((b(((b((f.fVar11) <= (0.5))) != 0) && ((b((f.fVar12) <= (0.5))) != 0))) != 0))) != 0) 892 else 931
        }
        933 -> {
            if ((b(((b(((b((1.5) < (f.fVar15))) != 0) || ((b((1.5) < (f.fVar13))) != 0))) != 0) || ((b((1.5) < (f.fVar14))) != 0))) != 0) 932 else 840
        }
        934 -> {
            f.fVar31 = f32(f.fVar19)
            933
        }
        935 -> {
            f.fVar19 = f32(((((f.param_12) + (f.param_16))) * (0.5)))
            2
        }
        936 -> {
            0
        }
        937 -> {
            1
        }
        938 -> {
            f.fVar19 = f32(0.25)
            937
        }
        939 -> {
            if ((b((2.0) < (f.fVar31))) != 0) 938 else 936
        }
        940 -> {
            if ((b(((b((f.fVar42) <= (2.0))) != 0) && ((b((42.0) <= (f.param_20))) != 0))) != 0) 939 else 2
        }
        941 -> {
            0
        }
        942 -> {
            if ((b(((b(((b(((b(((b((f.param_16) < (f.param_5))) != 0) && ((b((f.dVar43) < (((f.dVar26) + (0.3))))) != 0))) != 0) && ((b((f.param_3) < (f.param_16))) != 0))) != 0) && ((b((42.0) < (f.param_20))) != 0))) != 0) || ((b(((b(((b(((b((f.fVar15) < (1.0))) != 0) && ((b((f.fVar14) < (1.0))) != 0))) != 0) && ((b(((b((0.0) < (f.fVar13))) != 0) && ((b(((b((0.0) < (f.fVar14))) != 0) && ((b((f.fVar13) < (1.0))) != 0))) != 0))) != 0))) != 0) && ((b((0.0) < (f.fVar15))) != 0))) != 0))) != 0) 941 else 2
        }
        943 -> {
            if ((b(((b((f.dVar26) <= (DAT_0012cca0))) != 0) || ((b(((b((f.param_17) <= (f.param_18))) != 0) && ((b(((b((f.fVar37) <= (0.25))) != 0) || ((b((f.fVar42) <= (1.0))) != 0))) != 0))) != 0))) != 0) 940 else 942
        }
        944 -> {
            f.fVar19 = f32(((((f.fVar31) * (f.fVar19))) + (f.param_12)))
            2
        }
        945 -> {
            f.fVar19 = f32(0.75)
            1
        }
        946 -> {
            if ((b(((b(((b((3.8) < (f.dVar40))) != 0) && ((b((f.param_14) < (0x360))) != 0))) != 0) || ((b(((b(((b((3.4) < (f.dVar40))) != 0) && ((b(((b((3.4) < (f.dVar43))) != 0) && ((b((3.4) < (f.dVar44))) != 0))) != 0))) != 0) && ((b(((b((f.param_16) <= (5.5))) != 0) || ((b(((b(((b((3.9) <= (f.dVar43))) != 0) && ((b((3.9) <= (f.dVar40))) != 0))) != 0) && ((b((3.9) <= (f.dVar44))) != 0))) != 0))) != 0))) != 0))) != 0) 945 else 2
        }
        947 -> {
            if ((b(((b(((b((f.fVar31) <= (1.5))) != 0) || ((b((f.dVar26) <= (3.9))) != 0))) != 0) || ((b((3.9) <= (f.param_12))) != 0))) != 0) 943 else 946
        }
        948 -> {
            f.fVar31 = f32(((f.param_16) - (f.param_12)))
            947
        }
        949 -> {
            if ((b((f.param_12) < (f.param_16))) != 0) 948 else 2
        }
        950 -> {
            0
        }
        951 -> {
            if ((b(((b((f.param_16) <= (3.0))) != 0) || ((b((f.fVar42) <= (DAT_0012cca8))) != 0))) != 0) 950 else 2
        }
        952 -> {
            if ((b(((b(((b(((b((f.fVar15) <= (0.0))) != 0) || ((b((f.fVar14) <= (0.0))) != 0))) != 0) || ((b((f.param_16) <= (f.param_12))) != 0))) != 0) || ((b((DAT_0012cca0) <= (f.dVar26))) != 0))) != 0) 949 else 951
        }
        953 -> {
            f.dVar26 = f.param_16
            952
        }
        954 -> {
            if ((b(((b(((b(((b((f.param_12) < (f.param_16))) != 0) && ((b((f.fVar37) < (0.5))) != 0))) != 0) && ((b(((b((f.fVar16) < (0.5))) != 0) && ((b(((b(((b(((b((f.fVar17) < (0.5))) != 0) && ((b((0.0) < (f.fVar18))) != 0))) != 0) && ((b((0.0) < (f.fVar17))) != 0))) != 0) && ((b(((b((f.fVar18) < (0.5))) != 0) && ((b((0.0) < (f.fVar16))) != 0))) != 0))) != 0))) != 0))) != 0) || ((b(((b(((b(((b((f.fVar18) < (2.0))) != 0) && ((b(((b((f.fVar17) < (2.0))) != 0) && ((b((f.fVar16) < (2.0))) != 0))) != 0))) != 0) && ((b(((b((5.0) < (f.param_8))) != 0) && ((b(((b(((b((5.0) < (f.param_7))) != 0) && ((b((5.0) < (f.param_6))) != 0))) != 0) && ((b((f.fVar37) < (0.5))) != 0))) != 0))) != 0))) != 0) || ((b(((b(((b(((b(((b((f.fVar37) < (DAT_0012cdf0))) != 0) && ((b((f.fVar16) < (1.0))) != 0))) != 0) && ((b((f.fVar18) < (1.0))) != 0))) != 0) && ((b(((b((f.fVar17) < (1.0))) != 0) && ((b((f.param_12) < (f.param_16))) != 0))) != 0))) != 0) && ((b(((b((f.param_12) < (f.param_17))) != 0) && ((b((f.param_17) < (4.0))) != 0))) != 0))) != 0))) != 0))) != 0) 0 else 953
        }
        955 -> {
            2
        }
        956 -> {
            if ((b((2.0) < (((kotlin.math.abs(f.param_16)) - (f.param_12))))) != 0) 955 else 954
        }
        957 -> {
            f.fVar19 = f32(f.param_12)
            956
        }
        958 -> {
            if ((b((f.param_14) < (0x241))) != 0) 847 else 957
        }
        959 -> {
            f.fVar31 = f32(f.param_12)
            958
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustmentrangeStep30(f: adjustmentrangeFrame, pc: Int): Int {
    return when (pc) {
        960 -> {
            f.fVar42 = f32(((f.param_18) - (f.param_16)))
            959
        }
        961 -> {
            f.fVar37 = f32(((f.param_17) - (f.param_16)))
            960
        }
        962 -> {
            f.dVar39 = f.param_16
            961
        }
        963 -> {
            f.fVar32 = f32(((f.param_5) - (f.param_4)))
            962
        }
        964 -> {
            f.dVar44 = f.param_5
            963
        }
        965 -> {
            f.dVar40 = f.param_3
            964
        }
        966 -> {
            f.dVar43 = f.param_4
            965
        }
        967 -> {
            f.fVar18 = f32(((f.param_17) - (f.param_8)))
            966
        }
        968 -> {
            f.fVar17 = f32(((f.param_17) - (f.param_7)))
            967
        }
        969 -> {
            f.fVar16 = f32(((f.param_17) - (f.param_6)))
            968
        }
        970 -> {
            f.fVar15 = f32(((f.param_16) - (f.param_5)))
            969
        }
        971 -> {
            f.fVar14 = f32(((f.param_16) - (f.param_4)))
            970
        }
        972 -> {
            f.fVar13 = f32(((f.param_16) - (f.param_3)))
            971
        }
        973 -> {
            f.fVar12 = f32(((f.param_4) - (f.param_5)))
            972
        }
        974 -> {
            f.fVar11 = f32(((f.param_3) - (f.param_4)))
            973
        }
        975 -> {
            f.fVar10 = f32(kotlin.math.abs(((f.param_4) - (f.param_3))))
            974
        }
        976 -> {
            f.fVar35 = f32(3.5)
            975
        }
        else -> error("bad C state: $pc")
    }
}

private fun adjustment_range(param_1: Ptr, param_2: Double, param_3: Double, param_4: Double, param_5: Double, param_6: Double, param_7: Double, param_8: Double, param_9: Double, param_10: Double, param_11: Double, param_12: Double, param_13: Double, param_14: Int, param_15: Double, param_16: Double, param_17: Double, param_18: Double, param_19: Double, param_20: Double, param_21: Double, param_22: Double, param_23: Double, param_24: Double, param_25: Double, param_26: Int, param_27: Double, param_28: Double, param_29: Double, param_30: Double): Double {
    val f = adjustmentrangeFrame(param_1, f32(param_2), f32(param_3), f32(param_4), f32(param_5), f32(param_6), f32(param_7), f32(param_8), f32(param_9), f32(param_10), f32(param_11), f32(param_12), f32(param_13), param_14, f32(param_15), f32(param_16), f32(param_17), f32(param_18), f32(param_19), f32(param_20), f32(param_21), f32(param_22), f32(param_23), f32(param_24), f32(param_25), param_26, f32(param_27), f32(param_28), f32(param_29), f32(param_30))
    var pc = 976
    while (true) {
        pc = when (pc / 32) {
            0 -> adjustmentrangeStep0(f, pc)
            1 -> adjustmentrangeStep1(f, pc)
            2 -> adjustmentrangeStep2(f, pc)
            3 -> adjustmentrangeStep3(f, pc)
            4 -> adjustmentrangeStep4(f, pc)
            5 -> adjustmentrangeStep5(f, pc)
            6 -> adjustmentrangeStep6(f, pc)
            7 -> adjustmentrangeStep7(f, pc)
            8 -> adjustmentrangeStep8(f, pc)
            9 -> adjustmentrangeStep9(f, pc)
            10 -> adjustmentrangeStep10(f, pc)
            11 -> adjustmentrangeStep11(f, pc)
            12 -> adjustmentrangeStep12(f, pc)
            13 -> adjustmentrangeStep13(f, pc)
            14 -> adjustmentrangeStep14(f, pc)
            15 -> adjustmentrangeStep15(f, pc)
            16 -> adjustmentrangeStep16(f, pc)
            17 -> adjustmentrangeStep17(f, pc)
            18 -> adjustmentrangeStep18(f, pc)
            19 -> adjustmentrangeStep19(f, pc)
            20 -> adjustmentrangeStep20(f, pc)
            21 -> adjustmentrangeStep21(f, pc)
            22 -> adjustmentrangeStep22(f, pc)
            23 -> adjustmentrangeStep23(f, pc)
            24 -> adjustmentrangeStep24(f, pc)
            25 -> adjustmentrangeStep25(f, pc)
            26 -> adjustmentrangeStep26(f, pc)
            27 -> adjustmentrangeStep27(f, pc)
            28 -> adjustmentrangeStep28(f, pc)
            29 -> adjustmentrangeStep29(f, pc)
            30 -> adjustmentrangeStep30(f, pc)
            else -> error("bad C chunk: $pc")
        }
        if (pc == C_DONE) {
            return f.result
        }
    }
}

private class ClippingfilterFrame(var param_1: Ptr, var param_2: Ptr, var param_3: Ptr, var param_4: Double, var param_5: Double, var param_6: Double, var param_7: Double, var param_8: Double, var param_9: Double, var param_10: Double, var param_11: Double, var param_12: Double, var param_13: Double, var param_14: Int) {
    var pjVar1: Ptr = Ptr(ByteArray(0), 0)
    var iVar2: Int = 0
    var lVar3: Int = 0
    var lVar4: Int = 0
    var lVar5: Int = 0
    var uVar6: Long = 0L
    var bVar7: Int = 0
    var bVar8: Int = 0
    var bVar9: Int = 0
    var bVar10: Int = 0
    var bVar11: Int = 0
    var bVar12: Int = 0
    var bVar13: Int = 0
    var iVar14: Int = 0
    var iVar15: Int = 0
    var iVar16: Int = 0
    var iVar17: Int = 0
    var lVar18: Int = 0
    var iVar19: Int = 0
    var iVar20: Int = 0
    var iVar21: Int = 0
    var fVar22: Double = 0.0
    var fVar23: Double = 0.0
    var fVar24: Double = 0.0
    var fVar25: Double = 0.0
    var fVar26: Double = 0.0
    var fVar27: Double = 0.0
    var fVar28: Double = 0.0
    var fVar29: Double = 0.0
    var uVar30: Int = 0
    var dVar31: Double = 0.0
    var dVar32: Double = 0.0
    var dVar33: Double = 0.0
    var dVar34: Double = 0.0
    var fVar35: Double = 0.0
    var fVar36: Double = 0.0
    var fVar37: Double = 0.0
    var dVar38: Double = 0.0
    var dVar39: Double = 0.0
    var fVar40: Double = 0.0
    var fVar41: Double = 0.0
    var dVar42: Double = 0.0
    var fVar43: Double = 0.0
    var fVar44: Double = 0.0
    var fVar45: Double = 0.0
    var fVar46: Double = 0.0
    var fVar47: Double = 0.0
    var dVar48: Double = 0.0
    var dVar49: Double = 0.0
    var fVar50: Double = 0.0
    var fVar51: Double = 0.0
    var fVar52: Double = 0.0
    var dVar53: Double = 0.0
    var fVar54: Double = 0.0
    var fVar55: Double = 0.0
    var fVar56: Double = 0.0
    var fVar57: Double = 0.0
    var fVar58: Double = 0.0
    var dVar59: Double = 0.0
    var fVar60: Double = 0.0
    var fVar61: Double = 0.0
    var dVar62: Double = 0.0
    var dVar63: Double = 0.0
    var fVar64: Double = 0.0
    var fVar65: Double = 0.0
    var fVar66: Double = 0.0
    var fVar67: Double = 0.0
    var fVar68: Double = 0.0
    var fVar69: Double = 0.0
    var fVar70: Double = 0.0
    var fVar71: Double = 0.0
    var fVar72: Double = 0.0
    var fVar73: Double = 0.0
    var fVar74: Double = 0.0
    var dVar75: Double = 0.0
    var fVar76: Double = 0.0
    var dVar77: Double = 0.0
    var fVar78: Double = 0.0
    var fVar79: Double = 0.0
    var fVar80: Double = 0.0
    var dVar81: Double = 0.0
    var fVar82: Double = 0.0
    var dVar83: Double = 0.0
    var local_178: Ptr = Ptr(ByteArray(0), 0)
    var result: Int = 0
}

private fun ClippingfilterStep0(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        0 -> {
            4321
        }
        1 -> {
            4313
        }
        2 -> {
            4287
        }
        3 -> {
            4285
        }
        4 -> {
            4277
        }
        5 -> {
            4276
        }
        6 -> {
            4274
        }
        7 -> {
            4272
        }
        8 -> {
            4270
        }
        9 -> {
            4682
        }
        10 -> {
            4678
        }
        11 -> {
            4677
        }
        12 -> {
            4675
        }
        13 -> {
            4674
        }
        14 -> {
            4671
        }
        15 -> {
            4656
        }
        16 -> {
            4655
        }
        17 -> {
            4631
        }
        18 -> {
            4629
        }
        19 -> {
            4606
        }
        20 -> {
            4574
        }
        21 -> {
            4572
        }
        22 -> {
            4553
        }
        23 -> {
            4561
        }
        24 -> {
            4539
        }
        25 -> {
            4526
        }
        26 -> {
            4507
        }
        27 -> {
            4471
        }
        28 -> {
            4465
        }
        29 -> {
            4452
        }
        30 -> {
            4481
        }
        31 -> {
            4485
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep1(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        32 -> {
            4480
        }
        33 -> {
            4487
        }
        34 -> {
            4449
        }
        35 -> {
            4444
        }
        36 -> {
            4413
        }
        37 -> {
            4398
        }
        38 -> {
            4396
        }
        39 -> {
            4366
        }
        40 -> {
            4353
        }
        41 -> {
            4340
        }
        42 -> {
            4268
        }
        43 -> {
            4207
        }
        44 -> {
            4183
        }
        45 -> {
            4180
        }
        46 -> {
            4153
        }
        47 -> {
            4150
        }
        48 -> {
            4146
        }
        49 -> {
            4145
        }
        50 -> {
            4142
        }
        51 -> {
            4118
        }
        52 -> {
            4063
        }
        53 -> {
            4033
        }
        54 -> {
            4021
        }
        55 -> {
            4003
        }
        56 -> {
            4093
        }
        57 -> {
            4101
        }
        58 -> {
            4001
        }
        59 -> {
            3999
        }
        60 -> {
            3997
        }
        61 -> {
            3996
        }
        62 -> {
            4193
        }
        63 -> {
            4187
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep2(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        64 -> {
            4184
        }
        65 -> {
            4208
        }
        66 -> {
            4218
        }
        67 -> {
            4221
        }
        68 -> {
            4233
        }
        69 -> {
            3994
        }
        70 -> {
            3992
        }
        71 -> {
            4252
        }
        72 -> {
            3970
        }
        73 -> {
            3979
        }
        74 -> {
            3968
        }
        75 -> {
            3850
        }
        76 -> {
            3847
        }
        77 -> {
            3928
        }
        78 -> {
            3903
        }
        79 -> {
            3779
        }
        80 -> {
            3726
        }
        81 -> {
            3749
        }
        82 -> {
            3691
        }
        83 -> {
            3682
        }
        84 -> {
            3660
        }
        85 -> {
            3616
        }
        86 -> {
            3573
        }
        87 -> {
            3560
        }
        88 -> {
            3559
        }
        89 -> {
            3518
        }
        90 -> {
            3516
        }
        91 -> {
            3506
        }
        92 -> {
            3539
        }
        93 -> {
            3489
        }
        94 -> {
            3483
        }
        95 -> {
            3547
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep3(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        96 -> {
            3481
        }
        97 -> {
            3463
        }
        98 -> {
            3462
        }
        99 -> {
            3588
        }
        100 -> {
            3587
        }
        101 -> {
            3669
        }
        102 -> {
            3662
        }
        103 -> {
            3461
        }
        104 -> {
            3385
        }
        105 -> {
            3384
        }
        106 -> {
            3413
        }
        107 -> {
            3399
        }
        108 -> {
            3353
        }
        109 -> {
            1156
        }
        110 -> {
            1135
        }
        111 -> {
            1131
        }
        112 -> {
            1047
        }
        113 -> {
            1029
        }
        114 -> {
            1028
        }
        115 -> {
            1027
        }
        116 -> {
            1023
        }
        117 -> {
            1021
        }
        118 -> {
            988
        }
        119 -> {
            981
        }
        120 -> {
            977
        }
        121 -> {
            972
        }
        122 -> {
            966
        }
        123 -> {
            957
        }
        124 -> {
            951
        }
        125 -> {
            949
        }
        126 -> {
            899
        }
        127 -> {
            880
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep4(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        128 -> {
            858
        }
        129 -> {
            853
        }
        130 -> {
            1114
        }
        131 -> {
            1109
        }
        132 -> {
            1103
        }
        133 -> {
            1087
        }
        134 -> {
            1083
        }
        135 -> {
            1076
        }
        136 -> {
            1070
        }
        137 -> {
            1060
        }
        138 -> {
            1056
        }
        139 -> {
            852
        }
        140 -> {
            851
        }
        141 -> {
            840
        }
        142 -> {
            832
        }
        143 -> {
            828
        }
        144 -> {
            826
        }
        145 -> {
            819
        }
        146 -> {
            815
        }
        147 -> {
            811
        }
        148 -> {
            796
        }
        149 -> {
            793
        }
        150 -> {
            803
        }
        151 -> {
            673
        }
        152 -> {
            706
        }
        153 -> {
            720
        }
        154 -> {
            715
        }
        155 -> {
            671
        }
        156 -> {
            663
        }
        157 -> {
            658
        }
        158 -> {
            667
        }
        159 -> {
            647
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep5(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        160 -> {
            625
        }
        161 -> {
            594
        }
        162 -> {
            587
        }
        163 -> {
            571
        }
        164 -> {
            556
        }
        165 -> {
            553
        }
        166 -> {
            541
        }
        167 -> {
            516
        }
        168 -> {
            513
        }
        169 -> {
            505
        }
        170 -> {
            491
        }
        171 -> {
            485
        }
        172 -> {
            466
        }
        173 -> {
            451
        }
        174 -> {
            447
        }
        175 -> {
            432
        }
        176 -> {
            416
        }
        177 -> {
            422
        }
        178 -> {
            407
        }
        179 -> {
            402
        }
        180 -> {
            398
        }
        181 -> {
            396
        }
        182 -> {
            392
        }
        183 -> {
            1488
        }
        184 -> {
            1476
        }
        185 -> {
            1434
        }
        186 -> {
            1402
        }
        187 -> {
            1413
        }
        188 -> {
            1388
        }
        189 -> {
            1346
        }
        190 -> {
            1344
        }
        191 -> {
            1300
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep6(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        192 -> {
            1291
        }
        193 -> {
            1276
        }
        194 -> {
            1250
        }
        195 -> {
            1243
        }
        196 -> {
            1234
        }
        197 -> {
            1212
        }
        198 -> {
            1201
        }
        199 -> {
            1194
        }
        200 -> {
            1187
        }
        201 -> {
            1172
        }
        202 -> {
            391
        }
        203 -> {
            3085
        }
        204 -> {
            1668
        }
        205 -> {
            1654
        }
        206 -> {
            1630
        }
        207 -> {
            1636
        }
        208 -> {
            1635
        }
        209 -> {
            1596
        }
        210 -> {
            1918
        }
        211 -> {
            1809
        }
        212 -> {
            1713
        }
        213 -> {
            1741
        }
        214 -> {
            1739
        }
        215 -> {
            1738
        }
        216 -> {
            1736
        }
        217 -> {
            1751
        }
        218 -> {
            2109
        }
        219 -> {
            2129
        }
        220 -> {
            2136
        }
        221 -> {
            2082
        }
        222 -> {
            2070
        }
        223 -> {
            2038
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep7(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        224 -> {
            1991
        }
        225 -> {
            1967
        }
        226 -> {
            1953
        }
        227 -> {
            1944
        }
        228 -> {
            2198
        }
        229 -> {
            2197
        }
        230 -> {
            2232
        }
        231 -> {
            2257
        }
        232 -> {
            2290
        }
        233 -> {
            2271
        }
        234 -> {
            2270
        }
        235 -> {
            2280
        }
        236 -> {
            2278
        }
        237 -> {
            2334
        }
        238 -> {
            2327
        }
        239 -> {
            2362
        }
        240 -> {
            2359
        }
        241 -> {
            2370
        }
        242 -> {
            2355
        }
        243 -> {
            2380
        }
        244 -> {
            3027
        }
        245 -> {
            3014
        }
        246 -> {
            2966
        }
        247 -> {
            2854
        }
        248 -> {
            2863
        }
        249 -> {
            2940
        }
        250 -> {
            2935
        }
        251 -> {
            2910
        }
        252 -> {
            2904
        }
        253 -> {
            2921
        }
        254 -> {
            2901
        }
        255 -> {
            2951
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep8(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        256 -> {
            2808
        }
        257 -> {
            2800
        }
        258 -> {
            2798
        }
        259 -> {
            2766
        }
        260 -> {
            2757
        }
        261 -> {
            2745
        }
        262 -> {
            2786
        }
        263 -> {
            2780
        }
        264 -> {
            2719
        }
        265 -> {
            2513
        }
        266 -> {
            2505
        }
        267 -> {
            2508
        }
        268 -> {
            2432
        }
        269 -> {
            2545
        }
        270 -> {
            2536
        }
        271 -> {
            2532
        }
        272 -> {
            2527
        }
        273 -> {
            2518
        }
        274 -> {
            2609
        }
        275 -> {
            2607
        }
        276 -> {
            2587
        }
        277 -> {
            2708
        }
        278 -> {
            2699
        }
        279 -> {
            2697
        }
        280 -> {
            2686
        }
        281 -> {
            2682
        }
        282 -> {
            2680
        }
        283 -> {
            2678
        }
        284 -> {
            2670
        }
        285 -> {
            2666
        }
        286 -> {
            2622
        }
        287 -> {
            2619
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep9(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        288 -> {
            2618
        }
        289 -> {
            2415
        }
        290 -> {
            2411
        }
        291 -> {
            3066
        }
        292 -> {
            3069
        }
        293 -> {
            2394
        }
        294 -> {
            3284
        }
        295 -> {
            3271
        }
        296 -> {
            3294
        }
        297 -> {
            3288
        }
        298 -> {
            3249
        }
        299 -> {
            3201
        }
        300 -> {
            3104
        }
        301 -> {
            3162
        }
        302 -> {
            3156
        }
        303 -> {
            3115
        }
        304 -> {
            3146
        }
        305 -> {
            3195
        }
        306 -> {
            3203
        }
        307 -> {
            3208
        }
        308 -> {
            3211
        }
        309 -> {
            3216
        }
        310 -> {
            3217
        }
        311 -> {
            3228
        }
        312 -> {
            3221
        }
        313 -> {
            3243
        }
        314 -> {
            3102
        }
        315 -> {
            3086
        }
        316 -> {
            390
        }
        317 -> {
            351
        }
        318 -> {
            345
        }
        319 -> {
            342
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep10(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        320 -> {
            376
        }
        321 -> {
            373
        }
        322 -> {
            369
        }
        323 -> {
            341
        }
        324 -> {
            C_DONE
        }
        325 -> {
            writeF32(f.param_1.plus(0x250), f32(f.fVar54))
            324
        }
        326 -> {
            writeF32(f.param_3.plus(0x24), f32(f.param_9))
            325
        }
        327 -> {
            writeI32(f.param_1.plus(8), f.uVar30)
            326
        }
        328 -> {
            f.uVar30 = Calibration_baseline(f.param_3, f.param_9, f.fVar55, f.fVar78, readF32(f.param_1.plus(0x178)), readF32(f.param_1.plus(0x144)), readF32(f.param_1.plus(0x150)), f.fVar35, f.param_14)
            327
        }
        329 -> {
            writeI32(f.param_1.plus(0x270), f.iVar19)
            328
        }
        330 -> {
            f.iVar19 = ((readI32(f.param_1.plus(0x270))) + (1))
            329
        }
        331 -> {
            if ((b(((b((f.param_5) < (7.5))) != 0) && ((run { run { f.fVar24 = f32(((((((((((((f.fVar22) + (0.0))) + (f.fVar40))) + (f.fVar57))) + (f.fVar23))) + (f.param_7))) / (5.0))); f32(((((((((((((f.fVar22) + (0.0))) + (f.fVar40))) + (f.fVar57))) + (f.fVar23))) + (f.param_7))) / (5.0))) }; b((((((((((((((((((((((f.fVar22) - (f.fVar24))) * (((f.fVar22) - (f.fVar24))))) + (0.0))) + (((((f.fVar40) - (f.fVar24))) * (((f.fVar40) - (f.fVar24))))))) + (((((f.fVar57) - (f.fVar24))) * (((f.fVar57) - (f.fVar24))))))) + (((((f.fVar23) - (f.fVar24))) * (((f.fVar23) - (f.fVar24))))))) + (((((f.param_7) - (f.fVar24))) * (((f.param_7) - (f.fVar24))))))) / (5.0))) * (100.0))) + (5.0))) <= (5.1)) }) != 0))) != 0) 330 else 329
        }
        332 -> {
            writeF32(f.param_1.plus(0x1c), f32(f.param_7))
            331
        }
        333 -> {
            writeF32(f.param_1.plus(0x18), f32(f.fVar23))
            332
        }
        334 -> {
            writeF32(f.param_1.plus(0x14), f32(f.fVar57))
            333
        }
        335 -> {
            writeF32(f.param_1.plus(0x10), f32(f.fVar40))
            334
        }
        336 -> {
            writeF32(f.param_1.plus(0xc), f32(f.fVar22))
            335
        }
        337 -> {
            f.iVar19 = 0
            336
        }
        338 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x1c)))
            337
        }
        339 -> {
            f.fVar57 = f32(readF32(f.param_1.plus(0x18)))
            338
        }
        340 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x14)))
            339
        }
        341 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x10)))
            340
        }
        342 -> {
            f.fVar54 = f32(((f.fVar70) * (0.75)))
            323
        }
        343 -> {
            323
        }
        344 -> {
            if ((b(((b(((b((f.param_14) < (0x120))) != 0) || ((b(((b((DAT_0012cde8) <= (f.dVar31))) != 0) || ((b((f.fVar70) <= (1.5))) != 0))) != 0))) != 0) || ((b(((b((((f.fVar55) + (f.fVar70))) <= (3.9))) != 0) || ((b(((b((readF32(f.param_1.plus(0x1d8))) <= (6.8))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) <= (6.8))) != 0))) != 0))) != 0))) != 0) 343 else 319
        }
        345 -> {
            f.fVar54 = f32(f.fVar70)
            344
        }
        346 -> {
            322
        }
        347 -> {
            if ((b(((b(((b(((b((f.fVar55) < (3.5))) != 0) && ((b(((b((0x11f) < (f.param_14))) != 0) && ((b((f.iVar14) < (0x24))) != 0))) != 0))) != 0) && ((b((3.9) < (f.fVar54))) != 0))) != 0) || ((b(((b(((b((f.fVar55) < (1.0))) != 0) && ((b(((b((0x11f) < (f.param_14))) != 0) && ((b((f.iVar14) < (0x24))) != 0))) != 0))) != 0) && ((b((DAT_0012cca8) < (f.dVar38))) != 0))) != 0))) != 0) 346 else 318
        }
        348 -> {
            317
        }
        349 -> {
            if ((b(((b((0.7) < (f.dVar38))) != 0) && ((b(((f.bVar7).and(b((6.8) < (readF32(f.param_1.plus(0x1d4)))))) != 0)) != 0))) != 0) 348 else 347
        }
        350 -> {
            319
        }
        351 -> {
            if ((b((DAT_0012ce68) < (readF32(f.param_1.plus(0x22c))))) != 0) 350 else 347
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep11(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        352 -> {
            if ((b(((b(!((b(((f.bVar7).xor(1)) != 0)) != 0))) != 0) && ((b((0.7) < (f.dVar38))) != 0))) != 0) 317 else 347
        }
        353 -> {
            if ((b((readF32(f.param_1.plus(0x1d8))) <= (6.8))) != 0) 349 else 352
        }
        354 -> {
            if ((b(((b((f.dVar31) < (2.8))) != 0) && ((b((3.0) < (f.fVar54))) != 0))) != 0) 353 else 347
        }
        355 -> {
            322
        }
        356 -> {
            if ((b(((b(((b(((b((f.dVar31) < (3.3))) != 0) && ((b((3.9) < (f.fVar54))) != 0))) != 0) && ((b(((b((DAT_0012cd18) < (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((DAT_0012cd18) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0))) != 0) || ((b(((b((f.dVar31) < (2.8))) != 0) && ((b(((b((3.9) < (f.fVar54))) != 0) && ((b(((b(((b((DAT_0012cf28) < (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((DAT_0012cf28) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) && ((b((0.35) < (f.fVar28))) != 0))) != 0))) != 0))) != 0))) != 0) 355 else 354
        }
        357 -> {
            f.fVar54 = f32(((f.fVar55) + (f.fVar70)))
            356
        }
        358 -> {
            323
        }
        359 -> {
            if ((b(((b((f.fVar70) < (0.0))) != 0) || ((run { run { f.dVar38 = f.fVar70; f.fVar70 }; run { f.fVar54 = f32(f.fVar70); f32(f.fVar70) }; b(((b(((f.bVar9).xor(1)) != 0)) != 0) || ((b((f.dVar38) <= (DAT_0012ccb0))) != 0)) }) != 0))) != 0) 358 else 357
        }
        360 -> {
            f.fVar54 = f32(0.0)
            359
        }
        361 -> {
            323
        }
        362 -> {
            f.fVar54 = f32(((f.fVar70) * (0.5)))
            361
        }
        363 -> {
            if ((b(!((f.bVar9) != 0))) != 0) 362 else 361
        }
        364 -> {
            f.bVar9 = b((b((((f.fVar55) + (f.fVar70))) < (3.5))) != 0)
            363
        }
        365 -> {
            if ((b(((b((readF32(f.param_1.plus(0x1d8))) < (7.8))) != 0) && ((run { run { f.bVar9 = b((0) != 0); b((0) != 0) }; b(!((b((((f.fVar55) + (f.fVar70))).isNaN())) != 0)) }) != 0))) != 0) 364 else 363
        }
        366 -> {
            f.bVar9 = b((0) != 0)
            365
        }
        367 -> {
            if ((b(((b(((b((f.dVar42) < (DAT_0012cde0))) != 0) && ((b((f.iVar14) < (0x24))) != 0))) != 0) && ((b(((b((6.8) < (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((6.8) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0))) != 0) 366 else 361
        }
        368 -> {
            if ((b(((b((f.dVar42) < (DAT_0012cca0))) != 0) && ((b(((b(((b((f.iVar14) < (0x3c))) != 0) && ((b((4.5) < (f.fVar22))) != 0))) != 0) && ((b((DAT_0012cc40) < (((f.fVar22) - (f.fVar78))))) != 0))) != 0))) != 0) 367 else 360
        }
        369 -> {
            f.fVar54 = f32(((f.fVar70) * (0.5)))
            323
        }
        370 -> {
            323
        }
        371 -> {
            if ((b(((b(((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((0x26) < (f.iVar14))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x1d8))) <= (6.8))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) <= (6.8))) != 0))) != 0))) != 0) || ((b(((b(((b(((b(((f.bVar11).xor(1)) != 0)) != 0) || ((b((f.fVar70) <= (0.0))) != 0))) != 0) || ((b((readI32(f.local_178)) != (1))) != 0))) != 0) || ((run { run { f.fVar54 = f32(0.0); f32(0.0) }; b((f.dVar38) < (0.3)) }) != 0))) != 0))) != 0) 370 else 322
        }
        372 -> {
            318
        }
        373 -> {
            if ((b(((b(((b(((b((3.5) <= (f.fVar55))) != 0) || ((b(((b((f.param_14) < (0x120))) != 0) || ((b((0x23) < (f.iVar14))) != 0))) != 0))) != 0) || ((b((f.fVar54) <= (3.9))) != 0))) != 0) && ((b(((b(((b((1.0) <= (f.fVar55))) != 0) || ((b(((b((f.param_14) < (0x120))) != 0) || ((b((0x23) < (f.iVar14))) != 0))) != 0))) != 0) || ((b((f.dVar38) <= (DAT_0012cca8))) != 0))) != 0))) != 0) 372 else 322
        }
        374 -> {
            319
        }
        375 -> {
            321
        }
        376 -> {
            if ((b((readF32(f.param_1.plus(0x22c))) <= (DAT_0012ce68))) != 0) 375 else 374
        }
        377 -> {
            321
        }
        378 -> {
            if ((b(((b(((f.bVar7).xor(1)) != 0)) != 0) || ((b((f.dVar38) <= (0.7))) != 0))) != 0) 377 else 320
        }
        379 -> {
            321
        }
        380 -> {
            320
        }
        381 -> {
            if ((b(((b((0.7) < (f.dVar38))) != 0) && ((b(((f.bVar7).and(b((6.8) < (readF32(f.param_1.plus(0x1d4)))))) != 0)) != 0))) != 0) 380 else 379
        }
        382 -> {
            if ((b((readF32(f.param_1.plus(0x1d8))) <= (6.8))) != 0) 381 else 378
        }
        383 -> {
            if ((b(((b((f.dVar31) < (2.8))) != 0) && ((b((2.9) < (f.fVar54))) != 0))) != 0) 382 else 321
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep12(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        384 -> {
            if ((b(((b(((b((3.3) <= (f.dVar31))) != 0) || ((b((f.fVar54) <= (3.9))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x1d8))) <= (DAT_0012cd18))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) <= (DAT_0012cd18))) != 0))) != 0))) != 0) 383 else 322
        }
        385 -> {
            f.fVar54 = f32(((f.fVar55) + (f.fVar70)))
            384
        }
        386 -> {
            if ((b(((b(((f.bVar9).xor(1)) != 0)) != 0) || ((b((f.dVar38) <= (DAT_0012ccb0))) != 0))) != 0) 371 else 385
        }
        387 -> {
            f.dVar38 = f.fVar70
            386
        }
        388 -> {
            if ((b(((b((f.param_12) < (10.5))) != 0) || ((b((f.fVar22) < (4.3))) != 0))) != 0) 368 else 387
        }
        389 -> {
            f.fVar54 = f32(f.fVar70)
            388
        }
        390 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x234)))
            389
        }
        391 -> {
            f.fVar70 = f32(f32(f.dVar62))
            316
        }
        392 -> {
            f.dVar62 = ((f.dVar77) - (f.dVar34))
            202
        }
        393 -> {
            f.dVar77 = 3.9
            182
        }
        394 -> {
            316
        }
        395 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(3.9)))))) != 0) 394 else 393
        }
        396 -> {
            f.fVar70 = f32(0.0)
            395
        }
        397 -> {
            143
        }
        398 -> {
            f.dVar75 = 3.9
            397
        }
        399 -> {
            179
        }
        400 -> {
            if ((b((((f.dVar49) + (-(3.9)))) < (0.5))) != 0) 399 else 180
        }
        401 -> {
            202
        }
        402 -> {
            f.dVar62 = ((((((7.8) - (f.dVar49))) - (f.dVar63))) * (0.5))
            401
        }
        403 -> {
            f.dVar49 = f.dVar31
            179
        }
        404 -> {
            if ((b((1.0) < (f.fVar55))) != 0) 403 else 179
        }
        405 -> {
            if ((b(((b((f.fVar28) < (1.0))) != 0) && ((b((((f.dVar49) + (-(3.9)))) < (0.5))) != 0))) != 0) 404 else 400
        }
        406 -> {
            202
        }
        407 -> {
            f.dVar62 = ((((((f.dVar53) - (f.dVar63))) - (f.dVar31))) * (0.5))
            406
        }
        408 -> {
            f.dVar53 = 7.8
            178
        }
        409 -> {
            if ((b(((b(((b((f.fVar55) < (f.fVar22))) != 0) && ((b((((f.dVar31) + (-(3.9)))) < (0.0))) != 0))) != 0) && ((b(((b((f.fVar28) < (0.85))) != 0) && ((b((f.fVar60) < (1.0))) != 0))) != 0))) != 0) 408 else 405
        }
        410 -> {
            if ((b((((f.dVar63) + (-(3.9)))) < (0.0))) != 0) 409 else 181
        }
        411 -> {
            316
        }
        412 -> {
            f.fVar70 = f32(((((((9.0) - (f.fVar54))) - (f.fVar22))) * (0.5)))
            411
        }
        413 -> {
            176
        }
        414 -> {
            if ((b((f.fVar55) <= (1.0))) != 0) 413 else 412
        }
        415 -> {
            f.fVar54 = f32(f.fVar55)
            414
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep13(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        416 -> {
            f.fVar54 = f32(f.fVar35)
            412
        }
        417 -> {
            177
        }
        418 -> {
            if ((b((f.fVar35) <= (f.fVar22))) != 0) 417 else 176
        }
        419 -> {
            if ((b((f.fVar28) < (DAT_0012cdf0))) != 0) 415 else 418
        }
        420 -> {
            f.fVar70 = f32(f32(((4.5) - (f.dVar63))))
            411
        }
        421 -> {
            180
        }
        422 -> {
            if ((b((1.0) < (((4.5) - (f.dVar63))))) != 0) 421 else 420
        }
        423 -> {
            if ((b((((f.dVar49) + (-(4.5)))) < (0.5))) != 0) 419 else 177
        }
        424 -> {
            219
        }
        425 -> {
            f.fVar22 = f32(((((9.0) - (f.fVar22))) - (f.fVar55)))
            424
        }
        426 -> {
            if ((b(((b(((b(((b((f.fVar55) < (f.fVar22))) != 0) && ((b((((f.dVar31) + (-(4.5)))) < (0.0))) != 0))) != 0) && ((b((f.fVar28) < (DAT_0012ccb8))) != 0))) != 0) && ((b((f.fVar60) < (1.0))) != 0))) != 0) 425 else 423
        }
        427 -> {
            316
        }
        428 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(4.5)))))) != 0) 427 else 426
        }
        429 -> {
            f.fVar70 = f32(0.0)
            428
        }
        430 -> {
            if ((b(((b((f.fVar52) < (6.5))) != 0) && ((b((f.fVar79) < (6.5))) != 0))) != 0) 429 else 410
        }
        431 -> {
            316
        }
        432 -> {
            f.fVar70 = f32(((3.5) - (f.param_4)))
            431
        }
        433 -> {
            182
        }
        434 -> {
            if ((b((2.0) <= (f.fVar55))) != 0) 433 else 175
        }
        435 -> {
            f.dVar34 = f.dVar38
            434
        }
        436 -> {
            f.dVar77 = DAT_0012cde0
            435
        }
        437 -> {
            316
        }
        438 -> {
            if ((b((3.5) <= (f.param_4))) != 0) 437 else 436
        }
        439 -> {
            f.fVar70 = f32(0.0)
            438
        }
        440 -> {
            202
        }
        441 -> {
            f.dVar62 = ((DAT_0012cde0) - (f.dVar31))
            440
        }
        442 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012ce50))) < (0.0))) != 0) && ((b((f.fVar28) < (1.0))) != 0))) != 0) 441 else 439
        }
        443 -> {
            202
        }
        444 -> {
            173
        }
        445 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (DAT_0012ce50))))) != 0) || ((b((0.5) <= (f.fVar28))) != 0))) != 0) 444 else 443
        }
        446 -> {
            f.dVar62 = ((((((DAT_0012d010) - (f.dVar63))) - (f.dVar31))) * (0.5))
            445
        }
        447 -> {
            if ((b((((f.dVar63) + (DAT_0012ce50))) < (0.0))) != 0) 446 else 442
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep14(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        448 -> {
            172
        }
        449 -> {
            if ((b(((b(((b((f.fVar23) < (5.5))) != 0) && ((b((f.fVar52) < (7.0))) != 0))) != 0) && ((b((f.fVar79) < (7.0))) != 0))) != 0) 448 else 174
        }
        450 -> {
            202
        }
        451 -> {
            f.dVar62 = ((f.dVar62) * (0.5))
            450
        }
        452 -> {
            f.dVar62 = ((((((DAT_0012cd18) - (f.dVar63))) - (f.dVar31))) * (0.5))
            173
        }
        453 -> {
            202
        }
        454 -> {
            f.dVar62 = ((((((DAT_0012cd18) - (f.dVar63))) - (f.dVar31))) * (0.5))
            453
        }
        455 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012cf58))) < (0.0))) != 0) && ((b((f.fVar28) < (DAT_0012cdf0))) != 0))) != 0) 454 else 452
        }
        456 -> {
            182
        }
        457 -> {
            202
        }
        458 -> {
            f.dVar62 = ((DAT_0012cdf8) - (f.dVar38))
            457
        }
        459 -> {
            if ((b((2.0) <= (f.fVar55))) != 0) 458 else 456
        }
        460 -> {
            f.dVar34 = f.dVar38
            459
        }
        461 -> {
            f.dVar77 = DAT_0012cde0
            460
        }
        462 -> {
            316
        }
        463 -> {
            if ((b(((b((DAT_0012cdf8) <= (f.dVar38))) != 0) || ((b((7.5) <= (f.fVar52))) != 0))) != 0) 462 else 461
        }
        464 -> {
            f.fVar70 = f32(0.0)
            463
        }
        465 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (DAT_0012cf58))))) != 0) || ((run { run { f.dVar77 = DAT_0012cde0; DAT_0012cde0 }; b((1.0) <= (f.fVar28)) }) != 0))) != 0) 464 else 456
        }
        466 -> {
            if ((b((0.0) <= (((f.dVar63) + (DAT_0012cf58))))) != 0) 465 else 455
        }
        467 -> {
            174
        }
        468 -> {
            if ((b((5.5) <= (f.fVar23))) != 0) 467 else 172
        }
        469 -> {
            if ((b((f.fVar79) < (6.0))) != 0) 468 else 449
        }
        470 -> {
            165
        }
        471 -> {
            129
        }
        472 -> {
            166
        }
        473 -> {
            if ((b(((b((0.0) <= (((f.fVar55) + (-(3.0)))))) != 0) || ((b((DAT_0012ccb8) <= (f.fVar28))) != 0))) != 0) 472 else 471
        }
        474 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.0))) != 0) 473 else 470
        }
        475 -> {
            if ((b(((b((8.0) < (f.fVar52))) != 0) && ((b((DAT_0012cc40) < (f.fVar28))) != 0))) != 0) 474 else 469
        }
        476 -> {
            316
        }
        477 -> {
            202
        }
        478 -> {
            f.dVar62 = ((DAT_0012ce18) - (f.dVar49))
            477
        }
        479 -> {
            182
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep15(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        480 -> {
            if ((b(((b((1.0) <= (f.fVar55))) != 0) || ((b((0.0) <= (((f.dVar49) + (DAT_0012d018))))) != 0))) != 0) 479 else 478
        }
        481 -> {
            if ((b((((f.dVar31) + (DAT_0012d018))) < (0.0))) != 0) 480 else 476
        }
        482 -> {
            f.fVar70 = f32(0.0)
            481
        }
        483 -> {
            if ((b(((b(((b(((b((0) < (f.iVar16))) != 0) && ((b((8.0) < (f.fVar52))) != 0))) != 0) && ((b((0) < (f.iVar17))) != 0))) != 0) && ((b(((b(((b((8.0) < (f.fVar79))) != 0) && ((b((f.fVar79) < (f.fVar52))) != 0))) != 0) && ((b((12.5) < (f.fVar57))) != 0))) != 0))) != 0) 482 else 475
        }
        484 -> {
            202
        }
        485 -> {
            f.dVar62 = ((((f.dVar49) - (f.dVar63))) * (0.5))
            484
        }
        486 -> {
            f.dVar49 = ((7.6) - (f.dVar63))
            171
        }
        487 -> {
            169
        }
        488 -> {
            f.dVar63 = 3.8
            487
        }
        489 -> {
            if ((b((0.5) <= (((f.dVar63) + (-(3.8)))))) != 0) 488 else 486
        }
        490 -> {
            202
        }
        491 -> {
            f.dVar62 = ((((((7.6) - (f.dVar38))) - (f.dVar49))) * (0.5))
            490
        }
        492 -> {
            if ((b((((f.dVar49) + (-(3.8)))) < (0.0))) != 0) 170 else 489
        }
        493 -> {
            f.dVar38 = f.dVar31
            492
        }
        494 -> {
            316
        }
        495 -> {
            f.fVar70 = f32(((3.8) - (f.fVar36)))
            494
        }
        496 -> {
            if ((b(((b((f.dVar38) < (3.8))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((((f.param_4) + (0.0))) < (3.8)) }) != 0))) != 0) 495 else 494
        }
        497 -> {
            f.fVar70 = f32(0.0)
            496
        }
        498 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(3.8)))))) != 0) 497 else 493
        }
        499 -> {
            143
        }
        500 -> {
            f.dVar75 = 3.8
            499
        }
        501 -> {
            170
        }
        502 -> {
            if ((b((((f.dVar49) + (-(3.8)))) < (0.5))) != 0) 501 else 500
        }
        503 -> {
            f.dVar38 = f.dVar63
            502
        }
        504 -> {
            202
        }
        505 -> {
            f.dVar62 = ((((f.dVar63) - (f.dVar31))) * (0.5))
            504
        }
        506 -> {
            f.dVar63 = ((7.6) - (f.dVar63))
            169
        }
        507 -> {
            if ((b((f.fVar28) < (1.0))) != 0) 506 else 503
        }
        508 -> {
            if ((b(((b((((f.dVar31) + (-(3.8)))) < (0.0))) != 0) && ((b(((b((0.5) < (f.fVar55))) != 0) || ((b((f.fVar28) < (0.85))) != 0))) != 0))) != 0) 507 else 500
        }
        509 -> {
            if ((b((((f.dVar63) + (-(3.8)))) < (0.0))) != 0) 508 else 498
        }
        510 -> {
            if ((b(((b(((b(((b((f.fVar52) < (8.0))) != 0) && ((b((f.iVar19) == (1))) != 0))) != 0) && ((b((f.fVar52) < (7.0))) != 0))) != 0) && ((b((((f.fVar40) - (readF32(f.param_1.plus(0x268))))) < (4.0))) != 0))) != 0) 509 else 483
        }
        511 -> {
            147
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep16(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        512 -> {
            f.dVar77 = DAT_0012cde0
            511
        }
        513 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012ce50))
            512
        }
        514 -> {
            178
        }
        515 -> {
            143
        }
        516 -> {
            if ((b((0.0) <= (f.dVar38))) != 0) 515 else 514
        }
        517 -> {
            if ((b((((f.dVar63) + (DAT_0012ce50))) < (0.0))) != 0) 167 else 168
        }
        518 -> {
            f.dVar53 = DAT_0012d010
            517
        }
        519 -> {
            f.dVar75 = DAT_0012cde0
            518
        }
        520 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012ce50))
            519
        }
        521 -> {
            147
        }
        522 -> {
            167
        }
        523 -> {
            if ((b((((f.dVar63) + (DAT_0012d020))) < (0.0))) != 0) 522 else 521
        }
        524 -> {
            f.dVar77 = DAT_0012cde8
            523
        }
        525 -> {
            f.dVar53 = DAT_0012d028
            524
        }
        526 -> {
            f.dVar75 = DAT_0012cde8
            525
        }
        527 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012d020))
            526
        }
        528 -> {
            if ((b((1.5) <= (f.fVar55))) != 0) 527 else 520
        }
        529 -> {
            147
        }
        530 -> {
            131
        }
        531 -> {
            f.dVar63 = ((DAT_0012ce48) - (f.dVar63))
            530
        }
        532 -> {
            143
        }
        533 -> {
            if ((b((0.0) <= (f.dVar38))) != 0) 532 else 531
        }
        534 -> {
            f.dVar75 = DAT_0012ce18
            533
        }
        535 -> {
            if ((b((((f.dVar63) + (DAT_0012d018))) < (0.0))) != 0) 534 else 529
        }
        536 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012d018))
            535
        }
        537 -> {
            if ((b(((b((7.5) < (f.fVar52))) != 0) && ((b((7.5) < (f.fVar79))) != 0))) != 0) 536 else 528
        }
        538 -> {
            if ((b((0.35) < (readF32(f.param_1.plus(0x1a0))))) != 0) 537 else 510
        }
        539 -> {
            f.dVar77 = DAT_0012ce18
            538
        }
        540 -> {
            316
        }
        541 -> {
            f.fVar70 = f32(((3.0) - (f.fVar22)))
            540
        }
        542 -> {
            157
        }
        543 -> {
            if ((b((((f.fVar35) + (-(3.0)))) < (0.0))) != 0) 542 else 166
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep17(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        544 -> {
            f.fVar54 = f32(f.fVar35)
            543
        }
        545 -> {
            129
        }
        546 -> {
            if ((b(((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) && ((b(((b((f.param_4) < (1.0))) != 0) || ((b((f.dVar53) < (DAT_0012cdf0))) != 0))) != 0))) != 0) 545 else 544
        }
        547 -> {
            316
        }
        548 -> {
            200
        }
        549 -> {
            if ((b((((f.param_4) + (0.0))) < (3.0))) != 0) 548 else 547
        }
        550 -> {
            f.fVar70 = f32(0.0)
            549
        }
        551 -> {
            f.fVar71 = f32(f.fVar36)
            550
        }
        552 -> {
            109
        }
        553 -> {
            if ((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) 552 else 551
        }
        554 -> {
            if ((b((0.0) <= (((f.fVar22) + (-(3.0)))))) != 0) 165 else 546
        }
        555 -> {
            162
        }
        556 -> {
            if ((b(((b((f.dVar33) <= (DAT_0012cf28))) != 0) || ((b((1.0) <= (f.fVar73))) != 0))) != 0) 555 else 554
        }
        557 -> {
            162
        }
        558 -> {
            if ((b((2.0) <= (f.fVar55))) != 0) 557 else 164
        }
        559 -> {
            158
        }
        560 -> {
            153
        }
        561 -> {
            151
        }
        562 -> {
            219
        }
        563 -> {
            f.fVar22 = f32(((((7.0) - (f.fVar54))) - (f.fVar22)))
            562
        }
        564 -> {
            f.fVar54 = f32(f.fVar55)
            563
        }
        565 -> {
            if ((b((1.0) < (f.fVar55))) != 0) 564 else 563
        }
        566 -> {
            f.fVar54 = f32(f.fVar35)
            565
        }
        567 -> {
            if ((b(((b((DAT_0012ccb8) < (f.dVar53))) != 0) && ((b((((f.dVar49) + (-(3.5)))) < (0.5))) != 0))) != 0) 566 else 561
        }
        568 -> {
            if ((b(((b(((b((1.0) <= (f.fVar60))) != 0) || ((b((f.fVar22) <= (f.fVar55))) != 0))) != 0) || ((b(((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) || ((b((DAT_0012ccb8) <= (f.dVar53))) != 0))) != 0))) != 0) 567 else 560
        }
        569 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 568 else 559
        }
        570 -> {
            264
        }
        571 -> {
            f.dVar62 = ((((f.dVar38) - (f.dVar63))) - (f.dVar31))
            570
        }
        572 -> {
            f.dVar38 = 7.8
            163
        }
        573 -> {
            171
        }
        574 -> {
            f.dVar49 = ((7.8) - (f.dVar49))
            573
        }
        575 -> {
            f.dVar49 = ((7.8) - (f.dVar31))
            573
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep18(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        576 -> {
            if ((b((f.fVar55) <= (1.0))) != 0) 574 else 575
        }
        577 -> {
            180
        }
        578 -> {
            if ((b(((b((f.dVar53) <= (DAT_0012ccb8))) != 0) || ((b((0.5) <= (((f.dVar49) + (-(3.9)))))) != 0))) != 0) 577 else 576
        }
        579 -> {
            if ((b(((b(((b(((b((1.0) <= (f.fVar60))) != 0) || ((b((f.fVar22) <= (f.fVar55))) != 0))) != 0) || ((b((0.0) <= (((f.dVar31) + (-(3.9)))))) != 0))) != 0) || ((b((DAT_0012ccb8) <= (f.dVar53))) != 0))) != 0) 578 else 572
        }
        580 -> {
            181
        }
        581 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(3.9)))))) != 0) 580 else 579
        }
        582 -> {
            if ((b(((b((f.fVar79) < (6.0))) != 0) && ((b((f.fVar57) < (9.0))) != 0))) != 0) 581 else 569
        }
        583 -> {
            316
        }
        584 -> {
            200
        }
        585 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.0))) != 0) 584 else 583
        }
        586 -> {
            f.fVar70 = f32(0.0)
            585
        }
        587 -> {
            if ((b((1.0) <= (f.fVar28))) != 0) 586 else 582
        }
        588 -> {
            164
        }
        589 -> {
            if ((b(((b((f.fVar55) < (2.0))) != 0) && ((b((7.0) < (f.fVar79))) != 0))) != 0) 588 else 162
        }
        590 -> {
            if ((b((f.fVar52) <= (7.0))) != 0) 589 else 558
        }
        591 -> {
            if ((b(((b((f.fVar54) < (10.0))) != 0) && ((b(((b((0xc) < (readI32(f.param_1.plus(0x1f8))))) != 0) && ((run { run { f.dVar53 = f.fVar28; f.fVar28 }; b((f.dVar53) < (1.2)) }) != 0))) != 0))) != 0) 590 else 539
        }
        592 -> {
            if ((b(((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((readI32(f.param_1.plus(0x188))) < (0x19))) != 0))) != 0) || ((b(((b(((b((10.0) <= (f.fVar26))) != 0) || ((b((readI32(f.param_1.plus(0x1f8))) < (0x37))) != 0))) != 0) && ((b(((b((DAT_0012cd18) <= (f.dVar33))) != 0) || ((b((1.2) <= (f.fVar28))) != 0))) != 0))) != 0))) != 0) 591 else 430
        }
        593 -> {
            140
        }
        594 -> {
            f.fVar24 = f32(((f.fVar24) - (f.fVar22)))
            593
        }
        595 -> {
            316
        }
        596 -> {
            f.fVar70 = f32(((4.0) - (f.fVar22)))
            595
        }
        597 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(4.0)))))) != 0) 596 else 161
        }
        598 -> {
            316
        }
        599 -> {
            f.fVar70 = f32(((4.0) - (f.fVar55)))
            598
        }
        600 -> {
            if ((b((((f.dVar31) + (-(4.0)))) < (0.0))) != 0) 599 else 598
        }
        601 -> {
            f.fVar70 = f32(0.0)
            600
        }
        602 -> {
            if ((b(((b((f.fVar22) <= (1.0))) != 0) || ((b((0.5) <= (((f.dVar63) + (-(4.0)))))) != 0))) != 0) 601 else 597
        }
        603 -> {
            147
        }
        604 -> {
            167
        }
        605 -> {
            if ((b(((b((1.0) < (f.fVar22))) != 0) && ((run { run { f.dVar53 = DAT_0012d008; DAT_0012d008 }; b((((f.dVar63) + (DAT_0012ce58))) < (0.5)) }) != 0))) != 0) 604 else 603
        }
        606 -> {
            f.dVar77 = DAT_0012ce60
            605
        }
        607 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012ce58))
            606
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep19(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        608 -> {
            if ((b((f.fVar28) < (DAT_0012ccb8))) != 0) 607 else 602
        }
        609 -> {
            if ((b(((b(((b(((b(((b((f.fVar54) < (6.0))) != 0) && ((b((0x18) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) && ((b((f.fVar60) < (0.7))) != 0))) != 0) && ((b(((b((f.dVar33) < (6.8))) != 0) && ((b((f.fVar80) < (0.5))) != 0))) != 0))) != 0) && ((b((((f.fVar40) - (readF32(f.param_1.plus(0x268))))) < (3.0))) != 0))) != 0) 608 else 592
        }
        610 -> {
            f.fVar24 = f32(8.0)
            609
        }
        611 -> {
            264
        }
        612 -> {
            f.dVar62 = ((((DAT_0012d010) - (f.dVar63))) - (f.dVar31))
            611
        }
        613 -> {
            202
        }
        614 -> {
            f.dVar62 = ((DAT_0012cde0) - (f.dVar63))
            613
        }
        615 -> {
            if ((b((0.0) <= (((f.dVar31) + (DAT_0012ce50))))) != 0) 614 else 612
        }
        616 -> {
            168
        }
        617 -> {
            if ((b((0.0) <= (((f.dVar63) + (DAT_0012ce50))))) != 0) 616 else 615
        }
        618 -> {
            f.dVar62 = ((3.5) - (f.dVar31))
            611
        }
        619 -> {
            316
        }
        620 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) 619 else 618
        }
        621 -> {
            f.fVar70 = f32(0.0)
            620
        }
        622 -> {
            151
        }
        623 -> {
            140
        }
        624 -> {
            f.fVar24 = f32(((7.0) - (f.fVar22)))
            623
        }
        625 -> {
            if ((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) 624 else 622
        }
        626 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 160 else 621
        }
        627 -> {
            if ((b(((b((f.fVar55) <= (2.5))) != 0) || ((b((3.5) <= (f.fVar55))) != 0))) != 0) 617 else 626
        }
        628 -> {
            316
        }
        629 -> {
            131
        }
        630 -> {
            f.dVar63 = 4.1
            629
        }
        631 -> {
            f.dVar63 = ((8.2) - (f.dVar63))
            629
        }
        632 -> {
            if ((b((0.5) <= (((f.dVar63) + (-(4.1)))))) != 0) 630 else 631
        }
        633 -> {
            if ((b((((f.dVar31) + (-(4.1)))) < (0.0))) != 0) 632 else 628
        }
        634 -> {
            f.fVar70 = f32(0.0)
            633
        }
        635 -> {
            202
        }
        636 -> {
            f.dVar62 = ((4.1) - (f.dVar63))
            635
        }
        637 -> {
            183
        }
        638 -> {
            f.dVar38 = 8.2
            637
        }
        639 -> {
            if ((b((((f.dVar31) + (-(4.1)))) < (0.0))) != 0) 638 else 636
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep20(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        640 -> {
            if ((b((((f.dVar63) + (-(4.1)))) < (0.0))) != 0) 639 else 634
        }
        641 -> {
            156
        }
        642 -> {
            if ((b((10.0) <= (f.fVar26))) != 0) 641 else 640
        }
        643 -> {
            f.fVar70 = f32(((2.5) - (f.fVar55)))
            628
        }
        644 -> {
            if ((b((((f.dVar31) + (-(2.5)))) < (0.0))) != 0) 643 else 628
        }
        645 -> {
            f.fVar70 = f32(0.0)
            644
        }
        646 -> {
            140
        }
        647 -> {
            f.fVar24 = f32(((5.0) - (f.fVar22)))
            646
        }
        648 -> {
            152
        }
        649 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(2.5)))))) != 0) 648 else 159
        }
        650 -> {
            if ((b((((f.dVar63) + (-(2.5)))) < (0.0))) != 0) 649 else 645
        }
        651 -> {
            158
        }
        652 -> {
            160
        }
        653 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 652 else 651
        }
        654 -> {
            if ((b((f.fVar26) < (10.0))) != 0) 653 else 650
        }
        655 -> {
            if ((b((f.iVar19) == (1))) != 0) 642 else 654
        }
        656 -> {
            if ((b(((b((7.5) <= (f.fVar79))) != 0) || ((b((9.0) <= (f.fVar57))) != 0))) != 0) 655 else 627
        }
        657 -> {
            316
        }
        658 -> {
            f.fVar70 = f32(((3.0) - (f.fVar54)))
            657
        }
        659 -> {
            if ((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) 157 else 657
        }
        660 -> {
            f.fVar70 = f32(0.0)
            659
        }
        661 -> {
            f.fVar54 = f32(f.fVar55)
            660
        }
        662 -> {
            150
        }
        663 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.0))) != 0) 662 else 661
        }
        664 -> {
            175
        }
        665 -> {
            if ((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) 664 else 657
        }
        666 -> {
            f.fVar70 = f32(0.0)
            665
        }
        667 -> {
            f.param_4 = f32(f.fVar55)
            666
        }
        668 -> {
            148
        }
        669 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 668 else 158
        }
        670 -> {
            if ((b(((b((3.5) <= (f.fVar55))) != 0) || ((b((0.3) <= (f.dVar48))) != 0))) != 0) 156 else 669
        }
        671 -> {
            if ((b(((b((f.fVar79) < (7.5))) != 0) && ((b((DAT_0012cca8) < (f.fVar80))) != 0))) != 0) 670 else 656
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep21(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        672 -> {
            316
        }
        673 -> {
            f.fVar70 = f32(((3.5) - (f.fVar22)))
            672
        }
        674 -> {
            138
        }
        675 -> {
            if ((b(((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) && ((b((f.fVar28) < (DAT_0012cdc0))) != 0))) != 0) 674 else 151
        }
        676 -> {
            158
        }
        677 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(3.5)))))) != 0) 676 else 675
        }
        678 -> {
            155
        }
        679 -> {
            if ((b(((b(((b((4.0) <= (f.fVar40))) != 0) || ((b((f.iVar21) < (0x1f))) != 0))) != 0) || ((b(((b((7.8) < (f.dVar33))) != 0) && ((b(((b((f.iVar21) < (0x31))) != 0) || ((b((0.35) <= (f.fVar28))) != 0))) != 0))) != 0))) != 0) 678 else 677
        }
        680 -> {
            f.fVar70 = f32(f32(f.dVar62))
            672
        }
        681 -> {
            114
        }
        682 -> {
            if ((b((1.0) <= (f.fVar28))) != 0) 681 else 680
        }
        683 -> {
            f.dVar62 = ((3.5) - (f.dVar31))
            682
        }
        684 -> {
            if ((b(((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) && ((b((DAT_0012cf98) < (((f.dVar31) + (DAT_0012ce50))))) != 0))) != 0) 683 else 672
        }
        685 -> {
            f.fVar70 = f32(0.0)
            684
        }
        686 -> {
            154
        }
        687 -> {
            if ((b(((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) && ((b((f.fVar28) < (1.0))) != 0))) != 0) 686 else 685
        }
        688 -> {
            148
        }
        689 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 688 else 687
        }
        690 -> {
            f.fVar70 = f32(((((3.0) - (f.fVar55))) * (0.5)))
            672
        }
        691 -> {
            if ((b(((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) && ((b(((b((DAT_0012cf98) < (((f.dVar31) + (DAT_0012ce50))))) != 0) && ((run { run { f.fVar70 = f32(((3.0) - (f.fVar55))); f32(((3.0) - (f.fVar55))) }; b((1.0) <= (f.fVar28)) }) != 0))) != 0))) != 0) 690 else 672
        }
        692 -> {
            f.fVar70 = f32(0.0)
            691
        }
        693 -> {
            109
        }
        694 -> {
            if ((b(((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) && ((b((f.fVar28) < (1.0))) != 0))) != 0) 693 else 692
        }
        695 -> {
            150
        }
        696 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.0))) != 0) 695 else 694
        }
        697 -> {
            if ((b(((b((f.fVar26) <= (11.0))) != 0) || ((b(((b(((b((f.fVar52) <= (8.5))) != 0) && ((b((f.fVar79) <= (8.5))) != 0))) != 0) || ((b((60.0) <= (f.fVar27))) != 0))) != 0))) != 0) 689 else 696
        }
        698 -> {
            f.fVar70 = f32(0.0)
            672
        }
        699 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 698 else 672
        }
        700 -> {
            f.fVar70 = f32(((2.5) - (f.fVar55)))
            699
        }
        701 -> {
            f.bVar8 = b((b((f.dVar38) < (0.0))) != 0)
            700
        }
        702 -> {
            if ((b(((b((DAT_0012cf98) < (f.dVar38))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar38).isNaN())) != 0)) }) != 0))) != 0) 701 else 700
        }
        703 -> {
            f.bVar8 = b((0) != 0)
            702
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep22(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        704 -> {
            f.fVar70 = f32(((2.5) - (f.fVar55)))
            672
        }
        705 -> {
            if ((b(((b((0.0) <= (f.dVar38))) != 0) || ((b((1.0) <= (f.fVar28))) != 0))) != 0) 703 else 704
        }
        706 -> {
            f.fVar70 = f32(((2.5) - (f.fVar22)))
            672
        }
        707 -> {
            159
        }
        708 -> {
            if ((b((f.dVar38) < (0.0))) != 0) 707 else 152
        }
        709 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(2.5)))))) != 0) 705 else 708
        }
        710 -> {
            f.dVar38 = ((f.dVar31) + (-(2.5)))
            709
        }
        711 -> {
            if ((b(((b((f.fVar52) <= (8.5))) != 0) || ((b((f.fVar79) <= (8.5))) != 0))) != 0) 697 else 710
        }
        712 -> {
            175
        }
        713 -> {
            if ((b((((f.param_4) + (0.0))) < (3.5))) != 0) 712 else 672
        }
        714 -> {
            f.fVar70 = f32(0.0)
            713
        }
        715 -> {
            f.fVar70 = f32(((3.5) - (f.fVar55)))
            672
        }
        716 -> {
            153
        }
        717 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.5))) != 0) 716 else 154
        }
        718 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) || ((b((1.0) <= (f.fVar28))) != 0))) != 0) 714 else 717
        }
        719 -> {
            219
        }
        720 -> {
            f.fVar22 = f32(((((7.0) - (f.fVar22))) - (f.fVar55)))
            719
        }
        721 -> {
            151
        }
        722 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) || ((b((1.2) <= (f.fVar28))) != 0))) != 0) 721 else 153
        }
        723 -> {
            if ((b(((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) && ((b((f.fVar79) < (7.5))) != 0))) != 0) 722 else 718
        }
        724 -> {
            180
        }
        725 -> {
            198
        }
        726 -> {
            f.dVar38 = 7.8
            725
        }
        727 -> {
            if ((b(((b((((f.dVar31) + (-(3.9)))) < (0.0))) != 0) && ((b((f.fVar28) < (0.85))) != 0))) != 0) 726 else 724
        }
        728 -> {
            127
        }
        729 -> {
            f.bVar8 = b((b((f.fVar28) < (1.0))) != 0)
            728
        }
        730 -> {
            f.fVar70 = f32(((3.5) - (f.fVar55)))
            729
        }
        731 -> {
            f.dVar38 = ((f.dVar31) + (-(3.5)))
            730
        }
        732 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(3.9)))))) != 0) 731 else 727
        }
        733 -> {
            if ((b(((b((f.fVar79) < (6.5))) != 0) || ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((0x24) < (f.iVar21)) }) != 0))) != 0) 732 else 672
        }
        734 -> {
            if ((b((readF32(f.param_1.plus(0x26c))) < (11.0))) != 0) 723 else 733
        }
        735 -> {
            if ((b((7.5) <= (f.fVar52))) != 0) 711 else 734
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep23(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        736 -> {
            if ((b(((b((f.fVar79) <= (f.fVar52))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) != (0.0))) != 0))) != 0) 679 else 735
        }
        737 -> {
            if ((b((0xb) < (f.iVar21))) != 0) 736 else 155
        }
        738 -> {
            f.iVar21 = readI32(f.param_1.plus(0x1f8))
            737
        }
        739 -> {
            316
        }
        740 -> {
            f.fVar70 = f32(((4.5) - (f.fVar35)))
            739
        }
        741 -> {
            125
        }
        742 -> {
            if ((b((0.5) <= (((f.dVar49) + (-(4.5)))))) != 0) 741 else 740
        }
        743 -> {
            124
        }
        744 -> {
            if ((b(((b((((f.dVar31) + (-(4.5)))) < (0.0))) != 0) && ((b((f.fVar28) < (0.5))) != 0))) != 0) 743 else 742
        }
        745 -> {
            158
        }
        746 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(4.5)))))) != 0) 745 else 744
        }
        747 -> {
            if ((b(((b((2.0) < (f.fVar70))) != 0) || ((b(((b((f.dVar33) < (DAT_0012cd18))) != 0) && ((b((f.dVar32) < (DAT_0012cd18))) != 0))) != 0))) != 0) 746 else 738
        }
        748 -> {
            if ((b(((b(((b((f.fVar40) < (4.5))) != 0) && ((b((0x24) < (readI32(f.param_1.plus(0x188))))) != 0))) != 0) && ((b((3.5) < (f.fVar22))) != 0))) != 0) 747 else 738
        }
        749 -> {
            316
        }
        750 -> {
            f.fVar70 = f32(f32(((f.dVar77) - (f.dVar63))))
            749
        }
        751 -> {
            316
        }
        752 -> {
            f.fVar70 = f32(f32(((f.dVar77) - (f.dVar49))))
            751
        }
        753 -> {
            if ((b((((f.dVar49) + (f.dVar53))) < (0.5))) != 0) 752 else 750
        }
        754 -> {
            113
        }
        755 -> {
            f.dVar38 = f.dVar31
            754
        }
        756 -> {
            f.dVar62 = ((f.dVar62) - (f.dVar63))
            755
        }
        757 -> {
            if ((b(((b((f.fVar55) < (f.fVar22))) != 0) && ((b((kotlin.math.abs(f.fVar28)) < (0.5))) != 0))) != 0) 756 else 753
        }
        758 -> {
            if ((b((f.dVar38) < (0.0))) != 0) 757 else 750
        }
        759 -> {
            147
        }
        760 -> {
            if ((b((0.0) <= (((f.dVar63) + (f.dVar53))))) != 0) 759 else 758
        }
        761 -> {
            f.dVar38 = ((f.dVar31) + (f.dVar53))
            760
        }
        762 -> {
            f.dVar62 = DAT_0012d038
            761
        }
        763 -> {
            f.dVar53 = DAT_0012d030
            762
        }
        764 -> {
            f.dVar77 = DAT_0012ce00
            763
        }
        765 -> {
            if ((b((f.dVar32) < (6.8))) != 0) 764 else 761
        }
        766 -> {
            f.dVar62 = DAT_0012d010
            765
        }
        767 -> {
            f.dVar53 = DAT_0012ce50
            766
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep24(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        768 -> {
            f.dVar77 = DAT_0012cde0
            767
        }
        769 -> {
            149
        }
        770 -> {
            153
        }
        771 -> {
            151
        }
        772 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) 771 else 770
        }
        773 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 772 else 769
        }
        774 -> {
            if ((b(((b((10.0) < (f.fVar57))) != 0) && ((b((8.0) < (f.fVar54))) != 0))) != 0) 773 else 768
        }
        775 -> {
            146
        }
        776 -> {
            if ((b((((f.dVar49) + (DAT_0012d040))) < (0.0))) != 0) 775 else 749
        }
        777 -> {
            f.fVar70 = f32(0.0)
            776
        }
        778 -> {
            202
        }
        779 -> {
            f.dVar62 = ((DAT_0012cca0) - (f.dVar31))
            778
        }
        780 -> {
            if ((b(((b((f.fVar55) < (f.fVar22))) != 0) && ((b((((f.dVar31) + (DAT_0012d040))) < (0.0))) != 0))) != 0) 779 else 777
        }
        781 -> {
            143
        }
        782 -> {
            264
        }
        783 -> {
            f.dVar62 = ((DAT_0012cca0) - (f.dVar63))
            782
        }
        784 -> {
            163
        }
        785 -> {
            if ((b((f.fVar60) < (1.0))) != 0) 784 else 783
        }
        786 -> {
            f.dVar38 = DAT_0012d048
            785
        }
        787 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012d040))) < (0.0))) != 0) && ((b((f.dVar38) < (DAT_0012ccb8))) != 0))) != 0) 786 else 781
        }
        788 -> {
            if ((b((((f.dVar63) + (DAT_0012d040))) < (0.0))) != 0) 787 else 780
        }
        789 -> {
            if ((b(((b(((b((DAT_0012cdf0) <= (f.dVar38))) != 0) || ((b((6.5) <= (f.fVar52))) != 0))) != 0) || ((b((6.5) <= (f.fVar79))) != 0))) != 0) 774 else 788
        }
        790 -> {
            111
        }
        791 -> {
            f.fVar54 = f32(3.5)
            790
        }
        792 -> {
            if ((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) 791 else 749
        }
        793 -> {
            f.fVar70 = f32(0.0)
            792
        }
        794 -> {
            151
        }
        795 -> {
            138
        }
        796 -> {
            if ((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) 795 else 794
        }
        797 -> {
            if ((b(((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) && ((b((f.dVar38) < (DAT_0012ccb8))) != 0))) != 0) 148 else 149
        }
        798 -> {
            f.fVar70 = f32(((3.0) - (f.fVar55)))
            749
        }
        799 -> {
            if ((b((((f.fVar55) + (-(3.0)))) < (0.0))) != 0) 798 else 749
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep25(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        800 -> {
            f.fVar70 = f32(0.0)
            799
        }
        801 -> {
            129
        }
        802 -> {
            166
        }
        803 -> {
            if ((b((0.0) <= (((f.fVar55) + (-(3.0)))))) != 0) 802 else 801
        }
        804 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.0))) != 0) 150 else 800
        }
        805 -> {
            if ((b(((b((0.35) <= (f.dVar38))) != 0) || ((b((f.fVar57) <= (8.0))) != 0))) != 0) 797 else 804
        }
        806 -> {
            if ((b((f.fVar52) <= (f.fVar79))) != 0) 789 else 805
        }
        807 -> {
            if ((b(((b(((b((((f.fVar26) - (f.fVar22))) < (6.0))) != 0) && ((b((0x20) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) && ((b(((b((f.fVar52) < (7.5))) != 0) && ((run { run { f.dVar38 = f.fVar28; f.fVar28 }; b(((b((f.dVar38) < (0.6))) != 0) && ((b((f.fVar79) < (7.5))) != 0)) }) != 0))) != 0))) != 0) 806 else 748
        }
        808 -> {
            316
        }
        809 -> {
            182
        }
        810 -> {
            if ((b((f.dVar38) < (0.0))) != 0) 809 else 808
        }
        811 -> {
            f.fVar70 = f32(0.0)
            810
        }
        812 -> {
            143
        }
        813 -> {
            316
        }
        814 -> {
            202
        }
        815 -> {
            f.dVar62 = ((DAT_0012cca0) - (f.dVar49))
            814
        }
        816 -> {
            if ((b((((f.dVar49) + (DAT_0012d040))) < (0.5))) != 0) 146 else 813
        }
        817 -> {
            f.fVar70 = f32(0.0)
            816
        }
        818 -> {
            202
        }
        819 -> {
            f.dVar62 = ((((((f.dVar38) - (f.dVar63))) - (f.dVar31))) * (0.5))
            818
        }
        820 -> {
            if ((b((f.fVar28) < (DAT_0012cdf0))) != 0) 145 else 817
        }
        821 -> {
            f.dVar38 = DAT_0012d048
            820
        }
        822 -> {
            if ((b((f.dVar38) < (0.0))) != 0) 821 else 812
        }
        823 -> {
            if ((b((((f.dVar63) + (DAT_0012d040))) < (0.5))) != 0) 822 else 147
        }
        824 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012d040))
            823
        }
        825 -> {
            if ((b(((b(((b(((b((f.fVar40) < (2.0))) != 0) && ((b((f.fVar52) < (7.5))) != 0))) != 0) && ((b((f.fVar28) < (0.5))) != 0))) != 0) && ((b(((b((f.fVar79) < (7.5))) != 0) && ((b((0x3c) < (readI32(f.param_1.plus(0x188))))) != 0))) != 0))) != 0) 824 else 807
        }
        826 -> {
            f.dVar75 = DAT_0012cca0
            825
        }
        827 -> {
            202
        }
        828 -> {
            f.dVar62 = ((f.dVar75) - (f.dVar63))
            827
        }
        829 -> {
            145
        }
        830 -> {
            316
        }
        831 -> {
            202
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep26(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        832 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar49))
            831
        }
        833 -> {
            if ((b((((f.dVar49) + (DAT_0012ce58))) < (0.5))) != 0) 142 else 830
        }
        834 -> {
            f.fVar70 = f32(0.0)
            833
        }
        835 -> {
            if ((b(((b((0.35) <= (f.fVar28))) != 0) || ((run { run { f.dVar38 = DAT_0012d008; DAT_0012d008 }; b((0.85) <= (f.fVar60)) }) != 0))) != 0) 834 else 829
        }
        836 -> {
            if ((b((f.dVar38) < (0.0))) != 0) 835 else 143
        }
        837 -> {
            147
        }
        838 -> {
            if ((b((0.5) <= (((f.dVar63) + (DAT_0012ce58))))) != 0) 837 else 836
        }
        839 -> {
            f.dVar77 = DAT_0012ce60
            838
        }
        840 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012ce58))
            839
        }
        841 -> {
            144
        }
        842 -> {
            if ((b((f.iVar14) < (0x49))) != 0) 841 else 141
        }
        843 -> {
            144
        }
        844 -> {
            141
        }
        845 -> {
            if ((b(((b((0x48) < (f.iVar14))) != 0) && ((b((2.0) < (kotlin.math.abs(((f.fVar52) - (f.fVar79)))))) != 0))) != 0) 844 else 843
        }
        846 -> {
            if ((b(((b((7.5) <= (f.fVar52))) != 0) || ((b((7.5) <= (f.fVar79))) != 0))) != 0) 845 else 842
        }
        847 -> {
            if ((b(((b((f.fVar40) < (DAT_0012ce10))) != 0) && ((b((f.fVar28) < (0.6))) != 0))) != 0) 846 else 144
        }
        848 -> {
            f.fVar40 = f32(((f.fVar40) - (readF32(f.param_1.plus(0x268)))))
            847
        }
        849 -> {
            if ((b((2.0) < (f.fVar55))) != 0) 848 else 610
        }
        850 -> {
            316
        }
        851 -> {
            f.fVar70 = f32(((((f.fVar24) - (f.fVar55))) * (0.5)))
            850
        }
        852 -> {
            f.fVar24 = f32(((f.fVar24) - (f.fVar22)))
            140
        }
        853 -> {
            f.fVar24 = f32(6.0)
            139
        }
        854 -> {
            316
        }
        855 -> {
            200
        }
        856 -> {
            if ((b((kotlin.math.abs(((f.fVar22) - (f.fVar55)))) < (DAT_0012cc40))) != 0) 855 else 854
        }
        857 -> {
            f.fVar70 = f32(0.0)
            856
        }
        858 -> {
            f.fVar70 = f32(((f.fVar54) - (f.fVar55)))
            854
        }
        859 -> {
            f.fVar70 = f32(((3.0) - (f.fVar35)))
            854
        }
        860 -> {
            if ((b((f.fVar55) <= (f.fVar35))) != 0) 128 else 859
        }
        861 -> {
            f.fVar54 = f32(3.0)
            860
        }
        862 -> {
            if ((b((0.0) <= (f.fVar54))) != 0) 857 else 861
        }
        863 -> {
            f.fVar70 = f32(((3.0) - (f.fVar35)))
            854
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep27(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        864 -> {
            if ((b(((b((f.fVar35) <= (f.fVar55))) != 0) || ((b((0.0) <= (((f.dVar49) + (-(3.5)))))) != 0))) != 0) 862 else 863
        }
        865 -> {
            if ((b(((b((0.0) <= (f.fVar54))) != 0) || ((b((f.fVar22) <= (f.fVar55))) != 0))) != 0) 864 else 129
        }
        866 -> {
            316
        }
        867 -> {
            f.fVar70 = f32(0.0)
            866
        }
        868 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 867 else 866
        }
        869 -> {
            f.fVar70 = f32(((3.0) - (f.fVar55)))
            868
        }
        870 -> {
            f.bVar8 = b((b((f.fVar54) < (0.0))) != 0)
            869
        }
        871 -> {
            if ((b(((b((-(1.0)) < (f.fVar54))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar54).isNaN())) != 0)) }) != 0))) != 0) 870 else 869
        }
        872 -> {
            f.bVar8 = b((0) != 0)
            871
        }
        873 -> {
            if ((b((0.0) <= (((f.fVar22) + (-(3.0)))))) != 0) 872 else 865
        }
        874 -> {
            f.fVar54 = f32(((f.fVar55) + (-(3.0))))
            873
        }
        875 -> {
            316
        }
        876 -> {
            f.fVar70 = f32(0.0)
            875
        }
        877 -> {
            if ((b(!((f.bVar12) != 0))) != 0) 876 else 875
        }
        878 -> {
            f.bVar12 = b((b((f.dVar38) < (0.0))) != 0)
            877
        }
        879 -> {
            if ((b(((f.bVar8) != 0) && ((run { run { f.bVar12 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar38).isNaN())) != 0)) }) != 0))) != 0) 878 else 877
        }
        880 -> {
            f.bVar12 = b((0) != 0)
            879
        }
        881 -> {
            f.bVar8 = b((b((f.fVar55) < (f.param_4))) != 0)
            127
        }
        882 -> {
            if ((b(((b((f.fVar26) < (8.0))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.fVar55).isNaN())) != 0))) != 0) && ((b(!((b((f.param_4).isNaN())) != 0))) != 0)) }) != 0))) != 0) 881 else 127
        }
        883 -> {
            f.bVar8 = b((0) != 0)
            882
        }
        884 -> {
            f.dVar38 = ((f.dVar31) + (-(4.5)))
            883
        }
        885 -> {
            f.fVar70 = f32(((4.5) - (f.fVar55)))
            884
        }
        886 -> {
            202
        }
        887 -> {
            f.dVar62 = ((3.9) - (f.dVar31))
            886
        }
        888 -> {
            if ((b(((b((f.fVar55) < (f.param_4))) != 0) && ((b((((f.dVar31) + (-(3.9)))) < (0.0))) != 0))) != 0) 887 else 885
        }
        889 -> {
            316
        }
        890 -> {
            f.fVar70 = f32(((3.5) - (f.param_4)))
            889
        }
        891 -> {
            128
        }
        892 -> {
            if ((b((f.fVar55) < (f.param_4))) != 0) 891 else 890
        }
        893 -> {
            f.fVar54 = f32(3.5)
            892
        }
        894 -> {
            if ((b((((f.dVar38) + (-(3.5)))) < (0.0))) != 0) 893 else 888
        }
        895 -> {
            202
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep28(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        896 -> {
            f.dVar62 = ((((3.5) - (f.dVar42))) * (0.5))
            895
        }
        897 -> {
            if ((b(((b(((b((0.0) < (f.fVar78))) != 0) && ((b((3.0) < (f.fVar78))) != 0))) != 0) && ((b((((f.dVar42) + (-(3.5)))) < (0.0))) != 0))) != 0) 896 else 894
        }
        898 -> {
            264
        }
        899 -> {
            f.dVar62 = ((3.5) - (f.dVar59))
            898
        }
        900 -> {
            if ((b(((b((0.0) < (f.fVar41))) != 0) && ((b(((b((((f.fVar55) - (f.fVar41))) < (1.0))) != 0) && ((b((((f.dVar59) + (-(3.5)))) < (0.0))) != 0))) != 0))) != 0) 126 else 897
        }
        901 -> {
            154
        }
        902 -> {
            126
        }
        903 -> {
            if ((b(((b((0.0) < (f.fVar41))) != 0) && ((b(((b((((f.fVar55) - (f.fVar41))) < (1.0))) != 0) && ((b((((f.dVar59) + (-(3.5)))) < (0.0))) != 0))) != 0))) != 0) 902 else 901
        }
        904 -> {
            if ((b(((b((f.dVar53) < (0.0))) != 0) && ((b((f.fVar57) < (8.0))) != 0))) != 0) 903 else 900
        }
        905 -> {
            151
        }
        906 -> {
            316
        }
        907 -> {
            f.fVar70 = f32(0.0)
            906
        }
        908 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 907 else 906
        }
        909 -> {
            f.fVar70 = f32(((3.5) - (f.param_4)))
            908
        }
        910 -> {
            f.bVar8 = b((b((f.param_4) < (3.5))) != 0)
            909
        }
        911 -> {
            if ((b(((b((((f.param_4) + (0.0))) < (3.5))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_4).isNaN())) != 0)) }) != 0))) != 0) 910 else 909
        }
        912 -> {
            f.bVar8 = b((0) != 0)
            911
        }
        913 -> {
            if ((b((0.85) <= (((f.fVar55) - (f.fVar22))))) != 0) 912 else 905
        }
        914 -> {
            154
        }
        915 -> {
            264
        }
        916 -> {
            f.dVar62 = ((3.5) - (f.dVar49))
            915
        }
        917 -> {
            if ((b((f.fVar35) < (f.fVar55))) != 0) 916 else 914
        }
        918 -> {
            if ((b((f.dVar53) < (0.0))) != 0) 917 else 913
        }
        919 -> {
            316
        }
        920 -> {
            f.fVar70 = f32(((3.5) - (f.fVar35)))
            919
        }
        921 -> {
            if ((b(((b((f.fVar55) < (f.fVar35))) != 0) && ((b((((f.dVar49) + (-(3.5)))) < (0.0))) != 0))) != 0) 920 else 918
        }
        922 -> {
            138
        }
        923 -> {
            if ((b(((b((f.fVar55) < (f.fVar22))) != 0) && ((b((f.dVar53) < (0.0))) != 0))) != 0) 922 else 921
        }
        924 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.0))) != 0) 923 else 904
        }
        925 -> {
            f.dVar53 = ((f.dVar31) + (-(3.5)))
            924
        }
        926 -> {
            120
        }
        927 -> {
            f.bVar8 = b((b((f.dVar31) < (3.9))) != 0)
            926
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep29(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        928 -> {
            if ((b(((b((((f.dVar31) + (-(4.5)))) < (0.5))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar31).isNaN())) != 0)) }) != 0))) != 0) 927 else 926
        }
        929 -> {
            f.bVar8 = b((0) != 0)
            928
        }
        930 -> {
            f.fVar70 = f32(((4.5) - (f.fVar55)))
            929
        }
        931 -> {
            125
        }
        932 -> {
            124
        }
        933 -> {
            if ((b((((f.dVar31) + (-(4.5)))) < (0.5))) != 0) 932 else 931
        }
        934 -> {
            if ((b(((b((f.fVar28) < (0.5))) != 0) && ((b((((f.dVar63) + (-(4.5)))) < (0.5))) != 0))) != 0) 933 else 930
        }
        935 -> {
            if ((b(((b((3.5) < (f.fVar55))) != 0) && ((b(((b(((b((f.fVar26) < (10.0))) != 0) && ((b((3.5) < (f.fVar22))) != 0))) != 0) && ((b((f.fVar79) < (7.0))) != 0))) != 0))) != 0) 934 else 925
        }
        936 -> {
            if ((b(((b((f.dVar32) <= (7.8))) != 0) || ((b((0x35) < (readI32(f.param_1.plus(0x188))))) != 0))) != 0) 935 else 874
        }
        937 -> {
            316
        }
        938 -> {
            202
        }
        939 -> {
            f.dVar62 = ((DAT_0012cde0) - (f.dVar31))
            938
        }
        940 -> {
            if ((b(((b((f.dVar31) < (DAT_0012cdf8))) != 0) && ((b((((f.dVar31) + (DAT_0012ce50))) < (0.5))) != 0))) != 0) 939 else 937
        }
        941 -> {
            f.fVar70 = f32(0.0)
            940
        }
        942 -> {
            f.fVar70 = f32(f32(((DAT_0012cde0) - (f.dVar63))))
            937
        }
        943 -> {
            145
        }
        944 -> {
            if ((b((((f.dVar31) + (DAT_0012ce50))) < (0.5))) != 0) 943 else 942
        }
        945 -> {
            f.dVar38 = DAT_0012d010
            944
        }
        946 -> {
            if ((b((0.5) <= (((f.dVar63) + (DAT_0012ce50))))) != 0) 941 else 945
        }
        947 -> {
            if ((b(((b(((b((8.0) < (f.fVar52))) != 0) && ((b(((b(((b((8.0) < (f.fVar79))) != 0) && ((b((-(0.5)) < (f.fVar80))) != 0))) != 0) && ((b((readI32(f.param_1.plus(0x188))) < (0x42))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x268))) < (DAT_0012cde0))) != 0))) != 0) 946 else 936
        }
        948 -> {
            316
        }
        949 -> {
            f.fVar70 = f32(((4.5) - (f.fVar22)))
            948
        }
        950 -> {
            139
        }
        951 -> {
            f.fVar24 = f32(9.0)
            950
        }
        952 -> {
            if ((b(((b((((f.dVar31) + (-(4.5)))) < (0.0))) != 0) && ((b((f.fVar28) < (DAT_0012cc40))) != 0))) != 0) 124 else 125
        }
        953 -> {
            110
        }
        954 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(4.5)))))) != 0) 953 else 952
        }
        955 -> {
            if ((b(((b(((b(((b((0x24) < (f.iVar19))) != 0) && ((b((((f.dVar31) + (DAT_0012cdd0))) < (f.dVar63))) != 0))) != 0) && ((b((((readF32(f.param_1.plus(0x26c))) - (f.fVar40))) < (4.0))) != 0))) != 0) && ((b(((b(((b((f.fVar40) < (5.0))) != 0) && ((b((f.dVar33) < (DAT_0012cd18))) != 0))) != 0) && ((b((f.dVar32) < (7.3))) != 0))) != 0))) != 0) 954 else 947
        }
        956 -> {
            202
        }
        957 -> {
            f.dVar62 = ((DAT_0012cca0) - (f.dVar63))
            956
        }
        958 -> {
            202
        }
        959 -> {
            f.dVar62 = ((3.9) - (f.dVar63))
            958
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep30(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        960 -> {
            if ((b(((b((5.3) < (f.dVar53))) != 0) && ((b((f.dVar63) < (3.9))) != 0))) != 0) 959 else 123
        }
        961 -> {
            117
        }
        962 -> {
            if ((b(((b((5.3) < (f.dVar53))) != 0) && ((b((3.5) < (f.fVar55))) != 0))) != 0) 961 else 960
        }
        963 -> {
            if ((b((((f.dVar31) + (DAT_0012d040))) < (0.0))) != 0) 962 else 123
        }
        964 -> {
            130
        }
        965 -> {
            if ((b((0.0) <= (((f.dVar63) + (DAT_0012d040))))) != 0) 964 else 963
        }
        966 -> {
            if ((b(((b(((b(((b(((b((f.fVar55) <= (f.fVar22))) != 0) && ((b((f.fVar28) < (1.0))) != 0))) != 0) && ((b((0x1d) < (f.iVar19))) != 0))) != 0) && ((b(((b((f.fVar57) < (8.5))) != 0) && ((b((f.fVar54) < (6.0))) != 0))) != 0))) != 0) && ((b((f.dVar53) < (5.8))) != 0))) != 0) 965 else 955
        }
        967 -> {
            160
        }
        968 -> {
            154
        }
        969 -> {
            119
        }
        970 -> {
            f.fVar70 = f32(4.0)
            969
        }
        971 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) 970 else 968
        }
        972 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(3.5)))))) != 0) 971 else 967
        }
        973 -> {
            118
        }
        974 -> {
            if ((b((0x2a) < (f.iVar19))) != 0) 973 else 121
        }
        975 -> {
            316
        }
        976 -> {
            f.fVar70 = f32(0.0)
            975
        }
        977 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 976 else 975
        }
        978 -> {
            f.bVar8 = b((b((f.param_12) < (11.5))) != 0)
            120
        }
        979 -> {
            if ((b(((b((f.fVar55) < (4.0))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_12).isNaN())) != 0)) }) != 0))) != 0) 978 else 120
        }
        980 -> {
            f.bVar8 = b((0) != 0)
            979
        }
        981 -> {
            f.fVar70 = f32(((f.fVar70) - (f.fVar55)))
            980
        }
        982 -> {
            f.fVar70 = f32(4.5)
            119
        }
        983 -> {
            182
        }
        984 -> {
            if ((b((((f.dVar31) + (DAT_0012d040))) < (0.0))) != 0) 983 else 982
        }
        985 -> {
            116
        }
        986 -> {
            if ((b((((f.dVar63) + (DAT_0012d040))) < (0.0))) != 0) 985 else 984
        }
        987 -> {
            121
        }
        988 -> {
            if ((b(((b(((b((9.0) <= (f.fVar57))) != 0) || ((b((f.fVar22) == (f.fVar55))) != 0))) != 0) || ((b(((b((0.35) <= (f.fVar28))) != 0) || ((b(((b((7.5) <= (f.fVar52))) != 0) || ((b((7.5) <= (f.fVar79))) != 0))) != 0))) != 0))) != 0) 987 else 986
        }
        989 -> {
            316
        }
        990 -> {
            f.fVar70 = f32(f.fVar54)
            989
        }
        991 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 990 else 989
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep31(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        992 -> {
            f.fVar70 = f32(((4.5) - (f.fVar55)))
            991
        }
        993 -> {
            f.bVar8 = b((b((f.param_12) < (11.5))) != 0)
            992
        }
        994 -> {
            if ((b(((b((f.fVar55) < (4.0))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.param_12).isNaN())) != 0)) }) != 0))) != 0) 993 else 992
        }
        995 -> {
            f.bVar8 = b((0) != 0)
            994
        }
        996 -> {
            f.fVar70 = f32(((4.5) - (f.fVar55)))
            989
        }
        997 -> {
            if ((b((0.0) <= (((f.dVar31) + (DAT_0012d040))))) != 0) 995 else 996
        }
        998 -> {
            161
        }
        999 -> {
            125
        }
        1000 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(4.5)))))) != 0) 999 else 998
        }
        1001 -> {
            if ((b((((f.dVar63) + (-(4.5)))) < (0.0))) != 0) 1000 else 997
        }
        1002 -> {
            f.fVar24 = f32(9.0)
            1001
        }
        1003 -> {
            f.fVar54 = f32(f32(((3.9) - (f.dVar31))))
            1002
        }
        1004 -> {
            if ((b(((b(((b((f.fVar22) == (f.fVar55))) != 0) && ((run { run { f.fVar54 = f32(0.0); f32(0.0) }; b((1.0) < (((4.5) - (f.dVar31)))) }) != 0))) != 0) && ((run { run { f.fVar54 = f32(0.0); f32(0.0) }; b((((f.dVar31) + (-(4.5)))) < (0.0)) }) != 0))) != 0) 1003 else 1002
        }
        1005 -> {
            f.fVar54 = f32(0.0)
            1004
        }
        1006 -> {
            if ((b(((b((f.fVar52) < (7.5))) != 0) && ((b((f.fVar79) < (7.5))) != 0))) != 0) 1005 else 118
        }
        1007 -> {
            if ((b(((b((0x2e) < (f.iVar19))) != 0) && ((b((f.fVar57) < (9.5))) != 0))) != 0) 1006 else 974
        }
        1008 -> {
            316
        }
        1009 -> {
            f.fVar70 = f32(((((((((7.0) - (f.fVar67))) - (f.fVar41))) * (0.5))) * (0.5)))
            1008
        }
        1010 -> {
            202
        }
        1011 -> {
            f.dVar62 = ((((3.5) - (f.dVar83))) * (0.5))
            1010
        }
        1012 -> {
            if ((b((0.0) <= (((f.dVar59) + (-(3.5)))))) != 0) 1011 else 1009
        }
        1013 -> {
            126
        }
        1014 -> {
            if ((b((((f.dVar59) + (-(3.5)))) < (0.0))) != 0) 1013 else 1008
        }
        1015 -> {
            f.fVar70 = f32(0.0)
            1014
        }
        1016 -> {
            if ((b((((f.dVar83) + (-(3.5)))) < (0.0))) != 0) 1012 else 1015
        }
        1017 -> {
            if ((b(((b((f.fVar67) < (f.fVar22))) != 0) && ((b((0.0) < (f.fVar67))) != 0))) != 0) 1016 else 1007
        }
        1018 -> {
            122
        }
        1019 -> {
            if ((b(((b(((b((5.3) <= (f.dVar53))) != 0) || ((b((f.iVar19) < (0x25))) != 0))) != 0) || ((b((6.0) <= (f.fVar54))) != 0))) != 0) 1018 else 1017
        }
        1020 -> {
            264
        }
        1021 -> {
            f.dVar62 = ((((DAT_0012d048) - (f.dVar63))) - (f.dVar31))
            1020
        }
        1022 -> {
            123
        }
        1023 -> {
            if ((b((0.0) <= (((f.dVar31) + (DAT_0012d040))))) != 0) 1022 else 117
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep32(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1024 -> {
            130
        }
        1025 -> {
            if ((b((0.0) <= (((f.dVar63) + (DAT_0012d040))))) != 0) 1024 else 116
        }
        1026 -> {
            316
        }
        1027 -> {
            f.fVar70 = f32(f32(((f.dVar62) * (f.dVar38))))
            1026
        }
        1028 -> {
            f.dVar38 = 0.5
            115
        }
        1029 -> {
            f.dVar62 = ((f.dVar62) - (f.dVar38))
            114
        }
        1030 -> {
            f.dVar38 = f.dVar42
            113
        }
        1031 -> {
            f.dVar62 = ((DAT_0012d008) - (f.dVar62))
            1030
        }
        1032 -> {
            316
        }
        1033 -> {
            219
        }
        1034 -> {
            f.fVar22 = f32(((((7.0) - (f.fVar69))) - (f.fVar78)))
            1033
        }
        1035 -> {
            if ((b(((b(((b((((f.dVar42) + (-(3.5)))) < (0.0))) != 0) && ((b((((f.dVar62) + (-(3.5)))) < (0.0))) != 0))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((f.fVar45) < (0.85)) }) != 0))) != 0) 1034 else 1032
        }
        1036 -> {
            f.fVar70 = f32(0.0)
            1035
        }
        1037 -> {
            if ((b(((b(((b((0.0) <= (((f.dVar42) + (DAT_0012ce58))))) != 0) || ((b((0.0) <= (((f.dVar62) + (DAT_0012ce58))))) != 0))) != 0) || ((b((0.6) <= (f.fVar45))) != 0))) != 0) 1036 else 1031
        }
        1038 -> {
            316
        }
        1039 -> {
            if ((b((f.fVar78) <= (0.0))) != 0) 1038 else 1037
        }
        1040 -> {
            f.fVar70 = f32(0.0)
            1039
        }
        1041 -> {
            202
        }
        1042 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar31))
            1041
        }
        1043 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012ce58))) < (0.0))) != 0) && ((b(((b((f.fVar22) == (25.0))) != 0) || ((b((f.fVar28) < (0.85))) != 0))) != 0))) != 0) 1042 else 1040
        }
        1044 -> {
            202
        }
        1045 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar63))
            1044
        }
        1046 -> {
            142
        }
        1047 -> {
            if ((b((((f.dVar49) + (DAT_0012ce58))) < (0.0))) != 0) 1046 else 1045
        }
        1048 -> {
            if ((b((f.fVar55) < (f.fVar35))) != 0) 112 else 1045
        }
        1049 -> {
            264
        }
        1050 -> {
            f.dVar62 = ((((DAT_0012d008) - (f.dVar63))) - (f.dVar31))
            1049
        }
        1051 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012ce58))) < (0.0))) != 0) && ((b((f.fVar28) < (DAT_0012cdf0))) != 0))) != 0) 1050 else 1048
        }
        1052 -> {
            if ((b((((f.dVar63) + (DAT_0012ce58))) < (0.0))) != 0) 1051 else 1043
        }
        1053 -> {
            if ((b(((b((f.dVar32) < (6.8))) != 0) && ((b((1.0) < (readF32(f.param_1.plus(0x268))))) != 0))) != 0) 1052 else 1025
        }
        1054 -> {
            if ((b(((b(((b(((b((0x1d) < (f.iVar19))) != 0) && ((b((DAT_0012cde0) < (f.dVar31))) != 0))) != 0) && ((b((f.fVar54) < (5.5))) != 0))) != 0) && ((b(((b(((b((((f.fVar61) - (f.fVar23))) < (DAT_0012cef8))) != 0) && ((b((f.dVar53) < (6.6))) != 0))) != 0) && ((b(((b((((readF32(f.param_1.plus(0x26c))) - (f.fVar40))) < (4.5))) != 0) && ((b(((b((0.0) < (f.fVar52))) != 0) && ((b((f.fVar52) <= (f.fVar79))) != 0))) != 0))) != 0))) != 0))) != 0) 1053 else 1019
        }
        1055 -> {
            if ((b((f.fVar55) < (f.fVar22))) != 0) 1054 else 122
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep33(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1056 -> {
            f.fVar24 = f32(7.0)
            139
        }
        1057 -> {
            151
        }
        1058 -> {
            316
        }
        1059 -> {
            f.fVar70 = f32(((3.5) - (f.fVar35)))
            1058
        }
        1060 -> {
            if ((b((((f.dVar49) + (-(3.5)))) < (0.0))) != 0) 1059 else 1057
        }
        1061 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) || ((b((DAT_0012ccb0) <= (f.fVar28))) != 0))) != 0) 137 else 138
        }
        1062 -> {
            316
        }
        1063 -> {
            f.fVar70 = f32(0.0)
            1062
        }
        1064 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 1063 else 1062
        }
        1065 -> {
            f.fVar70 = f32(((3.5) - (f.fVar55)))
            1064
        }
        1066 -> {
            f.bVar8 = b((b((f.fVar22) == (25.0))) != 0)
            1065
        }
        1067 -> {
            if ((b(((b((0.85) <= (f.fVar28))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar22).isNaN())) != 0)) }) != 0))) != 0) 1066 else 1065
        }
        1068 -> {
            f.bVar8 = b((1) != 0)
            1067
        }
        1069 -> {
            if ((b((((f.dVar31) + (-(3.5)))) < (0.0))) != 0) 1068 else 1062
        }
        1070 -> {
            f.fVar70 = f32(0.0)
            1069
        }
        1071 -> {
            if ((b((0.0) <= (((f.fVar22) + (-(3.5)))))) != 0) 136 else 1061
        }
        1072 -> {
            153
        }
        1073 -> {
            137
        }
        1074 -> {
            if ((b(((b((0.0) <= (((f.dVar31) + (-(3.5)))))) != 0) || ((b((DAT_0012ccb0) <= (f.fVar28))) != 0))) != 0) 1073 else 1072
        }
        1075 -> {
            136
        }
        1076 -> {
            if ((b((0.0) <= (((f.dVar63) + (-(3.5)))))) != 0) 1075 else 1074
        }
        1077 -> {
            132
        }
        1078 -> {
            if ((b((f.fVar26) < (9.0))) != 0) 1077 else 135
        }
        1079 -> {
            146
        }
        1080 -> {
            123
        }
        1081 -> {
            if ((b((0.0) <= (((f.dVar49) + (DAT_0012ce58))))) != 0) 1080 else 1079
        }
        1082 -> {
            202
        }
        1083 -> {
            f.dVar62 = ((((((f.dVar38) - (f.dVar63))) - (f.dVar31))) * (0.5))
            1082
        }
        1084 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012d040))) < (0.0))) != 0) && ((run { run { f.dVar38 = DAT_0012d048; DAT_0012d048 }; b((f.fVar28) < (DAT_0012ccb0)) }) != 0))) != 0) 134 else 1081
        }
        1085 -> {
            182
        }
        1086 -> {
            316
        }
        1087 -> {
            if ((b(((b((f.fVar22) != (25.0))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((0.85) <= (f.fVar28)) }) != 0))) != 0) 1086 else 1085
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep34(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1088 -> {
            316
        }
        1089 -> {
            if ((b((0.0) <= (((f.dVar31) + (DAT_0012d040))))) != 0) 1088 else 133
        }
        1090 -> {
            f.fVar70 = f32(0.0)
            1089
        }
        1091 -> {
            if ((b((0.0) <= (((f.dVar63) + (DAT_0012d040))))) != 0) 1090 else 1084
        }
        1092 -> {
            316
        }
        1093 -> {
            f.fVar70 = f32(f32(((DAT_0012ce60) - (f.dVar31))))
            1092
        }
        1094 -> {
            112
        }
        1095 -> {
            if ((b(((b((f.fVar55) <= (3.5))) != 0) || ((b((f.dVar63) <= (DAT_0012ce00))) != 0))) != 0) 1094 else 1093
        }
        1096 -> {
            134
        }
        1097 -> {
            if ((b(((b((((f.dVar31) + (DAT_0012ce58))) < (0.0))) != 0) && ((run { run { f.dVar38 = DAT_0012d008; DAT_0012d008 }; b((f.fVar28) < (DAT_0012ccb0)) }) != 0))) != 0) 1096 else 1095
        }
        1098 -> {
            133
        }
        1099 -> {
            if ((b((((f.dVar31) + (DAT_0012ce58))) < (0.0))) != 0) 1098 else 1092
        }
        1100 -> {
            f.dVar77 = DAT_0012ce60
            1099
        }
        1101 -> {
            f.fVar70 = f32(0.0)
            1100
        }
        1102 -> {
            if ((b((((f.dVar63) + (DAT_0012ce58))) < (0.0))) != 0) 1097 else 1101
        }
        1103 -> {
            if ((b((f.fVar79) < (6.0))) != 0) 1102 else 1091
        }
        1104 -> {
            135
        }
        1105 -> {
            if ((b(((b(((b(((b((9.0) <= (f.fVar26))) != 0) || ((b((f.fVar55) <= (3.5))) != 0))) != 0) || ((b((f.dVar63) <= (DAT_0012ce00))) != 0))) != 0) || ((b((6.5) <= (f.fVar79))) != 0))) != 0) 1104 else 132
        }
        1106 -> {
            if ((b((f.iVar19) < (0x31))) != 0) 1105 else 1078
        }
        1107 -> {
            if ((b((f.dVar39) <= (DAT_0012cc40))) != 0) 1106 else 1071
        }
        1108 -> {
            202
        }
        1109 -> {
            f.dVar62 = ((((f.dVar63) - (f.dVar31))) * (0.5))
            1108
        }
        1110 -> {
            f.dVar63 = ((DAT_0012d048) - (f.dVar63))
            131
        }
        1111 -> {
            123
        }
        1112 -> {
            if ((b((0.0) <= (((f.dVar31) + (DAT_0012d040))))) != 0) 1111 else 1110
        }
        1113 -> {
            147
        }
        1114 -> {
            f.dVar38 = ((f.dVar31) + (DAT_0012d040))
            1113
        }
        1115 -> {
            if ((b((0.5) <= (((f.dVar63) + (DAT_0012d040))))) != 0) 130 else 1112
        }
        1116 -> {
            if ((b(((b((f.fVar35) <= (f.fVar22))) != 0) || ((b((f.fVar24) <= (1.0))) != 0))) != 0) 1115 else 1107
        }
        1117 -> {
            if ((b(((b(((b(((b(((b((f.fVar22) <= (f.fVar55))) != 0) || ((b((f.iVar19) < (0x19))) != 0))) != 0) || ((b((5.5) <= (f.fVar54))) != 0))) != 0) || ((run { run { f.fVar24 = f32(readF32(f.param_1.plus(0x268))); f32(readF32(f.param_1.plus(0x268))) }; b(((b((3.5) <= (((f.fVar40) - (f.fVar24))))) != 0) || ((b((f.fVar79) < (f.fVar52))) != 0)) }) != 0))) != 0) || ((b(((b((0.5) <= (((f.fVar55) - (f.fVar24))))) != 0) || ((b(((b((6.6) <= (f.dVar53))) != 0) || ((b((4.0) <= (((readF32(f.param_1.plus(0x26c))) - (f.fVar40))))) != 0))) != 0))) != 0))) != 0) 1055 else 1116
        }
        1118 -> {
            f.iVar19 = readI32(f.param_1.plus(0x1f8))
            1117
        }
        1119 -> {
            if ((b((3.0) < (f.fVar55))) != 0) 1118 else 849
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep35(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1120 -> {
            f.fVar71 = f32(f.fVar22)
            1119
        }
        1121 -> {
            f.dVar77 = DAT_0012cca0
            1120
        }
        1122 -> {
            316
        }
        1123 -> {
            f.fVar70 = f32(((5.0) - (f.fVar55)))
            1122
        }
        1124 -> {
            if ((b((((f.fVar55) + (-(5.0)))) < (0.0))) != 0) 1123 else 1122
        }
        1125 -> {
            f.fVar70 = f32(0.0)
            1124
        }
        1126 -> {
            f.fVar70 = f32(((5.0) - (f.fVar22)))
            1122
        }
        1127 -> {
            139
        }
        1128 -> {
            f.fVar24 = f32(10.0)
            1127
        }
        1129 -> {
            if ((b((((f.fVar55) + (-(5.0)))) < (0.0))) != 0) 1128 else 1126
        }
        1130 -> {
            if ((b((0.0) <= (((f.fVar22) + (-(5.0)))))) != 0) 1125 else 1129
        }
        1131 -> {
            f.fVar70 = f32(((f.fVar54) - (f.fVar55)))
            1122
        }
        1132 -> {
            f.fVar54 = f32(4.5)
            111
        }
        1133 -> {
            316
        }
        1134 -> {
            if ((b((0.0) <= (((f.dVar31) + (-(4.5)))))) != 0) 1133 else 1132
        }
        1135 -> {
            f.fVar70 = f32(0.0)
            1134
        }
        1136 -> {
            125
        }
        1137 -> {
            124
        }
        1138 -> {
            if ((b((((f.dVar31) + (-(4.5)))) < (0.0))) != 0) 1137 else 1136
        }
        1139 -> {
            if ((b((((f.fVar22) + (-(4.5)))) < (0.0))) != 0) 1138 else 110
        }
        1140 -> {
            if ((b((f.iVar19) == (1))) != 0) 1130 else 1139
        }
        1141 -> {
            182
        }
        1142 -> {
            316
        }
        1143 -> {
            if ((b(((b(((b((f.fVar35) <= (f.fVar22))) != 0) || ((b((0.0) <= (((f.dVar31) + (DAT_0012ce58))))) != 0))) != 0) || ((run { run { f.dVar77 = DAT_0012ce60; DAT_0012ce60 }; b((DAT_0012cdf0) <= (f.fVar28)) }) != 0))) != 0) 1142 else 1141
        }
        1144 -> {
            f.fVar70 = f32(0.0)
            1143
        }
        1145 -> {
            202
        }
        1146 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar62))
            1145
        }
        1147 -> {
            264
        }
        1148 -> {
            f.dVar62 = ((((DAT_0012d008) - (f.dVar62))) - (f.dVar31))
            1147
        }
        1149 -> {
            if ((b((((f.dVar31) + (DAT_0012ce58))) < (0.0))) != 0) 1148 else 1146
        }
        1150 -> {
            if ((b(((b((f.fVar22) < (f.fVar35))) != 0) && ((run { run { f.dVar62 = f.fVar22; f.fVar22 }; b((((f.dVar62) + (DAT_0012ce58))) < (0.0)) }) != 0))) != 0) 1149 else 1144
        }
        1151 -> {
            if ((b(((b(((b(((b((f.fVar54) < (6.0))) != 0) && ((b((0xc) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) && ((b((f.fVar28) < (DAT_0012cc40))) != 0))) != 0) && ((b((8.0) < (f.fVar57))) != 0))) != 0) 1150 else 1140
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep36(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1152 -> {
            if ((b(((b(((b(((b((4.0) < (f.fVar55))) != 0) && ((b((0.0) < (f.fVar52))) != 0))) != 0) && ((b(((b((0.0) < (f.fVar79))) != 0) && ((b(((b((f.fVar52) < (7.5))) != 0) && ((b((f.fVar79) < (7.5))) != 0))) != 0))) != 0))) != 0) && ((b((((f.fVar40) - (readF32(f.param_1.plus(0x268))))) < (2.5))) != 0))) != 0) 1151 else 1121
        }
        1153 -> {
            f.dVar34 = f.dVar31
            1152
        }
        1154 -> {
            f.fVar54 = f32(((f.fVar57) - (f.fVar22)))
            1153
        }
        1155 -> {
            316
        }
        1156 -> {
            f.fVar70 = f32(((3.0) - (f.fVar55)))
            1155
        }
        1157 -> {
            316
        }
        1158 -> {
            219
        }
        1159 -> {
            f.fVar22 = f32(((((6.0) - (f.fVar67))) - (f.fVar41)))
            1158
        }
        1160 -> {
            if ((b(((b(((b((((f.fVar41) + (-(3.0)))) < (0.5))) != 0) && ((b((((f.fVar67) + (-(3.0)))) < (0.5))) != 0))) != 0) && ((b((((f.fVar67) - (f.fVar41))) < (0.85))) != 0))) != 0) 1159 else 1157
        }
        1161 -> {
            f.fVar70 = f32(0.0)
            1160
        }
        1162 -> {
            if ((b((0.5) <= (((f.fVar55) + (-(3.0)))))) != 0) 1161 else 109
        }
        1163 -> {
            202
        }
        1164 -> {
            f.dVar62 = ((((((((DAT_0012d008) - (f.dVar83))) - (f.dVar59))) * (0.5))) * (0.5))
            1163
        }
        1165 -> {
            316
        }
        1166 -> {
            if ((b(((b((0.5) <= (((f.dVar59) + (DAT_0012ce58))))) != 0) || ((b((0.5) <= (((f.dVar83) + (DAT_0012ce58))))) != 0))) != 0) 1165 else 1164
        }
        1167 -> {
            f.fVar70 = f32(0.0)
            1166
        }
        1168 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar31))
            1163
        }
        1169 -> {
            if ((b((0.5) <= (((f.dVar31) + (DAT_0012ce58))))) != 0) 1167 else 1168
        }
        1170 -> {
            if ((b(((b(((b((f.fVar40) < (5.5))) != 0) && ((b((f.fVar52) < (7.5))) != 0))) != 0) && ((b(((b((f.fVar79) < (7.5))) != 0) && ((b((0x24) < (readI32(f.param_1.plus(0x188))))) != 0))) != 0))) != 0) 1169 else 1162
        }
        1171 -> {
            if ((b((5.0) <= (f.fVar55))) != 0) 1170 else 1154
        }
        1172 -> {
            f.dVar62 = ((f.dVar62) * (f.dVar38))
            202
        }
        1173 -> {
            f.dVar62 = ((4.5) - (f.dVar63))
            201
        }
        1174 -> {
            f.dVar38 = 0.7
            1173
        }
        1175 -> {
            316
        }
        1176 -> {
            if ((b((0.5) <= (((f.dVar63) + (-(4.5)))))) != 0) 1175 else 1174
        }
        1177 -> {
            316
        }
        1178 -> {
            201
        }
        1179 -> {
            f.dVar62 = ((3.5) - (f.dVar63))
            1178
        }
        1180 -> {
            f.dVar38 = 0.7
            1179
        }
        1181 -> {
            if ((b((((f.dVar63) + (-(3.5)))) < (0.5))) != 0) 1180 else 1177
        }
        1182 -> {
            if ((b((1.2) <= (kotlin.math.abs(((f.fVar71) - (f.fVar69)))))) != 0) 1181 else 1176
        }
        1183 -> {
            218
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep37(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1184 -> {
            219
        }
        1185 -> {
            f.fVar22 = f32(((((9.0) - (f.fVar71))) - (f.fVar67)))
            1184
        }
        1186 -> {
            316
        }
        1187 -> {
            f.fVar70 = f32(((3.0) - (f.fVar71)))
            1186
        }
        1188 -> {
            316
        }
        1189 -> {
            if ((b((3.0) <= (f.fVar71))) != 0) 1188 else 200
        }
        1190 -> {
            if ((b((0.5) <= (((f.dVar83) + (-(4.5)))))) != 0) 1189 else 1185
        }
        1191 -> {
            if ((b((f.fVar82) < (1.2))) != 0) 1190 else 1183
        }
        1192 -> {
            316
        }
        1193 -> {
            197
        }
        1194 -> {
            f.dVar38 = ((f.dVar38) - (f.dVar63))
            1193
        }
        1195 -> {
            f.dVar38 = 9.6
            199
        }
        1196 -> {
            if ((b((((f.dVar62) + (-(4.8)))) < (0.5))) != 0) 1195 else 1192
        }
        1197 -> {
            if ((b((f.fVar22) < (5.5))) != 0) 1196 else 1191
        }
        1198 -> {
            202
        }
        1199 -> {
            f.dVar62 = ((((((((7.8) - (f.dVar63))) - (f.dVar38))) * (0.5))) * (DAT_0012cc40))
            1198
        }
        1200 -> {
            264
        }
        1201 -> {
            f.dVar62 = ((((f.dVar38) - (f.dVar63))) - (f.dVar31))
            1200
        }
        1202 -> {
            316
        }
        1203 -> {
            if ((b((0.5) <= (((f.dVar63) + (DAT_0012ce58))))) != 0) 1202 else 198
        }
        1204 -> {
            f.dVar38 = DAT_0012d008
            1203
        }
        1205 -> {
            202
        }
        1206 -> {
            f.dVar62 = ((((((((DAT_0012d008) - (f.dVar63))) - (f.dVar38))) * (0.5))) * (DAT_0012cc40))
            1205
        }
        1207 -> {
            if ((b((1.0) <= (f.fVar71))) != 0) 1206 else 1204
        }
        1208 -> {
            if ((b((kotlin.math.abs(((f.fVar69) - (f.fVar71)))) < (1.0))) != 0) 1207 else 1199
        }
        1209 -> {
            if ((b((f.fVar22) < (4.5))) != 0) 1208 else 1197
        }
        1210 -> {
            316
        }
        1211 -> {
            264
        }
        1212 -> {
            f.dVar62 = ((f.dVar38) - (f.dVar62))
            1211
        }
        1213 -> {
            f.dVar38 = ((f.dVar38) - (f.dVar63))
            197
        }
        1214 -> {
            f.dVar38 = 10.2
            1213
        }
        1215 -> {
            316
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep38(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1216 -> {
            199
        }
        1217 -> {
            f.dVar38 = 10.6
            1216
        }
        1218 -> {
            if ((b((f.fVar22) < (6.5))) != 0) 1217 else 1215
        }
        1219 -> {
            if ((b((6.0) <= (f.fVar22))) != 0) 1218 else 1214
        }
        1220 -> {
            f.dVar38 = 9.6
            1213
        }
        1221 -> {
            if ((b((5.5) <= (f.fVar22))) != 0) 1219 else 1220
        }
        1222 -> {
            if ((b((kotlin.math.abs(((f.fVar69) - (f.fVar22)))) < (DAT_0012cc40))) != 0) 1221 else 1210
        }
        1223 -> {
            219
        }
        1224 -> {
            f.fVar22 = f32(((6.0) - (f.fVar22)))
            1223
        }
        1225 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.5))) != 0) 1224 else 1210
        }
        1226 -> {
            264
        }
        1227 -> {
            f.dVar62 = ((3.9) - (f.dVar63))
            1226
        }
        1228 -> {
            if ((b(((b(((b((((f.dVar63) + (-(3.9)))) < (0.5))) != 0) && ((b((f.fVar57) < (12.0))) != 0))) != 0) && ((b((((f.dVar31) + (-(3.9)))) < (0.5))) != 0))) != 0) 1227 else 1225
        }
        1229 -> {
            if ((b((1.2) < (kotlin.math.abs(((f.fVar69) - (f.fVar71)))))) != 0) 1228 else 1210
        }
        1230 -> {
            if ((b((4.5) <= (f.fVar22))) != 0) 1222 else 1229
        }
        1231 -> {
            if ((b(((b((7.0) <= (f.fVar71))) != 0) || ((b((f.dVar38) <= (DAT_0012cdc8))) != 0))) != 0) 1230 else 1209
        }
        1232 -> {
            if ((b(((b(((b((3.9) <= (f.dVar38))) != 0) || ((b((f.fVar57) <= (8.0))) != 0))) != 0) || ((b(((b((f.fVar71) <= (2.0))) != 0) && ((b((f.fVar69) <= (2.0))) != 0))) != 0))) != 0) 1231 else 1182
        }
        1233 -> {
            316
        }
        1234 -> {
            f.fVar70 = f32(f32(f.dVar62))
            1233
        }
        1235 -> {
            f.dVar62 = ((((3.9) - (f.dVar38))) * (0.5))
            196
        }
        1236 -> {
            202
        }
        1237 -> {
            f.dVar62 = ((((3.9) - (f.dVar38))) * (0.5))
            1236
        }
        1238 -> {
            f.dVar62 = ((((((DAT_0012d008) - (f.dVar63))) - (f.dVar49))) * (0.5))
            1236
        }
        1239 -> {
            if ((b((1.5) <= (f.fVar37))) != 0) 1237 else 1238
        }
        1240 -> {
            if ((b((f.fVar71) < (1.0))) != 0) 1239 else 1235
        }
        1241 -> {
            if ((b(((b(((b(((b((readF32(f.param_1.plus(0x7c))) < (4.0))) != 0) && ((b((1.2) < (readF32(f.param_1.plus(0x7c))))) != 0))) != 0) && ((b((6.0) < (f.fVar57))) != 0))) != 0) && ((b((f.dVar38) < (3.9))) != 0))) != 0) 1240 else 1232
        }
        1242 -> {
            217
        }
        1243 -> {
            f.fVar76 = f32(3.0)
            1242
        }
        1244 -> {
            f.fVar57 = f32(1.2)
            195
        }
        1245 -> {
            316
        }
        1246 -> {
            if ((b(((b((f.fVar22) <= (f.fVar67))) != 0) || ((run { run { f.fVar70 = f32(f.fVar36); f32(f.fVar36) }; b((((f.dVar83) + (DAT_0012ce50))) == (0.0)) }) != 0))) != 0) 1245 else 1244
        }
        1247 -> {
            f.fVar70 = f32(0.0)
            1246
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep39(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1248 -> {
            270
        }
        1249 -> {
            f.fVar57 = f32(3.2)
            1248
        }
        1250 -> {
            f.fVar60 = f32(1.2)
            1249
        }
        1251 -> {
            if ((b((((f.dVar63) + (DAT_0012ce50))) < (0.5))) != 0) 194 else 1247
        }
        1252 -> {
            270
        }
        1253 -> {
            f.fVar57 = f32(3.0)
            1252
        }
        1254 -> {
            f.fVar60 = f32(1.2)
            1253
        }
        1255 -> {
            194
        }
        1256 -> {
            if ((b((((f.dVar63) + (DAT_0012ce50))) < (0.5))) != 0) 1255 else 1254
        }
        1257 -> {
            if ((b((f.iVar14) < (0x19))) != 0) 1256 else 1251
        }
        1258 -> {
            270
        }
        1259 -> {
            f.fVar57 = f32(2.2)
            1258
        }
        1260 -> {
            f.fVar60 = f32(1.3)
            1259
        }
        1261 -> {
            if ((b((13.0) <= (f.fVar57))) != 0) 1260 else 1257
        }
        1262 -> {
            270
        }
        1263 -> {
            f.fVar57 = f32(3.5)
            1262
        }
        1264 -> {
            f.fVar60 = f32(1.0)
            1263
        }
        1265 -> {
            if ((b((f.fVar54) < (10.0))) != 0) 1264 else 1261
        }
        1266 -> {
            193
        }
        1267 -> {
            if ((b((0x30) < (f.iVar14))) != 0) 1266 else 1265
        }
        1268 -> {
            316
        }
        1269 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.9, 0.95, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1268
        }
        1270 -> {
            293
        }
        1271 -> {
            f.fVar76 = f32(3.0)
            1270
        }
        1272 -> {
            f.fVar57 = f32(1.2)
            1271
        }
        1273 -> {
            f.fVar76 = f32(2.5)
            1270
        }
        1274 -> {
            f.fVar57 = f32(1.3)
            1273
        }
        1275 -> {
            if ((b(((b((f.fVar28) <= (0.5))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0))) != 0) 1272 else 1274
        }
        1276 -> {
            if ((b(((b((DAT_0012cc40) <= (f.fVar56))) != 0) || ((b((7.0) <= (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) 1275 else 1269
        }
        1277 -> {
            adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 4.7, 0.5, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)
            193
        }
        1278 -> {
            if ((b(((b(((b(((b((3.0) < (f.fVar23))) != 0) && ((b((f.fVar45) < (6.0))) != 0))) != 0) && ((b((0x30) < (f.iVar14))) != 0))) != 0) && ((b(((b((f.fVar54) < (11.0))) != 0) && ((b((((f.fVar71) - (f.fVar69))) < (1.2))) != 0))) != 0))) != 0) 1277 else 1267
        }
        1279 -> {
            115
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep40(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1280 -> {
            f.dVar38 = DAT_0012cc40
            1279
        }
        1281 -> {
            f.dVar62 = ((DAT_0012cde0) - (f.dVar63))
            1280
        }
        1282 -> {
            316
        }
        1283 -> {
            197
        }
        1284 -> {
            if ((b((((f.dVar62) + (DAT_0012ce50))) < (0.5))) != 0) 1283 else 1282
        }
        1285 -> {
            f.dVar38 = DAT_0012cde0
            1284
        }
        1286 -> {
            if ((b((0.5) <= (((f.dVar63) + (DAT_0012ce50))))) != 0) 1285 else 1281
        }
        1287 -> {
            316
        }
        1288 -> {
            f.fVar70 = f32(((3.0) - (f.fVar22)))
            1287
        }
        1289 -> {
            219
        }
        1290 -> {
            f.fVar22 = f32(((3.0) - (f.fVar69)))
            1289
        }
        1291 -> {
            if ((b((((f.fVar69) + (-(3.0)))) < (0.5))) != 0) 1290 else 1287
        }
        1292 -> {
            if ((b((((f.fVar22) + (-(3.0)))) < (0.5))) != 0) 1288 else 192
        }
        1293 -> {
            if ((b((12.0) < (f.fVar57))) != 0) 1292 else 1286
        }
        1294 -> {
            316
        }
        1295 -> {
            f.fVar70 = f32(f32(f.dVar38))
            1294
        }
        1296 -> {
            f.dVar38 = ((f.dVar38) * (DAT_0012cc40))
            1295
        }
        1297 -> {
            f.dVar38 = ((3.0) - (f.fVar22))
            1296
        }
        1298 -> {
            192
        }
        1299 -> {
            if ((b((0.5) <= (((f.fVar22) + (-(3.0)))))) != 0) 1298 else 1297
        }
        1300 -> {
            f.dVar38 = ((f.dVar38) - (f.dVar63))
            1296
        }
        1301 -> {
            f.dVar38 = 3.5
            191
        }
        1302 -> {
            316
        }
        1303 -> {
            197
        }
        1304 -> {
            f.dVar38 = 3.5
            1303
        }
        1305 -> {
            if ((b((((f.dVar62) + (-(3.5)))) < (0.5))) != 0) 1304 else 1302
        }
        1306 -> {
            if ((b((0.5) <= (((f.dVar63) + (-(3.5)))))) != 0) 1305 else 1301
        }
        1307 -> {
            if ((b((readI32(f.param_1.plus(0x1f8))) < (0x19))) != 0) 1299 else 1306
        }
        1308 -> {
            197
        }
        1309 -> {
            f.dVar38 = 3.9
            1308
        }
        1310 -> {
            316
        }
        1311 -> {
            if ((b((0.5) <= (((f.dVar62) + (-(3.9)))))) != 0) 1310 else 1309
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep41(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1312 -> {
            191
        }
        1313 -> {
            f.dVar38 = 3.9
            1312
        }
        1314 -> {
            if ((b((((f.dVar63) + (-(3.9)))) < (0.5))) != 0) 1313 else 1311
        }
        1315 -> {
            if ((b((0x24) < (readI32(f.param_1.plus(0x1f8))))) != 0) 1314 else 1307
        }
        1316 -> {
            f.dVar38 = ((2.3) - (f.dVar49))
            1295
        }
        1317 -> {
            if ((b((((f.dVar49) + (-(2.3)))) < (0.5))) != 0) 1316 else 1295
        }
        1318 -> {
            f.dVar38 = ((((((4.6) - (f.dVar63))) - (f.dVar31))) * (0.5))
            1295
        }
        1319 -> {
            if ((b(((b((0.5) <= (((f.dVar31) + (-(2.3)))))) != 0) || ((b((DAT_0012cc40) <= (f.fVar28))) != 0))) != 0) 1317 else 1318
        }
        1320 -> {
            316
        }
        1321 -> {
            if ((b((0.5) <= (f.dVar38))) != 0) 1320 else 1319
        }
        1322 -> {
            f.dVar38 = ((f.dVar63) + (-(2.3)))
            1321
        }
        1323 -> {
            if ((b(((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) || ((b(((b((0x47) < (f.iVar14))) != 0) && ((b((f.fVar72) <= (0.6))) != 0))) != 0))) != 0) 1315 else 1322
        }
        1324 -> {
            if ((b(((b((f.fVar22) <= (f.fVar71))) != 0) || ((b((0x3b) < (f.iVar14))) != 0))) != 0) 1323 else 1293
        }
        1325 -> {
            316
        }
        1326 -> {
            if ((b((1.0) < (f.fVar69))) != 0) 1325 else 1324
        }
        1327 -> {
            if ((b((f.fVar69) <= (1.0))) != 0) 1326 else 1278
        }
        1328 -> {
            270
        }
        1329 -> {
            f.fVar57 = f32(3.5)
            1328
        }
        1330 -> {
            f.fVar60 = f32(0.55)
            1329
        }
        1331 -> {
            270
        }
        1332 -> {
            f.fVar57 = f32(3.2)
            1331
        }
        1333 -> {
            f.fVar60 = f32(0.55)
            1332
        }
        1334 -> {
            if ((b(((b((f.dVar42) < (DAT_0012cde0))) != 0) && ((b((f.iVar14) < (0x24))) != 0))) != 0) 1333 else 1330
        }
        1335 -> {
            189
        }
        1336 -> {
            f.fVar60 = f32(0.55)
            1335
        }
        1337 -> {
            if ((b(((b((8.0) <= (f.fVar52))) != 0) || ((b(((b((7.0) <= (f.fVar52))) != 0) && ((b((8.0) <= (f.fVar79))) != 0))) != 0))) != 0) 1336 else 1334
        }
        1338 -> {
            190
        }
        1339 -> {
            270
        }
        1340 -> {
            f.fVar57 = f32(4.0)
            1339
        }
        1341 -> {
            f.fVar60 = f32(1.0)
            1340
        }
        1342 -> {
            if ((b((1.5) < (f.fVar80))) != 0) 1341 else 1338
        }
        1343 -> {
            if ((b(((b((0x1e) < (f.iVar14))) != 0) && ((b((f.fVar26) < (10.5))) != 0))) != 0) 1342 else 1337
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep42(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1344 -> {
            f.fVar60 = f32(1.0)
            1329
        }
        1345 -> {
            270
        }
        1346 -> {
            f.fVar57 = f32(3.0)
            1345
        }
        1347 -> {
            f.fVar60 = f32(1.2)
            189
        }
        1348 -> {
            if ((b(((b((1.5) < (f.fVar37))) != 0) && ((b((7.0) < (f.fVar52))) != 0))) != 0) 1347 else 190
        }
        1349 -> {
            if ((b(((b((8.0) <= (f.fVar45))) != 0) || ((b((f.fVar37) <= (1.0))) != 0))) != 0) 1343 else 1348
        }
        1350 -> {
            210
        }
        1351 -> {
            f.fVar57 = f32(4.2)
            1350
        }
        1352 -> {
            f.fVar60 = f32(0.55)
            1351
        }
        1353 -> {
            if ((b(((b(((b((f.fVar60) < (1.0))) != 0) && ((b((f.fVar45) < (6.5))) != 0))) != 0) && ((b(((b((f.fVar26) < (9.0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0))) != 0) 1352 else 1349
        }
        1354 -> {
            217
        }
        1355 -> {
            f.fVar76 = f32(4.5)
            1354
        }
        1356 -> {
            f.fVar57 = f32(0.5)
            1355
        }
        1357 -> {
            if ((b(((b(((b(((b((f.fVar45) < (6.5))) != 0) && ((b((f.fVar82) < (1.0))) != 0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) && ((b((f.dVar33) < (DAT_0012cd18))) != 0))) != 0) 1356 else 1353
        }
        1358 -> {
            315
        }
        1359 -> {
            f.fVar57 = f32(3.0)
            1358
        }
        1360 -> {
            f.fVar60 = f32(1.2)
            1359
        }
        1361 -> {
            if ((b((12.0) < (f.fVar57))) != 0) 1360 else 1357
        }
        1362 -> {
            if ((b((2.0) < (f.fVar69))) != 0) 1361 else 1327
        }
        1363 -> {
            293
        }
        1364 -> {
            f.fVar57 = f32(1.0)
            1363
        }
        1365 -> {
            f.fVar76 = f32(3.5)
            1364
        }
        1366 -> {
            f.fVar76 = f32(3.0)
            1364
        }
        1367 -> {
            if ((b(((b(((b((f.fVar52) <= (9.0))) != 0) || ((b((f.fVar54) <= (14.5))) != 0))) != 0) || ((b((3.0) <= (f.fVar78))) != 0))) != 0) 1365 else 1366
        }
        1368 -> {
            217
        }
        1369 -> {
            f.fVar76 = f32(3.2)
            1368
        }
        1370 -> {
            f.fVar57 = f32(1.2)
            1369
        }
        1371 -> {
            if ((b(((b(((b((f.iVar14) < (0x30))) != 0) && ((b((6.5) < (f.fVar52))) != 0))) != 0) && ((b(((b((8.0) < (f.fVar54))) != 0) || ((b((7.0) < (f.fVar79))) != 0))) != 0))) != 0) 1370 else 1367
        }
        1372 -> {
            f.fVar57 = f32(1.0)
            1363
        }
        1373 -> {
            f.fVar76 = f32(3.5)
            1372
        }
        1374 -> {
            f.fVar76 = f32(4.5)
            1372
        }
        1375 -> {
            if ((b(((b(((b((10.0) <= (f.fVar57))) != 0) || ((b((5.0) <= (f.fVar23))) != 0))) != 0) || ((b(((b((7.0) <= (f.fVar52))) != 0) || ((b(((b((f.iVar14) < (0x49))) != 0) || ((b((60.0) <= (f.fVar27))) != 0))) != 0))) != 0))) != 0) 1373 else 1374
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep43(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1376 -> {
            270
        }
        1377 -> {
            f.fVar57 = f32(4.3)
            1376
        }
        1378 -> {
            f.fVar60 = f32(0.55)
            1377
        }
        1379 -> {
            f.fVar57 = f32(4.7)
            1376
        }
        1380 -> {
            f.fVar60 = f32(0.5)
            1379
        }
        1381 -> {
            if ((b(((b(((b((DAT_0012cf28) < (f.dVar33))) != 0) || ((b((f.iVar14) < (0x42))) != 0))) != 0) || ((b((DAT_0012cf28) < (f.dVar32))) != 0))) != 0) 1378 else 1380
        }
        1382 -> {
            if ((b(((b(((b((f.fVar54) < (8.0))) != 0) && ((b((f.fVar52) < (7.5))) != 0))) != 0) && ((b((f.fVar79) < (7.5))) != 0))) != 0) 1381 else 1375
        }
        1383 -> {
            if ((b(((b(((b((1.0) <= (((f.fVar67) - (f.fVar41))))) != 0) || ((b((6.0) <= (f.fVar45))) != 0))) != 0) || ((b((f.iVar14) < (0x30))) != 0))) != 0) 1371 else 1382
        }
        1384 -> {
            if ((b((3.0) < (f.fVar69))) != 0) 1383 else 1362
        }
        1385 -> {
            209
        }
        1386 -> {
            316
        }
        1387 -> {
            if ((b((f.iVar19) != (1))) != 0) 1386 else 1385
        }
        1388 -> {
            f.fVar70 = f32(f.fVar54)
            1387
        }
        1389 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            188
        }
        1390 -> {
            316
        }
        1391 -> {
            f.fVar70 = f32(f.fVar54)
            1390
        }
        1392 -> {
            writeF32(f.pjVar1, f32(f32(f.dVar38)))
            1391
        }
        1393 -> {
            f.dVar38 = ((((2.5) - (f.dVar31))) * (DAT_0012ce88))
            1392
        }
        1394 -> {
            f.dVar38 = ((((2.8) - (f.dVar31))) * (0.5))
            1392
        }
        1395 -> {
            if ((b((f.dVar31) <= (2.8))) != 0) 1393 else 1394
        }
        1396 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1395
        }
        1397 -> {
            if ((b(((b(((b((f.fVar55) < (3.5))) != 0) && ((b((2.5) < (f.fVar55))) != 0))) != 0) && ((b(((b((f.fVar54) == (0.0))) != 0) && ((b((2.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1396 else 1389
        }
        1398 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.6, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1397
        }
        1399 -> {
            316
        }
        1400 -> {
            f.fVar70 = f32(f.fVar54)
            1399
        }
        1401 -> {
            writeF32(f.pjVar1, f32(f32(f.dVar39)))
            1400
        }
        1402 -> {
            f.dVar39 = ((f.dVar39) * (f.dVar53))
            1401
        }
        1403 -> {
            187
        }
        1404 -> {
            if ((b((f.dVar38) < (f.dVar59))) != 0) 1403 else 186
        }
        1405 -> {
            f.dVar53 = DAT_0012ce88
            1404
        }
        1406 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1405
        }
        1407 -> {
            f.dVar39 = ((DAT_0012cde0) - (f.dVar59))
            1406
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep44(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1408 -> {
            188
        }
        1409 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            1408
        }
        1410 -> {
            if ((b(((b(((b((f.dVar59) <= (DAT_0012cde0))) != 0) || ((b((DAT_0012cca0) <= (f.dVar59))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0) 1409 else 1407
        }
        1411 -> {
            f.dVar39 = ((((3.3) - (f.dVar31))) * (DAT_0012ce88))
            1401
        }
        1412 -> {
            186
        }
        1413 -> {
            f.dVar53 = 0.5
            1412
        }
        1414 -> {
            f.dVar39 = ((f.dVar38) - (f.dVar31))
            187
        }
        1415 -> {
            if ((b((f.dVar38) < (f.dVar31))) != 0) 1414 else 1411
        }
        1416 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1415
        }
        1417 -> {
            if ((b(((b((4.5) <= (f.fVar55))) != 0) || ((b(((b(((b((f.dVar31) <= (3.3))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.3))) != 0))) != 0))) != 0) 1410 else 1416
        }
        1418 -> {
            f.dVar38 = DAT_0012cdf8
            1417
        }
        1419 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1418
        }
        1420 -> {
            if ((b(((b((f.dVar33) <= (DAT_0012ce68))) != 0) || ((b(((b((f.dVar32) <= (DAT_0012ce68))) != 0) && ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0))) != 0))) != 0) 1419 else 1398
        }
        1421 -> {
            316
        }
        1422 -> {
            f.fVar70 = f32(f.fVar54)
            1421
        }
        1423 -> {
            writeF32(f.pjVar1, f32(0.0))
            1422
        }
        1424 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b(((b((f.fVar54) != (0.0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((((readF32(f.pjVar1)) + (f.param_4))) <= (3.0)) }) != 0))) != 0))) != 0) 1423 else 1421
        }
        1425 -> {
            f.fVar70 = f32(f.fVar54)
            1421
        }
        1426 -> {
            writeF32(f.pjVar1, f32(f32(f.dVar38)))
            1425
        }
        1427 -> {
            f.dVar38 = ((((3.3) - (f.dVar31))) * (DAT_0012ce88))
            1426
        }
        1428 -> {
            f.dVar38 = ((((f.dVar38) - (f.dVar31))) * (0.5))
            1426
        }
        1429 -> {
            if ((b((f.dVar31) <= (f.dVar38))) != 0) 1427 else 1428
        }
        1430 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1429
        }
        1431 -> {
            if ((b(((b(((b((4.5) <= (f.fVar55))) != 0) || ((b((f.dVar31) <= (3.3))) != 0))) != 0) || ((b(((b((f.fVar54) != (0.0))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0))) != 0))) != 0) 1424 else 1430
        }
        1432 -> {
            f.dVar38 = DAT_0012cdf8
            1431
        }
        1433 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.5, 1.0, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1432
        }
        1434 -> {
            if ((b(((b(((b((f.fVar45) < (8.0))) != 0) && ((b(((b((0x24) < (f.iVar14))) != 0) || ((b((f.fVar52) < (6.5))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x1a0))) < (0.3))) != 0))) != 0) 1433 else 1420
        }
        1435 -> {
            217
        }
        1436 -> {
            f.fVar76 = f32(f.fVar78)
            1435
        }
        1437 -> {
            f.fVar57 = f32(1.0)
            1436
        }
        1438 -> {
            185
        }
        1439 -> {
            if ((b(((b((6.5) < (f.fVar79))) != 0) || ((b(((b(((b((4.8) <= (f.dVar42))) != 0) || ((b((f.fVar78) <= (3.5))) != 0))) != 0) || ((b((DAT_0012cf28) <= (f.dVar33))) != 0))) != 0))) != 0) 1438 else 1437
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep45(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1440 -> {
            f.fVar76 = f32(4.3)
            1435
        }
        1441 -> {
            f.fVar57 = f32(0.9)
            1440
        }
        1442 -> {
            if ((b(((b(((b(((b((f.iVar14) < (0x3c))) != 0) && ((b(((b((5.0) <= (f.fVar23))) != 0) || ((b((7.0) <= (f.fVar52))) != 0))) != 0))) != 0) || ((b((DAT_0012cc40) <= (f.fVar72))) != 0))) != 0) || ((b(((b((7.0) <= (f.fVar52))) != 0) || ((b((7.5) <= (f.fVar79))) != 0))) != 0))) != 0) 1439 else 1441
        }
        1443 -> {
            if ((f.bVar9) != 0) 1442 else 185
        }
        1444 -> {
            217
        }
        1445 -> {
            f.fVar76 = f32(4.2)
            1444
        }
        1446 -> {
            f.fVar57 = f32(0.8)
            1445
        }
        1447 -> {
            if ((b(((b(((b((3.5) < (f.fVar55))) != 0) && ((b((3.5) < (f.fVar41))) != 0))) != 0) && ((b(((b((f.fVar52) < (9.0))) != 0) && ((b(((b(((b((3.5) < (f.fVar24))) != 0) && ((b((3.5) < (f.fVar44))) != 0))) != 0) && ((b((0x36) < (f.iVar14))) != 0))) != 0))) != 0))) != 0) 1446 else 1443
        }
        1448 -> {
            217
        }
        1449 -> {
            f.fVar76 = f32(4.7)
            1448
        }
        1450 -> {
            f.fVar57 = f32(0.8)
            1449
        }
        1451 -> {
            if ((b(((b(((b(((b((f.fVar82) < (1.0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((f.fVar57) < (12.0))) != 0))) != 0) && ((b(((b(((b((f.fVar45) < (6.0))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0) && ((b((f.fVar79) < (7.0))) != 0))) != 0))) != 0) 1450 else 1447
        }
        1452 -> {
            if ((b((4.0) < (f.fVar69))) != 0) 1451 else 1384
        }
        1453 -> {
            210
        }
        1454 -> {
            f.fVar60 = f32(1.2)
            1453
        }
        1455 -> {
            f.fVar57 = f32(3.5)
            1454
        }
        1456 -> {
            f.fVar57 = f32(3.9)
            1454
        }
        1457 -> {
            if ((b(((b((f.dVar42) <= (DAT_0012cde8))) != 0) || ((b((f.iVar14) < (0x31))) != 0))) != 0) 1455 else 1456
        }
        1458 -> {
            315
        }
        1459 -> {
            f.fVar57 = f32(3.2)
            1458
        }
        1460 -> {
            f.fVar60 = f32(1.2)
            1459
        }
        1461 -> {
            if ((b(((b(((b((f.iVar14) < (0x2b))) != 0) || ((b((9.0) <= (f.fVar54))) != 0))) != 0) || ((b((7.8) <= (f.dVar32))) != 0))) != 0) 1460 else 1457
        }
        1462 -> {
            217
        }
        1463 -> {
            f.fVar76 = f32(5.0)
            1462
        }
        1464 -> {
            f.fVar57 = f32(0.75)
            1463
        }
        1465 -> {
            184
        }
        1466 -> {
            if ((b((f.fVar54) < (13.0))) != 0) 1465 else 1464
        }
        1467 -> {
            315
        }
        1468 -> {
            f.fVar57 = f32(4.2)
            1467
        }
        1469 -> {
            f.fVar60 = f32(0.9)
            1468
        }
        1470 -> {
            if ((b((f.fVar54) < (12.0))) != 0) 1469 else 1466
        }
        1471 -> {
            if ((b(((b(((b((f.dVar33) < (DAT_0012cd18))) != 0) && ((b((f.fVar56) < (DAT_0012cc40))) != 0))) != 0) && ((b(((b((0x24) < (f.iVar14))) != 0) && ((b((f.dVar32) < (DAT_0012cd18))) != 0))) != 0))) != 0) 1470 else 1461
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep46(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1472 -> {
            217
        }
        1473 -> {
            f.fVar76 = f32(5.0)
            1472
        }
        1474 -> {
            f.fVar57 = f32(0.75)
            1473
        }
        1475 -> {
            196
        }
        1476 -> {
            f.dVar62 = ((DAT_0012cf18) - (f.dVar62))
            1475
        }
        1477 -> {
            if ((b((f.fVar54) < (13.0))) != 0) 184 else 1474
        }
        1478 -> {
            293
        }
        1479 -> {
            f.fVar76 = f32(4.7)
            1478
        }
        1480 -> {
            f.fVar57 = f32(1.0)
            1479
        }
        1481 -> {
            f.fVar76 = f32(4.3)
            1478
        }
        1482 -> {
            f.fVar57 = f32(0.9)
            1481
        }
        1483 -> {
            if ((b((f.fVar52) <= (6.0))) != 0) 1480 else 1482
        }
        1484 -> {
            if ((b((f.fVar54) < (12.0))) != 0) 1483 else 1477
        }
        1485 -> {
            if ((b(((b(((b(((b((f.fVar52) < (7.5))) != 0) && ((b((f.fVar45) < (6.0))) != 0))) != 0) && ((b((f.fVar72) < (DAT_0012cc40))) != 0))) != 0) && ((b((0x30) < (f.iVar14))) != 0))) != 0) 1484 else 1471
        }
        1486 -> {
            if ((b((5.0) < (f.fVar69))) != 0) 1485 else 1452
        }
        1487 -> {
            202
        }
        1488 -> {
            f.dVar62 = ((((((f.dVar38) - (f.dVar63))) - (f.dVar31))) * (0.5))
            1487
        }
        1489 -> {
            143
        }
        1490 -> {
            if ((b((0.5) <= (((f.dVar31) + (DAT_0012ce58))))) != 0) 1489 else 183
        }
        1491 -> {
            f.dVar38 = DAT_0012d008
            1490
        }
        1492 -> {
            316
        }
        1493 -> {
            202
        }
        1494 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar38))
            1493
        }
        1495 -> {
            if ((b((((f.dVar38) + (DAT_0012ce58))) < (0.5))) != 0) 1494 else 1492
        }
        1496 -> {
            if ((b((0.6) <= (((f.dVar63) + (DAT_0012ce58))))) != 0) 1495 else 1491
        }
        1497 -> {
            316
        }
        1498 -> {
            f.fVar70 = f32(((5.5) - (f.fVar69)))
            1497
        }
        1499 -> {
            202
        }
        1500 -> {
            f.dVar62 = ((DAT_0012cf38) - (f.dVar63))
            1499
        }
        1501 -> {
            if ((b((((f.dVar63) + (DAT_0012cf40))) < (0.6))) != 0) 1500 else 1498
        }
        1502 -> {
            f.fVar70 = f32(((5.5) - (f.fVar22)))
            1497
        }
        1503 -> {
            if ((b(((b((f.fVar54) < (12.0))) != 0) && ((b((((f.dVar63) + (-(5.5)))) < (0.6))) != 0))) != 0) 1502 else 1497
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep47(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1504 -> {
            143
        }
        1505 -> {
            f.dVar75 = 5.3
            1504
        }
        1506 -> {
            if ((b((((f.dVar63) + (-(5.3)))) < (0.6))) != 0) 1505 else 1497
        }
        1507 -> {
            if ((b((11.0) <= (f.fVar54))) != 0) 1503 else 1506
        }
        1508 -> {
            143
        }
        1509 -> {
            f.dVar75 = 5.1
            1508
        }
        1510 -> {
            if ((b((((f.dVar63) + (-(5.1)))) < (0.6))) != 0) 1509 else 1497
        }
        1511 -> {
            if ((b((10.0) <= (f.fVar54))) != 0) 1507 else 1510
        }
        1512 -> {
            if ((b((f.fVar54) < (9.0))) != 0) 1501 else 1511
        }
        1513 -> {
            if ((b((8.0) <= (f.fVar54))) != 0) 1512 else 1496
        }
        1514 -> {
            217
        }
        1515 -> {
            f.fVar76 = f32(3.9)
            1514
        }
        1516 -> {
            f.fVar57 = f32(1.2)
            1515
        }
        1517 -> {
            293
        }
        1518 -> {
            f.fVar57 = f32(1.2)
            1517
        }
        1519 -> {
            f.fVar76 = f32(3.0)
            1518
        }
        1520 -> {
            f.fVar76 = f32(3.5)
            1518
        }
        1521 -> {
            if ((b(((b((8.0) <= (f.fVar79))) != 0) || ((b((f.iVar19) < (0x31))) != 0))) != 0) 1519 else 1520
        }
        1522 -> {
            if ((b(((b(((b(((b((7.0) <= (f.fVar52))) != 0) || ((b((7.0) <= (f.fVar79))) != 0))) != 0) || ((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0))) != 0) || ((b((f.iVar19) < (0x31))) != 0))) != 0) 1521 else 1516
        }
        1523 -> {
            if ((b(((b((DAT_0012cc40) <= (f.fVar56))) != 0) || ((b(((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((f.iVar19) < (0x31))) != 0))) != 0) || ((b((f.dVar31) <= (3.9))) != 0))) != 0))) != 0) 1522 else 1513
        }
        1524 -> {
            f.iVar19 = readI32(f.param_1.plus(0x1f8))
            1523
        }
        1525 -> {
            if ((b(((b((6.0) < (f.fVar69))) != 0) && ((b((f.fVar69) < (7.0))) != 0))) != 0) 1524 else 1486
        }
        1526 -> {
            316
        }
        1527 -> {
            264
        }
        1528 -> {
            f.dVar62 = ((5.1) - (f.dVar63))
            1527
        }
        1529 -> {
            if ((b(((b((f.fVar54) < (12.0))) != 0) && ((b((((f.dVar63) + (-(5.1)))) < (0.6))) != 0))) != 0) 1528 else 1526
        }
        1530 -> {
            264
        }
        1531 -> {
            f.dVar62 = ((DAT_0012cf38) - (f.dVar63))
            1530
        }
        1532 -> {
            if ((b((((f.dVar63) + (DAT_0012cf40))) < (0.6))) != 0) 1531 else 1526
        }
        1533 -> {
            if ((b((11.0) <= (f.fVar54))) != 0) 1529 else 1532
        }
        1534 -> {
            264
        }
        1535 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar63))
            1534
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep48(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1536 -> {
            if ((b((((f.dVar63) + (DAT_0012ce58))) < (0.6))) != 0) 1535 else 1526
        }
        1537 -> {
            if ((b((10.0) <= (f.fVar54))) != 0) 1533 else 1536
        }
        1538 -> {
            264
        }
        1539 -> {
            f.dVar62 = ((4.5) - (f.dVar63))
            1538
        }
        1540 -> {
            if ((b((((f.dVar63) + (-(4.5)))) < (0.6))) != 0) 1539 else 1526
        }
        1541 -> {
            if ((b((9.0) <= (f.fVar54))) != 0) 1537 else 1540
        }
        1542 -> {
            217
        }
        1543 -> {
            f.fVar76 = f32(3.0)
            1542
        }
        1544 -> {
            f.fVar57 = f32(1.2)
            1543
        }
        1545 -> {
            if ((b(((b((1.0) <= (f.fVar82))) != 0) || ((b((readI32(f.param_1.plus(0x1f8))) < (0x31))) != 0))) != 0) 1544 else 1541
        }
        1546 -> {
            if ((b((7.0) < (f.fVar69))) != 0) 1545 else 1525
        }
        1547 -> {
            if ((b((f.fVar69) < (7.5))) != 0) 1546 else 1241
        }
        1548 -> {
            f.dVar38 = f.fVar71
            1547
        }
        1549 -> {
            293
        }
        1550 -> {
            f.fVar57 = f32(1.2)
            1549
        }
        1551 -> {
            f.fVar76 = f32(3.0)
            1550
        }
        1552 -> {
            f.fVar76 = f32(3.5)
            1550
        }
        1553 -> {
            if ((b(((b((8.0) <= (f.fVar52))) != 0) || ((b((8.0) <= (f.fVar79))) != 0))) != 0) 1551 else 1552
        }
        1554 -> {
            217
        }
        1555 -> {
            f.fVar76 = f32(4.5)
            1554
        }
        1556 -> {
            f.fVar57 = f32(0.5)
            1555
        }
        1557 -> {
            if ((b(((b((f.fVar54) < (8.0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 1556 else 1553
        }
        1558 -> {
            316
        }
        1559 -> {
            143
        }
        1560 -> {
            f.dVar75 = 4.8
            1559
        }
        1561 -> {
            if ((b((((f.dVar63) + (-(4.8)))) < (0.0))) != 0) 1560 else 1558
        }
        1562 -> {
            if ((b((4.5) <= (f.fVar22))) != 0) 1561 else 1557
        }
        1563 -> {
            f.fVar76 = f32(3.0)
            1549
        }
        1564 -> {
            f.fVar57 = f32(1.2)
            1563
        }
        1565 -> {
            f.fVar76 = f32(2.5)
            1549
        }
        1566 -> {
            f.fVar57 = f32(1.3)
            1565
        }
        1567 -> {
            if ((b(((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) || ((b(((b((f.fVar45) <= (8.0))) != 0) && ((b((f.fVar72) <= (1.0))) != 0))) != 0))) != 0) 1564 else 1566
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep49(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1568 -> {
            f.fVar76 = f32(3.5)
            1549
        }
        1569 -> {
            f.fVar57 = f32(1.0)
            1568
        }
        1570 -> {
            f.fVar76 = f32(3.2)
            1549
        }
        1571 -> {
            f.fVar57 = f32(1.2)
            1570
        }
        1572 -> {
            if ((b((f.fVar57) < (10.0))) != 0) 1569 else 1571
        }
        1573 -> {
            if ((b((readI32(f.param_1.plus(0x1f8))) < (0x19))) != 0) 1567 else 1572
        }
        1574 -> {
            217
        }
        1575 -> {
            f.fVar76 = f32(4.7)
            1574
        }
        1576 -> {
            f.fVar57 = f32(0.5)
            1575
        }
        1577 -> {
            if ((b(((b(((b((((f.fVar71) - (f.fVar69))) < (1.2))) != 0) && ((b((f.fVar57) < (11.0))) != 0))) != 0) && ((b((0x30) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) 1576 else 1573
        }
        1578 -> {
            if ((b((f.fVar57) <= (12.0))) != 0) 1562 else 1577
        }
        1579 -> {
            if ((b((100.0) <= (f.fVar27))) != 0) 1578 else 1548
        }
        1580 -> {
            f.fVar70 = f32(f.fVar36)
            1579
        }
        1581 -> {
            f.fVar45 = f32(((f.fVar54) - (f.fVar69)))
            1580
        }
        1582 -> {
            316
        }
        1583 -> {
            if ((b((f.param_14) < (0x120))) != 0) 1582 else 1581
        }
        1584 -> {
            f.fVar70 = f32(0.0)
            1583
        }
        1585 -> {
            f.fVar36 = f32(0.0)
            1584
        }
        1586 -> {
            if ((b(uLt(((f.param_14) - (6)), 0x11a))) != 0) 1171 else 1585
        }
        1587 -> {
            f.dVar75 = DAT_0012ce60
            1586
        }
        1588 -> {
            f.fVar60 = f32(((f.fVar35) - (f.fVar55)))
            1587
        }
        1589 -> {
            f.dVar49 = f.fVar35
            1588
        }
        1590 -> {
            f.dVar63 = f.fVar22
            1589
        }
        1591 -> {
            f.fVar70 = f32(f.fVar54)
            316
        }
        1592 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 1591 else 316
        }
        1593 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            1592
        }
        1594 -> {
            f.bVar8 = b((b((f.fVar54) == (0.0))) != 0)
            1593
        }
        1595 -> {
            if ((b(((b((3.0) < (((readF32(f.pjVar1)) + (f.param_4))))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar54).isNaN())) != 0)) }) != 0))) != 0) 1594 else 1593
        }
        1596 -> {
            f.bVar8 = b((0) != 0)
            1595
        }
        1597 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 209 else 316
        }
        1598 -> {
            f.fVar70 = f32(f.fVar54)
            1597
        }
        1599 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            316
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep50(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1600 -> {
            f.fVar70 = f32(f32(((f.dVar53) * (f.dVar38))))
            1599
        }
        1601 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1600
        }
        1602 -> {
            f.dVar38 = ARR_0012d080[b((DAT_0012cdf8) < (f.dVar42))]
            1601
        }
        1603 -> {
            f.dVar53 = ((DAT_0012cde0) - (f.dVar42))
            1602
        }
        1604 -> {
            if ((b(((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((f.dVar42) <= (DAT_0012cde0))) != 0))) != 0) || ((b((4.3) <= (f.dVar42))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0) 1598 else 1603
        }
        1605 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1604
        }
        1606 -> {
            f.fVar57 = f32(3.2)
            1605
        }
        1607 -> {
            if ((b(((f.bVar12) != 0) || ((b((f.bVar8) != (f.bVar10))) != 0))) != 0) 1606 else 1605
        }
        1608 -> {
            f.fVar57 = f32(2.8)
            1607
        }
        1609 -> {
            f.bVar10 = b((0) != 0)
            1608
        }
        1610 -> {
            f.bVar12 = b((b((f.fVar54) == (12.0))) != 0)
            1609
        }
        1611 -> {
            f.bVar8 = b((b((f.fVar54) < (12.0))) != 0)
            1610
        }
        1612 -> {
            if ((b(!((b((f.fVar54).isNaN())) != 0))) != 0) 1611 else 1608
        }
        1613 -> {
            f.bVar10 = b((1) != 0)
            1612
        }
        1614 -> {
            f.bVar12 = b((0) != 0)
            1613
        }
        1615 -> {
            f.bVar8 = b((0) != 0)
            1614
        }
        1616 -> {
            if ((b((f.dVar42) < (2.8))) != 0) 1615 else 1608
        }
        1617 -> {
            f.bVar10 = b((0) != 0)
            1616
        }
        1618 -> {
            f.bVar12 = b((1) != 0)
            1617
        }
        1619 -> {
            f.bVar8 = b((0) != 0)
            1618
        }
        1620 -> {
            293
        }
        1621 -> {
            f.fVar76 = f32(4.7)
            1620
        }
        1622 -> {
            f.fVar57 = f32(0.5)
            1621
        }
        1623 -> {
            208
        }
        1624 -> {
            f.fVar57 = f32(0.5)
            1623
        }
        1625 -> {
            if ((b(((b(((b((f.dVar38) < (4.3))) != 0) && ((b((7.0) < (f.fVar26))) != 0))) != 0) && ((b(((b((0.35) < (f.dVar39))) != 0) || ((b((5.8) <= (f.dVar32))) != 0))) != 0))) != 0) 1624 else 1622
        }
        1626 -> {
            206
        }
        1627 -> {
            if ((b(((b(((b((f.fVar78) < (4.0))) != 0) && ((b((0.5) < (f.fVar60))) != 0))) != 0) && ((b((7.0) < (f.fVar52))) != 0))) != 0) 1626 else 1625
        }
        1628 -> {
            217
        }
        1629 -> {
            f.fVar76 = f32(4.2)
            1628
        }
        1630 -> {
            f.fVar57 = f32(0.5)
            1629
        }
        1631 -> {
            if ((b((f.fVar78) < (4.0))) != 0) 206 else 1625
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep51(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1632 -> {
            if ((b((f.dVar39) <= (DAT_0012ccb8))) != 0) 1627 else 1631
        }
        1633 -> {
            f.fVar76 = f32(3.2)
            1620
        }
        1634 -> {
            f.fVar57 = f32(0.55)
            1633
        }
        1635 -> {
            f.fVar76 = f32(4.2)
            1620
        }
        1636 -> {
            f.fVar57 = f32(0.55)
            208
        }
        1637 -> {
            if ((b(((b((f.iVar14) < (0x49))) != 0) || ((b((f.dVar49) <= (DAT_0012cc90))) != 0))) != 0) 1634 else 207
        }
        1638 -> {
            if ((b(((b((3.9) <= (f.dVar38))) != 0) || ((b(((b((f.fVar26) <= (7.5))) != 0) || ((b((f.fVar52) <= (6.5))) != 0))) != 0))) != 0) 1632 else 1637
        }
        1639 -> {
            f.fVar76 = f32(3.9)
            1620
        }
        1640 -> {
            f.fVar57 = f32(0.45)
            1639
        }
        1641 -> {
            205
        }
        1642 -> {
            f.fVar57 = f32(0.5)
            1641
        }
        1643 -> {
            if ((b(((b((f.dVar42) < (DAT_0012cdf8))) != 0) && ((b(((b((f.dVar38) < (3.9))) != 0) || ((b((DAT_0012ccb8) < (f.dVar39))) != 0))) != 0))) != 0) 1642 else 1640
        }
        1644 -> {
            if ((b(((b(((b(((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((f.fVar57) <= (1.0))) != 0))) != 0) && ((b(((b((DAT_0012ce48) <= (f.dVar38))) != 0) || ((b((f.fVar57) <= (0.7))) != 0))) != 0))) != 0) && ((b(((b((DAT_0012cca0) <= (f.dVar38))) != 0) || ((b((f.fVar57) <= (0.6))) != 0))) != 0))) != 0) || ((b(((b((f.dVar77) <= (8.2))) != 0) || ((b(((b((DAT_0012ce00) <= (f.dVar42))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb0))) != 0))) != 0))) != 0))) != 0) 1638 else 1643
        }
        1645 -> {
            217
        }
        1646 -> {
            f.fVar76 = f32(3.0)
            1645
        }
        1647 -> {
            f.fVar57 = f32(0.45)
            1646
        }
        1648 -> {
            if ((b(((b(((b(((b((f.fVar23) < (3.5))) != 0) && ((b((5.0) <= (f.fVar79))) != 0))) != 0) && ((b((7.0) < (f.fVar26))) != 0))) != 0) && ((b((f.iVar14) < (0x48))) != 0))) != 0) 1647 else 1644
        }
        1649 -> {
            if ((b(((b(((b((f.fVar72) < (1.2))) != 0) && ((b((f.dVar38) < (DAT_0012cf18))) != 0))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (5.5))) != 0))) != 0) 1648 else 1619
        }
        1650 -> {
            217
        }
        1651 -> {
            f.fVar57 = f32(1.0)
            1650
        }
        1652 -> {
            f.fVar76 = f32(3.5)
            1651
        }
        1653 -> {
            293
        }
        1654 -> {
            f.fVar76 = f32(3.5)
            1653
        }
        1655 -> {
            f.fVar57 = f32(0.55)
            205
        }
        1656 -> {
            207
        }
        1657 -> {
            if ((b((f.dVar33) <= (7.8))) != 0) 1656 else 1655
        }
        1658 -> {
            204
        }
        1659 -> {
            if ((b(((b(((b((f.fVar54) < (9.5))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b((f.fVar52) < (6.5))) != 0))) != 0) 1658 else 1657
        }
        1660 -> {
            f.fVar57 = f32(1.0)
            205
        }
        1661 -> {
            293
        }
        1662 -> {
            f.fVar76 = f32(3.0)
            1661
        }
        1663 -> {
            f.fVar57 = f32(1.0)
            1662
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep52(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1664 -> {
            if ((b(((b((f.fVar54) < (8.5))) != 0) && ((b((8.0) < (f.fVar79))) != 0))) != 0) 1663 else 1660
        }
        1665 -> {
            if ((b(((b(((b((3.0) <= (f.fVar23))) != 0) || ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0) || ((b((f.fVar52) <= (6.0))) != 0))) != 0) 1659 else 1664
        }
        1666 -> {
            217
        }
        1667 -> {
            f.fVar76 = f32(4.7)
            1666
        }
        1668 -> {
            f.fVar57 = f32(0.5)
            1667
        }
        1669 -> {
            if ((b((0.5) <= (((f.fVar22) + (-(3.5)))))) != 0) 204 else 1665
        }
        1670 -> {
            if ((b(((b((4.3) <= (f.dVar38))) != 0) || ((b(((b(((b(((b((f.fVar52) <= (6.0))) != 0) && ((b((f.fVar79) <= (6.0))) != 0))) != 0) || ((b((f.fVar23) <= (2.0))) != 0))) != 0) || ((b(((b((f.fVar54) <= (6.8))) != 0) || ((b((f.dVar39) <= (DAT_0012cdf0))) != 0))) != 0))) != 0))) != 0) 1669 else 1652
        }
        1671 -> {
            f.fVar76 = f32(3.0)
            1651
        }
        1672 -> {
            if ((b(((b(((b(((b(((b((3.0) <= (f.fVar23))) != 0) || ((b(((b((f.fVar52) <= (6.0))) != 0) && ((b((f.fVar79) <= (6.0))) != 0))) != 0))) != 0) || ((b((f.dVar39) <= (0.3))) != 0))) != 0) || ((b(((b((f.dVar77) <= (6.8))) != 0) || ((b((f.dVar38) <= (DAT_0012cca8))) != 0))) != 0))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) 1670 else 1671
        }
        1673 -> {
            if ((b(((b(((b((f.fVar71) < (3.0))) != 0) && ((b((f.fVar69) < (3.0))) != 0))) != 0) && ((b((f.fVar52) < (8.5))) != 0))) != 0) 1672 else 1649
        }
        1674 -> {
            if ((b((f.fVar67) <= (8.0))) != 0) 1673 else 316
        }
        1675 -> {
            f.fVar70 = f32(0.0)
            1674
        }
        1676 -> {
            216
        }
        1677 -> {
            if ((b(((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b(((b((((readF32(f.pjVar1)) + (f.param_4))) <= (3.0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((0.5) <= (((((readF32(f.param_1.plus(0x230))) - (readF32(f.param_1.plus(0x1a8))))) - (((readF32(f.param_1.plus(0x1a8))) - (readF32(f.param_1.plus(0x234)))))))) }) != 0))) != 0))) != 0) 1676 else 316
        }
        1678 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            316
        }
        1679 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1678
        }
        1680 -> {
            f.fVar70 = f32(f32(((((3.3) - (f.dVar42))) * (f.dVar38))))
            1679
        }
        1681 -> {
            f.dVar38 = DAT_0012ce88
            1680
        }
        1682 -> {
            if ((b((f.dVar42) <= (DAT_0012cdf8))) != 0) 1681 else 1680
        }
        1683 -> {
            f.dVar38 = 0.5
            1682
        }
        1684 -> {
            if ((b(((b(((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((f.dVar42) <= (3.3))) != 0))) != 0) || ((b((DAT_0012ce48) <= (f.dVar42))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x248))) <= (DAT_0012cfe0))) != 0) || ((b((((readF32(f.param_1.plus(0x248))) - (kotlin.math.abs(readF32(f.param_1.plus(0x24c)))))) <= (DAT_0012cf68))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.3))) != 0))) != 0) 1677 else 1683
        }
        1685 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.0, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1684
        }
        1686 -> {
            f.fVar57 = f32(3.0)
            1685
        }
        1687 -> {
            if ((b(((b((DAT_0012cf88) <= (f.dVar48))) != 0) || ((run { run { f.fVar57 = f32(3.5); f32(3.5) }; b(((b((1.5) <= (f.fVar60))) != 0) && ((run { run { f.fVar57 = f32(3.5); f32(3.5) }; b((DAT_0012cd18) <= (f.dVar33)) }) != 0)) }) != 0))) != 0) 1686 else 1685
        }
        1688 -> {
            f.fVar57 = f32(3.0)
            1685
        }
        1689 -> {
            if ((b(((f.bVar10) != 0) || ((b((f.bVar12) != (f.bVar13))) != 0))) != 0) 1688 else 1685
        }
        1690 -> {
            f.fVar57 = f32(3.5)
            1689
        }
        1691 -> {
            f.bVar13 = b((0) != 0)
            1690
        }
        1692 -> {
            f.bVar10 = b((b((f.dVar42) == (DAT_0012ce20))) != 0)
            1691
        }
        1693 -> {
            f.bVar12 = b((b((f.dVar42) < (DAT_0012ce20))) != 0)
            1692
        }
        1694 -> {
            if ((b(((b(!((b((f.dVar42).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012ce20).isNaN())) != 0))) != 0))) != 0) 1693 else 1690
        }
        1695 -> {
            f.bVar13 = b((1) != 0)
            1694
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep53(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1696 -> {
            f.bVar10 = b((0) != 0)
            1695
        }
        1697 -> {
            f.bVar12 = b((0) != 0)
            1696
        }
        1698 -> {
            if ((f.bVar8) != 0) 1697 else 1690
        }
        1699 -> {
            f.bVar13 = b((0) != 0)
            1698
        }
        1700 -> {
            f.bVar10 = b((1) != 0)
            1699
        }
        1701 -> {
            f.bVar12 = b((0) != 0)
            1700
        }
        1702 -> {
            f.bVar8 = b((b((f.dVar48) < (0.35))) != 0)
            1701
        }
        1703 -> {
            if ((b(((b((f.fVar65) < (DAT_0012cc78))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(!((b((f.dVar48).isNaN())) != 0)) }) != 0))) != 0) 1702 else 1701
        }
        1704 -> {
            f.bVar8 = b((0) != 0)
            1703
        }
        1705 -> {
            if ((b(((b(((b((f.dVar53) <= (DAT_0012cca8))) != 0) && ((b((-(0.35)) <= (f.dVar49))) != 0))) != 0) || ((b((DAT_0012ce20) <= (f.dVar42))) != 0))) != 0) 1687 else 1704
        }
        1706 -> {
            if ((b(((b((84.0) < (f.fVar27))) != 0) && ((b(((b((f.fVar52) < (8.0))) != 0) || ((run { run { f.fVar57 = f32(3.0); f32(3.0) }; b((f.fVar79) < (8.0)) }) != 0))) != 0))) != 0) 1705 else 1685
        }
        1707 -> {
            f.fVar57 = f32(3.0)
            1706
        }
        1708 -> {
            212
        }
        1709 -> {
            if ((b((0x36) < (f.iVar14))) != 0) 1708 else 1707
        }
        1710 -> {
            293
        }
        1711 -> {
            f.fVar57 = f32(1.0)
            1710
        }
        1712 -> {
            f.fVar76 = f32(3.5)
            1711
        }
        1713 -> {
            if ((b(((b(((b((f.fVar78) <= (6.0))) != 0) || ((b(((b(((b((DAT_0012cc80) <= (f.fVar46))) != 0) || ((b((DAT_0012cc80) <= (f.fVar47))) != 0))) != 0) || ((b((DAT_0012cc80) <= (f.fVar74))) != 0))) != 0))) != 0) || ((run { run { f.fVar76 = f32(f.fVar78); f32(f.fVar78) }; b((0.3) <= (f.fVar45)) }) != 0))) != 0) 1712 else 1711
        }
        1714 -> {
            if ((b(((b((0x36) < (f.iVar14))) != 0) && ((b((f.dVar33) < (8.2))) != 0))) != 0) 212 else 1707
        }
        1715 -> {
            if ((b((f.dVar53) < (DAT_0012ccb0))) != 0) 1709 else 1714
        }
        1716 -> {
            293
        }
        1717 -> {
            f.fVar57 = f32(1.0)
            1716
        }
        1718 -> {
            f.fVar76 = f32(2.5)
            1717
        }
        1719 -> {
            f.fVar76 = f32(3.0)
            1717
        }
        1720 -> {
            if ((b((f.fVar78) <= (2.5))) != 0) 1718 else 1719
        }
        1721 -> {
            217
        }
        1722 -> {
            f.fVar76 = f32(3.2)
            1721
        }
        1723 -> {
            f.fVar57 = f32(1.0)
            1722
        }
        1724 -> {
            if ((b((f.fVar65) < (DAT_0012cc78))) != 0) 1723 else 1720
        }
        1725 -> {
            f.fVar76 = f32(3.5)
            1717
        }
        1726 -> {
            f.fVar76 = f32(3.2)
            1717
        }
        1727 -> {
            if ((b((f.fVar52) <= (f.fVar79))) != 0) 1725 else 1726
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep54(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1728 -> {
            if ((b(((b(((b((8.0) <= (f.fVar52))) != 0) || ((b((f.fVar27) <= (84.0))) != 0))) != 0) || ((b(((b((f.dVar42) <= (2.8))) != 0) || ((b((f.iVar14) < (0x31))) != 0))) != 0))) != 0) 1724 else 1727
        }
        1729 -> {
            if ((b(((b(((b(((b((1.2) < (f.dVar53))) != 0) && ((b((DAT_0012ce40) < (f.dVar39))) != 0))) != 0) && ((b((f.dVar38) < (4.6))) != 0))) != 0) && ((b((f.dVar42) < (DAT_0012ce20))) != 0))) != 0) 1728 else 1715
        }
        1730 -> {
            f.dVar53 = f.fVar57
            1729
        }
        1731 -> {
            217
        }
        1732 -> {
            f.fVar76 = f32(2.7)
            1731
        }
        1733 -> {
            f.fVar57 = f32(1.0)
            1732
        }
        1734 -> {
            if ((b(((b((f.dVar49) < (DAT_0012d060))) != 0) && ((b(((b((f.dVar42) < (DAT_0012ce20))) != 0) && ((b((0.35) < (f.dVar48))) != 0))) != 0))) != 0) 1733 else 1730
        }
        1735 -> {
            f.fVar70 = f32(f.fVar54)
            316
        }
        1736 -> {
            writeF32(f.pjVar1, f32(0.0))
            1735
        }
        1737 -> {
            316
        }
        1738 -> {
            if ((b((2.5) < (f.fVar69))) != 0) 1737 else 216
        }
        1739 -> {
            f.fVar69 = f32(((f.fVar70) + (f.param_4)))
            215
        }
        1740 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            214
        }
        1741 -> {
            if ((b(((b((f.iVar19) == (1))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) 1740 else 216
        }
        1742 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            213
        }
        1743 -> {
            writeI32(f.param_1.plus(0x168), 1)
            316
        }
        1744 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            1743
        }
        1745 -> {
            f.fVar70 = f32(f32(((((2.8) - (f.dVar42))) * (ARR_0012d080[b((3.0) < (f.fVar78))]))))
            1744
        }
        1746 -> {
            if ((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) || ((b(((b((3.5) <= (f.fVar78))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.8))) != 0))) != 0))) != 0))) != 0) 1742 else 1745
        }
        1747 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar36, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1746
        }
        1748 -> {
            f.fVar36 = f32(2.5)
            1747
        }
        1749 -> {
            if ((b(((b(((b(((b(((b((9.0) <= (f.fVar79))) != 0) || ((b((f.dVar49) <= (DAT_0012ce98))) != 0))) != 0) || ((b((f.fVar78) <= (2.0))) != 0))) != 0) || ((b((f.fVar27) <= (90.0))) != 0))) != 0) && ((run { run { f.fVar36 = f32(2.8); f32(2.8) }; b((f.fVar73) <= (2.0)) }) != 0))) != 0) 1748 else 1747
        }
        1750 -> {
            if ((b(((b(((b((f.fVar52) <= (8.0))) != 0) || ((b(((b((f.fVar60) <= (1.5))) != 0) && ((b((((f.fVar54) - (f.fVar69))) <= (8.0))) != 0))) != 0))) != 0) || ((b(((b((f.fVar79) <= (8.5))) != 0) || ((run { run { f.fVar36 = f32(3.0); f32(3.0) }; b(((b((3.0) <= (f.fVar78))) != 0) && ((b((f.fVar27) <= (108.0))) != 0)) }) != 0))) != 0))) != 0) 1734 else 1749
        }
        1751 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar76, f.fVar57, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            316
        }
        1752 -> {
            f.fVar76 = f32(4.2)
            217
        }
        1753 -> {
            f.fVar57 = f32(0.55)
            1752
        }
        1754 -> {
            if ((b(((b(((b((1.0) <= (f.fVar56))) != 0) || ((b((8.0) <= (((f.fVar54) - (f.fVar69))))) != 0))) != 0) || ((b(((b((1.0) <= (f.fVar72))) != 0) || ((b((f.iVar14) < (0x3c))) != 0))) != 0))) != 0) 1750 else 1753
        }
        1755 -> {
            293
        }
        1756 -> {
            f.fVar57 = f32(0.65)
            1755
        }
        1757 -> {
            f.fVar76 = f32(4.2)
            1756
        }
        1758 -> {
            f.fVar76 = f32(4.5)
            1756
        }
        1759 -> {
            if ((b(((b(((b((f.dVar31) <= (DAT_0012ce00))) != 0) || ((b((f.dVar59) <= (DAT_0012ce00))) != 0))) != 0) || ((b((f.dVar81) <= (DAT_0012ce00))) != 0))) != 0) 1757 else 1758
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep55(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1760 -> {
            316
        }
        1761 -> {
            293
        }
        1762 -> {
            f.fVar76 = f32(3.5)
            1761
        }
        1763 -> {
            f.fVar57 = f32(1.0)
            1762
        }
        1764 -> {
            270
        }
        1765 -> {
            f.fVar57 = f32(3.9)
            1764
        }
        1766 -> {
            f.fVar60 = f32(0.55)
            1765
        }
        1767 -> {
            f.fVar57 = f32(3.5)
            1764
        }
        1768 -> {
            f.fVar60 = f32(0.55)
            1767
        }
        1769 -> {
            if ((b(((b(((b((f.fVar27) <= (84.0))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb8))) != 0))) != 0) || ((b(((b((DAT_0012ce00) <= (f.dVar42))) != 0) || ((b((f.fVar52) <= (6.5))) != 0))) != 0))) != 0) 1766 else 1768
        }
        1770 -> {
            if ((b(((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((f.fVar57) <= (DAT_0012cc40))) != 0))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb8))) != 0))) != 0) 1769 else 1763
        }
        1771 -> {
            217
        }
        1772 -> {
            f.fVar76 = f32(4.7)
            1771
        }
        1773 -> {
            f.fVar57 = f32(0.4)
            1772
        }
        1774 -> {
            316
        }
        1775 -> {
            if ((b(((b((8.0) <= (f.fVar26))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((DAT_0012cd18) <= (f.dVar32)) }) != 0))) != 0) 1774 else 1773
        }
        1776 -> {
            f.fVar76 = f32(4.2)
            1771
        }
        1777 -> {
            f.fVar57 = f32(0.55)
            1776
        }
        1778 -> {
            if ((b(((b((f.fVar60) <= (1.0))) != 0) || ((b(((b((f.fVar79) <= (7.0))) != 0) && ((b(((b((f.fVar54) <= (8.0))) != 0) || ((b((f.fVar52) <= (6.5))) != 0))) != 0))) != 0))) != 0) 1775 else 1777
        }
        1779 -> {
            if ((b(((b(((b((5.3) <= (f.dVar38))) != 0) || ((b(((b((f.dVar39) <= (0.7))) != 0) && ((b((f.fVar79) <= (7.0))) != 0))) != 0))) != 0) || ((b((f.fVar26) <= (9.5))) != 0))) != 0) 1778 else 1770
        }
        1780 -> {
            f.fVar57 = f32(1.2)
            1762
        }
        1781 -> {
            293
        }
        1782 -> {
            f.fVar76 = f32(3.0)
            1781
        }
        1783 -> {
            f.fVar57 = f32(1.2)
            1782
        }
        1784 -> {
            if ((b(((b((DAT_0012cff8) <= (f.dVar48))) != 0) || ((b((f.dVar49) <= (-(0.3)))) != 0))) != 0) 1783 else 1780
        }
        1785 -> {
            if ((b(((b(((b((3.0) <= (f.fVar78))) != 0) || ((b((f.fVar26) <= (9.0))) != 0))) != 0) || ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0) 1779 else 1784
        }
        1786 -> {
            316
        }
        1787 -> {
            290
        }
        1788 -> {
            f.bVar12 = b((b((f.fVar22) < (3.0))) != 0)
            1787
        }
        1789 -> {
            f.bVar10 = b((b((f.fVar22) == (3.0))) != 0)
            1788
        }
        1790 -> {
            f.bVar8 = b((b((f.fVar22).isNaN())) != 0)
            1789
        }
        1791 -> {
            f.fVar22 = f32(((f.fVar70) + (f.param_4)))
            1790
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep56(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1792 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            1791
        }
        1793 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 1792 else 1786
        }
        1794 -> {
            f.fVar70 = f32(f.fVar54)
            1793
        }
        1795 -> {
            229
        }
        1796 -> {
            f.dVar38 = ((((f.dVar63) - (f.dVar42))) * (ARR_0012d080[b((DAT_0012cdf8) < (f.dVar42))]))
            1795
        }
        1797 -> {
            if ((b(((b(((b((f.dVar42) < (4.3))) != 0) && ((b((f.dVar63) < (f.dVar42))) != 0))) != 0) && ((b(((b((f.fVar54) == (0.0))) != 0) && ((b((3.0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1796 else 1794
        }
        1798 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1797
        }
        1799 -> {
            273
        }
        1800 -> {
            f.fVar57 = f32(3.5)
            1799
        }
        1801 -> {
            f.fVar60 = f32(1.0)
            1800
        }
        1802 -> {
            if ((b(((b(((b((f.fVar54) < (12.0))) != 0) && ((b((3.5) < (f.fVar23))) != 0))) != 0) && ((b(((b((f.fVar52) < (7.5))) != 0) && ((b(((b((f.fVar54) < (10.0))) != 0) || ((b((0x36) < (f.iVar14))) != 0))) != 0))) != 0))) != 0) 1801 else 1798
        }
        1803 -> {
            228
        }
        1804 -> {
            f.dVar53 = ((3.0) - (f.fVar78))
            1803
        }
        1805 -> {
            f.dVar38 = ARR_0012d080[b((3.3) < (f.dVar42))]
            1804
        }
        1806 -> {
            if ((b(((b(((b(((b((f.dVar42) < (4.6))) != 0) && ((b((3.0) < (f.fVar78))) != 0))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) && ((b((3.0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 1805 else 1794
        }
        1807 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1806
        }
        1808 -> {
            if ((b(((b(((b((f.fVar79) <= (8.0))) != 0) || ((b(((b((f.fVar57) <= (DAT_0012cca8))) != 0) && ((b((f.dVar33) <= (DAT_0012ce68))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.0))) != 0))) != 0) 1802 else 1807
        }
        1809 -> {
            if ((b(((b(((b(((b(((b((f.fVar57) <= (1.5))) != 0) || ((b((f.dVar81) <= (DAT_0012ce18))) != 0))) != 0) || ((b((f.dVar59) <= (DAT_0012ce18))) != 0))) != 0) || ((b(((b((0.75) <= (f.fVar45))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0))) != 0) || ((b(((b((3.0) <= (f.fVar78))) != 0) || ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((f.dVar39) <= (DAT_0012cca8)) }) != 0))) != 0))) != 0) 1808 else 1786
        }
        1810 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1786
        }
        1811 -> {
            f.fVar57 = f32(3.2)
            1810
        }
        1812 -> {
            f.fVar57 = f32(2.5)
            1810
        }
        1813 -> {
            if ((b(((b(((b((f.dVar48) < (0.3))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0) || ((b(((b((f.dVar48) < (0.35))) != 0) && ((b((f.fVar65) < (DAT_0012cc78))) != 0))) != 0))) != 0) 1811 else 1812
        }
        1814 -> {
            211
        }
        1815 -> {
            if ((b(((b(((b((0x35) < (f.iVar14))) != 0) || ((b((f.dVar33) <= (8.2))) != 0))) != 0) || ((b((f.dVar39) <= (1.2))) != 0))) != 0) 1814 else 1813
        }
        1816 -> {
            f.fVar57 = f32(3.0)
            1810
        }
        1817 -> {
            f.fVar57 = f32(3.5)
            1810
        }
        1818 -> {
            if ((b(((b((f.iVar14) < (0x3d))) != 0) || ((b((DAT_0012cd18) <= (f.dVar33))) != 0))) != 0) 1816 else 1817
        }
        1819 -> {
            if ((b(((b((f.fVar60) <= (1.0))) != 0) || ((b(((b((f.iVar14) < (0x3d))) != 0) && ((b((8.2) <= (f.dVar33))) != 0))) != 0))) != 0) 1815 else 1818
        }
        1820 -> {
            if ((b(((b((3.0) <= (f.fVar78))) != 0) || ((b((f.fVar26) <= (9.0))) != 0))) != 0) 211 else 1819
        }
        1821 -> {
            316
        }
        1822 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1821
        }
        1823 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            1822
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep57(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1824 -> {
            f.fVar70 = f32(f32(((((2.5) - (f.dVar42))) * (ARR_0012d090[b((2.8) < (f.dVar42))]))))
            1823
        }
        1825 -> {
            213
        }
        1826 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            1825
        }
        1827 -> {
            if ((b(((b(((b((3.8) <= (f.dVar42))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) || ((b(((b((f.fVar54) != (0.0))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.5))) != 0))) != 0))) != 0))) != 0) 1826 else 1824
        }
        1828 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1827
        }
        1829 -> {
            if ((b(((b(((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0) && ((b((f.iVar14) < (0x3c))) != 0))) != 0) && ((b(((b((6.0) < (f.fVar36))) != 0) || ((b((0.6) < (f.fVar45))) != 0))) != 0))) != 0) 1828 else 1820
        }
        1830 -> {
            316
        }
        1831 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.5, 0.75, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1830
        }
        1832 -> {
            if ((b(((b(((b(((b((4.3) <= (f.dVar38))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b((f.fVar78) <= (3.0))) != 0))) != 0) || ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((f.fVar57) <= (1.2)) }) != 0))) != 0) 1831 else 1830
        }
        1833 -> {
            if ((b(((b((0.75) < (f.fVar60))) != 0) && ((b(((b((0x42) < (f.iVar14))) != 0) || ((b(((b((f.fVar54) < (10.0))) != 0) || ((b((f.fVar52) < (7.0))) != 0))) != 0))) != 0))) != 0) 1832 else 1829
        }
        1834 -> {
            if ((b(((b((f.fVar36) < (7.0))) != 0) && ((b(((b((f.fVar54) < (10.0))) != 0) || ((b((f.fVar72) < (1.0))) != 0))) != 0))) != 0) 1833 else 1829
        }
        1835 -> {
            243
        }
        1836 -> {
            f.fVar57 = f32(4.2)
            1835
        }
        1837 -> {
            f.fVar60 = f32(0.5)
            1836
        }
        1838 -> {
            if ((b(((b(((b((3.5) < (f.fVar78))) != 0) || ((b((f.fVar36) < (6.5))) != 0))) != 0) && ((b(((b((f.fVar45) < (0.5))) != 0) && ((b(((b((f.fVar72) < (DAT_0012ccb8))) != 0) && ((b((0x36) < (f.iVar14))) != 0))) != 0))) != 0))) != 0) 1837 else 1834
        }
        1839 -> {
            f.fVar36 = f32(((f.fVar54) - (f.fVar69)))
            1838
        }
        1840 -> {
            if ((b(((b(((b(((b((5.1) <= (f.dVar38))) != 0) || ((b((0.85) <= (f.fVar45))) != 0))) != 0) || ((b((1.0) <= (f.fVar72))) != 0))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0) 1839 else 1785
        }
        1841 -> {
            217
        }
        1842 -> {
            f.fVar76 = f32(4.5)
            1841
        }
        1843 -> {
            f.fVar57 = f32(0.55)
            1842
        }
        1844 -> {
            f.fVar76 = f32(3.5)
            1841
        }
        1845 -> {
            f.fVar57 = f32(0.55)
            1844
        }
        1846 -> {
            293
        }
        1847 -> {
            f.fVar57 = f32(0.55)
            1846
        }
        1848 -> {
            f.fVar76 = f32(3.5)
            1847
        }
        1849 -> {
            if ((b(((b((f.fVar78) <= (3.5))) != 0) || ((run { run { f.fVar76 = f32(f.fVar78); f32(f.fVar78) }; b((4.5) <= (f.fVar78)) }) != 0))) != 0) 1848 else 1847
        }
        1850 -> {
            if ((b((DAT_0012ced0) <= (f.dVar49))) != 0) 1849 else 1845
        }
        1851 -> {
            if ((b(((b((f.dVar39) <= (0.85))) != 0) || ((b((f.dVar33) <= (6.8))) != 0))) != 0) 1843 else 1850
        }
        1852 -> {
            316
        }
        1853 -> {
            if ((b(((b((6.0) < (f.fVar52))) != 0) && ((b(((b((6.5) < (f.fVar79))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((5.5) < (f.fVar23)) }) != 0))) != 0))) != 0) 1852 else 1851
        }
        1854 -> {
            if ((b(((b(((b((4.55) < (f.dVar38))) != 0) && ((b((DAT_0012ce00) < (f.dVar42))) != 0))) != 0) && ((b(((b((0x36) < (f.iVar14))) != 0) || ((b(((b((f.dVar48) < (0.3))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0))) != 0))) != 0) 1853 else 1840
        }
        1855 -> {
            f.fVar76 = f32(4.7)
            1761
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep58(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1856 -> {
            f.fVar57 = f32(0.45)
            1855
        }
        1857 -> {
            f.fVar76 = f32(4.2)
            1761
        }
        1858 -> {
            f.fVar57 = f32(0.4)
            1857
        }
        1859 -> {
            if ((b(((b(((b(((b((f.fVar78) <= (3.0))) != 0) || ((b((f.fVar26) <= (8.5))) != 0))) != 0) || ((b((4.0) <= (f.fVar78))) != 0))) != 0) || ((b(((b((f.fVar60) <= (0.5))) != 0) || ((b((DAT_0012cfc0) <= (f.dVar49))) != 0))) != 0))) != 0) 1856 else 1858
        }
        1860 -> {
            f.fVar76 = f32(4.2)
            1761
        }
        1861 -> {
            f.fVar57 = f32(0.45)
            1860
        }
        1862 -> {
            270
        }
        1863 -> {
            f.fVar57 = f32(4.7)
            1862
        }
        1864 -> {
            f.fVar60 = f32(0.45)
            1863
        }
        1865 -> {
            f.fVar57 = f32(4.2)
            1862
        }
        1866 -> {
            f.fVar60 = f32(0.45)
            1865
        }
        1867 -> {
            if ((b(((b((f.dVar39) <= (DAT_0012cdf0))) != 0) || ((b((f.fVar65) <= (DAT_0012d058))) != 0))) != 0) 1864 else 1866
        }
        1868 -> {
            if ((b(((b(((b((f.dVar48) <= (0.3))) != 0) || ((b((-(0.3)) <= (f.dVar49))) != 0))) != 0) && ((b(((b((f.dVar48) <= (DAT_0012cfc8))) != 0) || ((b((f.fVar64) <= (f.fVar29))) != 0))) != 0))) != 0) 1867 else 1861
        }
        1869 -> {
            f.fVar57 = f32(0.5)
            1860
        }
        1870 -> {
            if ((b(((b(((b((f.fVar60) <= (0.5))) != 0) && ((b(((b((DAT_0012cdf8) <= (f.dVar42))) != 0) || ((b((f.dVar39) <= (DAT_0012cdf0))) != 0))) != 0))) != 0) || ((b((f.dVar32) <= (DAT_0012cf28))) != 0))) != 0) 1868 else 1869
        }
        1871 -> {
            217
        }
        1872 -> {
            f.fVar76 = f32(3.5)
            1871
        }
        1873 -> {
            f.fVar57 = f32(1.0)
            1872
        }
        1874 -> {
            if ((b(((b(((b(((b(((b((f.fVar23) < (4.5))) != 0) && ((b((1.0) < (f.fVar57))) != 0))) != 0) || ((b(((b((f.dVar38) < (DAT_0012ce48))) != 0) && ((b((0.7) < (f.fVar57))) != 0))) != 0))) != 0) || ((b(((b((f.dVar38) < (DAT_0012cca0))) != 0) && ((b((DAT_0012cdc0) < (f.fVar57))) != 0))) != 0))) != 0) && ((b(((b((f.dVar42) < (DAT_0012ce00))) != 0) && ((b(((b((8.2) < (f.dVar77))) != 0) && ((b((0.35) < (f.dVar39))) != 0))) != 0))) != 0))) != 0) 1873 else 1870
        }
        1875 -> {
            if ((b(((b(((b((5.0) <= (f.fVar23))) != 0) || ((b((f.fVar26) <= (8.0))) != 0))) != 0) || ((b(((b(((b((f.fVar57) <= (0.5))) != 0) && ((b((f.fVar52) <= (7.0))) != 0))) != 0) && ((b((f.dVar32) <= (DAT_0012cd18))) != 0))) != 0))) != 0) 1859 else 1874
        }
        1876 -> {
            f.fVar57 = f32(1.0)
            1761
        }
        1877 -> {
            f.fVar76 = f32(3.5)
            1876
        }
        1878 -> {
            f.fVar76 = f32(3.0)
            1876
        }
        1879 -> {
            if ((b(((b(((b((3.3) <= (f.dVar38))) != 0) || ((b(((b((f.fVar52) <= (6.0))) != 0) && ((b((f.fVar79) <= (6.0))) != 0))) != 0))) != 0) || ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0) 1877 else 1878
        }
        1880 -> {
            if ((b(((b(((b(((b((f.fVar26) <= (8.5))) != 0) || ((b((4.6) <= (f.dVar38))) != 0))) != 0) || ((b((f.fVar52) < (6.0))) != 0))) != 0) || ((b(((b((3.9) <= (f.dVar42))) != 0) || ((b((f.fVar27) <= (84.0))) != 0))) != 0))) != 0) 1875 else 1879
        }
        1881 -> {
            if ((b(((b(((b(((b((0.6) <= (f.fVar45))) != 0) || ((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0))) != 0) || ((b((DAT_0012cc40) <= (f.fVar72))) != 0))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0) 1854 else 1880
        }
        1882 -> {
            217
        }
        1883 -> {
            f.fVar76 = f32(3.2)
            1882
        }
        1884 -> {
            f.fVar57 = f32(0.45)
            1883
        }
        1885 -> {
            if ((b(((b(((b((f.dVar38) < (DAT_0012cde0))) != 0) && ((b((f.fVar78) < (3.0))) != 0))) != 0) && ((b((6.5) < (f.fVar79))) != 0))) != 0) 1884 else 1881
        }
        1886 -> {
            if ((b(((b(((b(((b((f.fVar78) <= (4.0))) != 0) || ((b((f.fVar46) <= (0.3))) != 0))) != 0) || ((b((-(0.7)) <= (f.fVar47))) != 0))) != 0) || ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((-(0.7)) <= (f.fVar74)) }) != 0))) != 0) 1885 else 1760
        }
        1887 -> {
            217
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep59(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1888 -> {
            f.fVar76 = f32(3.5)
            1887
        }
        1889 -> {
            f.fVar57 = f32(0.65)
            1888
        }
        1890 -> {
            if ((b(((b((f.fVar54) < (9.0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 1889 else 1760
        }
        1891 -> {
            f.fVar70 = f32(0.0)
            1890
        }
        1892 -> {
            if ((b(((b((f.dVar42) <= (DAT_0012cca0))) != 0) || ((b(((b(((b((f.fVar46) <= (1.2))) != 0) && ((b((f.fVar47) <= (1.2))) != 0))) != 0) && ((b((f.fVar74) <= (1.2))) != 0))) != 0))) != 0) 1886 else 1891
        }
        1893 -> {
            if ((b(((b(((b(((b((f.dVar42) <= (DAT_0012ce00))) != 0) || ((b(((b((f.iVar14) < (0x37))) != 0) || ((b((f.dVar31) <= (3.3))) != 0))) != 0))) != 0) || ((b((f.dVar59) <= (3.3))) != 0))) != 0) || ((b((f.dVar81) <= (3.3))) != 0))) != 0) 1892 else 1759
        }
        1894 -> {
            f.fVar57 = f32(0.55)
            1755
        }
        1895 -> {
            f.fVar76 = f32(4.7)
            1894
        }
        1896 -> {
            if ((b(((b(((b(((b((3.9) < (f.dVar31))) != 0) && ((b((3.9) < (f.dVar59))) != 0))) != 0) && ((b((3.9) < (f.dVar81))) != 0))) != 0) && ((b((f.dVar42) < (DAT_0012ce60))) != 0))) != 0) 1895 else 1894
        }
        1897 -> {
            f.fVar76 = f32(f.fVar78)
            1896
        }
        1898 -> {
            217
        }
        1899 -> {
            f.fVar76 = f32(3.0)
            1898
        }
        1900 -> {
            f.fVar57 = f32(0.85)
            1899
        }
        1901 -> {
            if ((b((f.fVar78) < (2.5))) != 0) 1900 else 1897
        }
        1902 -> {
            if ((b(((b(((b(((b((readI32(f.param_1.plus(0x228))) < (1))) != 0) || ((b((((f.param_14) - (readI32(f.param_1.plus(0x228))))) < (0x241))) != 0))) != 0) || ((b((DAT_0012ce08) <= (f.fVar46))) != 0))) != 0) || ((b(((b((DAT_0012ce08) <= (f.fVar47))) != 0) || ((b((DAT_0012ce08) <= (f.fVar74))) != 0))) != 0))) != 0) 1893 else 1901
        }
        1903 -> {
            if ((b((f.fVar54) <= (12.0))) != 0) 1902 else 1754
        }
        1904 -> {
            316
        }
        1905 -> {
            293
        }
        1906 -> {
            f.fVar76 = f32(3.2)
            1905
        }
        1907 -> {
            f.fVar57 = f32(1.2)
            1906
        }
        1908 -> {
            f.fVar76 = f32(2.5)
            1905
        }
        1909 -> {
            f.fVar57 = f32(1.3)
            1908
        }
        1910 -> {
            if ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) 1907 else 1909
        }
        1911 -> {
            f.fVar57 = f32(0.5)
            1905
        }
        1912 -> {
            f.fVar76 = f32(4.5)
            1911
        }
        1913 -> {
            f.fVar76 = f32(4.2)
            1911
        }
        1914 -> {
            if ((b(((b((f.fVar26) <= (10.0))) != 0) || ((b((f.dVar39) <= (0.6))) != 0))) != 0) 1912 else 1913
        }
        1915 -> {
            if ((b(((b(((b(((b((DAT_0012ccb8) <= (f.fVar45))) != 0) || ((b((DAT_0012cc40) <= (f.fVar72))) != 0))) != 0) || ((b((f.iVar14) < (0x25))) != 0))) != 0) || ((b(((b((f.dVar38) <= (4.6))) != 0) && ((b((8.5) <= (f.fVar54))) != 0))) != 0))) != 0) 1910 else 1914
        }
        1916 -> {
            if ((b((200.0) <= (f.fVar27))) != 0) 1915 else 1904
        }
        1917 -> {
            f.fVar70 = f32(0.0)
            1916
        }
        1918 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1904
        }
        1919 -> {
            f.fVar57 = f32(3.0)
            210
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep60(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1920 -> {
            f.fVar60 = f32(1.2)
            1919
        }
        1921 -> {
            f.fVar57 = f32(2.5)
            210
        }
        1922 -> {
            f.fVar60 = f32(1.3)
            1921
        }
        1923 -> {
            if ((b(((b(((b((f.fVar57) <= (1.2))) != 0) || ((b((DAT_0012cde0) <= (f.dVar42))) != 0))) != 0) || ((b(((b((0x2f) < (f.iVar14))) != 0) || ((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((f.fVar26) <= (13.0))) != 0))) != 0))) != 0))) != 0) 1920 else 1922
        }
        1924 -> {
            if ((b((1.0) < (f.fVar56))) != 0) 1923 else 1904
        }
        1925 -> {
            f.fVar70 = f32(0.0)
            1924
        }
        1926 -> {
            270
        }
        1927 -> {
            f.fVar60 = f32(0.5)
            1926
        }
        1928 -> {
            f.fVar57 = f32(4.2)
            1927
        }
        1929 -> {
            f.fVar57 = f32(4.7)
            1927
        }
        1930 -> {
            if ((b(((b(((b((0.3) < (f.dVar48))) != 0) && ((b((f.dVar49) < (-(0.3)))) != 0))) != 0) || ((b(((b((DAT_0012cfc8) < (f.dVar48))) != 0) && ((b((f.fVar29) < (f.fVar64))) != 0))) != 0))) != 0) 1928 else 1929
        }
        1931 -> {
            if ((b(((b(((b((((f.fVar54) - (f.fVar69))) < (5.5))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 1930 else 1925
        }
        1932 -> {
            if ((b(((b((f.fVar27) <= (180.0))) != 0) || ((b((200.0) <= (f.fVar27))) != 0))) != 0) 1917 else 1931
        }
        1933 -> {
            if ((b(((b((f.fVar27) < (84.0))) != 0) || ((b((180.0) < (f.fVar27))) != 0))) != 0) 1932 else 1903
        }
        1934 -> {
            234
        }
        1935 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            1934
        }
        1936 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 1935 else 316
        }
        1937 -> {
            281
        }
        1938 -> {
            if ((b(((b(((b((f.fVar78) < (4.5))) != 0) && ((b((3.3) < (f.dVar42))) != 0))) != 0) && ((b(((b((f.fVar70) == (0.0))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1937 else 1936
        }
        1939 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.0, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1938
        }
        1940 -> {
            f.fVar57 = f32(3.2)
            1939
        }
        1941 -> {
            f.fVar57 = f32(2.7)
            1939
        }
        1942 -> {
            if ((b(((b(((b(((b((f.fVar60) <= (2.0))) != 0) || ((b((f.fVar78) <= (3.0))) != 0))) != 0) || ((b((3.9) <= (f.dVar42))) != 0))) != 0) || ((b((39.0) <= (f.fVar50))) != 0))) != 0) 1940 else 1941
        }
        1943 -> {
            f.fVar70 = f32(f32(f.dVar38))
            316
        }
        1944 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar38)))
            1943
        }
        1945 -> {
            writeI32(f.param_1.plus(0x168), 1)
            227
        }
        1946 -> {
            f.dVar38 = ((DAT_0012ce10) - (f.dVar42))
            1945
        }
        1947 -> {
            if ((b((f.dVar42) <= (2.8))) != 0) 1946 else 1945
        }
        1948 -> {
            f.dVar38 = ((((DAT_0012ce10) - (f.dVar42))) * (DAT_0012ccb0))
            1947
        }
        1949 -> {
            216
        }
        1950 -> {
            268
        }
        1951 -> {
            f.fVar22 = f32(2.5)
            1950
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep61(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1952 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            1951
        }
        1953 -> {
            if ((b((f.fVar54) == (0.0))) != 0) 1952 else 1949
        }
        1954 -> {
            216
        }
        1955 -> {
            if ((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) 1954 else 226
        }
        1956 -> {
            if ((b(((b(((b(((b(((b((3.5) <= (f.fVar78))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((f.fVar45) <= (0.5))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012ce10))) != 0))) != 0) 1955 else 1948
        }
        1957 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1956
        }
        1958 -> {
            f.fVar57 = f32(3.2)
            1957
        }
        1959 -> {
            if ((b(((b(((b((f.fVar52) < (f.fVar79))) != 0) && ((run { run { f.fVar57 = f32(2.5); f32(2.5) }; b((f.fVar79) < (9.0)) }) != 0))) != 0) && ((b((DAT_0012cc40) < (f.fVar70))) != 0))) != 0) 1958 else 1957
        }
        1960 -> {
            f.fVar57 = f32(2.5)
            1959
        }
        1961 -> {
            if ((b(((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) <= (0.35))) != 0))) != 0) || ((b(((b((f.fVar45) <= (0.5))) != 0) && ((b((((f.fVar54) - (f.fVar69))) <= (8.0))) != 0))) != 0))) != 0) 1942 else 1960
        }
        1962 -> {
            225
        }
        1963 -> {
            f.fVar57 = f32(1.0)
            1962
        }
        1964 -> {
            if ((b(((b((f.fVar60) <= (2.0))) != 0) && ((b(((b((f.fVar52) <= (8.5))) != 0) || ((b((f.fVar79) <= (9.0))) != 0))) != 0))) != 0) 1963 else 1961
        }
        1965 -> {
            if ((b((f.fVar54) <= (12.0))) != 0) 1964 else 1961
        }
        1966 -> {
            217
        }
        1967 -> {
            f.fVar76 = f32(3.5)
            1966
        }
        1968 -> {
            f.fVar57 = f32(0.6)
            225
        }
        1969 -> {
            316
        }
        1970 -> {
            224
        }
        1971 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            1970
        }
        1972 -> {
            236
        }
        1973 -> {
            f.dVar38 = ((2.5) - (f.dVar42))
            1972
        }
        1974 -> {
            if ((b((f.dVar42) <= (2.8))) != 0) 1973 else 1972
        }
        1975 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1974
        }
        1976 -> {
            f.dVar38 = ((((2.5) - (f.dVar42))) * (DAT_0012ccb0))
            1975
        }
        1977 -> {
            if ((b(((b(((b((f.fVar78) < (3.5))) != 0) && ((b((2.3) < (f.dVar42))) != 0))) != 0) && ((b(((b((DAT_0012cc40) < (f.fVar28))) != 0) && ((b((2.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1976 else 1971
        }
        1978 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 1977 else 1969
        }
        1979 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.3, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1978
        }
        1980 -> {
            216
        }
        1981 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b(((b((f.fVar54) != (0.0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((((readF32(f.pjVar1)) + (f.param_4))) < (3.0)) }) != 0))) != 0))) != 0) 1980 else 1969
        }
        1982 -> {
            281
        }
        1983 -> {
            if ((b(((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((f.fVar78) < (4.5))) != 0))) != 0) && ((b((3.3) < (f.dVar42))) != 0))) != 0) && ((b(((b((DAT_0012cfa8) < (((readF32(f.param_1.plus(0x248))) + (readF32(f.param_1.plus(0x24c))))))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1982 else 1981
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep62(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        1984 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1983
        }
        1985 -> {
            231
        }
        1986 -> {
            f.fVar57 = f32(3.5)
            1985
        }
        1987 -> {
            f.fVar60 = f32(1.0)
            1986
        }
        1988 -> {
            if ((b(((b((78.0) < (f.fVar27))) != 0) && ((b(((b((f.fVar52) < (8.0))) != 0) || ((b((f.fVar79) < (8.0))) != 0))) != 0))) != 0) 1987 else 1984
        }
        1989 -> {
            if ((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0) 1979 else 1988
        }
        1990 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            1969
        }
        1991 -> {
            if ((b((f.iVar19) == (1))) != 0) 1990 else 1969
        }
        1992 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            224
        }
        1993 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 1992 else 1969
        }
        1994 -> {
            227
        }
        1995 -> {
            f.dVar38 = ((2.5) - (f.dVar42))
            1994
        }
        1996 -> {
            if ((b((f.dVar42) <= (2.8))) != 0) 1995 else 1994
        }
        1997 -> {
            writeI32(f.param_1.plus(0x168), 1)
            1996
        }
        1998 -> {
            f.dVar38 = ((((2.5) - (f.dVar42))) * (DAT_0012ccb0))
            1997
        }
        1999 -> {
            if ((b(((b((f.fVar78) < (3.5))) != 0) && ((b(((b(((b((2.3) < (f.dVar42))) != 0) && ((b((DAT_0012cc40) < (f.fVar45))) != 0))) != 0) && ((b((2.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 1998 else 1993
        }
        2000 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            1999
        }
        2001 -> {
            if ((b(((b((f.fVar57) <= (2.0))) != 0) || ((b(((b(((b((f.fVar54) <= (12.0))) != 0) || ((b((f.dVar33) <= (DAT_0012ce68))) != 0))) != 0) || ((b((DAT_0012ce10) <= (f.dVar42))) != 0))) != 0))) != 0) 1989 else 2000
        }
        2002 -> {
            if ((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((0.6) <= (f.dVar38))) != 0))) != 0) 2001 else 1968
        }
        2003 -> {
            if ((b(((b(((b((f.fVar36) <= (1.0))) != 0) || ((b((f.fVar72) <= (1.0))) != 0))) != 0) || ((b((0x2f) < (f.iVar14))) != 0))) != 0) 2002 else 1965
        }
        2004 -> {
            316
        }
        2005 -> {
            290
        }
        2006 -> {
            f.bVar8 = b((0) != 0)
            2005
        }
        2007 -> {
            f.bVar10 = b((b((f.fVar22) == (3.0))) != 0)
            2006
        }
        2008 -> {
            f.bVar12 = b((b((f.fVar22) < (3.0))) != 0)
            2007
        }
        2009 -> {
            if ((b(!((b((f.fVar22).isNaN())) != 0))) != 0) 2008 else 2005
        }
        2010 -> {
            f.bVar8 = b((1) != 0)
            2009
        }
        2011 -> {
            f.bVar10 = b((0) != 0)
            2010
        }
        2012 -> {
            f.bVar12 = b((0) != 0)
            2011
        }
        2013 -> {
            f.fVar22 = f32(((f.fVar70) + (f.param_4)))
            2012
        }
        2014 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2013
        }
        2015 -> {
            if ((b((f.iVar19) == (1))) != 0) 2014 else 2004
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep63(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2016 -> {
            f.fVar70 = f32(f.fVar54)
            2015
        }
        2017 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            2016
        }
        2018 -> {
            242
        }
        2019 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2018
        }
        2020 -> {
            f.dVar38 = ARR_0012d080[b((DAT_0012cdf8) < (f.dVar42))]
            2019
        }
        2021 -> {
            f.dVar53 = ((DAT_0012cde0) - (f.dVar42))
            2020
        }
        2022 -> {
            if ((b(((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) && ((b((f.dVar42) < (DAT_0012cca0))) != 0))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 2021 else 2017
        }
        2023 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2022
        }
        2024 -> {
            f.fVar57 = f32(3.2)
            2023
        }
        2025 -> {
            f.fVar57 = f32(2.8)
            2023
        }
        2026 -> {
            if ((b(((b(((b((f.dVar39) <= (DAT_0012cca8))) != 0) || ((b((f.dVar32) <= (8.2))) != 0))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012cde8))) != 0) || ((b((f.dVar33) <= (8.2))) != 0))) != 0))) != 0) 2024 else 2025
        }
        2027 -> {
            223
        }
        2028 -> {
            if ((b(((b((f.fVar27) < (60.0))) != 0) && ((b((((f.fVar23) + (((((f.fVar61) - (f.fVar40))) - (f.fVar40))))) < (0.3))) != 0))) != 0) 2027 else 2026
        }
        2029 -> {
            316
        }
        2030 -> {
            289
        }
        2031 -> {
            f.fVar22 = f32(2.5)
            2030
        }
        2032 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2031
        }
        2033 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 2032 else 2029
        }
        2034 -> {
            f.fVar70 = f32(f.fVar54)
            2033
        }
        2035 -> {
            241
        }
        2036 -> {
            if ((b(((b(((b(((b((1.0) < (f.fVar28))) != 0) && ((b((f.fVar78) < (3.5))) != 0))) != 0) && ((b((2.5) < (f.fVar78))) != 0))) != 0) && ((b(((b((f.fVar54) == (0.0))) != 0) && ((b((2.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2035 else 2034
        }
        2037 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2036
        }
        2038 -> {
            if ((b((2.4) < (readF32(f.param_1.plus(0x274))))) != 0) 2037 else 2026
        }
        2039 -> {
            if ((b((f.fVar27) < (60.0))) != 0) 223 else 2026
        }
        2040 -> {
            if ((b((f.dVar33) <= (DAT_0012d048))) != 0) 2028 else 2039
        }
        2041 -> {
            if ((b(((b((DAT_0012ccb0) < (readF32(f.param_1.plus(0x1a0))))) != 0) && ((b((f.dVar42) < (3.3))) != 0))) != 0) 2040 else 2026
        }
        2042 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            2016
        }
        2043 -> {
            285
        }
        2044 -> {
            f.dVar53 = f.dVar39
            2043
        }
        2045 -> {
            if ((b((f.dVar42) <= (f.dVar38))) != 0) 2044 else 2043
        }
        2046 -> {
            f.dVar53 = ((((3.5) - (f.dVar42))) * (0.5))
            2045
        }
        2047 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2046
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep64(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2048 -> {
            f.dVar39 = ((((3.3) - (f.dVar42))) * (DAT_0012ce88))
            2047
        }
        2049 -> {
            if ((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((3.5) < (f.fVar78))) != 0))) != 0) && ((b(((b((f.fVar78) < (4.5))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2048 else 2042
        }
        2050 -> {
            f.dVar38 = DAT_0012cdf8
            2049
        }
        2051 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 0.55, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2050
        }
        2052 -> {
            f.fVar57 = f32(3.6)
            2051
        }
        2053 -> {
            if ((b(((f.bVar12) != 0) || ((b((f.bVar8) != (f.bVar10))) != 0))) != 0) 2052 else 2051
        }
        2054 -> {
            f.fVar57 = f32(3.0)
            2053
        }
        2055 -> {
            f.bVar10 = b((0) != 0)
            2054
        }
        2056 -> {
            f.bVar12 = b((b((f.dVar48) == (DAT_0012cfe0))) != 0)
            2055
        }
        2057 -> {
            f.bVar8 = b((b((f.dVar48) < (DAT_0012cfe0))) != 0)
            2056
        }
        2058 -> {
            if ((b(((b(!((b((f.dVar48).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012cfe0).isNaN())) != 0))) != 0))) != 0) 2057 else 2054
        }
        2059 -> {
            f.bVar10 = b((1) != 0)
            2058
        }
        2060 -> {
            f.bVar12 = b((0) != 0)
            2059
        }
        2061 -> {
            f.bVar8 = b((0) != 0)
            2060
        }
        2062 -> {
            if ((b((f.dVar49) < (DAT_0012cfc0))) != 0) 2061 else 2054
        }
        2063 -> {
            f.bVar10 = b((0) != 0)
            2062
        }
        2064 -> {
            f.bVar12 = b((1) != 0)
            2063
        }
        2065 -> {
            f.bVar8 = b((0) != 0)
            2064
        }
        2066 -> {
            if ((b(((b(((b((f.iVar14) < (0x37))) != 0) || ((b((1.2) <= (f.dVar38))) != 0))) != 0) || ((b(((b((0.85) <= (f.fVar45))) != 0) && ((b((((((f.dVar62) + (DAT_0012cdc8))) - (f.dVar42))) <= (f.dVar38))) != 0))) != 0))) != 0) 2041 else 2065
        }
        2067 -> {
            if ((b(((b((0x3c) < (f.iVar14))) != 0) || ((b((f.fVar27) < (66.0))) != 0))) != 0) 2066 else 2003
        }
        2068 -> {
            f.dVar38 = f.fVar72
            2067
        }
        2069 -> {
            217
        }
        2070 -> {
            f.fVar76 = f32(4.7)
            2069
        }
        2071 -> {
            f.fVar57 = f32(0.5)
            222
        }
        2072 -> {
            if ((b(((b(((b(((b((f.fVar36) < (1.0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b(uLt(((readI32(f.param_1.plus(0x1f8))) - (0x41)), 0x2b))) != 0))) != 0) && ((b(((b((((f.fVar54) - (f.fVar69))) < (7.0))) != 0) && ((b((f.fVar27) < (60.0))) != 0))) != 0))) != 0) 2071 else 2068
        }
        2073 -> {
            316
        }
        2074 -> {
            f.fVar70 = f32(((4.5) - (f.fVar22)))
            2073
        }
        2075 -> {
            if ((b(((b((((f.fVar22) + (-(4.5)))) < (0.5))) != 0) && ((b((((f.dVar31) + (-(4.5)))) < (0.0))) != 0))) != 0) 2074 else 2073
        }
        2076 -> {
            264
        }
        2077 -> {
            f.dVar62 = ((DAT_0012cde0) - (f.dVar62))
            2076
        }
        2078 -> {
            if ((b((((f.fVar22) + (DAT_0012ce50))) < (0.6))) != 0) 2077 else 2073
        }
        2079 -> {
            if ((b((f.fVar82) <= (1.0))) != 0) 2075 else 2078
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep65(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2080 -> {
            f.fVar70 = f32(f32(((((((6.6) - (f.dVar38))) - (f.dVar83))) / (3.0))))
            2073
        }
        2081 -> {
            if ((b((((f.dVar38) + (-(3.3)))) < (0.5))) != 0) 2080 else 2073
        }
        2082 -> {
            f.fVar70 = f32(f32(((f.dVar38) - (f.dVar62))))
            2073
        }
        2083 -> {
            f.dVar38 = 3.3
            221
        }
        2084 -> {
            f.fVar70 = f32(f32(((((((6.6) - (f.dVar62))) - (f.dVar38))) * (0.5))))
            2073
        }
        2085 -> {
            if ((b((0.6) <= (((f.dVar38) + (-(3.3)))))) != 0) 2083 else 2084
        }
        2086 -> {
            if ((b((0.0) <= (((((6.6) - (f.dVar62))) - (f.dVar83))))) != 0) 2081 else 2085
        }
        2087 -> {
            f.dVar38 = f.fVar22
            2086
        }
        2088 -> {
            if ((b((kotlin.math.abs(((f.fVar69) - (f.fVar67)))) < (0.5))) != 0) 2079 else 2087
        }
        2089 -> {
            218
        }
        2090 -> {
            if ((b((f.dVar62) <= (DAT_0012ce18))) != 0) 2089 else 2088
        }
        2091 -> {
            f.fVar70 = f32(0.0)
            2090
        }
        2092 -> {
            if ((b((f.fVar54) < (12.0))) != 0) 2091 else 2072
        }
        2093 -> {
            316
        }
        2094 -> {
            217
        }
        2095 -> {
            f.fVar76 = f32(f.fVar78)
            2094
        }
        2096 -> {
            f.fVar57 = f32(0.45)
            2095
        }
        2097 -> {
            if ((b((0x36) < (f.iVar14))) != 0) 2096 else 2093
        }
        2098 -> {
            f.fVar70 = f32(0.0)
            2097
        }
        2099 -> {
            218
        }
        2100 -> {
            if ((b(((b(((b((2.0) <= (f.fVar74))) != 0) || ((b((2.0) <= (f.fVar47))) != 0))) != 0) || ((b((2.0) <= (f.fVar46))) != 0))) != 0) 2099 else 2098
        }
        2101 -> {
            195
        }
        2102 -> {
            f.fVar57 = f32(1.0)
            2101
        }
        2103 -> {
            if ((b(((b((((f.fVar55) + (-(3.0)))) < (0.5))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((((f.fVar22) + (-(3.0)))) < (0.5)) }) != 0))) != 0) 2102 else 2093
        }
        2104 -> {
            f.fVar70 = f32(0.0)
            2103
        }
        2105 -> {
            293
        }
        2106 -> {
            f.fVar76 = f32(3.6)
            2105
        }
        2107 -> {
            f.fVar57 = f32(1.0)
            2106
        }
        2108 -> {
            if ((b(((b((f.fVar55) < (4.5))) != 0) && ((b((3.8) < (f.dVar31))) != 0))) != 0) 2107 else 2104
        }
        2109 -> {
            f.fVar70 = f32(0.0)
            2093
        }
        2110 -> {
            if ((b((1.0) < (f.fVar82))) != 0) 2108 else 218
        }
        2111 -> {
            if ((b((3.9) < (f.dVar83))) != 0) 2100 else 2110
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep66(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2112 -> {
            219
        }
        2113 -> {
            f.fVar22 = f32(((((12.0) - (f.fVar69))) - (f.fVar67)))
            2112
        }
        2114 -> {
            264
        }
        2115 -> {
            f.dVar62 = ((6.5) - (f.dVar62))
            2114
        }
        2116 -> {
            if ((b((13.5) <= (f.fVar54))) != 0) 2115 else 2113
        }
        2117 -> {
            if ((b(((b(((b((12.0) < (f.fVar54))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((f.fVar27) < (96.0))) != 0))) != 0) 2116 else 2093
        }
        2118 -> {
            218
        }
        2119 -> {
            if ((b((1.0) <= (f.fVar82))) != 0) 2118 else 2117
        }
        2120 -> {
            f.fVar70 = f32(0.0)
            2119
        }
        2121 -> {
            if ((b(((b((f.fVar69) < (6.5))) != 0) || ((b((7.0) <= (f.fVar69))) != 0))) != 0) 2111 else 2120
        }
        2122 -> {
            236
        }
        2123 -> {
            f.dVar38 = ((((3.3) - (f.dVar42))) * (0.6))
            2122
        }
        2124 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2123
        }
        2125 -> {
            233
        }
        2126 -> {
            if ((b(((b(((b((4.5) <= (f.fVar78))) != 0) || ((b((f.dVar42) <= (3.3))) != 0))) != 0) || ((b((f.fVar28) <= (DAT_0012cc40))) != 0))) != 0) 2125 else 2124
        }
        2127 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 2126 else 2093
        }
        2128 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.35, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2127
        }
        2129 -> {
            f.fVar70 = f32(((f.fVar22) * (0.5)))
            2093
        }
        2130 -> {
            f.fVar22 = f32(((6.0) - (f.fVar69)))
            219
        }
        2131 -> {
            if ((b(((b((12.0) < (f.fVar54))) != 0) && ((b((f.fVar27) < (96.0))) != 0))) != 0) 2130 else 2093
        }
        2132 -> {
            f.fVar70 = f32(0.0)
            2131
        }
        2133 -> {
            if ((b(((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((1.0) <= (f.fVar82))) != 0))) != 0) || ((b((1.0) <= (f.fVar72))) != 0))) != 0) 2128 else 2132
        }
        2134 -> {
            if ((b(((b((f.fVar69) < (6.0))) != 0) || ((b((6.5) <= (f.fVar69))) != 0))) != 0) 2121 else 2133
        }
        2135 -> {
            216
        }
        2136 -> {
            if ((b(((b(((b((f.iVar19) != (1))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((((readF32(f.pjVar1)) + (f.param_4))) <= (DAT_0012cde0)) }) != 0))) != 0) 2135 else 2093
        }
        2137 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            220
        }
        2138 -> {
            240
        }
        2139 -> {
            if ((b(((b(((b((3.3) < (f.dVar42))) != 0) && ((b((f.dVar42) < (4.3))) != 0))) != 0) && ((b(((b((f.fVar54) == (0.0))) != 0) && ((b(((b((f.dVar75) < (f.fVar28))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0))) != 0) 2138 else 2137
        }
        2140 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2139
        }
        2141 -> {
            f.fVar57 = f32(3.2)
            2140
        }
        2142 -> {
            if ((b((f.fVar78) <= (5.0))) != 0) 2141 else 2140
        }
        2143 -> {
            f.fVar57 = f32(3.5)
            2142
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep67(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2144 -> {
            273
        }
        2145 -> {
            f.fVar57 = f32(2.5)
            2144
        }
        2146 -> {
            f.fVar60 = f32(1.3)
            2145
        }
        2147 -> {
            if ((b(((b(((b(((b((DAT_0012ce68) < (f.dVar32))) != 0) && ((b((0.5) < (f.fVar45))) != 0))) != 0) && ((b((15.0) < (f.fVar54))) != 0))) != 0) && ((b((9.0) < (f.fVar52))) != 0))) != 0) 2146 else 2143
        }
        2148 -> {
            217
        }
        2149 -> {
            f.fVar76 = f32(f.fVar78)
            2148
        }
        2150 -> {
            f.fVar57 = f32(0.8)
            2149
        }
        2151 -> {
            if ((b(((b(((b(((b((4.5) < (f.fVar78))) != 0) && ((b(((b((f.fVar55) < (f.fVar78))) != 0) || ((b((f.fVar41) < (f.fVar78))) != 0))) != 0))) != 0) && ((b((0x6c0) < (f.param_14))) != 0))) != 0) && ((b(((b(((b((0x3c) < (f.iVar14))) != 0) && ((b((f.fVar52) < (7.5))) != 0))) != 0) && ((b((f.fVar79) < (8.0))) != 0))) != 0))) != 0) 2150 else 2147
        }
        2152 -> {
            222
        }
        2153 -> {
            f.fVar57 = f32(0.55)
            2152
        }
        2154 -> {
            if ((b(((b(((b(((b((f.fVar82) < (DAT_0012cc40))) != 0) && ((b((((f.fVar54) - (f.fVar22))) < (9.0))) != 0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0) 2153 else 2151
        }
        2155 -> {
            if ((b(((b((6.0) <= (f.fVar69))) != 0) || ((b((f.dVar62) < (DAT_0012cf18))) != 0))) != 0) 2134 else 2154
        }
        2156 -> {
            217
        }
        2157 -> {
            f.fVar76 = f32(f.fVar78)
            2156
        }
        2158 -> {
            f.fVar57 = f32(1.2)
            2157
        }
        2159 -> {
            231
        }
        2160 -> {
            f.fVar57 = f32(2.8)
            2159
        }
        2161 -> {
            f.fVar60 = f32(1.2)
            2160
        }
        2162 -> {
            220
        }
        2163 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            2162
        }
        2164 -> {
            316
        }
        2165 -> {
            f.fVar70 = f32(f32(((f.dVar38) * (f.dVar39))))
            2164
        }
        2166 -> {
            writeF32(f.pjVar1, f32(f32(((f.dVar38) * (f.dVar39)))))
            2165
        }
        2167 -> {
            f.dVar39 = DAT_0012ccb0
            2166
        }
        2168 -> {
            if ((b((DAT_0012cdf8) < (f.dVar53))) != 0) 2167 else 2166
        }
        2169 -> {
            f.dVar39 = DAT_0012ce88
            2168
        }
        2170 -> {
            f.dVar53 = f.dVar31
            2169
        }
        2171 -> {
            f.dVar38 = ((3.5) - (f.dVar31))
            2170
        }
        2172 -> {
            f.dVar53 = f.dVar42
            2169
        }
        2173 -> {
            f.dVar38 = ((DAT_0012cde0) - (f.dVar42))
            2172
        }
        2174 -> {
            if ((b(((b((4.5) <= (f.fVar78))) != 0) || ((b((f.dVar42) <= (DAT_0012cde0))) != 0))) != 0) 2171 else 2173
        }
        2175 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2174
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep68(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2176 -> {
            if ((b(((b((f.fVar54) == (0.0))) != 0) && ((b(((b(((b(((b((f.dVar42) < (DAT_0012cca0))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) || ((b(((b((f.dVar31) < (4.3))) != 0) && ((b((DAT_0012cde0) < (f.dVar31))) != 0))) != 0))) != 0) && ((b(((b(((b((f.iVar14) < (0x42))) != 0) && ((b((readF32(f.param_1.plus(0x24c))) < (-(0.35)))) != 0))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0))) != 0) 2175 else 2163
        }
        2177 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2176
        }
        2178 -> {
            if ((b(((b((f.fVar60) <= (2.0))) != 0) || ((b((f.fVar79) <= (8.5))) != 0))) != 0) 2177 else 2161
        }
        2179 -> {
            if ((b(((b(((b((1.5) <= (f.fVar74))) != 0) || ((b((1.5) <= (f.fVar47))) != 0))) != 0) || ((b(((b((5.0) <= (f.fVar78))) != 0) || ((b(((b((1.5) <= (f.fVar46))) != 0) || ((b((DAT_0012cfc8) <= (f.fVar45))) != 0))) != 0))) != 0))) != 0) 2178 else 2158
        }
        2180 -> {
            293
        }
        2181 -> {
            f.fVar57 = f32(1.2)
            2180
        }
        2182 -> {
            f.fVar76 = f32(3.5)
            2181
        }
        2183 -> {
            if ((b(((b(((b(((b((DAT_0012ce00) < (f.dVar42))) != 0) && ((b((DAT_0012cca8) < (f.dVar39))) != 0))) != 0) && ((b((DAT_0012cdf0) < (f.fVar45))) != 0))) != 0) && ((b((7.0) < (f.fVar52))) != 0))) != 0) 2182 else 2181
        }
        2184 -> {
            f.fVar76 = f32(f.fVar78)
            2183
        }
        2185 -> {
            if ((b(((b(((b(((b((f.fVar46) < (1.0))) != 0) && ((b((f.fVar47) < (1.0))) != 0))) != 0) && ((b(((b((3.0) < (f.fVar44))) != 0) && ((b(((b((3.0) < (f.fVar41))) != 0) && ((b((3.0) < (f.fVar55))) != 0))) != 0))) != 0))) != 0) && ((b((f.fVar74) < (1.0))) != 0))) != 0) 2184 else 2179
        }
        2186 -> {
            f.fVar76 = f32(4.7)
            2156
        }
        2187 -> {
            f.fVar57 = f32(0.5)
            2186
        }
        2188 -> {
            if ((b(((b(((b(((b((1.0) <= (f.fVar72))) != 0) || ((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0))) != 0) || ((b((1.0) <= (f.fVar82))) != 0))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0) 2185 else 2187
        }
        2189 -> {
            if ((b(((b((4.5) < (f.fVar69))) != 0) && ((b((f.dVar62) < (DAT_0012cf18))) != 0))) != 0) 2188 else 2155
        }
        2190 -> {
            if ((b(((b((f.fVar69) < (3.0))) != 0) || ((b((3.8) < (f.dVar62))) != 0))) != 0) 2189 else 2092
        }
        2191 -> {
            264
        }
        2192 -> {
            f.dVar62 = ((3.8) - (f.dVar62))
            2191
        }
        2193 -> {
            if ((b((((f.dVar62) + (-(3.8)))) < (0.5))) != 0) 2192 else 316
        }
        2194 -> {
            f.fVar70 = f32(0.0)
            2193
        }
        2195 -> {
            f.fVar70 = f32(f32(f.dVar38))
            316
        }
        2196 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2195
        }
        2197 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar38)))
            2196
        }
        2198 -> {
            f.dVar38 = ((f.dVar38) * (f.dVar53))
            229
        }
        2199 -> {
            f.dVar38 = ((DAT_0012cde0) - (f.dVar42))
            228
        }
        2200 -> {
            f.dVar53 = ARR_0012d080[b((DAT_0012cdf8) < (f.dVar42))]
            2199
        }
        2201 -> {
            216
        }
        2202 -> {
            239
        }
        2203 -> {
            f.fVar69 = f32(((f.fVar70) + (f.param_4)))
            2202
        }
        2204 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2203
        }
        2205 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) 2204 else 2201
        }
        2206 -> {
            if ((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((4.5) <= (f.fVar78))) != 0))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012cde0))) != 0) || ((b(((b(((b((f.param_12) <= (11.0))) != 0) || ((b((f.fVar60) <= (1.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0))) != 0))) != 0) 2205 else 2200
        }
        2207 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2206
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep69(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2208 -> {
            f.fVar57 = f32(3.2)
            2207
        }
        2209 -> {
            if ((b((f.iVar14) < (0x31))) != 0) 2208 else 2207
        }
        2210 -> {
            f.fVar57 = f32(3.5)
            2209
        }
        2211 -> {
            243
        }
        2212 -> {
            f.fVar57 = f32(2.8)
            2211
        }
        2213 -> {
            f.fVar60 = f32(1.2)
            2212
        }
        2214 -> {
            if ((b(((b(((b(((b((8.5) < (f.fVar52))) != 0) || ((b((8.5) < (f.fVar79))) != 0))) != 0) && ((b((DAT_0012cca8) < (f.dVar39))) != 0))) != 0) && ((b(((b((f.dVar42) < (DAT_0012cca0))) != 0) && ((b((DAT_0012ce10) < (f.dVar42))) != 0))) != 0))) != 0) 2213 else 2210
        }
        2215 -> {
            293
        }
        2216 -> {
            f.fVar76 = f32(3.0)
            2215
        }
        2217 -> {
            f.fVar57 = f32(1.0)
            2216
        }
        2218 -> {
            f.fVar76 = f32(2.8)
            2215
        }
        2219 -> {
            f.fVar57 = f32(1.2)
            2218
        }
        2220 -> {
            if ((b(((b((f.fVar60) <= (2.0))) != 0) || ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) && ((b(((b(((b((f.fVar52) <= (9.0))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b((f.fVar79) <= (9.0))) != 0))) != 0))) != 0))) != 0) 2217 else 2219
        }
        2221 -> {
            210
        }
        2222 -> {
            f.fVar57 = f32(3.5)
            2221
        }
        2223 -> {
            f.fVar60 = f32(1.0)
            2222
        }
        2224 -> {
            265
        }
        2225 -> {
            f.fVar57 = f32(3.2)
            2224
        }
        2226 -> {
            if ((b(((b(((b((1.2) < (f.dVar39))) != 0) && ((b(((b((f.iVar14) < (0x2a))) != 0) || ((b((f.fVar73) < (0.3))) != 0))) != 0))) != 0) && ((b(((b((7.0) < (f.fVar52))) != 0) || ((b((7.0) < (f.fVar79))) != 0))) != 0))) != 0) 2225 else 2223
        }
        2227 -> {
            if ((b(((b((f.dVar33) <= (8.2))) != 0) || ((b(((b((f.dVar32) <= (8.2))) != 0) || ((b((72.0) <= (f.fVar27))) != 0))) != 0))) != 0) 2226 else 2220
        }
        2228 -> {
            if ((b(((b((0x36) < (f.iVar14))) != 0) || ((b(((b((f.fVar52) < (7.5))) != 0) || ((b((f.fVar79) < (7.5))) != 0))) != 0))) != 0) 2227 else 2214
        }
        2229 -> {
            290
        }
        2230 -> {
            f.bVar12 = b((b((f.fVar69) < (3.0))) != 0)
            2229
        }
        2231 -> {
            f.bVar10 = b((b((f.fVar69) == (3.0))) != 0)
            2230
        }
        2232 -> {
            f.bVar8 = b((b((f.fVar69).isNaN())) != 0)
            2231
        }
        2233 -> {
            f.fVar69 = f32(((f.fVar70) + (f.param_4)))
            230
        }
        2234 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2233
        }
        2235 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 2234 else 316
        }
        2236 -> {
            f.fVar70 = f32(f.fVar54)
            2235
        }
        2237 -> {
            writeI32(f.param_1.plus(0x168), 1)
            316
        }
        2238 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            2237
        }
        2239 -> {
            f.fVar70 = f32(f32(((f.dVar38) * (((3.0) - (f.fVar78))))))
            2238
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep70(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2240 -> {
            f.dVar38 = DAT_0012ce88
            2239
        }
        2241 -> {
            if ((b((f.dVar42) <= (3.3))) != 0) 2240 else 2239
        }
        2242 -> {
            f.dVar38 = 0.5
            2241
        }
        2243 -> {
            if ((b(((b(((b((f.fVar78) <= (3.0))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b(((b((3.9) <= (f.dVar42))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.0))) != 0))) != 0))) != 0))) != 0) 2236 else 2242
        }
        2244 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2243
        }
        2245 -> {
            if ((b(((b((f.fVar79) <= (8.5))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0))) != 0) 2228 else 2244
        }
        2246 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            316
        }
        2247 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2246
        }
        2248 -> {
            f.fVar70 = f32(f32(((((3.3) - (f.dVar42))) * (f.dVar38))))
            2247
        }
        2249 -> {
            f.dVar38 = DAT_0012ce88
            2248
        }
        2250 -> {
            if ((b((f.dVar42) <= (DAT_0012cdf8))) != 0) 2249 else 2248
        }
        2251 -> {
            f.dVar38 = 0.5
            2250
        }
        2252 -> {
            234
        }
        2253 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            2252
        }
        2254 -> {
            if ((b(((b(((b(((b((f.dVar42) <= (3.3))) != 0) || ((b((4.3) <= (f.dVar42))) != 0))) != 0) || ((b((DAT_0012cca0) <= (f.dVar62))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.3))) != 0))) != 0) 2253 else 2251
        }
        2255 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 2254 else 316
        }
        2256 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.5, 1.0, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2255
        }
        2257 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            316
        }
        2258 -> {
            f.fVar57 = f32(4.3)
            231
        }
        2259 -> {
            f.fVar60 = f32(0.55)
            2258
        }
        2260 -> {
            if ((b(((b(((b((13.0) <= (f.fVar54))) != 0) || ((b((54.0) <= (f.fVar27))) != 0))) != 0) || ((b(((b((10.0) <= (f.fVar54))) != 0) && ((b((7.5) <= (f.fVar52))) != 0))) != 0))) != 0) 2256 else 2259
        }
        2261 -> {
            217
        }
        2262 -> {
            f.fVar76 = f32(4.7)
            2261
        }
        2263 -> {
            f.fVar57 = f32(0.5)
            2262
        }
        2264 -> {
            if ((b(((b((0x48) < (f.iVar14))) != 0) && ((b(((b((f.fVar54) < (10.0))) != 0) || ((b((f.fVar52) < (7.5))) != 0))) != 0))) != 0) 2263 else 2260
        }
        2265 -> {
            if ((b(((b((((f.fVar54) - (f.fVar69))) < (8.0))) != 0) && ((b((f.fVar27) < (72.0))) != 0))) != 0) 2264 else 2260
        }
        2266 -> {
            if ((b(((b(((b((1.0) <= (f.fVar36))) != 0) || ((b((1.0) <= (f.fVar72))) != 0))) != 0) || ((b((readI32(f.param_1.plus(0x1f8))) < (0x3d))) != 0))) != 0) 2245 else 2265
        }
        2267 -> {
            if ((b((f.fVar54) <= (12.0))) != 0) 2194 else 2266
        }
        2268 -> {
            if ((b(((b((4.5) <= (f.fVar69))) != 0) || ((b((f.dVar62) <= (3.8))) != 0))) != 0) 2190 else 2267
        }
        2269 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            316
        }
        2270 -> {
            if ((b((f.iVar19) == (1))) != 0) 2269 else 316
        }
        2271 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            234
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep71(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2272 -> {
            235
        }
        2273 -> {
            f.dVar38 = 3.3
            2272
        }
        2274 -> {
            if ((b(((b(((b((3.3) < (f.dVar42))) != 0) && ((b((f.dVar42) < (4.6))) != 0))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 2273 else 233
        }
        2275 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 2274 else 316
        }
        2276 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2275
        }
        2277 -> {
            f.fVar70 = f32(f32(f.dVar38))
            316
        }
        2278 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar38)))
            2277
        }
        2279 -> {
            f.dVar38 = ((((f.dVar38) - (f.dVar42))) * (0.6))
            236
        }
        2280 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2279
        }
        2281 -> {
            f.dVar38 = 2.3
            235
        }
        2282 -> {
            233
        }
        2283 -> {
            if ((b(((b(((b((f.dVar42) <= (2.3))) != 0) || ((b((DAT_0012cdf8) <= (f.dVar42))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.3))) != 0))) != 0) 2282 else 2281
        }
        2284 -> {
            if ((b((f.fVar70) == (0.0))) != 0) 2283 else 316
        }
        2285 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2284
        }
        2286 -> {
            if ((b(((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) || ((b(((b(((b((((f.fVar54) - (f.fVar69))) <= (8.0))) != 0) && ((b((f.fVar45) <= (DAT_0012cc40))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.3))) != 0))) != 0))) != 0) 2276 else 2285
        }
        2287 -> {
            if ((b((10.0) < (f.fVar54))) != 0) 2286 else 316
        }
        2288 -> {
            f.fVar70 = f32(0.0)
            2287
        }
        2289 -> {
            217
        }
        2290 -> {
            f.fVar57 = f32(0.5)
            2289
        }
        2291 -> {
            f.fVar76 = f32(4.7)
            232
        }
        2292 -> {
            if ((b(((b(((b((f.fVar36) < (1.0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b(((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0) && ((b((0x3c) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0))) != 0) 2291 else 2288
        }
        2293 -> {
            201
        }
        2294 -> {
            f.dVar62 = ((3.5) - (f.fVar22))
            2293
        }
        2295 -> {
            f.dVar38 = 0.6
            2294
        }
        2296 -> {
            if ((b((((f.fVar22) + (-(3.5)))) < (0.5))) != 0) 2295 else 316
        }
        2297 -> {
            f.fVar70 = f32(0.0)
            2296
        }
        2298 -> {
            f.fVar70 = f32(f32(((((DAT_0012cde0) - (f.dVar62))) * (0.5))))
            316
        }
        2299 -> {
            f.fVar70 = f32(((((((6.0) - (f.fVar22))) - (f.fVar69))) * (0.5)))
            316
        }
        2300 -> {
            if ((b((0.5) <= (((f.fVar22) + (DAT_0012ce50))))) != 0) 2298 else 2299
        }
        2301 -> {
            196
        }
        2302 -> {
            f.dVar62 = ((((4.5) - (f.dVar83))) * (0.5))
            2301
        }
        2303 -> {
            if ((b((f.fVar82) < (1.0))) != 0) 2302 else 2300
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep72(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2304 -> {
            f.fVar70 = f32(f32(((DAT_0012ce00) - (f.fVar22))))
            316
        }
        2305 -> {
            if ((b((((f.fVar22) + (DAT_0012d030))) < (0.5))) != 0) 2304 else 316
        }
        2306 -> {
            f.fVar70 = f32(0.0)
            2305
        }
        2307 -> {
            f.fVar70 = f32(((f.fVar67) * (0.5)))
            316
        }
        2308 -> {
            if ((b((3.0) <= (f.fVar22))) != 0) 2307 else 316
        }
        2309 -> {
            f.fVar70 = f32(0.0)
            2308
        }
        2310 -> {
            f.fVar70 = f32(((((3.0) - (f.fVar69))) * (0.5)))
            316
        }
        2311 -> {
            if ((b((((f.fVar69) + (-(3.0)))) < (0.5))) != 0) 2310 else 316
        }
        2312 -> {
            f.fVar70 = f32(0.0)
            2311
        }
        2313 -> {
            f.fVar70 = f32(((((((6.0) - (f.fVar69))) - (f.fVar22))) * (0.5)))
            316
        }
        2314 -> {
            if ((b((0.5) <= (((f.fVar22) + (-(3.0)))))) != 0) 2312 else 2313
        }
        2315 -> {
            if ((b((f.fVar67) <= (0.0))) != 0) 2309 else 2314
        }
        2316 -> {
            f.fVar67 = f32(((((6.0) - (f.fVar69))) - (f.fVar67)))
            2315
        }
        2317 -> {
            if ((b((f.fVar82) <= (1.0))) != 0) 2306 else 2316
        }
        2318 -> {
            if ((b((0.5) <= (kotlin.math.abs(((f.fVar67) - (f.fVar69)))))) != 0) 2303 else 2317
        }
        2319 -> {
            if ((b((2.5) <= (f.fVar69))) != 0) 2297 else 2318
        }
        2320 -> {
            230
        }
        2321 -> {
            f.fVar69 = f32(((f.fVar69) + (f.fVar70)))
            2320
        }
        2322 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2321
        }
        2323 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 2322 else 316
        }
        2324 -> {
            f.fVar70 = f32(f.fVar54)
            2323
        }
        2325 -> {
            316
        }
        2326 -> {
            f.fVar70 = f32(f32(f.dVar38))
            2325
        }
        2327 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar38)))
            2326
        }
        2328 -> {
            writeI32(f.param_1.plus(0x168), 1)
            238
        }
        2329 -> {
            f.dVar38 = ((((3.3) - (f.dVar42))) * (f.dVar38))
            2328
        }
        2330 -> {
            f.dVar38 = DAT_0012ce88
            2329
        }
        2331 -> {
            if ((b((f.dVar42) <= (DAT_0012cdf8))) != 0) 2330 else 2329
        }
        2332 -> {
            f.dVar38 = 0.5
            2331
        }
        2333 -> {
            if ((b(((b((f.fVar54) == (0.0))) != 0) && ((b(((b(((b((3.5) < (f.fVar78))) != 0) && ((b((f.dVar42) < (4.6))) != 0))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2332 else 2324
        }
        2334 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.1, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2333
        }
        2335 -> {
            238
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep73(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2336 -> {
            f.dVar38 = ((((2.3) - (f.dVar42))) * (f.dVar38))
            2335
        }
        2337 -> {
            f.dVar38 = DAT_0012ce88
            2336
        }
        2338 -> {
            if ((b((f.dVar42) <= (f.dVar53))) != 0) 2337 else 2336
        }
        2339 -> {
            f.dVar38 = 0.6
            2338
        }
        2340 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2339
        }
        2341 -> {
            if ((b(((b(((b((f.fVar78) < (4.0))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) && ((b(((b((2.5) < (f.fVar78))) != 0) && ((b((2.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2340 else 2324
        }
        2342 -> {
            f.dVar53 = DAT_0012ce10
            2341
        }
        2343 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.3, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2342
        }
        2344 -> {
            237
        }
        2345 -> {
            if ((b(((b((f.fVar52) <= (8.0))) != 0) || ((b(((b((0x29) < (f.iVar14))) != 0) && ((b(((b((0x35) < (f.iVar14))) != 0) || ((b((f.fVar52) <= (9.0))) != 0))) != 0))) != 0))) != 0) 2344 else 2343
        }
        2346 -> {
            if ((b((readF32(f.param_1.plus(0x1a0))) <= (DAT_0012ccb0))) != 0) 237 else 2345
        }
        2347 -> {
            243
        }
        2348 -> {
            f.fVar57 = f32(4.2)
            2347
        }
        2349 -> {
            f.fVar60 = f32(0.55)
            2348
        }
        2350 -> {
            if ((b(((b(((b((f.fVar36) < (1.0))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (7.0))) != 0))) != 0) && ((b(((b((f.fVar72) < (1.0))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0))) != 0) 2349 else 2346
        }
        2351 -> {
            316
        }
        2352 -> {
            f.fVar70 = f32(((((((6.0) - (f.fVar69))) - (f.fVar67))) * (0.5)))
            2351
        }
        2353 -> {
            if ((b((f.param_14) < (0x360))) != 0) 2352 else 2350
        }
        2354 -> {
            f.fVar70 = f32(f32(((f.dVar53) * (f.dVar38))))
            316
        }
        2355 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(((f.dVar53) * (f.dVar38)))))
            2354
        }
        2356 -> {
            f.dVar53 = ((3.3) - (f.dVar42))
            242
        }
        2357 -> {
            f.dVar38 = ARR_0012d080[b((f.dVar38) < (f.dVar42))]
            2356
        }
        2358 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2357
        }
        2359 -> {
            f.dVar38 = DAT_0012cdf8
            2358
        }
        2360 -> {
            216
        }
        2361 -> {
            316
        }
        2362 -> {
            if ((b((3.0) < (f.fVar69))) != 0) 2361 else 2360
        }
        2363 -> {
            f.fVar69 = f32(((f.fVar69) + (f.fVar70)))
            239
        }
        2364 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2363
        }
        2365 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) 2364 else 2360
        }
        2366 -> {
            if ((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((4.6) <= (f.dVar42))) != 0))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012cde0))) != 0) || ((b(((b((f.fVar28) <= (DAT_0012cc40))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.3))) != 0))) != 0))) != 0))) != 0) 2365 else 240
        }
        2367 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2366
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep74(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2368 -> {
            f.dVar53 = ((2.5) - (f.dVar42))
            242
        }
        2369 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2368
        }
        2370 -> {
            f.dVar38 = ARR_0012d080[b((2.8) < (f.dVar42))]
            2369
        }
        2371 -> {
            216
        }
        2372 -> {
            215
        }
        2373 -> {
            f.fVar69 = f32(((f.fVar69) + (f.fVar70)))
            2372
        }
        2374 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2373
        }
        2375 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0) 2374 else 2371
        }
        2376 -> {
            if ((b(((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) || ((b((DAT_0012cdf8) <= (f.dVar42))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.5))) != 0))) != 0) 2375 else 241
        }
        2377 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2376
        }
        2378 -> {
            if ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) 2367 else 2377
        }
        2379 -> {
            if ((b(((b(((b(((b((f.fVar79) <= (9.0))) != 0) || ((b((((f.fVar54) - (f.fVar69))) <= (6.0))) != 0))) != 0) || ((b((0x3b) < (f.iVar14))) != 0))) != 0) || ((b((f.fVar52) <= (9.0))) != 0))) != 0) 2353 else 2378
        }
        2380 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            316
        }
        2381 -> {
            f.fVar57 = f32(2.8)
            243
        }
        2382 -> {
            f.fVar60 = f32(1.3)
            2381
        }
        2383 -> {
            if ((b(((b(((b((f.fVar57) <= (2.5))) != 0) || ((b((f.dVar33) <= (DAT_0012ce68))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) <= (0.6))) != 0))) != 0) 2379 else 2382
        }
        2384 -> {
            293
        }
        2385 -> {
            f.fVar57 = f32(1.3)
            2384
        }
        2386 -> {
            f.fVar76 = f32(3.0)
            2385
        }
        2387 -> {
            f.fVar76 = f32(3.3)
            2385
        }
        2388 -> {
            if ((b(((b((f.iVar14) < (0x31))) != 0) || ((b((f.fVar70) <= (1.0))) != 0))) != 0) 2386 else 2387
        }
        2389 -> {
            if ((b(((b((DAT_0012cfe0) < (f.dVar48))) != 0) && ((b((f.dVar49) < (DAT_0012d060))) != 0))) != 0) 2388 else 2383
        }
        2390 -> {
            if ((b((f.fVar54) <= (12.0))) != 0) 2319 else 2389
        }
        2391 -> {
            if ((b(uLt(((f.param_14) - (0x241)), 0x11f))) != 0) 2292 else 2390
        }
        2392 -> {
            if ((b((3.0) <= (f.fVar69))) != 0) 2268 else 2391
        }
        2393 -> {
            f.fVar36 = f32(kotlin.math.abs(((f.fVar67) - (f.fVar71))))
            2392
        }
        2394 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar76, f.fVar57, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            316
        }
        2395 -> {
            f.fVar57 = f32(0.8)
            293
        }
        2396 -> {
            f.fVar76 = f32(4.2)
            2395
        }
        2397 -> {
            if ((b(((b(((b((0.5) <= (f.fVar74))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0) || ((run { run { f.fVar76 = f32(f.fVar78); f32(f.fVar78) }; b((0.5) <= (f.fVar47)) }) != 0))) != 0) 2396 else 2395
        }
        2398 -> {
            232
        }
        2399 -> {
            f.fVar76 = f32(4.8)
            2398
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep75(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2400 -> {
            if ((b(((b(((b((f.fVar45) < (DAT_0012cc40))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b(((b((f.fVar72) < (1.0))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0))) != 0) 2399 else 2397
        }
        2401 -> {
            f.fVar76 = f32(4.7)
            293
        }
        2402 -> {
            f.fVar57 = f32(0.5)
            2401
        }
        2403 -> {
            f.fVar76 = f32(3.7)
            293
        }
        2404 -> {
            f.fVar57 = f32(0.65)
            2403
        }
        2405 -> {
            if ((b(((b((f.fVar26) <= (9.0))) != 0) || ((b((f.fVar52) <= (6.0))) != 0))) != 0) 2402 else 2404
        }
        2406 -> {
            316
        }
        2407 -> {
            f.fVar70 = f32(f.fVar54)
            2406
        }
        2408 -> {
            if ((b(!((f.bVar13) != 0))) != 0) 2407 else 2406
        }
        2409 -> {
            f.bVar13 = b((b((f.fVar54) == (0.0))) != 0)
            2408
        }
        2410 -> {
            if ((b(((b(((b(!((f.bVar10) != 0))) != 0) && ((b((f.bVar12) == (f.bVar8))) != 0))) != 0) && ((run { run { f.bVar13 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar54).isNaN())) != 0)) }) != 0))) != 0) 2409 else 2408
        }
        2411 -> {
            f.bVar13 = b((0) != 0)
            2410
        }
        2412 -> {
            f.bVar12 = b((b((f.fVar57) < (f.fVar22))) != 0)
            290
        }
        2413 -> {
            f.bVar10 = b((b((f.fVar57) == (f.fVar22))) != 0)
            2412
        }
        2414 -> {
            f.bVar8 = b((b(((b((f.fVar57).isNaN())) != 0) || ((b((f.fVar22).isNaN())) != 0))) != 0)
            2413
        }
        2415 -> {
            f.fVar57 = f32(((f.fVar70) + (f.param_4)))
            2414
        }
        2416 -> {
            f.fVar22 = f32(3.0)
            289
        }
        2417 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2416
        }
        2418 -> {
            316
        }
        2419 -> {
            if ((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) 2418 else 2417
        }
        2420 -> {
            f.fVar70 = f32(f.fVar54)
            2419
        }
        2421 -> {
            283
        }
        2422 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2421
        }
        2423 -> {
            f.dVar39 = 3.3
            2422
        }
        2424 -> {
            if ((b(((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((f.dVar42) < (4.3))) != 0))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) && ((b((3.0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 2423 else 2420
        }
        2425 -> {
            f.dVar38 = DAT_0012cdf8
            2424
        }
        2426 -> {
            f.dVar53 = DAT_0012ce88
            2425
        }
        2427 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2426
        }
        2428 -> {
            if ((b(((b(((b((1.5) <= (f.fVar82))) != 0) || ((b((DAT_0012cc80) <= (f.fVar72))) != 0))) != 0) || ((b(((b((f.iVar14) < (0x37))) != 0) || ((b((8.5) <= (f.fVar52))) != 0))) != 0))) != 0) 2427 else 2405
        }
        2429 -> {
            if ((f.bVar10) != 0) 2400 else 2428
        }
        2430 -> {
            316
        }
        2431 -> {
            216
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep76(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2432 -> {
            if ((b((((f.fVar70) + (f.param_4))) <= (f.fVar22))) != 0) 2431 else 2430
        }
        2433 -> {
            f.fVar22 = f32(3.0)
            268
        }
        2434 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2433
        }
        2435 -> {
            216
        }
        2436 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) 2435 else 2434
        }
        2437 -> {
            227
        }
        2438 -> {
            f.dVar38 = ((3.3) - (f.dVar42))
            2437
        }
        2439 -> {
            if ((b((f.dVar42) <= (f.dVar53))) != 0) 2438 else 2437
        }
        2440 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2439
        }
        2441 -> {
            f.dVar38 = ((((3.3) - (f.dVar42))) * (DAT_0012ccb0))
            2440
        }
        2442 -> {
            if ((b(((b(((b((DAT_0012cde0) < (f.dVar42))) != 0) && ((b((f.dVar42) < (DAT_0012cca0))) != 0))) != 0) && ((b(((b((f.fVar54) == (0.0))) != 0) && ((b(((b((f.dVar75) < (f.fVar28))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0))) != 0) 2441 else 2436
        }
        2443 -> {
            f.dVar53 = DAT_0012cdf8
            2442
        }
        2444 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2443
        }
        2445 -> {
            316
        }
        2446 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2445
        }
        2447 -> {
            f.fVar57 = f32(f.fVar78)
            2446
        }
        2448 -> {
            f.fVar60 = f32(0.9)
            2447
        }
        2449 -> {
            316
        }
        2450 -> {
            f.fVar70 = f32(0.0)
            2449
        }
        2451 -> {
            writeF32(f.pjVar1, f32(0.0))
            2450
        }
        2452 -> {
            if ((b(((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b((((readF32(f.pjVar1)) + (f.param_4))) <= (DAT_0012cde0))) != 0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((readF32(f.param_1.plus(0x274))) <= (3.0)) }) != 0))) != 0) 2451 else 2449
        }
        2453 -> {
            writeF32(f.param_1.plus(0x16c), f32(f.fVar70))
            2449
        }
        2454 -> {
            f.fVar70 = f32(f32(((ARR_0012d080[b((f.dVar34) < (f.dVar42))]) * (((3.0) - (f.fVar78))))))
            2453
        }
        2455 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2454
        }
        2456 -> {
            if ((b(((b(((b((4.5) <= (f.fVar78))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012cde0))) != 0) || ((b((f.dVar39) <= (1.2))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (3.0))) != 0))) != 0) 2452 else 2455
        }
        2457 -> {
            if ((b(((b((3.9) <= (f.dVar42))) != 0) || ((b((7.0) <= (f.fVar79))) != 0))) != 0) 2456 else 2448
        }
        2458 -> {
            f.fVar60 = f32(1.5)
            2446
        }
        2459 -> {
            f.fVar57 = f32(3.5)
            2458
        }
        2460 -> {
            f.fVar57 = f32(4.2)
            2458
        }
        2461 -> {
            if ((b(((b(((b((f.dVar42) <= (3.9))) != 0) || ((b((1.0) <= (f.fVar60))) != 0))) != 0) || ((b(((b((5.0) <= (f.fVar23))) != 0) || ((b((f.fVar61) <= (6.5))) != 0))) != 0))) != 0) 2459 else 2460
        }
        2462 -> {
            if ((b((DAT_0012cca8) <= (f.fVar57))) != 0) 2457 else 2461
        }
        2463 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar78, 0.9, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2445
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep77(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2464 -> {
            if ((b(((b((f.param_14) < (0x6c1))) != 0) || ((b(((b(((b((f.fVar78) <= (3.5))) != 0) || ((b((DAT_0012ce48) <= (f.dVar42))) != 0))) != 0) || ((b((1.0) <= (f.fVar60))) != 0))) != 0))) != 0) 2462 else 2463
        }
        2465 -> {
            if ((b(((b((0x1f) < (f.iVar14))) != 0) || ((b((f.fVar72) <= (DAT_0012cc40))) != 0))) != 0) 2464 else 2444
        }
        2466 -> {
            227
        }
        2467 -> {
            f.dVar38 = ((((2.5) - (f.dVar42))) * (f.dVar53))
            2466
        }
        2468 -> {
            f.dVar53 = f.dVar38
            2467
        }
        2469 -> {
            if ((b((f.dVar42) <= (2.8))) != 0) 2468 else 2467
        }
        2470 -> {
            f.dVar53 = 0.5
            2469
        }
        2471 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2470
        }
        2472 -> {
            214
        }
        2473 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2472
        }
        2474 -> {
            216
        }
        2475 -> {
            if ((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) 2474 else 2473
        }
        2476 -> {
            if ((b(((b(((b(((b((f.dVar42) <= (DAT_0012ce18))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.3))) != 0))) != 0) 2475 else 2471
        }
        2477 -> {
            f.dVar38 = DAT_0012ce88
            2476
        }
        2478 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2477
        }
        2479 -> {
            f.fVar57 = f32(2.5)
            2478
        }
        2480 -> {
            if ((b(((f.bVar12) != 0) || ((b((f.bVar8) != (f.bVar10))) != 0))) != 0) 2479 else 2478
        }
        2481 -> {
            f.bVar10 = b((0) != 0)
            2480
        }
        2482 -> {
            f.bVar12 = b((b((f.fVar78) == (3.5))) != 0)
            2481
        }
        2483 -> {
            f.bVar8 = b((b((f.fVar78) < (3.5))) != 0)
            2482
        }
        2484 -> {
            if ((b(!((b((f.fVar78).isNaN())) != 0))) != 0) 2483 else 2480
        }
        2485 -> {
            f.bVar10 = b((1) != 0)
            2484
        }
        2486 -> {
            f.bVar12 = b((0) != 0)
            2485
        }
        2487 -> {
            f.bVar8 = b((0) != 0)
            2486
        }
        2488 -> {
            if ((b((0x30) < (f.iVar14))) != 0) 2487 else 2480
        }
        2489 -> {
            f.bVar10 = b((0) != 0)
            2488
        }
        2490 -> {
            f.bVar12 = b((1) != 0)
            2489
        }
        2491 -> {
            f.bVar8 = b((0) != 0)
            2490
        }
        2492 -> {
            f.fVar57 = f32(3.5)
            2491
        }
        2493 -> {
            if ((b(((b(((b((f.iVar14) < (0x48))) != 0) && ((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0))) != 0) && ((b((0.6) < (f.fVar72))) != 0))) != 0) 2492 else 2465
        }
        2494 -> {
            217
        }
        2495 -> {
            f.fVar76 = f32(4.2)
            2494
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep78(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2496 -> {
            f.fVar57 = f32(0.65)
            2495
        }
        2497 -> {
            if ((b(((b(((b(((b((3.3) < (f.dVar81))) != 0) && ((b((3.3) < (f.dVar59))) != 0))) != 0) && ((b((DAT_0012ce00) < (f.dVar42))) != 0))) != 0) && ((b(((b((3.3) < (f.dVar31))) != 0) && ((b((0x36) < (f.iVar14))) != 0))) != 0))) != 0) 2496 else 2493
        }
        2498 -> {
            270
        }
        2499 -> {
            f.fVar57 = f32(4.7)
            2498
        }
        2500 -> {
            f.fVar60 = f32(0.5)
            2499
        }
        2501 -> {
            266
        }
        2502 -> {
            if ((b(((b((f.fVar78) < (4.5))) != 0) && ((b((f.dVar49) < (DAT_0012cfc0))) != 0))) != 0) 2501 else 2500
        }
        2503 -> {
            267
        }
        2504 -> {
            f.fVar60 = f32(0.5)
            2503
        }
        2505 -> {
            if ((b(((b((9.0) < (f.fVar54))) != 0) && ((b((6.5) < (f.fVar52))) != 0))) != 0) 2504 else 2500
        }
        2506 -> {
            if ((b((f.fVar78) < (4.5))) != 0) 266 else 2500
        }
        2507 -> {
            if ((b((f.dVar48) <= (0.3))) != 0) 2502 else 2506
        }
        2508 -> {
            f.fVar57 = f32(4.2)
            2498
        }
        2509 -> {
            f.fVar60 = f32(0.55)
            267
        }
        2510 -> {
            if ((b((f.iVar14) < (0x6d))) != 0) 2507 else 2509
        }
        2511 -> {
            if ((b(((b(((b((f.fVar82) < (1.0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b(((b((0x48) < (f.iVar14))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (5.8))) != 0))) != 0))) != 0) 2510 else 2497
        }
        2512 -> {
            210
        }
        2513 -> {
            f.fVar60 = f32(1.0)
            2512
        }
        2514 -> {
            f.fVar57 = f32(3.0)
            265
        }
        2515 -> {
            f.fVar57 = f32(3.5)
            265
        }
        2516 -> {
            if ((b(((b(((b(((b((11.5) <= (f.fVar54))) != 0) || ((b((f.iVar14) < (0x37))) != 0))) != 0) || ((b((7.5) <= (f.fVar52))) != 0))) != 0) || ((b((1.2) <= (f.dVar39))) != 0))) != 0) 2514 else 2515
        }
        2517 -> {
            if ((b(!((f.bVar10) != 0))) != 0) 2516 else 2511
        }
        2518 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2430
        }
        2519 -> {
            f.fVar57 = f32(3.0)
            273
        }
        2520 -> {
            f.fVar60 = f32(1.3)
            2519
        }
        2521 -> {
            273
        }
        2522 -> {
            f.fVar57 = f32(2.5)
            2521
        }
        2523 -> {
            f.fVar60 = f32(1.3)
            2522
        }
        2524 -> {
            if ((b(((b((0.3) <= (f.dVar48))) != 0) || ((b(((b((7.8) <= (f.dVar33))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0))) != 0) 2523 else 2520
        }
        2525 -> {
            if ((b(((b((0.3) <= (f.dVar48))) != 0) || ((b((f.dVar49) <= (-(0.3)))) != 0))) != 0) 2524 else 2520
        }
        2526 -> {
            234
        }
        2527 -> {
            f.iVar19 = readI32(f.param_1.plus(0x168))
            2526
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep79(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2528 -> {
            286
        }
        2529 -> {
            if ((b(((b(((b((f.dVar42) < (4.3))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) && ((run { run { f.dVar53 = DAT_0012cdf8; DAT_0012cdf8 }; run { f.dVar38 = DAT_0012cde0; DAT_0012cde0 }; b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274)))) }) != 0))) != 0) 2528 else 272
        }
        2530 -> {
            316
        }
        2531 -> {
            if ((b((f.fVar70) != (0.0))) != 0) 2530 else 2529
        }
        2532 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2531
        }
        2533 -> {
            f.fVar57 = f32(3.0)
            271
        }
        2534 -> {
            if ((b(((b(((b((f.iVar14) < (0x30))) != 0) && ((b((f.fVar52) < (8.5))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x1a0))) < (0.5))) != 0))) != 0) 2533 else 2525
        }
        2535 -> {
            316
        }
        2536 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2535
        }
        2537 -> {
            f.fVar57 = f32(3.0)
            270
        }
        2538 -> {
            f.fVar60 = f32(1.2)
            2537
        }
        2539 -> {
            f.fVar57 = f32(2.5)
            270
        }
        2540 -> {
            f.fVar60 = f32(1.2)
            2539
        }
        2541 -> {
            if ((b((f.fVar52) <= (8.5))) != 0) 2538 else 2540
        }
        2542 -> {
            269
        }
        2543 -> {
            if ((b((0x30) < (f.iVar14))) != 0) 2542 else 2541
        }
        2544 -> {
            275
        }
        2545 -> {
            if ((b(((b((f.fVar52) < (7.5))) != 0) && ((b((f.fVar79) < (7.5))) != 0))) != 0) 2544 else 2541
        }
        2546 -> {
            274
        }
        2547 -> {
            f.fVar60 = f32(0.9)
            2546
        }
        2548 -> {
            if ((b((-(0.35)) < (f.dVar49))) != 0) 2547 else 269
        }
        2549 -> {
            if ((b((f.iVar14) < (0x37))) != 0) 2543 else 2548
        }
        2550 -> {
            270
        }
        2551 -> {
            f.fVar57 = f32(4.5)
            2550
        }
        2552 -> {
            f.fVar60 = f32(0.55)
            2551
        }
        2553 -> {
            if ((b(((b((f.fVar82) < (DAT_0012cc40))) != 0) && ((b(((b((f.fVar72) < (DAT_0012cc40))) != 0) && ((b((0x42) < (f.iVar14))) != 0))) != 0))) != 0) 2552 else 2549
        }
        2554 -> {
            if ((b(((b((f.fVar82) <= (1.0))) != 0) && ((b((f.fVar72) <= (1.0))) != 0))) != 0) 2553 else 2534
        }
        2555 -> {
            293
        }
        2556 -> {
            f.fVar76 = f32(3.2)
            2555
        }
        2557 -> {
            f.fVar57 = f32(1.1)
            2556
        }
        2558 -> {
            f.fVar76 = f32(3.9)
            2555
        }
        2559 -> {
            f.fVar57 = f32(0.55)
            2558
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep80(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2560 -> {
            if ((b(((b(((b((1.0) <= (f.fVar82))) != 0) || ((b((DAT_0012cc40) <= (f.fVar72))) != 0))) != 0) || ((b((7.5) <= (f.fVar52))) != 0))) != 0) 2557 else 2559
        }
        2561 -> {
            if ((b((f.fVar69) <= (2.0))) != 0) 2560 else 2554
        }
        2562 -> {
            f.fVar70 = f32(f.fVar54)
            2430
        }
        2563 -> {
            writeI64(f.param_1.plus(0x168), (0).toLong())
            2562
        }
        2564 -> {
            if ((b(((b(((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((run { run { f.fVar70 = f32(readF32(f.pjVar1)); f32(readF32(f.pjVar1)) }; b((((readF32(f.pjVar1)) + (f.param_4))) <= (3.0)) }) != 0))) != 0) 2563 else 2430
        }
        2565 -> {
            288
        }
        2566 -> {
            f.dVar38 = ((f.dVar38) * (f.dVar53))
            2565
        }
        2567 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2566
        }
        2568 -> {
            f.dVar38 = ((DAT_0012cde0) - (f.dVar42))
            2567
        }
        2569 -> {
            f.dVar53 = ARR_0012d080[b((DAT_0012cdf8) < (f.dVar42))]
            2568
        }
        2570 -> {
            if ((b(((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((f.dVar42) < (4.3))) != 0))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) && ((b(((b((f.dVar75) < (f.fVar28))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2569 else 2564
        }
        2571 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.2, 1.4, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2570
        }
        2572 -> {
            287
        }
        2573 -> {
            f.dVar38 = ((2.5) - (f.dVar42))
            2572
        }
        2574 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2573
        }
        2575 -> {
            f.dVar53 = ARR_0012d080[b((2.8) < (f.dVar42))]
            2574
        }
        2576 -> {
            216
        }
        2577 -> {
            226
        }
        2578 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 2577 else 2576
        }
        2579 -> {
            if ((b(((b(((b((DAT_0012cdf8) <= (f.dVar42))) != 0) || ((b((f.fVar54) != (0.0))) != 0))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012ce18))) != 0) || ((b(((b((0x3b) < (f.iVar14))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (2.3))) != 0))) != 0))) != 0))) != 0) 2578 else 2575
        }
        2580 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2579
        }
        2581 -> {
            if ((b(((b(((b((10.0) < (f.fVar52))) != 0) || ((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0))) != 0) && ((b((f.dVar42) < (2.8))) != 0))) != 0) 2580 else 2571
        }
        2582 -> {
            276
        }
        2583 -> {
            if ((b((0x36) < (f.iVar14))) != 0) 2582 else 2581
        }
        2584 -> {
            273
        }
        2585 -> {
            f.fVar57 = f32(3.5)
            2584
        }
        2586 -> {
            f.fVar60 = f32(1.3)
            2585
        }
        2587 -> {
            if ((b(((b(((b(((b((f.fVar54) < (11.0))) != 0) || ((b((f.fVar60) < (1.5))) != 0))) != 0) && ((b(((b((f.fVar52) < (7.5))) != 0) || ((b((((f.fVar64) - (f.fVar29))) < (DAT_0012cc78))) != 0))) != 0))) != 0) && ((b(((b((f.fVar57) < (2.0))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (9.0))) != 0))) != 0))) != 0) 2586 else 2581
        }
        2588 -> {
            273
        }
        2589 -> {
            f.fVar57 = f32(3.9)
            2588
        }
        2590 -> {
            f.fVar60 = f32(0.6)
            2589
        }
        2591 -> {
            if ((b(((b((f.fVar60) < (1.0))) != 0) && ((b((f.dVar32) < (7.8))) != 0))) != 0) 2590 else 276
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep81(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2592 -> {
            if ((b(((b((0.25) <= (f.fVar45))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0) 2583 else 2591
        }
        2593 -> {
            217
        }
        2594 -> {
            f.fVar76 = f32(4.5)
            2593
        }
        2595 -> {
            f.fVar57 = f32(0.55)
            2594
        }
        2596 -> {
            if ((b(((b(((b((f.fVar82) < (DAT_0012cc40))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b(((b((f.fVar72) < (DAT_0012cc40))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0))) != 0) 2595 else 2592
        }
        2597 -> {
            293
        }
        2598 -> {
            f.fVar76 = f32(3.5)
            2597
        }
        2599 -> {
            f.fVar57 = f32(1.1)
            2598
        }
        2600 -> {
            f.fVar76 = f32(3.0)
            2597
        }
        2601 -> {
            f.fVar57 = f32(1.1)
            2600
        }
        2602 -> {
            if ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b(((b((f.fVar60) <= (1.5))) != 0) || ((b((f.fVar45) <= (DAT_0012cdf0))) != 0))) != 0))) != 0) 2599 else 2601
        }
        2603 -> {
            f.fVar76 = f32(4.5)
            2597
        }
        2604 -> {
            f.fVar57 = f32(0.55)
            2603
        }
        2605 -> {
            270
        }
        2606 -> {
            f.fVar57 = f32(3.5)
            2605
        }
        2607 -> {
            f.fVar60 = f32(1.0)
            2606
        }
        2608 -> {
            270
        }
        2609 -> {
            f.fVar57 = f32(3.9)
            2608
        }
        2610 -> {
            f.fVar60 = f32(0.95)
            274
        }
        2611 -> {
            if ((b(((b(((b((f.dVar48) < (0.3))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (7.0))) != 0))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0) 2610 else 275
        }
        2612 -> {
            if ((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) 2611 else 2604
        }
        2613 -> {
            if ((b(((b((0.5) <= (f.fVar45))) != 0) || ((b((1.0) <= (f.fVar72))) != 0))) != 0) 2602 else 2612
        }
        2614 -> {
            if ((b((f.param_14) < (0x360))) != 0) 2613 else 2596
        }
        2615 -> {
            if ((b((f.fVar69) <= (3.0))) != 0) 2561 else 2614
        }
        2616 -> {
            if ((b((4.0) < (f.fVar69))) != 0) 2517 else 2615
        }
        2617 -> {
            f.fVar70 = f32(f32(f.dVar38))
            2430
        }
        2618 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar38)))
            2617
        }
        2619 -> {
            f.dVar38 = ((f.dVar38) * (f.dVar53))
            288
        }
        2620 -> {
            writeI32(f.param_1.plus(0x168), 1)
            287
        }
        2621 -> {
            f.dVar38 = ((f.dVar38) - (f.dVar42))
            2620
        }
        2622 -> {
            f.dVar53 = ARR_0012d080[b((f.dVar53) < (f.dVar42))]
            2621
        }
        2623 -> {
            272
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep82(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2624 -> {
            if ((b(((b(((b((DAT_0012cdf8) <= (f.dVar42))) != 0) || ((b((f.dVar42) <= (DAT_0012ce18))) != 0))) != 0) || ((run { run { f.dVar53 = DAT_0012ce10; DAT_0012ce10 }; run { f.dVar38 = DAT_0012ce18; DAT_0012ce18 }; b((readF32(f.param_1.plus(0x274))) <= (DAT_0012ce18)) }) != 0))) != 0) 2623 else 286
        }
        2625 -> {
            316
        }
        2626 -> {
            if ((b((f.fVar70) != (0.0))) != 0) 2625 else 2624
        }
        2627 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2626
        }
        2628 -> {
            271
        }
        2629 -> {
            f.fVar57 = f32(3.5)
            2628
        }
        2630 -> {
            if ((b(((f.bVar12) != 0) || ((b((f.bVar8) != (f.bVar10))) != 0))) != 0) 2629 else 2628
        }
        2631 -> {
            f.fVar57 = f32(f.fVar78)
            2630
        }
        2632 -> {
            f.bVar10 = b((0) != 0)
            2631
        }
        2633 -> {
            f.bVar12 = b((b((f.fVar78) == (3.5))) != 0)
            2632
        }
        2634 -> {
            f.bVar8 = b((b((f.fVar78) < (3.5))) != 0)
            2633
        }
        2635 -> {
            if ((b(!((b((f.fVar78).isNaN())) != 0))) != 0) 2634 else 2631
        }
        2636 -> {
            f.bVar10 = b((1) != 0)
            2635
        }
        2637 -> {
            f.bVar12 = b((0) != 0)
            2636
        }
        2638 -> {
            f.bVar8 = b((0) != 0)
            2637
        }
        2639 -> {
            if ((b((f.dVar42) < (3.9))) != 0) 2638 else 2631
        }
        2640 -> {
            f.bVar10 = b((0) != 0)
            2639
        }
        2641 -> {
            f.bVar12 = b((1) != 0)
            2640
        }
        2642 -> {
            f.bVar8 = b((0) != 0)
            2641
        }
        2643 -> {
            if ((b(((b((0x30) < (f.iVar14))) != 0) && ((run { run { f.fVar57 = f32(3.0); f32(3.0) }; b((f.fVar72) < (DAT_0012cc40)) }) != 0))) != 0) 2642 else 2628
        }
        2644 -> {
            f.fVar57 = f32(3.0)
            2643
        }
        2645 -> {
            if ((b((readF32(f.param_1.plus(0x1a0))) <= (0.5))) != 0) 2644 else 2627
        }
        2646 -> {
            270
        }
        2647 -> {
            f.fVar57 = f32(4.3)
            2646
        }
        2648 -> {
            f.fVar60 = f32(0.65)
            2647
        }
        2649 -> {
            f.fVar57 = f32(4.9)
            2646
        }
        2650 -> {
            f.fVar60 = f32(0.65)
            2649
        }
        2651 -> {
            if ((b(((b(((b((f.fVar55) <= (3.9))) != 0) || ((b((f.fVar41) <= (3.9))) != 0))) != 0) || ((b((f.fVar44) <= (3.9))) != 0))) != 0) 2648 else 2650
        }
        2652 -> {
            if ((b(((b(((b(((b((f.fVar82) < (1.2))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 2651 else 2645
        }
        2653 -> {
            217
        }
        2654 -> {
            f.fVar76 = f32(f.fVar78)
            2653
        }
        2655 -> {
            f.fVar57 = f32(0.5)
            2654
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep83(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2656 -> {
            if ((b(((b((0x6c0) < (f.param_14))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 2655 else 2652
        }
        2657 -> {
            277
        }
        2658 -> {
            if ((b(((b(((b(((b((f.dVar42) < (4.3))) != 0) && ((b((3.3) < (f.fVar44))) != 0))) != 0) && ((b((3.3) < (f.fVar41))) != 0))) != 0) && ((b(((b((3.3) < (f.fVar55))) != 0) && ((run { run { f.fVar76 = f32(f.fVar78); f32(f.fVar78) }; b((0) < (f.iVar21)) }) != 0))) != 0))) != 0) 2657 else 2656
        }
        2659 -> {
            293
        }
        2660 -> {
            f.fVar57 = f32(0.5)
            2659
        }
        2661 -> {
            f.fVar76 = f32(4.5)
            2660
        }
        2662 -> {
            if ((b(((b(((b((1.0) <= (f.fVar74))) != 0) || ((b((1.0) <= (f.fVar46))) != 0))) != 0) || ((run { run { f.fVar76 = f32(f.fVar78); f32(f.fVar78) }; b((1.0) <= (f.fVar47)) }) != 0))) != 0) 2661 else 2660
        }
        2663 -> {
            if ((b(((b(((b(((b((0x30) < (f.iVar14))) != 0) && ((b((3.9) < (f.fVar44))) != 0))) != 0) && ((b((3.9) < (f.fVar41))) != 0))) != 0) && ((b(((b(((b((3.9) < (f.fVar55))) != 0) && ((b((3.9) < (f.fVar24))) != 0))) != 0) && ((b((f.fVar52) < (8.0))) != 0))) != 0))) != 0) 2662 else 2658
        }
        2664 -> {
            316
        }
        2665 -> {
            f.fVar70 = f32(f32(f.dVar53))
            2664
        }
        2666 -> {
            writeF32(f.param_1.plus(0x16c), f32(f32(f.dVar53)))
            2665
        }
        2667 -> {
            f.dVar53 = ((f.dVar39) * (f.dVar38))
            285
        }
        2668 -> {
            f.dVar38 = f.dVar53
            2667
        }
        2669 -> {
            if ((b(((f.bVar10) != 0) || ((b((f.bVar12) != (f.bVar8))) != 0))) != 0) 2668 else 2667
        }
        2670 -> {
            f.dVar38 = 0.5
            2669
        }
        2671 -> {
            f.bVar8 = b((0) != 0)
            284
        }
        2672 -> {
            f.bVar10 = b((b((f.dVar42) == (f.dVar38))) != 0)
            2671
        }
        2673 -> {
            f.bVar12 = b((b((f.dVar42) < (f.dVar38))) != 0)
            2672
        }
        2674 -> {
            if ((b(((b(!((b((f.dVar42).isNaN())) != 0))) != 0) && ((b(!((b((f.dVar38).isNaN())) != 0))) != 0))) != 0) 2673 else 284
        }
        2675 -> {
            f.bVar8 = b((1) != 0)
            2674
        }
        2676 -> {
            f.bVar10 = b((0) != 0)
            2675
        }
        2677 -> {
            f.bVar12 = b((0) != 0)
            2676
        }
        2678 -> {
            f.dVar39 = ((f.dVar39) - (f.dVar42))
            2677
        }
        2679 -> {
            writeI32(f.param_1.plus(0x168), 1)
            283
        }
        2680 -> {
            f.dVar53 = DAT_0012ce88
            2679
        }
        2681 -> {
            f.dVar38 = DAT_0012cdf8
            282
        }
        2682 -> {
            f.dVar39 = 3.3
            2681
        }
        2683 -> {
            316
        }
        2684 -> {
            278
        }
        2685 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 2684 else 2683
        }
        2686 -> {
            f.fVar70 = f32(f.fVar54)
            2685
        }
        2687 -> {
            if ((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((4.3) <= (f.dVar42))) != 0))) != 0) || ((b(((b((f.dVar42) <= (DAT_0012cde0))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0))) != 0) 280 else 281
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep84(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2688 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.5, 1.1, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2687
        }
        2689 -> {
            231
        }
        2690 -> {
            f.fVar57 = f32(4.5)
            2689
        }
        2691 -> {
            f.fVar60 = f32(1.2)
            2690
        }
        2692 -> {
            if ((b((0x2f) < (f.iVar14))) != 0) 2691 else 2688
        }
        2693 -> {
            290
        }
        2694 -> {
            f.bVar12 = b((b((f.dVar53) < (f.dVar38))) != 0)
            2693
        }
        2695 -> {
            f.bVar10 = b((b((f.dVar53) == (f.dVar38))) != 0)
            2694
        }
        2696 -> {
            f.bVar8 = b((b(((b((f.dVar53).isNaN())) != 0) || ((b((f.dVar38).isNaN())) != 0))) != 0)
            2695
        }
        2697 -> {
            f.dVar53 = ((f.fVar70) + (f.param_4))
            2696
        }
        2698 -> {
            f.dVar38 = 2.8
            279
        }
        2699 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2698
        }
        2700 -> {
            316
        }
        2701 -> {
            if ((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) 2700 else 278
        }
        2702 -> {
            f.fVar70 = f32(f.fVar54)
            2701
        }
        2703 -> {
            240
        }
        2704 -> {
            if ((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((f.dVar42) < (4.3))) != 0))) != 0) && ((b(((b((DAT_0012cde0) < (f.dVar42))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 2703 else 2702
        }
        2705 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2704
        }
        2706 -> {
            if ((b((f.iVar14) < (0x24))) != 0) 2705 else 2692
        }
        2707 -> {
            217
        }
        2708 -> {
            f.fVar57 = f32(0.5)
            2707
        }
        2709 -> {
            f.fVar76 = f32(4.7)
            277
        }
        2710 -> {
            if ((b(((b(((b(((b((f.fVar82) < (DAT_0012cc40))) != 0) && ((b((f.fVar72) < (0.6))) != 0))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b((0x30) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) 2709 else 2706
        }
        2711 -> {
            if ((b(!((f.bVar10) != 0))) != 0) 2710 else 2663
        }
        2712 -> {
            if ((b((f.fVar69) <= (4.5))) != 0) 2616 else 2711
        }
        2713 -> {
            if ((b((f.dVar62) <= (DAT_0012cf18))) != 0) 2712 else 2429
        }
        2714 -> {
            316
        }
        2715 -> {
            264
        }
        2716 -> {
            f.dVar62 = ((5.5) - (f.dVar62))
            2715
        }
        2717 -> {
            if ((b((((f.dVar62) + (-(5.5)))) < (0.6))) != 0) 2716 else 2714
        }
        2718 -> {
            202
        }
        2719 -> {
            f.dVar62 = ((f.dVar62) * (0.5))
            2718
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep85(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2720 -> {
            f.dVar62 = ((DAT_0012cf18) - (f.dVar62))
            264
        }
        2721 -> {
            if ((b((((f.dVar62) + (DAT_0012cf20))) < (0.6))) != 0) 2720 else 2714
        }
        2722 -> {
            if ((b((11.0) <= (f.fVar54))) != 0) 2717 else 2721
        }
        2723 -> {
            f.dVar62 = f.fVar22
            2722
        }
        2724 -> {
            if ((b((f.fVar69) < (7.0))) != 0) 2723 else 2714
        }
        2725 -> {
            f.fVar70 = f32(0.0)
            2724
        }
        2726 -> {
            f.fVar70 = f32(((((5.0) - (f.fVar69))) * (0.5)))
            2714
        }
        2727 -> {
            f.fVar70 = f32(((((5.0) - (f.fVar22))) * (0.5)))
            2714
        }
        2728 -> {
            if ((b((0.6) <= (((f.fVar22) + (-(5.0)))))) != 0) 2726 else 2727
        }
        2729 -> {
            202
        }
        2730 -> {
            f.dVar62 = ((((f.dVar38) - (f.dVar62))) * (0.5))
            2729
        }
        2731 -> {
            316
        }
        2732 -> {
            264
        }
        2733 -> {
            f.dVar62 = ((5.5) - (f.dVar62))
            2732
        }
        2734 -> {
            if ((b((((f.dVar62) + (-(5.5)))) < (0.5))) != 0) 2733 else 2731
        }
        2735 -> {
            f.fVar70 = f32(0.0)
            2734
        }
        2736 -> {
            if ((b((0.6) <= (((f.dVar62) + (DAT_0012cf20))))) != 0) 2735 else 2730
        }
        2737 -> {
            f.dVar38 = DAT_0012cf18
            2736
        }
        2738 -> {
            f.dVar38 = 5.1
            2730
        }
        2739 -> {
            if ((b((0.6) <= (((f.dVar62) + (-(5.1)))))) != 0) 2737 else 2738
        }
        2740 -> {
            if ((b((11.0) <= (f.fVar54))) != 0) 2739 else 2728
        }
        2741 -> {
            if ((b(((b((1.5) <= (f.fVar56))) != 0) || ((b((DAT_0012cc80) <= (f.fVar72))) != 0))) != 0) 2725 else 2740
        }
        2742 -> {
            if ((b((6.0) < (f.fVar69))) != 0) 2741 else 2713
        }
        2743 -> {
            270
        }
        2744 -> {
            f.fVar57 = f32(3.5)
            2743
        }
        2745 -> {
            f.fVar60 = f32(0.85)
            2744
        }
        2746 -> {
            263
        }
        2747 -> {
            f.fVar60 = f32(0.65)
            2746
        }
        2748 -> {
            if ((b(((b(((b((4.0) <= (f.fVar78))) != 0) || ((b((f.fVar60) <= (0.5))) != 0))) != 0) || ((b(((b((f.fVar52) <= (6.0))) != 0) || ((b(((b((f.fVar57) <= (1.0))) != 0) && ((b((-(0.3)) <= (f.dVar49))) != 0))) != 0))) != 0))) != 0) 2747 else 261
        }
        2749 -> {
            258
        }
        2750 -> {
            if ((b(((b(((b((3.8) < (f.dVar42))) != 0) && ((b((f.dVar48) < (0.3))) != 0))) != 0) && ((b(((b((DAT_0012ced0) < (f.dVar49))) != 0) && ((b((f.fVar65) < (DAT_0012cf60))) != 0))) != 0))) != 0) 2749 else 2748
        }
        2751 -> {
            f.fVar60 = f32(0.45)
            2744
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep86(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2752 -> {
            if ((b(((b(((b((f.fVar52) <= (6.0))) != 0) || ((b((DAT_0012cdf8) <= (f.dVar42))) != 0))) != 0) || ((b((((f.fVar64) - (f.fVar29))) <= (DAT_0012cc88))) != 0))) != 0) 2750 else 2751
        }
        2753 -> {
            260
        }
        2754 -> {
            if ((b(((b((f.dVar39) < (DAT_0012cdc0))) != 0) && ((b((((f.fVar64) - (f.fVar29))) < (DAT_0012cc78))) != 0))) != 0) 2753 else 2752
        }
        2755 -> {
            259
        }
        2756 -> {
            257
        }
        2757 -> {
            if ((b(((b((f.fVar78) < (4.5))) != 0) && ((b((9.5) < (f.fVar26))) != 0))) != 0) 2756 else 2755
        }
        2758 -> {
            if ((b((f.dVar39) < (DAT_0012cdc0))) != 0) 260 else 2752
        }
        2759 -> {
            if ((b((f.dVar49) <= (-(0.3)))) != 0) 2754 else 2758
        }
        2760 -> {
            if ((b(((b((4.6) < (f.dVar38))) != 0) && ((b((f.dVar48) < (0.3))) != 0))) != 0) 2759 else 2752
        }
        2761 -> {
            293
        }
        2762 -> {
            f.fVar76 = f32(4.8)
            2761
        }
        2763 -> {
            f.fVar57 = f32(0.45)
            2762
        }
        2764 -> {
            270
        }
        2765 -> {
            f.fVar57 = f32(4.7)
            2764
        }
        2766 -> {
            f.fVar60 = f32(0.45)
            2765
        }
        2767 -> {
            263
        }
        2768 -> {
            f.fVar60 = f32(0.55)
            2767
        }
        2769 -> {
            if ((b(((b(((b(((b((0.5) < (f.fVar60))) != 0) && ((b((DAT_0012d058) < (f.fVar65))) != 0))) != 0) || ((b(((b(((b((7.8) < (f.dVar77))) != 0) && ((b((f.dVar38) < (4.3))) != 0))) != 0) && ((b((DAT_0012cf28) < (f.dVar32))) != 0))) != 0))) != 0) || ((b(((b(((b((f.dVar42) < (DAT_0012ce60))) != 0) && ((b(((b((0.25) < (f.fVar60))) != 0) || ((b((8.5) < (f.fVar26))) != 0))) != 0))) != 0) && ((b(((b((6.0) < (f.fVar52))) != 0) || ((b((6.5) < (f.fVar79))) != 0))) != 0))) != 0))) != 0) 2768 else 259
        }
        2770 -> {
            if ((b(((b((f.fVar55) <= (3.9))) != 0) || ((b(((b((f.fVar41) <= (3.9))) != 0) || ((b((f.fVar44) <= (3.9))) != 0))) != 0))) != 0) 2769 else 2763
        }
        2771 -> {
            f.fVar76 = f32(4.2)
            2761
        }
        2772 -> {
            f.fVar57 = f32(0.55)
            2771
        }
        2773 -> {
            f.fVar76 = f32(4.5)
            2761
        }
        2774 -> {
            f.fVar57 = f32(0.45)
            2773
        }
        2775 -> {
            if ((b(((b(((b((f.dVar38) <= (4.8))) != 0) || ((b((f.dVar42) <= (DAT_0012cca0))) != 0))) != 0) || ((b((f.dVar49) <= (DAT_0012cfc0))) != 0))) != 0) 2772 else 2774
        }
        2776 -> {
            if ((b(((b((4.5) <= (f.fVar78))) != 0) || ((b(((b((f.dVar48) <= (0.3))) != 0) && ((b((-(0.3)) <= (f.dVar49))) != 0))) != 0))) != 0) 2770 else 2775
        }
        2777 -> {
            if ((b(((b(((b((f.dVar59) <= (DAT_0012ccb0))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb0))) != 0))) != 0) || ((b(((b((DAT_0012cca0) <= (f.dVar42))) != 0) || ((b((f.fVar79) <= (6.0))) != 0))) != 0))) != 0) 2776 else 2760
        }
        2778 -> {
            f.fVar60 = f32(0.5)
            2744
        }
        2779 -> {
            270
        }
        2780 -> {
            f.fVar57 = f32(4.2)
            2779
        }
        2781 -> {
            f.fVar60 = f32(0.5)
            263
        }
        2782 -> {
            if ((b(((b(((b(((b((3.8) <= (f.dVar42))) != 0) || ((b((f.dVar53) <= (4.6))) != 0))) != 0) || ((b((f.fVar45) <= (0.25))) != 0))) != 0) || ((b(((b((f.dVar48) < (0.3))) != 0) && ((b(((b((-(0.3)) < (f.dVar49))) != 0) || ((b((((f.fVar64) - (f.fVar29))) < (DAT_0012cc78))) != 0))) != 0))) != 0))) != 0) 2781 else 2778
        }
        2783 -> {
            f.fVar60 = f32(1.0)
            2744
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep87(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2784 -> {
            if ((b((f.fVar72) < (0.7))) != 0) 2782 else 2783
        }
        2785 -> {
            270
        }
        2786 -> {
            f.fVar57 = f32(4.5)
            2785
        }
        2787 -> {
            f.fVar60 = f32(0.4)
            262
        }
        2788 -> {
            270
        }
        2789 -> {
            f.fVar57 = f32(3.9)
            2788
        }
        2790 -> {
            f.fVar60 = f32(0.4)
            2789
        }
        2791 -> {
            if ((b(((b((f.fVar23) < (4.0))) != 0) && ((b((0.6) < (f.dVar39))) != 0))) != 0) 2790 else 2787
        }
        2792 -> {
            if ((b(((b(((b((f.param_12) < (11.0))) != 0) && ((b((f.fVar40) < (5.0))) != 0))) != 0) || ((b(((b(((b(((b((f.fVar27) < (66.0))) != 0) && ((b(((b((DAT_0012ce00) < (f.dVar42))) != 0) && ((b((f.fVar52) < (f.fVar79))) != 0))) != 0))) != 0) || ((b((DAT_0012ce60) < (f.dVar53))) != 0))) != 0) && ((b((f.fVar60) < (0.5))) != 0))) != 0))) != 0) 2791 else 2784
        }
        2793 -> {
            if ((b(((b(((b(((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((f.fVar57) <= (1.0))) != 0))) != 0) && ((b(((b((DAT_0012ce48) <= (f.dVar38))) != 0) || ((b((f.dVar59) <= (DAT_0012cc40))) != 0))) != 0))) != 0) && ((b(((b((4.3) <= (f.dVar38))) != 0) || ((b((f.dVar59) <= (DAT_0012cdc0))) != 0))) != 0))) != 0) || ((b(((b((f.dVar77) <= (8.2))) != 0) || ((b(((b(((b((DAT_0012ce00) <= (f.dVar42))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb0))) != 0))) != 0) || ((b((f.dVar33) < (DAT_0012ce30))) != 0))) != 0))) != 0))) != 0) 2777 else 2792
        }
        2794 -> {
            293
        }
        2795 -> {
            f.fVar76 = f32(4.7)
            2794
        }
        2796 -> {
            f.fVar57 = f32(0.4)
            2795
        }
        2797 -> {
            262
        }
        2798 -> {
            f.fVar60 = f32(0.45)
            2797
        }
        2799 -> {
            263
        }
        2800 -> {
            f.fVar60 = f32(0.45)
            2799
        }
        2801 -> {
            if ((b(((b(((b((f.dVar38) <= (DAT_0012ce48))) != 0) || ((b((f.dVar42) <= (3.9))) != 0))) != 0) || ((b(((b((0.3) <= (f.dVar48))) != 0) || ((b((DAT_0012cf60) <= (f.fVar65))) != 0))) != 0))) != 0) 257 else 258
        }
        2802 -> {
            if ((b(((b(((b((0.25) < (f.fVar45))) != 0) || ((b(((b((f.fVar45) < (f.fVar72))) != 0) && ((b((8.2) < (f.dVar77))) != 0))) != 0))) != 0) || ((b(((b((9.0) < (f.fVar26))) != 0) && ((b((DAT_0012cd18) < (f.dVar33))) != 0))) != 0))) != 0) 2801 else 2796
        }
        2803 -> {
            if ((b((f.dVar42) < (4.3))) != 0) 2802 else 2796
        }
        2804 -> {
            256
        }
        2805 -> {
            if ((b(((b(((b((f.dVar62) < (4.1))) != 0) && ((b((f.fVar78) < (3.75))) != 0))) != 0) && ((b((7.5) < (f.fVar79))) != 0))) != 0) 2804 else 2803
        }
        2806 -> {
            217
        }
        2807 -> {
            f.fVar76 = f32(3.5)
            2806
        }
        2808 -> {
            f.fVar57 = f32(1.0)
            2807
        }
        2809 -> {
            if ((b((f.dVar62) < (4.1))) != 0) 256 else 2803
        }
        2810 -> {
            if ((b((DAT_0012cdf8) <= (f.dVar42))) != 0) 2805 else 2809
        }
        2811 -> {
            if ((b(((b((8.5) < (f.fVar26))) != 0) && ((b(((b((7.0) <= (f.fVar52))) != 0) || ((b(((b((DAT_0012cdc0) < (f.dVar39))) != 0) && ((b((6.0) < (f.fVar52))) != 0))) != 0))) != 0))) != 0) 2810 else 2803
        }
        2812 -> {
            293
        }
        2813 -> {
            f.fVar76 = f32(4.2)
            2812
        }
        2814 -> {
            f.fVar57 = f32(0.5)
            2813
        }
        2815 -> {
            f.fVar76 = f32(4.7)
            2812
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep88(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2816 -> {
            f.fVar57 = f32(0.4)
            2815
        }
        2817 -> {
            if ((b(((b((6.5) < (f.fVar52))) != 0) || ((b((6.5) < (f.fVar79))) != 0))) != 0) 2814 else 2816
        }
        2818 -> {
            217
        }
        2819 -> {
            f.fVar76 = f32(3.6)
            2818
        }
        2820 -> {
            f.fVar57 = f32(0.4)
            2819
        }
        2821 -> {
            if ((b(((b((f.fVar78) < (3.5))) != 0) && ((b(((b((DAT_0012cc88) < (((f.fVar64) - (f.fVar29))))) != 0) && ((b((f.dVar38) < (DAT_0012cca0))) != 0))) != 0))) != 0) 2820 else 2817
        }
        2822 -> {
            f.fVar76 = f32(4.2)
            2812
        }
        2823 -> {
            f.fVar57 = f32(0.45)
            2822
        }
        2824 -> {
            f.fVar76 = f32(3.5)
            2812
        }
        2825 -> {
            f.fVar57 = f32(0.75)
            2824
        }
        2826 -> {
            if ((b(((b((3.5) <= (f.fVar78))) != 0) || ((b((f.dVar39) <= (0.85))) != 0))) != 0) 2823 else 2825
        }
        2827 -> {
            if ((b(((b((f.fVar26) <= (8.0))) != 0) || ((b(((b(((b(((b((0x4d) < (f.iVar14))) != 0) || ((b((f.dVar39) <= (DAT_0012ccb0))) != 0))) != 0) && ((b(((b((f.dVar39) <= (DAT_0012ccb8))) != 0) || ((b((f.fVar52) <= (6.5))) != 0))) != 0))) != 0) || ((b(((b((f.fVar72) <= (f.fVar45))) != 0) && ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0))) != 0))) != 0))) != 0) 2821 else 2826
        }
        2828 -> {
            if ((b(((b((1.5) <= (f.fVar45))) != 0) || ((b(((b(((b(((b((0x59) < (f.iVar14))) != 0) && ((b(((b((f.fVar60) <= (0.5))) != 0) || ((b((f.fVar52) <= (7.0))) != 0))) != 0))) != 0) && ((b(((b((f.fVar79) <= (7.0))) != 0) || ((b((f.fVar52) <= (7.0))) != 0))) != 0))) != 0) || ((b(((b(((b((f.dVar77) <= (8.2))) != 0) || ((b((f.dVar33) <= (DAT_0012cf28))) != 0))) != 0) && ((b(((b((f.fVar26) <= (8.5))) != 0) || ((b((f.dVar39) <= (DAT_0012cdf0))) != 0))) != 0))) != 0))) != 0))) != 0) 2827 else 2811
        }
        2829 -> {
            217
        }
        2830 -> {
            f.fVar76 = f32(3.5)
            2829
        }
        2831 -> {
            f.fVar57 = f32(0.75)
            2830
        }
        2832 -> {
            if ((b(((b(((b(((b(((b((f.fVar23) < (4.5))) != 0) && ((b((1.0) < (f.fVar57))) != 0))) != 0) || ((b(((b(((b((f.dVar38) < (DAT_0012ce48))) != 0) && ((b((0.7) < (f.dVar59))) != 0))) != 0) || ((b(((b((f.dVar38) < (DAT_0012cca0))) != 0) && ((b((DAT_0012cdc0) < (f.dVar59))) != 0))) != 0))) != 0))) != 0) && ((b(((b((f.dVar42) < (DAT_0012ce00))) != 0) && ((b((8.2) < (f.dVar77))) != 0))) != 0))) != 0) && ((b((DAT_0012ccb0) < (f.dVar39))) != 0))) != 0) 2831 else 2828
        }
        2833 -> {
            if ((b(((b(((b((DAT_0012cf18) <= (f.dVar38))) != 0) || ((b((f.iVar14) < (0x43))) != 0))) != 0) || ((b((f.dVar59) <= (DAT_0012cdf0))) != 0))) != 0) 2832 else 2793
        }
        2834 -> {
            f.dVar59 = f.fVar57
            2833
        }
        2835 -> {
            293
        }
        2836 -> {
            f.fVar76 = f32(4.2)
            2835
        }
        2837 -> {
            f.fVar57 = f32(0.5)
            2836
        }
        2838 -> {
            255
        }
        2839 -> {
            f.fVar57 = f32(1.1)
            2838
        }
        2840 -> {
            if ((b(((b((7.5) < (f.fVar54))) != 0) && ((b(((b(((b((10.0) < (f.fVar26))) != 0) && ((b((f.fVar78) < (3.0))) != 0))) != 0) && ((b((7.0) < (f.fVar79))) != 0))) != 0))) != 0) 2839 else 2837
        }
        2841 -> {
            261
        }
        2842 -> {
            270
        }
        2843 -> {
            f.fVar57 = f32(3.0)
            2842
        }
        2844 -> {
            f.fVar60 = f32(0.85)
            2843
        }
        2845 -> {
            if ((b(((b((f.fVar78) < (3.0))) != 0) && ((b((DAT_0012cf50) < (f.dVar48))) != 0))) != 0) 2844 else 2841
        }
        2846 -> {
            257
        }
        2847 -> {
            if ((b(((b((3.5) <= (f.fVar23))) != 0) || ((b((f.fVar52) <= (6.5))) != 0))) != 0) 2846 else 2841
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep89(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2848 -> {
            if ((b(((b(((b((5.0) <= (f.fVar40))) != 0) || ((b((DAT_0012cca0) <= (f.dVar38))) != 0))) != 0) || ((b((0.85) <= (f.dVar39))) != 0))) != 0) 2845 else 2847
        }
        2849 -> {
            293
        }
        2850 -> {
            f.fVar76 = f32(3.0)
            2849
        }
        2851 -> {
            f.fVar57 = f32(0.55)
            2850
        }
        2852 -> {
            if ((b(((b((f.fVar23) < (4.0))) != 0) && ((b((1.0) < (f.fVar57))) != 0))) != 0) 2851 else 2848
        }
        2853 -> {
            293
        }
        2854 -> {
            f.fVar76 = f32(3.0)
            2853
        }
        2855 -> {
            f.fVar57 = f32(1.2)
            247
        }
        2856 -> {
            248
        }
        2857 -> {
            f.fVar57 = f32(0.85)
            2856
        }
        2858 -> {
            if ((b(((b((3.9) <= (f.dVar38))) != 0) || ((b((f.fVar52) <= (7.0))) != 0))) != 0) 2857 else 2855
        }
        2859 -> {
            217
        }
        2860 -> {
            f.fVar76 = f32(3.0)
            2859
        }
        2861 -> {
            f.fVar57 = f32(0.65)
            2860
        }
        2862 -> {
            if ((b(((b((f.dVar49) <= (-(0.3)))) != 0) && ((b(((b((DAT_0012cf08) <= (f.dVar33))) != 0) || ((b((0.3) <= (f.dVar48))) != 0))) != 0))) != 0) 2861 else 2858
        }
        2863 -> {
            f.fVar76 = f32(3.5)
            2853
        }
        2864 -> {
            f.fVar57 = f32(1.3)
            248
        }
        2865 -> {
            247
        }
        2866 -> {
            f.fVar57 = f32(1.3)
            2865
        }
        2867 -> {
            if ((b(((b((f.dVar38) < (3.9))) != 0) && ((b((7.0) < (f.fVar52))) != 0))) != 0) 2866 else 2864
        }
        2868 -> {
            f.fVar76 = f32(3.9)
            2853
        }
        2869 -> {
            f.fVar57 = f32(1.3)
            2868
        }
        2870 -> {
            if ((b(((b(((b((0.3) <= (f.dVar48))) != 0) || ((b((f.dVar49) <= (-(0.3)))) != 0))) != 0) || ((b((DAT_0012cc88) <= (f.fVar65))) != 0))) != 0) 2867 else 2869
        }
        2871 -> {
            if ((b(((b(((b((8.2) <= (f.dVar32))) != 0) || ((b((f.iVar14) < (0x31))) != 0))) != 0) || ((b((8.5) <= (f.fVar52))) != 0))) != 0) 2862 else 2870
        }
        2872 -> {
            279
        }
        2873 -> {
            f.dVar38 = DAT_0012ce10
            2872
        }
        2874 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            2873
        }
        2875 -> {
            316
        }
        2876 -> {
            if ((b((readI32(f.param_1.plus(0x168))) != (1))) != 0) 2875 else 2874
        }
        2877 -> {
            f.fVar70 = f32(f.fVar54)
            2876
        }
        2878 -> {
            245
        }
        2879 -> {
            if ((b(((b(((b((f.fVar54) == (0.0))) != 0) && ((b((f.dVar42) < (3.8))) != 0))) != 0) && ((b(((b((2.3) < (f.dVar42))) != 0) && ((b(((b((2.3) < (readF32(f.param_1.plus(0x21c))))) != 0) && ((run { run { f.dVar38 = DAT_0012ce10; DAT_0012ce10 }; b((2.3) < (readF32(f.param_1.plus(0x274)))) }) != 0))) != 0))) != 0))) != 0) 2878 else 2877
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep90(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2880 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.3, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2879
        }
        2881 -> {
            if ((b(((b(((b((11.0) < (f.fVar54))) != 0) && ((b((8.0) < (f.fVar52))) != 0))) != 0) && ((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0))) != 0) 2880 else 2871
        }
        2882 -> {
            if ((b(((b(((b(((b((9.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b(((b((1.0) <= (f.fVar72))) != 0) && ((b((f.iVar14) < (0x39))) != 0))) != 0))) != 0) || ((b((8.0) <= (f.fVar52))) != 0))) != 0) || ((b(((b(((b((1.0) <= (f.fVar45))) != 0) || ((b((f.iVar14) < (0x25))) != 0))) != 0) || ((b((8.0) <= (f.fVar79))) != 0))) != 0))) != 0) 2881 else 2852
        }
        2883 -> {
            217
        }
        2884 -> {
            f.fVar76 = f32(3.9)
            2883
        }
        2885 -> {
            f.fVar57 = f32(0.95)
            2884
        }
        2886 -> {
            if ((b(((b(((b(((b((f.fVar45) < (DAT_0012ccb0))) != 0) && ((b((f.dVar39) < (DAT_0012cc40))) != 0))) != 0) && ((b((f.fVar60) < (1.0))) != 0))) != 0) && ((b(((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0) && ((b((0x30) < (f.iVar14))) != 0))) != 0))) != 0) 2885 else 2882
        }
        2887 -> {
            if ((b(((b(((b((DAT_0012cdc0) <= (f.fVar72))) != 0) || ((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((f.iVar14) < (0x37))) != 0))) != 0))) != 0) || ((b(((b((0.25) <= (f.fVar45))) != 0) && ((b((DAT_0012cf28) <= (f.dVar33))) != 0))) != 0))) != 0) 2886 else 2840
        }
        2888 -> {
            f.fVar76 = f32(4.2)
            2835
        }
        2889 -> {
            f.fVar57 = f32(0.45)
            2888
        }
        2890 -> {
            f.fVar76 = f32(3.2)
            2835
        }
        2891 -> {
            f.fVar57 = f32(0.55)
            2890
        }
        2892 -> {
            if ((b(((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((DAT_0012cca0) <= (f.dVar38))) != 0))) != 0) || ((b(((b((f.fVar79) <= (7.0))) != 0) || ((b(((b((f.fVar54) <= (8.0))) != 0) || ((b((f.dVar39) <= (0.6))) != 0))) != 0))) != 0))) != 0) 2889 else 2891
        }
        2893 -> {
            217
        }
        2894 -> {
            f.fVar76 = f32(3.5)
            2893
        }
        2895 -> {
            f.fVar57 = f32(0.45)
            2894
        }
        2896 -> {
            if ((b(((b(((b((f.dVar38) < (3.3))) != 0) && ((b((6.0) < (f.fVar79))) != 0))) != 0) && ((b((42.0) < (f.fVar27))) != 0))) != 0) 2895 else 2892
        }
        2897 -> {
            if ((b(((b((5.0) <= (f.fVar23))) != 0) || ((b(((b((f.iVar14) < (0x49))) != 0) || ((b((60.0) <= (f.fVar27))) != 0))) != 0))) != 0) 2887 else 2896
        }
        2898 -> {
            f.fVar76 = f32(3.5)
            2835
        }
        2899 -> {
            f.fVar57 = f32(1.2)
            2898
        }
        2900 -> {
            270
        }
        2901 -> {
            f.fVar57 = f32(3.5)
            2900
        }
        2902 -> {
            f.fVar60 = f32(0.8)
            254
        }
        2903 -> {
            270
        }
        2904 -> {
            f.fVar57 = f32(4.3)
            2903
        }
        2905 -> {
            f.fVar60 = f32(0.8)
            252
        }
        2906 -> {
            if ((b(((b(((b((0x3b) < (f.iVar14))) != 0) || ((b((3.9) <= (f.dVar42))) != 0))) != 0) || ((b((f.fVar26) <= (11.0))) != 0))) != 0) 2905 else 2902
        }
        2907 -> {
            270
        }
        2908 -> {
            f.fVar57 = f32(4.7)
            2907
        }
        2909 -> {
            f.fVar60 = f32(0.8)
            2908
        }
        2910 -> {
            if ((b(((b(((b((f.dVar48) < (0.3))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0) || ((b(((b(((b(((b((f.fVar26) < (10.0))) != 0) && ((b((f.fVar79) < (7.0))) != 0))) != 0) && ((b((f.dVar48) < (0.3))) != 0))) != 0) && ((b((f.fVar65) < (DAT_0012cc78))) != 0))) != 0))) != 0) 2909 else 2906
        }
        2911 -> {
            253
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep91(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2912 -> {
            if ((b(((b((7.0) < (f.fVar54))) != 0) && ((b((9.5) < (f.fVar26))) != 0))) != 0) 2911 else 251
        }
        2913 -> {
            f.fVar60 = f32(1.0)
            254
        }
        2914 -> {
            252
        }
        2915 -> {
            f.fVar60 = f32(0.45)
            2914
        }
        2916 -> {
            254
        }
        2917 -> {
            f.fVar60 = f32(0.55)
            2916
        }
        2918 -> {
            if ((b(((b((f.dVar38) < (4.1))) != 0) && ((b(((b((f.iVar14) < (0x48))) != 0) && ((b((7.0) < (f.fVar79))) != 0))) != 0))) != 0) 2917 else 2915
        }
        2919 -> {
            if ((b(((b(((b((f.fVar26) <= (9.5))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b(((b((f.fVar79) <= (7.0))) != 0) || ((b(((b((3.0) <= (f.fVar78))) != 0) && ((b((f.fVar60) <= (0.75))) != 0))) != 0))) != 0))) != 0) 2918 else 2913
        }
        2920 -> {
            251
        }
        2921 -> {
            if ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) && ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0) 2920 else 2919
        }
        2922 -> {
            251
        }
        2923 -> {
            if ((b((f.fVar54) <= (7.0))) != 0) 2922 else 253
        }
        2924 -> {
            if ((b((f.fVar52) <= (7.0))) != 0) 2912 else 2923
        }
        2925 -> {
            316
        }
        2926 -> {
            if ((b(((b(((b(((b((8.0) < (f.fVar54))) != 0) && ((b((0x48) < (f.iVar14))) != 0))) != 0) && ((b((3.0) < (f.fVar55))) != 0))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((f.dVar33) < (DAT_0012cd18)) }) != 0))) != 0) 2925 else 2924
        }
        2927 -> {
            254
        }
        2928 -> {
            f.fVar60 = f32(0.65)
            2927
        }
        2929 -> {
            249
        }
        2930 -> {
            f.fVar60 = f32(0.5)
            2929
        }
        2931 -> {
            if ((b(((b(((b((f.dVar48) < (0.3))) != 0) && ((b(((b((-(0.3)) < (f.dVar49))) != 0) || ((b((f.iVar21) == (1))) != 0))) != 0))) != 0) && ((b((f.fVar65) < (DAT_0012cfa8))) != 0))) != 0) 2930 else 2928
        }
        2932 -> {
            if ((b(((b(((b(((b((f.fVar23) < (5.0))) != 0) && ((b((0.5) < (f.fVar57))) != 0))) != 0) && ((b((DAT_0012cc98) < (f.dVar53))) != 0))) != 0) && ((b(((b(((b((2.8) < (f.dVar42))) != 0) && ((b((6.8) < (f.fVar54))) != 0))) != 0) && ((b((DAT_0012ccb8) < (f.dVar39))) != 0))) != 0))) != 0) 2931 else 2926
        }
        2933 -> {
            270
        }
        2934 -> {
            f.fVar57 = f32(3.0)
            2933
        }
        2935 -> {
            f.fVar60 = f32(0.5)
            2934
        }
        2936 -> {
            if ((b(((b(((b((f.fVar23) < (3.5))) != 0) && ((b((DAT_0012ccb0) < (f.fVar57))) != 0))) != 0) && ((b(((b((6.8) < (f.fVar54))) != 0) && ((b(((b((0.35) < (f.dVar39))) != 0) && ((b((6.0) < (f.fVar79))) != 0))) != 0))) != 0))) != 0) 250 else 2932
        }
        2937 -> {
            254
        }
        2938 -> {
            f.fVar60 = f32(0.6)
            2937
        }
        2939 -> {
            270
        }
        2940 -> {
            f.fVar57 = f32(4.2)
            2939
        }
        2941 -> {
            f.fVar60 = f32(0.6)
            249
        }
        2942 -> {
            if ((b(((b(((b((f.fVar64) < (f.fVar29))) != 0) && ((b((f.dVar48) < (0.3))) != 0))) != 0) && ((b(((b((f.dVar53) < (0.35))) != 0) && ((b((-(0.3)) < (f.dVar49))) != 0))) != 0))) != 0) 2941 else 2938
        }
        2943 -> {
            250
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep92(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2944 -> {
            if ((b(((b(((b((8.5) < (f.fVar54))) != 0) && ((b((DAT_0012ccb8) < (f.dVar39))) != 0))) != 0) && ((b(((b((f.fVar78) < (3.0))) != 0) || ((b((0.85) < (f.dVar39))) != 0))) != 0))) != 0) 2943 else 2942
        }
        2945 -> {
            if ((b((f.fVar23) < (3.5))) != 0) 2944 else 2942
        }
        2946 -> {
            if ((b(((b(((b((DAT_0012cf08) < (f.dVar77))) != 0) && ((b(((b((7.0) < (f.fVar52))) != 0) || ((b((0.7) < (f.dVar39))) != 0))) != 0))) != 0) && ((b((f.dVar42) < (DAT_0012cdf8))) != 0))) != 0) 2945 else 2936
        }
        2947 -> {
            if ((b(((b(((b(((b(((b((f.fVar52) <= (6.0))) != 0) || ((b((3.9) <= (f.dVar38))) != 0))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b(((b((f.fVar26) <= (8.5))) != 0) || ((b((f.fVar79) <= (6.0))) != 0))) != 0))) != 0) || ((b((f.dVar39) <= (DAT_0012cdc0))) != 0))) != 0) 2946 else 2899
        }
        2948 -> {
            if ((b(((b(((b((DAT_0012cc40) <= (f.fVar72))) != 0) || ((run { run { f.dVar53 = f.fVar45; f.fVar45 }; b((0.6) <= (f.dVar53)) }) != 0))) != 0) || ((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b(((b(((b((f.fVar26) <= (9.0))) != 0) && ((b((f.iVar14) < (0x3d))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1a0))) != (0.0))) != 0))) != 0))) != 0))) != 0) 2897 else 2947
        }
        2949 -> {
            f.fVar76 = f32(2.8)
            2835
        }
        2950 -> {
            f.fVar57 = f32(0.45)
            2949
        }
        2951 -> {
            f.fVar76 = f32(3.2)
            2835
        }
        2952 -> {
            f.fVar57 = f32(0.45)
            255
        }
        2953 -> {
            if ((b((11.0) < (f.fVar26))) != 0) 2950 else 2952
        }
        2954 -> {
            if ((b(((b(((b(((b((DAT_0012cde0) <= (f.dVar38))) != 0) || ((b((0x53) < (f.iVar14))) != 0))) != 0) || ((b((3.0) <= (f.fVar78))) != 0))) != 0) || ((b((f.fVar79) <= (6.0))) != 0))) != 0) 2948 else 2953
        }
        2955 -> {
            217
        }
        2956 -> {
            f.fVar76 = f32(3.5)
            2955
        }
        2957 -> {
            f.fVar57 = f32(0.65)
            2956
        }
        2958 -> {
            if ((b(((b(((b((f.dVar38) < (3.9))) != 0) && ((b((8.0) < (f.fVar26))) != 0))) != 0) && ((b(((b((0.85) < (f.dVar39))) != 0) && ((b((6.0) < (f.fVar79))) != 0))) != 0))) != 0) 2957 else 2954
        }
        2959 -> {
            284
        }
        2960 -> {
            f.bVar12 = b((b((f.dVar42) < (f.dVar38))) != 0)
            2959
        }
        2961 -> {
            f.bVar10 = b((b((f.dVar42) == (f.dVar38))) != 0)
            2960
        }
        2962 -> {
            f.bVar8 = b((b(((b((f.dVar42).isNaN())) != 0) || ((b((f.dVar38).isNaN())) != 0))) != 0)
            2961
        }
        2963 -> {
            f.dVar39 = ((3.3) - (f.dVar42))
            2962
        }
        2964 -> {
            writeI32(f.param_1.plus(0x168), 1)
            2963
        }
        2965 -> {
            f.dVar38 = DAT_0012cdf8
            2964
        }
        2966 -> {
            f.dVar53 = DAT_0012ce88
            2965
        }
        2967 -> {
            280
        }
        2968 -> {
            if ((b(((b(((b(((b((f.fVar54) != (0.0))) != 0) || ((b((4.3) <= (f.dVar42))) != 0))) != 0) || ((b((f.dVar42) <= (DAT_0012cde0))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x21c))) <= (3.3))) != 0) || ((b((readF32(f.param_1.plus(0x274))) <= (DAT_0012cde0))) != 0))) != 0))) != 0) 2967 else 246
        }
        2969 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.2, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            2968
        }
        2970 -> {
            231
        }
        2971 -> {
            f.fVar57 = f32(4.7)
            2970
        }
        2972 -> {
            f.fVar60 = f32(0.8)
            2971
        }
        2973 -> {
            if ((b(((b((f.fVar82) < (1.2))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) 2972 else 2969
        }
        2974 -> {
            316
        }
        2975 -> {
            f.fVar70 = f32(f32(((((5.0) - (f.fVar22))) * (DAT_0012cc40))))
            2974
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep93(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        2976 -> {
            if ((b(((b((((f.fVar22) + (-(5.0)))) < (0.5))) != 0) && ((b((f.fVar37) < (1.0))) != 0))) != 0) 2975 else 2974
        }
        2977 -> {
            f.fVar70 = f32(0.0)
            2976
        }
        2978 -> {
            264
        }
        2979 -> {
            f.dVar62 = ((DAT_0012ce60) - (f.dVar62))
            2978
        }
        2980 -> {
            if ((b((((f.dVar62) + (DAT_0012ce58))) < (0.5))) != 0) 2979 else 2974
        }
        2981 -> {
            f.fVar70 = f32(0.0)
            2980
        }
        2982 -> {
            f.fVar70 = f32(f32(((DAT_0012ce60) - (f.dVar38))))
            2974
        }
        2983 -> {
            f.fVar70 = f32(f32(((((((DAT_0012d008) - (f.dVar38))) - (f.dVar62))) * (0.5))))
            2974
        }
        2984 -> {
            if ((b((0.5) <= (((f.dVar62) + (DAT_0012ce58))))) != 0) 2982 else 2983
        }
        2985 -> {
            if ((b((0.5) <= (((f.dVar38) + (DAT_0012ce58))))) != 0) 2981 else 2984
        }
        2986 -> {
            f.dVar38 = f.fVar22
            2985
        }
        2987 -> {
            if ((b(((b((1.2) <= (f.fVar82))) != 0) || ((b((1.0) <= (f.fVar72))) != 0))) != 0) 2977 else 2986
        }
        2988 -> {
            f.fVar70 = f32(((5.0) - (f.fVar69)))
            2974
        }
        2989 -> {
            219
        }
        2990 -> {
            f.fVar22 = f32(((((10.0) - (f.fVar69))) - (f.fVar22)))
            2989
        }
        2991 -> {
            if ((b((kotlin.math.abs(((f.fVar22) - (f.fVar69)))) < (DAT_0012cc40))) != 0) 2990 else 2988
        }
        2992 -> {
            if ((b(((b((((f.fVar22) + (-(5.0)))) < (0.5))) != 0) && ((b((((f.fVar69) + (-(5.0)))) < (0.5))) != 0))) != 0) 2991 else 2974
        }
        2993 -> {
            221
        }
        2994 -> {
            f.dVar38 = 4.8
            2993
        }
        2995 -> {
            if ((b((((f.dVar62) + (-(4.8)))) < (0.5))) != 0) 2994 else 2974
        }
        2996 -> {
            if ((b((9.0) <= (f.fVar54))) != 0) 2992 else 2995
        }
        2997 -> {
            if ((b(((b(((b((f.fVar82) < (1.2))) != 0) && ((b((8.0) <= (f.fVar54))) != 0))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) 2996 else 2974
        }
        2998 -> {
            f.fVar70 = f32(0.0)
            2997
        }
        2999 -> {
            if ((b((7.0) <= (f.fVar69))) != 0) 2987 else 2998
        }
        3000 -> {
            if ((b((6.0) <= (f.fVar69))) != 0) 2999 else 2973
        }
        3001 -> {
            217
        }
        3002 -> {
            f.fVar76 = f32(3.5)
            3001
        }
        3003 -> {
            f.fVar57 = f32(1.0)
            3002
        }
        3004 -> {
            316
        }
        3005 -> {
            if ((b(((b((f.iVar14) < (0x31))) != 0) || ((b((7.8) <= (f.dVar32))) != 0))) != 0) 3004 else 3003
        }
        3006 -> {
            f.fVar70 = f32(0.0)
            3005
        }
        3007 -> {
            f.fVar76 = f32(f.fVar78)
            3001
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep94(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3008 -> {
            f.fVar57 = f32(1.0)
            3007
        }
        3009 -> {
            if ((b(((b(((b((DAT_0012ce08) <= (f.fVar46))) != 0) || ((b((DAT_0012ce08) <= (f.fVar47))) != 0))) != 0) || ((b((DAT_0012ce08) <= (f.fVar74))) != 0))) != 0) 3006 else 3008
        }
        3010 -> {
            f.fVar76 = f32(3.5)
            3001
        }
        3011 -> {
            f.fVar57 = f32(1.0)
            3010
        }
        3012 -> {
            if ((b(((b((f.iVar14) < (0x3d))) != 0) || ((b(((b(((b((DAT_0012cd18) <= (f.dVar33))) != 0) && ((b((DAT_0012cc78) <= (((f.fVar64) - (f.fVar29))))) != 0))) != 0) || ((b((0.85) <= (f.fVar72))) != 0))) != 0))) != 0) 3009 else 3011
        }
        3013 -> {
            282
        }
        3014 -> {
            f.dVar39 = 2.3
            3013
        }
        3015 -> {
            244
        }
        3016 -> {
            if ((b(((b(((b((f.dVar42) <= (2.3))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b(((b((f.fVar54) != (0.0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x21c))) <= (2.3))) != 0) || ((run { run { f.dVar38 = DAT_0012cdf8; DAT_0012cdf8 }; b((readF32(f.param_1.plus(0x274))) <= (2.3)) }) != 0))) != 0))) != 0))) != 0) 3015 else 245
        }
        3017 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 2.5, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            3016
        }
        3018 -> {
            if ((b(((b(((b((0.5) < (readF32(f.param_1.plus(0x1a0))))) != 0) && ((b((0.6) < (f.fVar72))) != 0))) != 0) && ((b((f.iVar14) < (0x48))) != 0))) != 0) 3017 else 3012
        }
        3019 -> {
            f.fVar76 = f32(4.2)
            3001
        }
        3020 -> {
            f.fVar57 = f32(0.45)
            3019
        }
        3021 -> {
            if ((b(((b(((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((f.fVar82) <= (0.6))) != 0))) != 0) || ((b((DAT_0012cc40) <= (f.fVar72))) != 0))) != 0) || ((b((f.fVar23) <= (4.5))) != 0))) != 0) 3018 else 3020
        }
        3022 -> {
            316
        }
        3023 -> {
            279
        }
        3024 -> {
            f.dVar38 = 2.8
            3023
        }
        3025 -> {
            f.fVar70 = f32(readF32(f.pjVar1))
            3024
        }
        3026 -> {
            if ((b((readI32(f.param_1.plus(0x168))) == (1))) != 0) 3025 else 3022
        }
        3027 -> {
            f.fVar70 = f32(f.fVar54)
            3026
        }
        3028 -> {
            246
        }
        3029 -> {
            if ((b(((b(((b(((b((DAT_0012cde0) < (f.dVar42))) != 0) && ((b(((b((f.dVar42) < (4.3))) != 0) && ((b((f.fVar54) == (0.0))) != 0))) != 0))) != 0) && ((b((3.3) < (readF32(f.param_1.plus(0x21c))))) != 0))) != 0) && ((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 3028 else 244
        }
        3030 -> {
            f.fVar54 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, 3.0, 1.3, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            3029
        }
        3031 -> {
            if ((b(((b((7.0) < (((f.fVar54) - (f.fVar69))))) != 0) && ((b((f.iVar14) < (0x24))) != 0))) != 0) 3030 else 3021
        }
        3032 -> {
            f.fVar76 = f32(4.8)
            3001
        }
        3033 -> {
            f.fVar57 = f32(0.4)
            3032
        }
        3034 -> {
            if ((b(((b((1.2) <= (f.fVar82))) != 0) || ((b(((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b((0.6) <= (f.dVar39))) != 0))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0))) != 0) 3031 else 3033
        }
        3035 -> {
            f.fVar76 = f32(4.5)
            3001
        }
        3036 -> {
            f.fVar57 = f32(0.4)
            3035
        }
        3037 -> {
            if ((b(((b((5.0) <= (f.fVar23))) != 0) || ((b(((b(((b((f.fVar23) <= (4.5))) != 0) || ((b((DAT_0012cdc0) <= (f.dVar39))) != 0))) != 0) || ((b(((b((f.iVar14) < (0x49))) != 0) && ((b(((b((f.fVar78) <= (4.0))) != 0) || ((b((f.iVar14) < (0x37))) != 0))) != 0))) != 0))) != 0))) != 0) 3034 else 3036
        }
        3038 -> {
            f.fVar76 = f32(f.fVar78)
            3001
        }
        3039 -> {
            f.fVar57 = f32(0.4)
            3038
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep95(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3040 -> {
            210
        }
        3041 -> {
            f.fVar57 = f32(3.5)
            3040
        }
        3042 -> {
            f.fVar60 = f32(0.8)
            3041
        }
        3043 -> {
            f.fVar57 = f32(4.5)
            3040
        }
        3044 -> {
            f.fVar60 = f32(0.4)
            3043
        }
        3045 -> {
            if ((b(((b(((b((10.0) < (f.fVar26))) != 0) && ((b(((b((f.fVar78) < (4.5))) != 0) && ((b((f.iVar14) < (0x2d))) != 0))) != 0))) != 0) || ((b(((b((f.dVar42) < (DAT_0012cca0))) != 0) && ((b((f.iVar14) < (0x2a))) != 0))) != 0))) != 0) 3042 else 3044
        }
        3046 -> {
            if ((b(((b(((b((f.dVar32) <= (6.8))) != 0) || ((b((4.6) <= (f.dVar38))) != 0))) != 0) || ((b(((b((4.5) <= (f.fVar78))) != 0) || ((b(((b((f.fVar54) <= (8.5))) != 0) || ((b((f.fVar52) <= (7.0))) != 0))) != 0))) != 0))) != 0) 3045 else 3039
        }
        3047 -> {
            316
        }
        3048 -> {
            if ((b(((b(((b((6.0) < (f.fVar52))) != 0) && ((b((6.5) < (f.fVar79))) != 0))) != 0) && ((run { run { f.fVar70 = f32(0.0); f32(0.0) }; b((5.5) < (f.fVar23)) }) != 0))) != 0) 3047 else 3046
        }
        3049 -> {
            if ((b(((b((f.dVar42) <= (DAT_0012ce00))) != 0) || ((b(((b(((b((0.3) <= (f.dVar48))) != 0) || ((b((f.dVar49) <= (-(0.3)))) != 0))) != 0) && ((b(((b((0.3) <= (f.dVar48))) != 0) || ((b(((b((f.dVar49) <= (DAT_0012ced0))) != 0) || ((b((DAT_0012cc78) <= (f.fVar65))) != 0))) != 0))) != 0))) != 0))) != 0) 3037 else 3048
        }
        3050 -> {
            if ((b((f.fVar69) < (5.0))) != 0) 3049 else 3000
        }
        3051 -> {
            if ((b((4.0) <= (f.fVar69))) != 0) 3050 else 2958
        }
        3052 -> {
            if ((b(((b(((b((1.0) <= (f.fVar82))) != 0) || ((b((f.dVar62) < (DAT_0012cde0))) != 0))) != 0) || ((b(((b((6.0) <= (((f.fVar54) - (f.fVar69))))) != 0) || ((b(((b(((b((DAT_0012cc40) <= (f.fVar72))) != 0) || ((b((f.iVar14) < (0x3d))) != 0))) != 0) || ((b((DAT_0012cc40) <= (f.fVar45))) != 0))) != 0))) != 0))) != 0) 3051 else 2834
        }
        3053 -> {
            217
        }
        3054 -> {
            f.fVar76 = f32(3.5)
            3053
        }
        3055 -> {
            f.fVar57 = f32(0.8)
            3054
        }
        3056 -> {
            if ((b(((b(((b((f.dVar38) < (DAT_0012cca0))) != 0) && ((b(((b(((b(((b((0x48) < (f.iVar14))) != 0) || ((b((1.2) < (f.dVar39))) != 0))) != 0) && ((b((f.fVar78) < (3.5))) != 0))) != 0) && ((b(((b((8.0) < (f.fVar26))) != 0) && ((b((6.8) < (f.dVar32))) != 0))) != 0))) != 0))) != 0) && ((b(((b((0.3) < (f.fVar45))) != 0) || ((b((7.5) < (f.fVar79))) != 0))) != 0))) != 0) 3055 else 3052
        }
        3057 -> {
            293
        }
        3058 -> {
            f.fVar76 = f32(3.5)
            3057
        }
        3059 -> {
            f.fVar57 = f32(0.8)
            3058
        }
        3060 -> {
            f.fVar76 = f32(3.0)
            3057
        }
        3061 -> {
            f.fVar57 = f32(1.0)
            3060
        }
        3062 -> {
            if ((b(((b((2.9) <= (f.dVar42))) != 0) || ((b(((b(((b((2.5) <= (f.fVar55))) != 0) && ((b((2.5) <= (f.fVar41))) != 0))) != 0) && ((b((2.5) <= (f.fVar44))) != 0))) != 0))) != 0) 3059 else 3061
        }
        3063 -> {
            if ((b(((b(((b(((b((f.fVar36) < (2.5))) != 0) && ((b(((b(((b((6.8) < (f.dVar33))) != 0) || ((b((6.8) < (f.dVar32))) != 0))) != 0) && ((b((f.fVar41) < (3.5))) != 0))) != 0))) != 0) && ((b(((b((f.fVar55) < (3.5))) != 0) && ((b((f.dVar42) < (3.9))) != 0))) != 0))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0) 3062 else 3056
        }
        3064 -> {
            if ((b((f.fVar54) < (10.0))) != 0) 3063 else 2742
        }
        3065 -> {
            f.fVar57 = f32(1.0)
            293
        }
        3066 -> {
            f.fVar76 = f32(3.0)
            3065
        }
        3067 -> {
            292
        }
        3068 -> {
            if ((b(((b((0x36) < (f.iVar14))) != 0) && ((b((f.fVar52) < (6.5))) != 0))) != 0) 3067 else 291
        }
        3069 -> {
            f.fVar76 = f32(3.5)
            3065
        }
        3070 -> {
            291
        }
        3071 -> {
            if ((b((f.iVar14) < (0x37))) != 0) 3070 else 292
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep96(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3072 -> {
            if ((b((6.5) <= (f.fVar79))) != 0) 3068 else 3071
        }
        3073 -> {
            217
        }
        3074 -> {
            f.fVar76 = f32(4.7)
            3073
        }
        3075 -> {
            f.fVar57 = f32(0.4)
            3074
        }
        3076 -> {
            if ((b(((b(((b(((b((f.fVar82) < (1.2))) != 0) && ((b((f.fVar72) < (1.0))) != 0))) != 0) && ((b((((f.fVar54) - (f.fVar69))) < (6.0))) != 0))) != 0) && ((b((0x3c) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) 3075 else 3072
        }
        3077 -> {
            if ((b(((b((0x360) < (f.param_14))) != 0) || ((b((DAT_0012cca8) <= (f.dVar62))) != 0))) != 0) 3064 else 3076
        }
        3078 -> {
            if ((b((12.0) <= (f.fVar54))) != 0) 2393 else 3077
        }
        3079 -> {
            if ((b((84.0) <= (f.fVar27))) != 0) 1933 else 3078
        }
        3080 -> {
            f.dVar81 = f.fVar44
            3079
        }
        3081 -> {
            if ((b((f.fVar27) <= (0.0))) != 0) 1675 else 3080
        }
        3082 -> {
            f.dVar77 = f.fVar26
            3081
        }
        3083 -> {
            f.dVar75 = DAT_0012cc40
            3082
        }
        3084 -> {
            f.dVar63 = DAT_0012cde0
            3083
        }
        3085 -> {
            f.dVar34 = DAT_0012cdf8
            3084
        }
        3086 -> {
            f.fVar70 = f32(f32(adjustment_range(f.param_2, f.param_4, f.fVar55, f.fVar41, f.fVar44, f.fVar22, f.fVar67, f.fVar43, f.fVar35, f.fVar71, f.fVar25, f.fVar57, f.fVar60, f.param_14, f.param_13, f.fVar78, f.fVar69, f.fVar24, f.fVar54, f.fVar50, f.fVar26, f.fVar52, f.fVar79, f.fVar64, f.fVar58, f.iVar20, f.fVar40, f.fVar61, f.fVar23, f.fVar27)))
            316
        }
        3087 -> {
            f.fVar57 = f32(3.2)
            315
        }
        3088 -> {
            f.fVar60 = f32(1.2)
            3087
        }
        3089 -> {
            217
        }
        3090 -> {
            f.fVar57 = f32(1.0)
            3089
        }
        3091 -> {
            f.fVar57 = f32(1.2)
            3089
        }
        3092 -> {
            293
        }
        3093 -> {
            f.fVar76 = f32(f32(((f.dVar42) + (0.3))))
            3092
        }
        3094 -> {
            f.fVar57 = f32(1.0)
            3093
        }
        3095 -> {
            f.fVar76 = f32(3.5)
            3092
        }
        3096 -> {
            f.fVar57 = f32(1.2)
            3095
        }
        3097 -> {
            if ((b((3.0) <= (f.fVar78))) != 0) 3094 else 3096
        }
        3098 -> {
            if ((b(((b(((b((f.dVar48) <= (DAT_0012cff8))) != 0) || ((b((-(0.3)) <= (f.dVar49))) != 0))) != 0) || ((b((DAT_0012cff0) <= (f.fVar65))) != 0))) != 0) 3097 else 3091
        }
        3099 -> {
            if ((b(((b((f.fVar51) < (1.5))) != 0) || ((b(((b((f.dVar48) < (0.3))) != 0) && ((b((f.fVar65) < (DAT_0012cc78))) != 0))) != 0))) != 0) 3090 else 3098
        }
        3100 -> {
            if ((b((3.0) <= (f.fVar76))) != 0) 3099 else 3088
        }
        3101 -> {
            203
        }
        3102 -> {
            if ((b(((b(((b((0.35) <= (f.dVar48))) != 0) || ((b((f.fVar61) <= (7.5))) != 0))) != 0) || ((b((DAT_0012d050) <= (f.fVar61))) != 0))) != 0) 3101 else 3100
        }
        3103 -> {
            293
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep97(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3104 -> {
            f.fVar76 = f32(3.5)
            3103
        }
        3105 -> {
            f.fVar57 = f32(0.55)
            300
        }
        3106 -> {
            293
        }
        3107 -> {
            f.fVar76 = f32(3.2)
            3106
        }
        3108 -> {
            f.fVar57 = f32(0.55)
            3107
        }
        3109 -> {
            if ((b(((b((10.0) <= (f.fVar54))) != 0) || ((b((0.35) <= (f.fVar45))) != 0))) != 0) 3108 else 3105
        }
        3110 -> {
            217
        }
        3111 -> {
            f.fVar76 = f32(f.fVar78)
            3110
        }
        3112 -> {
            f.fVar57 = f32(0.55)
            3111
        }
        3113 -> {
            if ((b((3.0) < (f.fVar78))) != 0) 3112 else 3109
        }
        3114 -> {
            f.fVar57 = f32(1.0)
            3103
        }
        3115 -> {
            f.fVar76 = f32(f.fVar78)
            3114
        }
        3116 -> {
            300
        }
        3117 -> {
            f.fVar57 = f32(1.0)
            3116
        }
        3118 -> {
            if ((b(((b(((b((f.dVar42) <= (DAT_0012cde8))) != 0) || ((b((3.0) <= (f.fVar78))) != 0))) != 0) || ((b((f.fVar60) <= (1.5))) != 0))) != 0) 3117 else 303
        }
        3119 -> {
            309
        }
        3120 -> {
            306
        }
        3121 -> {
            if ((b(((b(((b(((b((f.dVar39) <= (1.2))) != 0) && ((b((f.fVar79) <= (8.5))) != 0))) != 0) || ((b(((b((0.0) <= (((f.fVar44) - (f.fVar41))))) != 0) && ((b(((b((f.fVar55) <= (DAT_0012ce18))) != 0) || ((b((kotlin.math.abs(((f.fVar55) - (f.fVar41)))) <= (0.5))) != 0))) != 0))) != 0))) != 0) && ((b(((b((3.5) <= (f.fVar78))) != 0) || ((b(((b(((b((f.fVar52) <= (8.0))) != 0) || ((b((f.fVar60) <= (1.5))) != 0))) != 0) || ((b((f.fVar79) <= (8.0))) != 0))) != 0))) != 0))) != 0) 3120 else 3119
        }
        3122 -> {
            if ((b(((b((DAT_0012cde0) <= (f.dVar75))) != 0) && ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((f.fVar50) <= (60.0))) != 0))) != 0))) != 0) 3121 else 3118
        }
        3123 -> {
            305
        }
        3124 -> {
            f.fVar76 = f32(2.8)
            3123
        }
        3125 -> {
            310
        }
        3126 -> {
            f.fVar76 = f32(3.0)
            3125
        }
        3127 -> {
            307
        }
        3128 -> {
            f.fVar57 = f32(1.0)
            3127
        }
        3129 -> {
            if ((b(((b(((b((3.3) <= (f.dVar42))) != 0) || ((b((f.fVar52) <= (8.0))) != 0))) != 0) || ((b(((b((f.dVar39) <= (DAT_0012cca8))) != 0) || ((b((f.fVar79) <= (8.0))) != 0))) != 0))) != 0) 3128 else 3126
        }
        3130 -> {
            210
        }
        3131 -> {
            f.fVar57 = f32(f.fVar78)
            3130
        }
        3132 -> {
            f.fVar60 = f32(1.0)
            3131
        }
        3133 -> {
            if ((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((f.iVar14) < (0x31))) != 0))) != 0) 3132 else 3129
        }
        3134 -> {
            if ((b((f.dVar42) < (3.9))) != 0) 3133 else 3124
        }
        3135 -> {
            if ((b(((b(((b(((b((f.fVar74) <= (0.0))) != 0) || ((b((f.fVar46) <= (0.0))) != 0))) != 0) || ((b((f.fVar47) <= (0.0))) != 0))) != 0) || ((b((1.0) <= (f.fVar51))) != 0))) != 0) 3134 else 3122
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep98(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3136 -> {
            304
        }
        3137 -> {
            if ((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b(((b((f.fVar46) < (0.5))) != 0) && ((b((f.fVar76) < (f.fVar78))) != 0))) != 0))) != 0) 3136 else 3135
        }
        3138 -> {
            303
        }
        3139 -> {
            if ((b(((b(((b(((b((f.dVar42) < (DAT_0012ce20))) != 0) && ((b((9.0) < (f.fVar52))) != 0))) != 0) && ((b((DAT_0012cc98) < (f.fVar45))) != 0))) != 0) && ((b((9.0) < (f.fVar79))) != 0))) != 0) 3138 else 3114
        }
        3140 -> {
            217
        }
        3141 -> {
            f.fVar76 = f32(f.fVar78)
            3140
        }
        3142 -> {
            f.fVar57 = f32(1.0)
            3141
        }
        3143 -> {
            if ((b(((b((3.0) < (f.fVar78))) != 0) && ((b(((b((DAT_0012ccb0) < (f.fVar45))) != 0) || ((b(((b((DAT_0012cca8) < (f.dVar39))) != 0) && ((b((0.35) < (f.fVar45))) != 0))) != 0))) != 0))) != 0) 3142 else 3139
        }
        3144 -> {
            217
        }
        3145 -> {
            f.fVar76 = f32(f.fVar78)
            3144
        }
        3146 -> {
            f.fVar57 = f32(0.85)
            3145
        }
        3147 -> {
            if ((b(((b((f.iVar15) == (1))) != 0) || ((b(((b((f.fVar74) < (0.5))) != 0) && ((b(((b((f.fVar47) < (0.5))) != 0) && ((b(((b((f.fVar46) < (0.5))) != 0) && ((b((f.fVar76) < (f.fVar78))) != 0))) != 0))) != 0))) != 0))) != 0) 304 else 3143
        }
        3148 -> {
            if ((b(((b(((b((DAT_0012ce38) <= (f.fVar46))) != 0) || ((b((DAT_0012ce38) <= (f.fVar74))) != 0))) != 0) || ((b((DAT_0012ce38) <= (f.fVar47))) != 0))) != 0) 3137 else 3147
        }
        3149 -> {
            217
        }
        3150 -> {
            f.fVar76 = f32(3.5)
            3149
        }
        3151 -> {
            f.fVar57 = f32(0.65)
            3150
        }
        3152 -> {
            301
        }
        3153 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012cd18))) != 0) || ((b(((b(((b((f.dVar33) <= (DAT_0012cd18))) != 0) || ((b((3.5) <= (f.fVar78))) != 0))) != 0) || ((b((f.iVar14) < (0x37))) != 0))) != 0))) != 0) || ((b(((b(((b((3.0) <= (f.fVar55))) != 0) && ((b((3.0) <= (f.fVar41))) != 0))) != 0) && ((b((3.0) <= (f.fVar44))) != 0))) != 0))) != 0) 3152 else 3151
        }
        3154 -> {
            302
        }
        3155 -> {
            if ((b(((b((3.8) < (f.dVar42))) != 0) && ((b((1.0) < (f.fVar60))) != 0))) != 0) 3154 else 3153
        }
        3156 -> {
            f.fVar57 = f32(0.55)
            3150
        }
        3157 -> {
            300
        }
        3158 -> {
            f.fVar57 = f32(0.85)
            3157
        }
        3159 -> {
            293
        }
        3160 -> {
            f.fVar76 = f32(3.9)
            3159
        }
        3161 -> {
            f.fVar57 = f32(0.55)
            3160
        }
        3162 -> {
            if ((b(((b(((b((f.dVar39) <= (DAT_0012cc80))) != 0) || ((b((3.9) <= (f.dVar42))) != 0))) != 0) || ((b((f.fVar57) <= (DAT_0012cca8))) != 0))) != 0) 3161 else 3158
        }
        3163 -> {
            if ((b(((b(((b((f.dVar42) <= (3.8))) != 0) || ((b((f.fVar60) <= (1.0))) != 0))) != 0) || ((b((f.fVar79) <= (7.5))) != 0))) != 0) 301 else 302
        }
        3164 -> {
            if ((b((DAT_0012cd18) < (f.dVar33))) != 0) 3155 else 3163
        }
        3165 -> {
            270
        }
        3166 -> {
            f.fVar60 = f32(0.85)
            3165
        }
        3167 -> {
            f.fVar57 = f32(3.5)
            3166
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep99(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3168 -> {
            if ((b(((b((60.0) < (f.fVar50))) != 0) && ((b((7.5) < (f.fVar79))) != 0))) != 0) 3167 else 3166
        }
        3169 -> {
            f.fVar57 = f32(f.fVar78)
            3168
        }
        3170 -> {
            if ((b(((b(((b((3.9) < (f.dVar42))) != 0) && ((b((f.fVar46) < (0.85))) != 0))) != 0) && ((b(((b((f.fVar47) < (0.85))) != 0) && ((b((f.fVar74) < (0.85))) != 0))) != 0))) != 0) 3169 else 3164
        }
        3171 -> {
            if ((b(((b(((b((3.9) < (f.dVar75))) != 0) && ((b((f.fVar78) < (4.5))) != 0))) != 0) && ((b((0.85) < (f.dVar39))) != 0))) != 0) 3170 else 3148
        }
        3172 -> {
            if ((b((1.5) < (f.fVar51))) != 0) 3113 else 3171
        }
        3173 -> {
            f.fVar76 = f32(3.2)
            3103
        }
        3174 -> {
            f.fVar57 = f32(0.65)
            3173
        }
        3175 -> {
            f.fVar76 = f32(3.0)
            3103
        }
        3176 -> {
            f.fVar57 = f32(0.85)
            3175
        }
        3177 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012ce68))) != 0) || ((b((f.fVar60) <= (2.5))) != 0))) != 0) || ((b((f.dVar33) <= (DAT_0012ce68))) != 0))) != 0) 3174 else 3176
        }
        3178 -> {
            217
        }
        3179 -> {
            f.fVar76 = f32(3.6)
            3178
        }
        3180 -> {
            f.fVar57 = f32(1.3)
            3179
        }
        3181 -> {
            if ((b(((b((DAT_0012d068) < (f.dVar49))) != 0) && ((b(((b((f.fVar54) < (10.5))) != 0) || ((b(((b((f.fVar23) < (5.0))) != 0) || ((b((f.dVar48) < (0.3))) != 0))) != 0))) != 0))) != 0) 3180 else 3177
        }
        3182 -> {
            if ((b((f.fVar65) < (DAT_0012cf60))) != 0) 3181 else 3177
        }
        3183 -> {
            217
        }
        3184 -> {
            f.fVar76 = f32(3.5)
            3183
        }
        3185 -> {
            f.fVar57 = f32(0.8)
            3184
        }
        3186 -> {
            if ((b(((b((f.fVar57) <= (1.0))) != 0) || ((b((DAT_0012cde0) <= (f.dVar42))) != 0))) != 0) 3185 else 3182
        }
        3187 -> {
            304
        }
        3188 -> {
            if ((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b(((b((3.5) < (f.fVar78))) != 0) && ((b((f.fVar46) < (0.5))) != 0))) != 0))) != 0) 3187 else 3186
        }
        3189 -> {
            if ((b(((b(((b(((b((5.3) <= (f.dVar38))) != 0) || ((b((f.fVar57) <= (0.85))) != 0))) != 0) || ((b(((b((0x55) < (f.iVar14))) != 0) || ((b(((b((f.fVar27) <= (66.0))) != 0) || ((b((4.0) <= (f.fVar69))) != 0))) != 0))) != 0))) != 0) || ((b((f.fVar26) <= (10.0))) != 0))) != 0) 3172 else 3188
        }
        3190 -> {
            f.fVar76 = f32(3.0)
            3103
        }
        3191 -> {
            f.fVar57 = f32(1.0)
            3190
        }
        3192 -> {
            303
        }
        3193 -> {
            if ((b(((b(((b((f.fVar50) <= (40.0))) != 0) || ((b((f.fVar27) <= (60.0))) != 0))) != 0) || ((b(((b((3.0) <= (f.fVar78))) != 0) || ((b((DAT_0012ccb0) <= (f.fVar45))) != 0))) != 0))) != 0) 3192 else 3191
        }
        3194 -> {
            217
        }
        3195 -> {
            f.fVar57 = f32(1.0)
            3194
        }
        3196 -> {
            f.fVar76 = f32(3.2)
            305
        }
        3197 -> {
            if ((b(((b((f.dVar38) < (3.9))) != 0) && ((b((9.0) < (f.fVar52))) != 0))) != 0) 3196 else 3193
        }
        3198 -> {
            if ((b(((b(((b(((b((4.5) <= (f.fVar23))) != 0) || ((b((f.fVar54) <= (10.0))) != 0))) != 0) || ((b((f.fVar52) <= (8.0))) != 0))) != 0) || ((b((f.fVar80) <= (1.0))) != 0))) != 0) 3189 else 3197
        }
        3199 -> {
            217
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep100(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3200 -> {
            f.fVar76 = f32(f.fVar78)
            3199
        }
        3201 -> {
            f.fVar57 = f32(1.0)
            3200
        }
        3202 -> {
            if ((b(((b(((b((8.0) < (f.fVar79))) != 0) && ((b(((b((3.9) < (f.dVar75))) != 0) && ((b((10.0) < (f.fVar54))) != 0))) != 0))) != 0) && ((b(((b((f.fVar78) < (3.5))) != 0) && ((b((0x3c) < (f.iVar14))) != 0))) != 0))) != 0) 299 else 3198
        }
        3203 -> {
            f.fVar57 = f32(1.0)
            3103
        }
        3204 -> {
            308
        }
        3205 -> {
            if ((b(((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b((f.fVar46) < (0.5))) != 0))) != 0) && ((b((f.fVar76) < (f.fVar78))) != 0))) != 0) 3204 else 306
        }
        3206 -> {
            299
        }
        3207 -> {
            if ((b(((b((f.dVar42) < (DAT_0012cca0))) != 0) && ((b((DAT_0012ce40) < (f.dVar39))) != 0))) != 0) 3206 else 3205
        }
        3208 -> {
            f.fVar76 = f32(3.5)
            3103
        }
        3209 -> {
            f.fVar57 = f32(0.85)
            307
        }
        3210 -> {
            f.fVar76 = f32(f.fVar78)
            3103
        }
        3211 -> {
            f.fVar57 = f32(0.85)
            3210
        }
        3212 -> {
            if ((b(((b(((b((0.5) <= (f.fVar74))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0) || ((b((0.5) <= (f.fVar47))) != 0))) != 0) 3209 else 308
        }
        3213 -> {
            if ((b((f.fVar51) < (1.0))) != 0) 3207 else 3212
        }
        3214 -> {
            if ((b(((b((0x2f) < (f.iVar14))) != 0) || ((b((f.dVar75) <= (3.9))) != 0))) != 0) 3202 else 3213
        }
        3215 -> {
            f.fVar76 = f32(f.fVar78)
            3103
        }
        3216 -> {
            f.fVar57 = f32(1.0)
            3215
        }
        3217 -> {
            f.fVar57 = f32(1.0)
            3103
        }
        3218 -> {
            f.fVar76 = f32(2.8)
            310
        }
        3219 -> {
            if ((b(((b((DAT_0012cde8) <= (f.dVar42))) != 0) || ((b((2.4) <= (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 309 else 3218
        }
        3220 -> {
            if ((b(((b(((b((f.fVar60) <= (2.0))) != 0) || ((b(((b(((b((3.5) <= (f.fVar78))) != 0) || ((b((f.fVar78) <= (2.5))) != 0))) != 0) || ((b((f.fVar45) <= (DAT_0012cdf0))) != 0))) != 0))) != 0) || ((b((f.fVar79) <= (7.5))) != 0))) != 0) 3214 else 3219
        }
        3221 -> {
            f.fVar76 = f32(3.5)
            3103
        }
        3222 -> {
            f.fVar57 = f32(1.0)
            312
        }
        3223 -> {
            f.fVar76 = f32(f.fVar78)
            3103
        }
        3224 -> {
            f.fVar57 = f32(1.0)
            3223
        }
        3225 -> {
            if ((b(((b(((b(((b((DAT_0012cde0) <= (f.dVar42))) != 0) || ((b((DAT_0012cca0) <= (f.dVar38))) != 0))) != 0) || ((b((10.0) <= (f.fVar54))) != 0))) != 0) || ((b(((b(((b((f.dVar39) <= (0.7))) != 0) || ((b((f.fVar79) <= (7.0))) != 0))) != 0) || ((b((60.0) <= (f.fVar27))) != 0))) != 0))) != 0) 3222 else 3224
        }
        3226 -> {
            217
        }
        3227 -> {
            f.fVar76 = f32(f.fVar78)
            3226
        }
        3228 -> {
            f.fVar57 = f32(0.85)
            3227
        }
        3229 -> {
            if ((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b(((b((3.5) < (f.fVar78))) != 0) && ((b((f.fVar46) < (0.5))) != 0))) != 0))) != 0) 311 else 3225
        }
        3230 -> {
            f.fVar57 = f32(0.85)
            3103
        }
        3231 -> {
            312
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep101(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3232 -> {
            f.fVar57 = f32(0.85)
            3231
        }
        3233 -> {
            if ((b((4.1) <= (f.dVar75))) != 0) 3232 else 3230
        }
        3234 -> {
            311
        }
        3235 -> {
            if ((b(((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b((f.fVar46) < (0.5))) != 0))) != 0) && ((b((f.fVar76) < (f.fVar78))) != 0))) != 0) 3234 else 3233
        }
        3236 -> {
            f.fVar57 = f32(1.0)
            3103
        }
        3237 -> {
            313
        }
        3238 -> {
            if ((b(((b(((b((f.fVar74) < (0.5))) != 0) && ((b((f.fVar47) < (0.5))) != 0))) != 0) && ((b(((b((f.fVar46) < (0.5))) != 0) && ((b(((b((1.5) < (f.fVar60))) != 0) || ((b((f.fVar76) < (f.fVar78))) != 0))) != 0))) != 0))) != 0) 3237 else 3236
        }
        3239 -> {
            if ((b(((b(((b((DAT_0012ce38) <= (f.fVar46))) != 0) || ((b((DAT_0012ce38) <= (f.fVar74))) != 0))) != 0) || ((b((DAT_0012ce38) <= (f.fVar47))) != 0))) != 0) 3235 else 3238
        }
        3240 -> {
            f.fVar76 = f32(3.5)
            3103
        }
        3241 -> {
            f.fVar57 = f32(1.0)
            3240
        }
        3242 -> {
            f.fVar76 = f32(f.fVar78)
            3103
        }
        3243 -> {
            f.fVar57 = f32(0.85)
            3242
        }
        3244 -> {
            if ((b(((b(((b((0.5) <= (f.fVar74))) != 0) || ((b((0.5) <= (f.fVar47))) != 0))) != 0) || ((b(((b((f.fVar78) <= (3.5))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0))) != 0) 3241 else 313
        }
        3245 -> {
            if ((b(((b(((b((DAT_0012ce48) <= (f.dVar42))) != 0) || ((b((f.dVar39) <= (1.2))) != 0))) != 0) || ((b((f.dVar75) <= (DAT_0012cca0))) != 0))) != 0) 3239 else 3244
        }
        3246 -> {
            if ((b(((b(((b((f.dVar49) <= (-(0.35)))) != 0) || ((b((8.0) <= (f.fVar52))) != 0))) != 0) || ((b((1.0) <= (f.fVar51))) != 0))) != 0) 3229 else 3245
        }
        3247 -> {
            if ((b(((b((f.dVar75) < (3.9))) != 0) || ((b((kotlin.math.abs(((f.fVar68) - (f.fVar66)))) < (DAT_0012cc80))) != 0))) != 0) 3220 else 3246
        }
        3248 -> {
            217
        }
        3249 -> {
            f.fVar57 = f32(1.2)
            3248
        }
        3250 -> {
            f.fVar76 = f32(f.fVar78)
            3248
        }
        3251 -> {
            f.fVar57 = f32(1.0)
            3250
        }
        3252 -> {
            298
        }
        3253 -> {
            if ((b(((b((f.fVar26) <= (8.0))) != 0) || ((b(((b(((b(((b((3.9) <= (f.fVar23))) != 0) || ((b((9.0) <= (f.fVar54))) != 0))) != 0) || ((b((f.fVar52) <= (6.0))) != 0))) != 0) || ((b(((b((f.dVar39) <= (0.85))) != 0) || ((b((f.iVar14) < (0x47))) != 0))) != 0))) != 0))) != 0) 3252 else 3251
        }
        3254 -> {
            f.fVar76 = f32(f.fVar78)
            3248
        }
        3255 -> {
            f.fVar57 = f32(1.2)
            3254
        }
        3256 -> {
            if ((b(((b((10.0) <= (f.fVar54))) != 0) || ((b(((b((f.fVar57) <= (1.0))) != 0) || ((b((f.fVar79) <= (7.0))) != 0))) != 0))) != 0) 3253 else 3255
        }
        3257 -> {
            if ((b(((b((f.fVar78) <= (3.0))) != 0) || ((b((f.fVar76) <= (f.fVar78))) != 0))) != 0) 298 else 3256
        }
        3258 -> {
            f.fVar76 = f32(f.fVar78)
            3248
        }
        3259 -> {
            f.fVar57 = f32(1.0)
            3258
        }
        3260 -> {
            if ((b(((b(((b(((b((0.5) <= (f.fVar74))) != 0) || ((b((0.5) <= (f.fVar47))) != 0))) != 0) || ((b((0.5) <= (f.fVar46))) != 0))) != 0) || ((b((f.fVar78) <= (f.fVar76))) != 0))) != 0) 3257 else 3259
        }
        3261 -> {
            297
        }
        3262 -> {
            if ((b(((b((0x47) < (f.iVar14))) != 0) || ((run { run { f.fVar36 = f32(4.3); f32(4.3) }; b((f.fVar79) <= (6.0)) }) != 0))) != 0) 3261 else 3260
        }
        3263 -> {
            f.fVar36 = f32(4.3)
            3262
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep102(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3264 -> {
            297
        }
        3265 -> {
            f.fVar36 = f32(4.3)
            3264
        }
        3266 -> {
            if ((b((f.fVar57) <= (0.6))) != 0) 3265 else 3263
        }
        3267 -> {
            295
        }
        3268 -> {
            if ((b(((b((4.1) < (f.dVar62))) != 0) && ((b(((b((f.dVar39) < (0.85))) != 0) && ((b((f.dVar33) < (DAT_0012cd18))) != 0))) != 0))) != 0) 3267 else 3266
        }
        3269 -> {
            297
        }
        3270 -> {
            f.fVar36 = f32(4.7)
            3269
        }
        3271 -> {
            if ((b(((b((4.5) < (f.fVar23))) != 0) && ((b((f.dVar38) < (DAT_0012cf18))) != 0))) != 0) 3270 else 3266
        }
        3272 -> {
            if ((b((f.dVar39) < (0.85))) != 0) 295 else 3266
        }
        3273 -> {
            if ((b(((b((6.6) <= (f.dVar33))) != 0) || ((b((6.6) <= (f.dVar32))) != 0))) != 0) 3268 else 3272
        }
        3274 -> {
            297
        }
        3275 -> {
            f.fVar36 = f32(4.2)
            3274
        }
        3276 -> {
            if ((b(((b(((b((9.0) < (f.fVar26))) != 0) && ((b((0.35) < (f.dVar39))) != 0))) != 0) && ((b(((b((DAT_0012cf28) < (f.dVar32))) != 0) && ((b(((b((4.5) < (f.fVar23))) != 0) && ((b((0.5) < (f.fVar57))) != 0))) != 0))) != 0))) != 0) 3275 else 3273
        }
        3277 -> {
            297
        }
        3278 -> {
            f.fVar36 = f32(3.5)
            3277
        }
        3279 -> {
            if ((b(((b(((b((f.fVar23) < (4.0))) != 0) && ((b((0.75) < (f.fVar60))) != 0))) != 0) && ((b(((b((0x3c) < (f.iVar14))) != 0) && ((b(((b(((b((84.0) < (f.fVar27))) != 0) && ((b((f.dVar42) < (DAT_0012cde0))) != 0))) != 0) && ((b((8.0) < (f.fVar26))) != 0))) != 0))) != 0))) != 0) 3278 else 3276
        }
        3280 -> {
            297
        }
        3281 -> {
            if ((b(((b(((b(((b(((b((f.dVar38) < (5.3))) != 0) && ((b((0.85) < (f.fVar57))) != 0))) != 0) && ((b((f.iVar14) < (0x4e))) != 0))) != 0) && ((b(((b((84.0) < (f.fVar27))) != 0) && ((b((f.fVar78) < (3.5))) != 0))) != 0))) != 0) && ((run { run { f.fVar36 = f32(3.5); f32(3.5) }; b((8.0) < (f.fVar26)) }) != 0))) != 0) 3280 else 3279
        }
        3282 -> {
            297
        }
        3283 -> {
            f.fVar36 = f32(3.9)
            3282
        }
        3284 -> {
            if ((b(((b(((b((f.dVar53) < (5.1))) != 0) && ((b((f.dVar38) < (4.55))) != 0))) != 0) && ((b(((b((9.0) < (f.fVar26))) != 0) && ((b(((b((DAT_0012cc40) < (f.fVar57))) != 0) && ((b((f.iVar14) < (0x48))) != 0))) != 0))) != 0))) != 0) 3283 else 3281
        }
        3285 -> {
            296
        }
        3286 -> {
            if ((b(((b(((b((f.dVar38) < (DAT_0012cca0))) != 0) && ((b((f.fVar78) < (3.5))) != 0))) != 0) && ((b((0.0) < (((f.fVar64) - (f.fVar29))))) != 0))) != 0) 3285 else 294
        }
        3287 -> {
            writeF32(f.param_1.plus(0x214), f32(f.fVar76))
            3260
        }
        3288 -> {
            f.fVar76 = f32(f.fVar36)
            3287
        }
        3289 -> {
            f.fVar36 = f32(3.5)
            297
        }
        3290 -> {
            if ((b(!((f.bVar8) != 0))) != 0) 3289 else 297
        }
        3291 -> {
            f.fVar36 = f32(4.2)
            3290
        }
        3292 -> {
            f.bVar8 = b((b((f.dVar33) < (DAT_0012cf28))) != 0)
            3291
        }
        3293 -> {
            if ((b(((b((DAT_0012cf28) <= (f.dVar32))) != 0) && ((run { run { f.bVar8 = b((0) != 0); b((0) != 0) }; b(((b(!((b((f.dVar33).isNaN())) != 0))) != 0) && ((b(!((b((DAT_0012cf28).isNaN())) != 0))) != 0)) }) != 0))) != 0) 3292 else 3291
        }
        3294 -> {
            f.bVar8 = b((1) != 0)
            3293
        }
        3295 -> {
            294
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep103(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3296 -> {
            if ((b((3.5) <= (f.fVar78))) != 0) 3295 else 296
        }
        3297 -> {
            if ((b((((f.fVar64) - (f.fVar29))) <= (DAT_0012cf80))) != 0) 3286 else 3296
        }
        3298 -> {
            if ((b(((b(((b(((b((f.dVar59) < (DAT_0012cca8))) != 0) && ((b((f.dVar39) < (1.2))) != 0))) != 0) || ((b(((b(((b((f.dVar59) < (2.3))) != 0) || ((b(((b((f.fVar23) < (4.5))) != 0) && ((b((f.fVar61) < (7.0))) != 0))) != 0))) != 0) && ((b((f.fVar45) < (DAT_0012ccb0))) != 0))) != 0))) != 0) && ((b((f.dVar42) < (DAT_0012ce48))) != 0))) != 0) 3297 else 3247
        }
        3299 -> {
            f.dVar59 = ((f.fVar61) - (f.fVar23))
            3298
        }
        3300 -> {
            314
        }
        3301 -> {
            if ((b(((b(((b(((b((2.5) <= (f.fVar66))) != 0) || ((b((DAT_0012ce10) <= (f.fVar68))) != 0))) != 0) && ((b(((b((9.0) <= (f.fVar54))) != 0) || ((b((DAT_0012ce60) <= (f.dVar75))) != 0))) != 0))) != 0) && ((b(((b(((b((f.iVar14) < (0x37))) != 0) || ((b((2.5) <= (f.fVar68))) != 0))) != 0) || ((b(((b((6.0) <= (f.fVar76))) != 0) || ((b((DAT_0012cde0) <= (f.fVar66))) != 0))) != 0))) != 0))) != 0) 3300 else 3299
        }
        3302 -> {
            f.fVar68 = f32(((f.fVar76) - (f.fVar55)))
            3301
        }
        3303 -> {
            f.fVar66 = f32(((f.fVar76) - (f.fVar41)))
            3302
        }
        3304 -> {
            if ((b((2.8) < (f.dVar75))) != 0) 3303 else 314
        }
        3305 -> {
            f.fVar51 = f32(((f.fVar76) - (f.fVar78)))
            3304
        }
        3306 -> {
            f.dVar75 = f.fVar76
            3305
        }
        3307 -> {
            writeF32(f.param_1.plus(0x214), f32(f.fVar76))
            3306
        }
        3308 -> {
            f.fVar76 = f32(((((f.fVar78) + (f.fVar69))) * (0.5)))
            3307
        }
        3309 -> {
            if ((b((f.fVar76) < (f.fVar69))) != 0) 3308 else 3306
        }
        3310 -> {
            f.fVar76 = f32(readF32(f.param_1.plus(0x214)))
            3309
        }
        3311 -> {
            if ((b((f.iVar20) < (2))) != 0) 203 else 3310
        }
        3312 -> {
            f.fVar29 = f32(kotlin.math.abs(f.fVar58))
            3311
        }
        3313 -> {
            f.fVar65 = f32(((f.fVar64) + (f.fVar58)))
            3312
        }
        3314 -> {
            f.fVar57 = f32(((f.fVar23) - (f.fVar78)))
            3313
        }
        3315 -> {
            f.fVar74 = f32(((f.fVar78) - (f.fVar44)))
            3314
        }
        3316 -> {
            f.fVar47 = f32(((f.fVar78) - (f.fVar41)))
            3315
        }
        3317 -> {
            f.fVar46 = f32(((f.fVar78) - (f.fVar55)))
            3316
        }
        3318 -> {
            f.dVar49 = f.fVar58
            3317
        }
        3319 -> {
            f.dVar38 = f.fVar23
            3318
        }
        3320 -> {
            if ((b((f.param_14) < (0x240))) != 0) 1590 else 3319
        }
        3321 -> {
            f.fVar80 = f32(((f.fVar52) - (f.fVar79)))
            3320
        }
        3322 -> {
            f.fVar82 = f32(((f.fVar71) - (f.fVar67)))
            3321
        }
        3323 -> {
            f.dVar83 = f.fVar67
            3322
        }
        3324 -> {
            f.fVar70 = f32(((f.fVar79) - (f.fVar52)))
            3323
        }
        3325 -> {
            f.dVar62 = f.fVar69
            3324
        }
        3326 -> {
            f.fVar73 = f32(kotlin.math.abs(((f.fVar79) - (f.fVar52))))
            3325
        }
        3327 -> {
            f.fVar56 = f32(kotlin.math.abs(((f.fVar71) - (f.fVar67))))
            3326
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep104(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3328 -> {
            f.dVar48 = f.fVar64
            3327
        }
        3329 -> {
            f.dVar59 = f.fVar41
            3328
        }
        3330 -> {
            f.fVar37 = f32(((f.fVar35) - (f.fVar22)))
            3329
        }
        3331 -> {
            f.pjVar1 = f.param_1.plus(0x16c)
            3330
        }
        3332 -> {
            f.fVar45 = f32(((f.fVar69) - (f.fVar78)))
            3331
        }
        3333 -> {
            f.iVar14 = (f.fVar50).toInt()
            3332
        }
        3334 -> {
            f.dVar33 = f.fVar52
            3333
        }
        3335 -> {
            f.dVar32 = f.fVar79
            3334
        }
        3336 -> {
            f.fVar72 = f32(((f.fVar24) - (f.fVar69)))
            3335
        }
        3337 -> {
            f.fVar58 = f32(readF32(f.param_1.plus(0x24c)))
            3336
        }
        3338 -> {
            f.fVar43 = f32(readF32(f.param_1.plus(0x160)))
            3337
        }
        3339 -> {
            f.fVar28 = f32(((f.fVar22) - (f.fVar55)))
            3338
        }
        3340 -> {
            f.dVar31 = f.fVar55
            3339
        }
        3341 -> {
            f.fVar44 = f32(readF32(f.param_1.plus(0x164)))
            3340
        }
        3342 -> {
            f.fVar61 = f32(readF32(f.param_1.plus(0x230)))
            3341
        }
        3343 -> {
            f.fVar64 = f32(readF32(f.param_1.plus(0x248)))
            3342
        }
        3344 -> {
            f.fVar27 = f32(readF32(f.param_1.plus(8)))
            3343
        }
        3345 -> {
            f.fVar41 = f32(readF32(f.param_1.plus(4)))
            3344
        }
        3346 -> {
            f.fVar71 = f32(readF32(f.param_1.plus(0x140)))
            3345
        }
        3347 -> {
            f.fVar67 = f32(readF32(f.param_1.plus(0x158)))
            3346
        }
        3348 -> {
            f.fVar50 = f32(readF32(f.param_1.plus(0x18c)))
            3347
        }
        3349 -> {
            f.fVar26 = f32(readF32(f.param_1.plus(0x22c)))
            3348
        }
        3350 -> {
            f.fVar52 = f32(readF32(f.param_1.plus(0x1d4)))
            3349
        }
        3351 -> {
            f.fVar79 = f32(readF32(f.param_1.plus(0x1d8)))
            3350
        }
        3352 -> {
            f.fVar69 = f32(readF32(f.param_1.plus(0x154)))
            3351
        }
        3353 -> {
            f.fVar25 = f32(readF32(f.param_1.plus(0x15c)))
            3352
        }
        3354 -> {
            f.fVar55 = f32(f.fVar22)
            108
        }
        3355 -> {
            writeI32(f.param_1.plus(0x270), 0)
            3354
        }
        3356 -> {
            f.fVar35 = f32(f.param_7)
            3355
        }
        3357 -> {
            writeF32(f.param_1.plus(0x138), f32(f.param_7))
            3356
        }
        3358 -> {
            if ((b((0x50) < (f.param_14))) != 0) 3357 else 3355
        }
        3359 -> {
            writeF32(f.param_1, f32(f.fVar22))
            3358
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep105(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3360 -> {
            writeF32(f.param_1.plus(0x134), f32(f.fVar22))
            3359
        }
        3361 -> {
            f.fVar22 = f32(f32(((f.dVar53) + (1.2))))
            3360
        }
        3362 -> {
            if ((b((f.fVar40) <= (3.0))) != 0) 3361 else 3360
        }
        3363 -> {
            f.fVar22 = f32(f.fVar40)
            3362
        }
        3364 -> {
            108
        }
        3365 -> {
            if ((b(((b((f.param_4) <= (2.5))) != 0) || ((b((readI32(f.param_1.plus(0x270))) < (6))) != 0))) != 0) 3364 else 3363
        }
        3366 -> {
            f.fVar22 = f32(((f.fVar40) + (1.0)))
            3360
        }
        3367 -> {
            if ((b((f.fVar40) <= (3.0))) != 0) 3366 else 3360
        }
        3368 -> {
            f.fVar22 = f32(f.fVar40)
            3367
        }
        3369 -> {
            if ((b(((b((f.param_4) <= (3.5))) != 0) || ((b((readI32(f.param_1.plus(0x270))) < (2))) != 0))) != 0) 3365 else 3368
        }
        3370 -> {
            if ((b(((b(!((b(((f.bVar7).xor(1)) != 0)) != 0))) != 0) && ((b((f.fVar36) < (1.5))) != 0))) != 0) 3369 else 108
        }
        3371 -> {
            f.dVar53 = f.fVar40
            3370
        }
        3372 -> {
            f.fVar36 = f32(readF32(f.param_1.plus(0x178)))
            3371
        }
        3373 -> {
            f.fVar35 = f32(f.fVar23)
            3372
        }
        3374 -> {
            f.fVar55 = f32(f.fVar23)
            3373
        }
        3375 -> {
            f.fVar22 = f32(f.fVar23)
            3374
        }
        3376 -> {
            writeF32(f.param_1.plus(0x138), f32(f.fVar23))
            3375
        }
        3377 -> {
            writeF32(f.param_1.plus(0x134), f32(f.fVar23))
            3376
        }
        3378 -> {
            writeF32(f.param_1, f32(f.fVar23))
            3377
        }
        3379 -> {
            if ((b(((b(((b(uLt((((readI32(f.param_1.plus(0x148))).inv()) + (f.param_14)), 0x2f))) != 0) && ((b(((b(!((b(((f.bVar7).xor(1)) != 0)) != 0))) != 0) && ((b((0x12) < (readI32(f.param_1.plus(0x270))))) != 0))) != 0))) != 0) && ((b((4.5) < (((f.fVar57) - (readF32(f.param_1.plus(0x178))))))) != 0))) != 0) 3378 else 3372
        }
        3380 -> {
            writeF32(f.param_1.plus(0x22c), f32(f32(((f.dVar38) + (0.6)))))
            3379
        }
        3381 -> {
            if ((b(((b((0x1d) < (f.param_14))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (((f.dVar38) + (0.6))))) != 0))) != 0) 3380 else 3379
        }
        3382 -> {
            writeI32(f.pjVar1, 0)
            3381
        }
        3383 -> {
            f.iVar20 = 0
            3382
        }
        3384 -> {
            if ((b(((b(((b((f.iVar21) == (0))) != 0) && ((b((((f.fVar23) + (((((readF32(f.param_1.plus(0x230))) - (f.fVar40))) - (f.fVar40))))) < (0.0))) != 0))) != 0) && ((b((11.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) 3383 else 3381
        }
        3385 -> {
            if ((b((f.iVar20) == (1))) != 0) 105 else 3381
        }
        3386 -> {
            106
        }
        3387 -> {
            if ((b((f.iVar20) == (2))) != 0) 3386 else 104
        }
        3388 -> {
            f.iVar20 = 2
            3381
        }
        3389 -> {
            107
        }
        3390 -> {
            if ((b(((b((1.5) < (f.fVar60))) != 0) && ((b((DAT_0012cde0) < (f.dVar42))) != 0))) != 0) 3389 else 3381
        }
        3391 -> {
            f.iVar20 = 2
            3390
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep106(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3392 -> {
            if ((b((readF32(f.param_1.plus(0x22c))) <= (11.0))) != 0) 3388 else 3391
        }
        3393 -> {
            f.iVar20 = 2
            3381
        }
        3394 -> {
            if ((b((f.iVar21) == (0))) != 0) 3392 else 3393
        }
        3395 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            3381
        }
        3396 -> {
            f.iVar20 = 1
            3395
        }
        3397 -> {
            if ((b((f.iVar19) == (0))) != 0) 3396 else 3381
        }
        3398 -> {
            writeI32(f.pjVar1, 1)
            3397
        }
        3399 -> {
            f.iVar20 = 1
            3398
        }
        3400 -> {
            if ((b(((b((0.3) <= (f.fVar36))) != 0) || ((b((readF32(f.param_1.plus(0x22c))) <= (11.0))) != 0))) != 0) 3394 else 107
        }
        3401 -> {
            104
        }
        3402 -> {
            writeI32(f.pjVar1, 1)
            3401
        }
        3403 -> {
            f.iVar20 = 1
            3402
        }
        3404 -> {
            if ((b(((b(((b((f.fVar36) < (0.5))) != 0) && ((b((10.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) && ((b((f.iVar15) == (1))) != 0))) != 0) 3403 else 3400
        }
        3405 -> {
            105
        }
        3406 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88)))))
            3405
        }
        3407 -> {
            f.iVar20 = 1
            3406
        }
        3408 -> {
            104
        }
        3409 -> {
            if ((b((f.iVar15) != (0))) != 0) 3408 else 3407
        }
        3410 -> {
            writeI32(f.pjVar1, 1)
            3409
        }
        3411 -> {
            f.iVar20 = 1
            3410
        }
        3412 -> {
            if ((b(((b(((b(((b((f.fVar36) < (0.3))) != 0) && ((b((11.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) && ((b((DAT_0012ce48) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) || ((b(((b(((b((f.iVar21) == (0))) != 0) && ((b((11.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) && ((b(((b((1.5) < (f.fVar60))) != 0) && ((b(((b((DAT_0012cde0) < (f.dVar42))) != 0) && ((b((DAT_0012cca0) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0))) != 0))) != 0) 3411 else 3404
        }
        3413 -> {
            f.fVar36 = f32(((f.fVar23) + (((((readF32(f.param_1.plus(0x230))) - (f.fVar40))) - (f.fVar40)))))
            3412
        }
        3414 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88)))))
            106
        }
        3415 -> {
            if ((b((f.iVar15) == (0))) != 0) 3414 else 106
        }
        3416 -> {
            writeI32(f.pjVar1, 2)
            3415
        }
        3417 -> {
            if ((b(((b(((b((f.param_14) < (0x5a1))) != 0) || ((b((1.5) <= (f.fVar55))) != 0))) != 0) || ((b((1.5) <= (readF32(f.param_1.plus(4))))) != 0))) != 0) 3387 else 3416
        }
        3418 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (f.dVar53)))))
            3417
        }
        3419 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3418
        }
        3420 -> {
            f.iVar20 = 2
            3419
        }
        3421 -> {
            if ((b(((b(((b(((b((13.0) < (f.fVar54))) != 0) && ((b((8.5) < (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) && ((b(((b((8.5) < (readF32(f.param_1.plus(0x1d4))))) != 0) && ((b(((b(((b(((b((f.fVar23) < (DAT_0012cf90))) != 0) && ((b((f.fVar78) < (3.0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (48.0))) != 0))) != 0) && ((b(((b((f.iVar15) == (0))) != 0) && ((b((readF32(f.param_1.plus(0x230))) < (10.5))) != 0))) != 0))) != 0))) != 0))) != 0) && ((b(((b((48.0) < (readF32(f.param_1.plus(8))))) != 0) && ((b((readF32(f.param_1.plus(0x274))) < (2.5))) != 0))) != 0))) != 0) 3420 else 3417
        }
        3422 -> {
            f.dVar53 = DAT_0012ce88
            3421
        }
        3423 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88)))))
            3422
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep107(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3424 -> {
            f.iVar20 = 2
            3423
        }
        3425 -> {
            if ((b((f.iVar15) == (0))) != 0) 3424 else 3422
        }
        3426 -> {
            writeI32(f.pjVar1, 2)
            3425
        }
        3427 -> {
            f.iVar20 = 2
            3426
        }
        3428 -> {
            if ((b(((b(((b((11.0) < (f.fVar54))) != 0) && ((b((8.0) < (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) && ((b(((b(((b((8.0) < (readF32(f.param_1.plus(0x1d4))))) != 0) && ((b(((b(((b((f.fVar23) < (5.0))) != 0) && ((b((f.dVar42) < (DAT_0012ce10))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (48.0))) != 0))) != 0))) != 0) && ((b(((b(((b((f.fVar55) < (DAT_0012ce18))) != 0) && ((b((readF32(f.param_1.plus(4))) < (DAT_0012ce18))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x164))) < (DAT_0012ce18))) != 0))) != 0))) != 0))) != 0) 3427 else 3422
        }
        3429 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x150)))
            3428
        }
        3430 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (f.dVar53)))))
            3429
        }
        3431 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3430
        }
        3432 -> {
            f.iVar20 = 2
            3431
        }
        3433 -> {
            if ((b(((b(((b(((b((f.fVar54) < (1.2))) != 0) && ((b((f.fVar23) < (5.0))) != 0))) != 0) && ((b((((readF32(f.param_1.plus(0x230))) - (f.fVar23))) < (2.5))) != 0))) != 0) && ((b(((b(((b((readF32(f.param_1.plus(0x274))) < (2.0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (60.0))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(0x1d8))) < (6.5))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0))) != 0))) != 0) 3432 else 3429
        }
        3434 -> {
            f.dVar53 = DAT_0012ce88
            3433
        }
        3435 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (f.dVar53)))))
            3434
        }
        3436 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3435
        }
        3437 -> {
            f.iVar20 = 2
            3436
        }
        3438 -> {
            writeI32(f.pjVar1, 1)
            3434
        }
        3439 -> {
            f.iVar20 = 1
            3438
        }
        3440 -> {
            if ((b(((b((42.0) <= (readF32(f.param_1.plus(8))))) != 0) || ((b(((b((54.0) <= (readF32(f.param_1.plus(0x18c))))) != 0) && ((b((f.dVar42) <= (3.9))) != 0))) != 0))) != 0) 3437 else 3439
        }
        3441 -> {
            if ((b(((b(((b(((b(((b((f.fVar54) < (1.0))) != 0) && ((b((5.0) < (f.fVar23))) != 0))) != 0) && ((b((((readF32(f.param_1.plus(0x230))) - (f.fVar23))) < (DAT_0012ce18))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(0x274))) < (4.0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (66.0))) != 0))) != 0))) != 0) && ((b(((b((f.iVar15) == (0))) != 0) && ((b((10.0) < (readF32(f.param_1.plus(0x150))))) != 0))) != 0))) != 0) 3440 else 3434
        }
        3442 -> {
            f.dVar53 = DAT_0012ce88
            3441
        }
        3443 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88)))))
            3442
        }
        3444 -> {
            f.iVar20 = 2
            3443
        }
        3445 -> {
            if ((b(((b((readF32(f.param_1.plus(0x18c))) <= (48.0))) != 0) || ((b((f.dVar39) <= (1.2))) != 0))) != 0) 3444 else 3442
        }
        3446 -> {
            writeI32(f.pjVar1, 2)
            3445
        }
        3447 -> {
            f.iVar20 = 2
            3446
        }
        3448 -> {
            if ((b(((b(((b(((b(((b((5.5) < (f.fVar23))) != 0) && ((b((f.fVar54) < (1.5))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x274))) < (DAT_0012cde0))) != 0))) != 0) && ((b(((b((54.0) < (readF32(f.param_1.plus(0x18c))))) != 0) && ((b((10.0) < (readF32(f.param_1.plus(0x150))))) != 0))) != 0))) != 0) && ((b(((b((((f.fVar54) + (1.0))) < (((readF32(f.param_1.plus(0x230))) - (f.fVar40))))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) < (DAT_0012cd18))) != 0))) != 0))) != 0) 3447 else 3442
        }
        3449 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (f.dVar53)))))
            3448
        }
        3450 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3449
        }
        3451 -> {
            f.iVar20 = 2
            3450
        }
        3452 -> {
            if ((b(((b(((b(((b(((b((f.fVar54) < (1.0))) != 0) && ((b((readF32(f.param_1.plus(0x274))) < (DAT_0012ce18))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(8))) < (48.0))) != 0) && ((b(((b((60.0) < (readF32(f.param_1.plus(0x18c))))) != 0) && ((b((5.3) < (f.fVar23))) != 0))) != 0))) != 0))) != 0) && ((b((f.fVar78) < (3.0))) != 0))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0) 3451 else 3448
        }
        3453 -> {
            f.dVar53 = DAT_0012ce88
            3452
        }
        3454 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88)))))
            3453
        }
        3455 -> {
            f.iVar20 = 2
            3454
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep108(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3456 -> {
            if ((b((f.iVar15) == (0))) != 0) 3455 else 3453
        }
        3457 -> {
            writeI32(f.pjVar1, 2)
            3456
        }
        3458 -> {
            f.iVar20 = 2
            3457
        }
        3459 -> {
            if ((b(((b(((b((f.fVar54) < (2.0))) != 0) && ((b((5.5) < (f.fVar23))) != 0))) != 0) && ((b(((b(((b((((f.fVar54) + (1.0))) < (((readF32(f.param_1.plus(0x230))) - (f.fVar40))))) != 0) && ((b(((b(((b((readF32(f.param_1.plus(0x274))) < (3.3))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (54.0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x1d8))) < (9.0))) != 0))) != 0))) != 0) && ((b((f.dVar39) <= (DAT_0012ce40))) != 0))) != 0))) != 0) 3458 else 3453
        }
        3460 -> {
            f.fVar54 = f32(((f.fVar40) - (f.fVar23)))
            3459
        }
        3461 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x234)))
            3460
        }
        3462 -> {
            writeI32(f.pjVar1, f.iVar20)
            103
        }
        3463 -> {
            f.iVar20 = 2
            98
        }
        3464 -> {
            86
        }
        3465 -> {
            if ((b(((b((9.0) <= (f.fVar37))) != 0) || ((b((9.0) <= (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) 3464 else 97
        }
        3466 -> {
            100
        }
        3467 -> {
            writeI32(f.pjVar1, 1)
            3466
        }
        3468 -> {
            if ((b(((b(((b((0.3) <= (f.dVar33))) != 0) || ((b((f.dVar32) <= (DAT_0012cf00))) != 0))) != 0) || ((b((DAT_0012cf60) <= (f.fVar67))) != 0))) != 0) 3467 else 3465
        }
        3469 -> {
            100
        }
        3470 -> {
            writeI32(f.pjVar1, 1)
            3469
        }
        3471 -> {
            writeI32(f.pjVar1, 1)
            3469
        }
        3472 -> {
            99
        }
        3473 -> {
            102
        }
        3474 -> {
            if ((b(((b(((b((f.dVar32) <= (0.3))) != 0) || ((b((DAT_0012cfe8) <= (f.fVar67))) != 0))) != 0) && ((b((f.dVar59) <= (DAT_0012cf90))) != 0))) != 0) 3473 else 3472
        }
        3475 -> {
            93
        }
        3476 -> {
            if ((b(((b((DAT_0012cfe0) < (f.dVar33))) != 0) && ((b((f.dVar32) < (DAT_0012cfd8))) != 0))) != 0) 3475 else 3474
        }
        3477 -> {
            if ((b((((readF32(f.param_1.plus(0x1d8))) - (f.fVar25))) <= (1.2))) != 0) 3476 else 3471
        }
        3478 -> {
            if ((b((f.iVar15) == (1))) != 0) 3470 else 3477
        }
        3479 -> {
            if ((b(((b(((b(((b((0x240) < (f.iVar2))) != 0) && ((b((f.fVar37) < (8.0))) != 0))) != 0) && ((b((0x240) < (f.param_14))) != 0))) != 0) && ((b((2.0) < (f.fVar41))) != 0))) != 0) 3478 else 3468
        }
        3480 -> {
            100
        }
        3481 -> {
            writeI32(f.pjVar1, 1)
            3480
        }
        3482 -> {
            87
        }
        3483 -> {
            if ((b(((b((f.dVar33) < (DAT_0012cfc8))) != 0) && ((b((DAT_0012cf70) < (f.dVar32))) != 0))) != 0) 3482 else 96
        }
        3484 -> {
            96
        }
        3485 -> {
            if ((b((f.iVar15) == (1))) != 0) 3484 else 94
        }
        3486 -> {
            100
        }
        3487 -> {
            f.iVar14 = readI32(f.param_1.plus(0x228))
            3486
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep109(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3488 -> {
            103
        }
        3489 -> {
            if ((b((f.iVar20) != (1))) != 0) 3488 else 3487
        }
        3490 -> {
            99
        }
        3491 -> {
            if ((b(((b(((b((0x240) < (f.param_14))) != 0) && ((b((f.fVar37) < (5.5))) != 0))) != 0) && ((b(((b((10.0) < (f.fVar69))) != 0) && ((b(((b((f.dVar48) < (DAT_0012cc88))) != 0) && ((b((84.0) < (readF32(f.param_1.plus(8))))) != 0))) != 0))) != 0))) != 0) 3490 else 93
        }
        3492 -> {
            102
        }
        3493 -> {
            if ((b(((b(((b(((b((f.dVar33) < (DAT_0012cf50))) != 0) && ((b((DAT_0012cfc0) < (f.dVar32))) != 0))) != 0) && ((b((f.fVar67) < (DAT_0012cc78))) != 0))) != 0) && ((b((f.fVar37) < (6.0))) != 0))) != 0) 3492 else 93
        }
        3494 -> {
            99
        }
        3495 -> {
            if ((b(((b((f.dVar33) < (DAT_0012cf50))) != 0) && ((b((DAT_0012cf48) < (f.dVar32))) != 0))) != 0) 3494 else 3493
        }
        3496 -> {
            if ((b(((b(((b((4.1) <= (f.dVar59))) != 0) || ((b(((b((DAT_0012ce20) <= (f.dVar42))) != 0) || ((b((f.fVar27) <= (DAT_0012ce38))) != 0))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(0x18c))) <= (66.0))) != 0) || ((b(((b((DAT_0012cca0) <= (f.dVar42))) != 0) || ((b(((b((f.fVar25) <= (7.0))) != 0) && ((b((f.fVar26) <= (DAT_0012cdf0))) != 0))) != 0))) != 0))) != 0))) != 0) 3495 else 93
        }
        3497 -> {
            if ((b(((b(((b((5.0) <= (f.fVar37))) != 0) || ((b((f.param_14) < (0x241))) != 0))) != 0) || ((b((f.fVar69) <= (7.0))) != 0))) != 0) 3491 else 3496
        }
        3498 -> {
            94
        }
        3499 -> {
            96
        }
        3500 -> {
            if ((b((0) < (f.iVar15))) != 0) 3499 else 3498
        }
        3501 -> {
            100
        }
        3502 -> {
            writeI32(f.pjVar1, 1)
            3501
        }
        3503 -> {
            if ((b(((b(((b((84.0) < (f.fVar54))) != 0) && ((b(((b((DAT_0012ce88) < (f.fVar27))) != 0) || ((b((DAT_0012cc40) < (((f.fVar25) - (readF32(f.param_1.plus(0x1d8))))))) != 0))) != 0))) != 0) && ((b((f.dVar42) < (3.9))) != 0))) != 0) 3502 else 3500
        }
        3504 -> {
            if ((b(((b(((b(((b((108.0) < (f.fVar54))) != 0) || ((b(((b((72.0) < (f.fVar54))) != 0) && ((b(((f.bVar8) != 0) || ((b((readF32(f.param_1.plus(0x1d8))) < (7.0))) != 0))) != 0))) != 0))) != 0) && ((b((7.5) < (f.fVar69))) != 0))) != 0) && ((b(((b(((b(((b((f.fVar69) < (10.0))) != 0) && ((b((4.5) < (f.fVar37))) != 0))) != 0) && ((b((f.dVar59) < (DAT_0012cf18))) != 0))) != 0) && ((b(((b((f.fVar60) < (2.0))) != 0) && ((b((f.fVar27) < (1.5))) != 0))) != 0))) != 0))) != 0) 3503 else 3497
        }
        3505 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(8)))
            3504
        }
        3506 -> {
            if ((b((0x240) < (f.param_14))) != 0) 3505 else 93
        }
        3507 -> {
            90
        }
        3508 -> {
            if ((b(((b((0.3) < (f.dVar62))) != 0) && ((b(((b(((b((0) < (f.iVar14))) != 0) && ((b((f.fVar37) < (4.5))) != 0))) != 0) && ((b((7.0) < (f.fVar69))) != 0))) != 0))) != 0) 3507 else 91
        }
        3509 -> {
            93
        }
        3510 -> {
            92
        }
        3511 -> {
            if ((b((f.dVar33) < (DAT_0012cfc8))) != 0) 3510 else 3509
        }
        3512 -> {
            99
        }
        3513 -> {
            102
        }
        3514 -> {
            if ((b(((b(((b((f.dVar33) <= (DAT_0012cfc8))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0) || ((b(((b((DAT_0012cf70) <= (f.dVar32))) != 0) && ((b((f.fVar37) < (6.0))) != 0))) != 0))) != 0) 3513 else 3512
        }
        3515 -> {
            if ((b((54.0) < (readF32(f.param_1.plus(0x18c))))) != 0) 3514 else 3511
        }
        3516 -> {
            if ((b((4.3) <= (f.dVar59))) != 0) 3515 else 3509
        }
        3517 -> {
            if ((b(((b((0) < (f.iVar14))) != 0) && ((b((0.3) < (f.dVar62))) != 0))) != 0) 90 else 91
        }
        3518 -> {
            if ((b(((b((5.1) <= (f.dVar59))) != 0) || ((b((f.fVar69) <= (6.5))) != 0))) != 0) 3508 else 3517
        }
        3519 -> {
            f.bVar8 = b((1) != 0)
            89
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep110(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3520 -> {
            88
        }
        3521 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3520
        }
        3522 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.fVar54) * (f.dVar53)))))
            3521
        }
        3523 -> {
            f.dVar53 = DAT_0012ce88
            3522
        }
        3524 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x20c)))
            3523
        }
        3525 -> {
            87
        }
        3526 -> {
            if ((b(((b(((b((3.5) <= (f.fVar37))) != 0) || ((b((6.0) <= (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) || ((b((8.0) <= (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) 3525 else 3524
        }
        3527 -> {
            f.dVar53 = 0.95
            3522
        }
        3528 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x20c)))
            3527
        }
        3529 -> {
            if ((b(((b((5.0) <= (f.fVar37))) != 0) || ((b((readF32(f.param_1.plus(0x22c))) <= (10.0))) != 0))) != 0) 3526 else 3528
        }
        3530 -> {
            96
        }
        3531 -> {
            if ((b(((b(((b(((b((DAT_0012cfd0) < (f.dVar53))) != 0) && ((b((8.0) < (f.fVar40))) != 0))) != 0) && ((b((f.dVar62) < (DAT_0012cc40))) != 0))) != 0) || ((b(((b((f.dVar32) < (-(0.35)))) != 0) || ((b((6.0) < (f.fVar37))) != 0))) != 0))) != 0) 3530 else 3529
        }
        3532 -> {
            99
        }
        3533 -> {
            if ((b((f.iVar15) == (1))) != 0) 3532 else 3531
        }
        3534 -> {
            89
        }
        3535 -> {
            if ((b(((b((f.dVar62) <= (0.3))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (48.0))) != 0))) != 0) 3534 else 3533
        }
        3536 -> {
            f.bVar8 = b((1) != 0)
            3535
        }
        3537 -> {
            if ((b((DAT_0012cca8) < (f.fVar41))) != 0) 3536 else 3519
        }
        3538 -> {
            99
        }
        3539 -> {
            if ((b((DAT_0012cf70) < (f.dVar32))) != 0) 3538 else 93
        }
        3540 -> {
            93
        }
        3541 -> {
            if ((b((DAT_0012cfc8) <= (f.dVar33))) != 0) 3540 else 92
        }
        3542 -> {
            if ((b(((b(((b((f.dVar62) <= (0.3))) != 0) || ((b((f.dVar42) <= (DAT_0012ce00))) != 0))) != 0) || ((b(((b((f.fVar28) <= (0.3))) != 0) || ((b((((readF32(f.param_1.plus(0x164))) - (f.fVar71))) <= (0.3))) != 0))) != 0))) != 0) 3537 else 3541
        }
        3543 -> {
            if ((b(((b(((b(((b((3.5) <= (f.fVar78))) != 0) || ((b((f.dVar62) <= (DAT_0012cdc8))) != 0))) != 0) || ((b(((b((8.0) <= (f.fVar25))) != 0) || ((b(((b(((b((readF32(f.param_1.plus(0x18c))) <= (60.0))) != 0) || ((b((5.0) <= (f.fVar37))) != 0))) != 0) || ((b((f.fVar36) <= (DAT_0012cde0))) != 0))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x21c))) <= (f.fVar54))) != 0))) != 0) 3542 else 3485
        }
        3544 -> {
            95
        }
        3545 -> {
            if ((b(((b((DAT_0012cfd8) < (f.dVar32))) != 0) && ((b((f.fVar67) < (DAT_0012cc78))) != 0))) != 0) 3544 else 96
        }
        3546 -> {
            87
        }
        3547 -> {
            if ((b((f.fVar37) < (6.0))) != 0) 3546 else 96
        }
        3548 -> {
            if ((b((DAT_0012cfd8) < (f.dVar32))) != 0) 95 else 96
        }
        3549 -> {
            if ((b((f.dVar32) <= (-(0.3)))) != 0) 3545 else 3548
        }
        3550 -> {
            if ((b(((b((f.dVar33) < (0.3))) != 0) && ((b((f.dVar48) < (DAT_0012cfa8))) != 0))) != 0) 3549 else 96
        }
        3551 -> {
            87
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep111(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3552 -> {
            if ((b((f.dVar39) <= (DAT_0012cdf0))) != 0) 3551 else 96
        }
        3553 -> {
            if ((b(((b((f.dVar32) < (-(0.3)))) != 0) || ((b(((b((0.3) < (f.dVar33))) != 0) || ((b((f.iVar15) == (1))) != 0))) != 0))) != 0) 3550 else 3552
        }
        3554 -> {
            if ((b(((b(((b(((b(((b((f.fVar28) <= (0.0))) != 0) || ((b((f.dVar62) <= (DAT_0012cc98))) != 0))) != 0) || ((b((8.0) <= (f.fVar25))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x18c))) <= (54.0))) != 0) || ((b((f.fVar36) <= (DAT_0012cde0))) != 0))) != 0))) != 0) || ((b((((readF32(f.param_1.plus(0x164))) - (f.fVar71))) <= (DAT_0012cdc8))) != 0))) != 0) 3543 else 3553
        }
        3555 -> {
            89
        }
        3556 -> {
            f.bVar8 = b((0) != 0)
            3555
        }
        3557 -> {
            if ((b((f.iVar14) < (1))) != 0) 3556 else 3554
        }
        3558 -> {
            103
        }
        3559 -> {
            f.iVar20 = 2
            3558
        }
        3560 -> {
            writeI32(f.pjVar1, 2)
            88
        }
        3561 -> {
            96
        }
        3562 -> {
            if ((b(((b((6.0) < (f.fVar37))) != 0) || ((b((f.iVar15) == (1))) != 0))) != 0) 3561 else 87
        }
        3563 -> {
            if ((b(((b(((b(((b((0.15) < (f.fVar28))) != 0) && ((b((f.dVar31) < (8.1))) != 0))) != 0) && ((b((0.15) < (((f.fVar78) - (readF32(f.param_1.plus(0x164))))))) != 0))) != 0) && ((b(((b(((b(((b((DAT_0012cde0) < (f.dVar42))) != 0) && ((b((readF32(f.param_1.plus(0x1d8))) < (8.5))) != 0))) != 0) && ((b(((b((0.15) < (((readF32(f.param_1.plus(0x164))) - (f.fVar71))))) != 0) && ((b(((b((0.3) < (f.dVar62))) != 0) && ((b((0) < (f.iVar14))) != 0))) != 0))) != 0))) != 0) && ((b((48.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0))) != 0) 3562 else 3557
        }
        3564 -> {
            f.fVar28 = f32(((f.fVar78) - (f.fVar71)))
            3563
        }
        3565 -> {
            91
        }
        3566 -> {
            f.bVar8 = b((0) != 0)
            3565
        }
        3567 -> {
            if ((b((f.iVar2) < (0x241))) != 0) 3566 else 3564
        }
        3568 -> {
            if ((b(((b(((b((f.iVar2) < (0x241))) != 0) || ((b((f.dVar62) <= (DAT_0012cc40))) != 0))) != 0) && ((b(((b((f.param_14) < (0x241))) != 0) || ((b((-(2.0)) <= (f.fVar41))) != 0))) != 0))) != 0) 3567 else 3479
        }
        3569 -> {
            99
        }
        3570 -> {
            93
        }
        3571 -> {
            if ((b((f.dVar32) < (-(0.35)))) != 0) 3570 else 3569
        }
        3572 -> {
            100
        }
        3573 -> {
            writeI32(f.pjVar1, 1)
            3572
        }
        3574 -> {
            97
        }
        3575 -> {
            if ((b((DAT_0012cfc0) <= (f.dVar32))) != 0) 3574 else 86
        }
        3576 -> {
            if ((b((((readF32(f.param_1.plus(0x1d8))) - (f.fVar25))) <= (DAT_0012cc40))) != 0) 3575 else 3569
        }
        3577 -> {
            if ((b(((b(((b((DAT_0012cf68) <= (f.fVar67))) != 0) && ((b(((b((0.3) <= (f.dVar33))) != 0) && ((b(((b((5.5) <= (f.fVar37))) != 0) || ((b((f.fVar69) <= (9.2))) != 0))) != 0))) != 0))) != 0) || ((b((f.dVar32) <= (-(0.35)))) != 0))) != 0) 3571 else 3576
        }
        3578 -> {
            if ((b(((b(((b((f.dVar33) < (0.35))) != 0) && ((b((0x7e0) < (f.param_14))) != 0))) != 0) && ((b(((b((0x120) < (f.iVar2))) != 0) && ((b(((b((0.15) < (f.dVar62))) != 0) && ((b((f.fVar67) < (DAT_0012cc78))) != 0))) != 0))) != 0))) != 0) 3577 else 3568
        }
        3579 -> {
            f.fVar67 = f32(((f.fVar67) + (f.fVar28)))
            3578
        }
        3580 -> {
            f.iVar20 = 1
            103
        }
        3581 -> {
            98
        }
        3582 -> {
            f.iVar20 = 1
            3581
        }
        3583 -> {
            97
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep112(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3584 -> {
            if ((b(((b((f.iVar15) != (1))) != 0) && ((b(((b(((b(((b(((b((readF32(f.param_1.plus(0x1d8))) < (9.0))) != 0) && ((b((((readF32(f.param_1.plus(0x1d8))) - (readF32(f.param_1.plus(0x1d4))))) < (1.5))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x234))) < (9.0))) != 0))) != 0) && ((b(((b((DAT_0012cf70) <= (readF32(f.param_1.plus(0x24c))))) != 0) || ((b((DAT_0012cf80) <= (((readF32(f.param_1.plus(0x248))) - (kotlin.math.abs(readF32(f.param_1.plus(0x24c)))))))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x234))) <= (5.8))) != 0))) != 0))) != 0) 3583 else 3582
        }
        3585 -> {
            if ((b(((b(((b((DAT_0012cc98) < (((f.fVar78) - (readF32(f.param_1.plus(4))))))) != 0) && ((b((60.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(0x1d4))) < (8.0))) != 0) && ((b(((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x154))))) != 0) && ((b((DAT_0012cc98) < (((readF32(f.param_1.plus(0x164))) - (readF32(f.param_1.plus(4))))))) != 0))) != 0))) != 0))) != 0) 3584 else 3580
        }
        3586 -> {
            if ((b(((b(((b((0) < (f.iVar14))) != 0) && ((b((0x240) < (((f.param_14) - (f.iVar14))))) != 0))) != 0) && ((b((0.5) < (f.fVar23))) != 0))) != 0) 3585 else 103
        }
        3587 -> {
            f.iVar20 = 1
            3586
        }
        3588 -> {
            writeI32(f.pjVar1, 1)
            100
        }
        3589 -> {
            103
        }
        3590 -> {
            writeI32(f.pjVar1, 2)
            3589
        }
        3591 -> {
            f.iVar20 = 2
            3590
        }
        3592 -> {
            83
        }
        3593 -> {
            if ((b(((b((f.dVar32) <= (DAT_0012cfc0))) != 0) || ((b((6.0) <= (f.fVar37))) != 0))) != 0) 3592 else 3591
        }
        3594 -> {
            100
        }
        3595 -> {
            writeI32(f.pjVar1, 1)
            3594
        }
        3596 -> {
            if ((b((f.iVar15) != (0))) != 0) 3595 else 3593
        }
        3597 -> {
            if ((b((f.fVar69) <= (10.0))) != 0) 3596 else 99
        }
        3598 -> {
            93
        }
        3599 -> {
            if ((b(((b((0.3) <= (f.dVar33))) != 0) && ((b((f.dVar32) <= (-(0.3)))) != 0))) != 0) 3598 else 3597
        }
        3600 -> {
            if ((b(((b(((b(((b((f.fVar41) <= (2.4))) != 0) || ((b((9.0) <= (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) || ((b((8.5) <= (f.fVar25))) != 0))) != 0) || ((b((((f.fVar40) - (f.fVar37))) <= (DAT_0012ccb8))) != 0))) != 0) 3579 else 3599
        }
        3601 -> {
            f.fVar41 = f32(((((f.fVar69) - (f.fVar40))) / (((f.fVar40) - (f.fVar37)))))
            3600
        }
        3602 -> {
            f.fVar69 = f32(readF32(f.param_1.plus(0x230)))
            3601
        }
        3603 -> {
            93
        }
        3604 -> {
            if ((b(((b(((b(((b((f.dVar59) < (4.8))) != 0) && ((b(((b((f.fVar78) < (3.5))) != 0) && ((b((1.2) < (f.fVar27))) != 0))) != 0))) != 0) && ((b((8.5) < (f.fVar25))) != 0))) != 0) && ((b((6.5) < (readF32(f.param_1.plus(0x230))))) != 0))) != 0) 3603 else 3602
        }
        3605 -> {
            f.fVar27 = f32(((f.fVar37) - (f.fVar78)))
            3604
        }
        3606 -> {
            f.dVar59 = f.fVar37
            3605
        }
        3607 -> {
            f.fVar37 = f32(readF32(f.param_1.plus(0x234)))
            3606
        }
        3608 -> {
            99
        }
        3609 -> {
            if ((b(((b(((b(((b((0x240) < (f.iVar2))) != 0) && ((b((0.15) < (f.dVar62))) != 0))) != 0) && ((b((-(0.3)) < (f.dVar32))) != 0))) != 0) && ((b(((b((f.iVar20) == (0))) != 0) && ((b((f.fVar54) < (readF32(f.param_1.plus(0x21c))))) != 0))) != 0))) != 0) 3608 else 3607
        }
        3610 -> {
            f.dVar62 = f.fVar23
            3609
        }
        3611 -> {
            f.iVar2 = ((f.param_14) - (f.iVar14))
            3610
        }
        3612 -> {
            103
        }
        3613 -> {
            writeI32(f.pjVar1, 0)
            3612
        }
        3614 -> {
            f.iVar20 = 0
            3613
        }
        3615 -> {
            100
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep113(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3616 -> {
            writeI32(f.pjVar1, 1)
            3615
        }
        3617 -> {
            99
        }
        3618 -> {
            102
        }
        3619 -> {
            if ((b(((b((f.fVar54) <= (6.0))) != 0) && ((b((8.0) <= (readF32(f.param_1.plus(0x150))))) != 0))) != 0) 3618 else 3617
        }
        3620 -> {
            93
        }
        3621 -> {
            if ((b(((b((DAT_0012cff8) <= (f.dVar33))) != 0) || ((b((f.dVar48) <= (DAT_0012cf80))) != 0))) != 0) 3620 else 3619
        }
        3622 -> {
            if ((b(((b(((b((0.3) <= (f.dVar33))) != 0) && ((b((f.dVar48) <= (DAT_0012cf80))) != 0))) != 0) || ((b((6.0) <= (f.fVar54))) != 0))) != 0) 3621 else 85
        }
        3623 -> {
            100
        }
        3624 -> {
            writeI32(f.pjVar1, 1)
            3623
        }
        3625 -> {
            writeI32(f.pjVar1, 1)
            3623
        }
        3626 -> {
            103
        }
        3627 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (f.dVar62)))))
            3626
        }
        3628 -> {
            writeI32(f.param_1.plus(0x210), 2)
            3627
        }
        3629 -> {
            f.iVar20 = 2
            3628
        }
        3630 -> {
            97
        }
        3631 -> {
            if ((b(((b(((b((4.3) < (f.dVar53))) != 0) && ((b((readF32(f.param_1.plus(0x230))) < (6.5))) != 0))) != 0) || ((b((((((readF32(f.param_1.plus(0x230))) - (((f.fVar40) + (f.fVar40))))) - (f.fVar54))) < (DAT_0012cdc0))) != 0))) != 0) 3630 else 3629
        }
        3632 -> {
            86
        }
        3633 -> {
            if ((b(((b((readF32(f.param_1.plus(0x18c))) < (60.0))) != 0) && ((b(((b(((b((3.9) < (f.dVar42))) != 0) && ((b((DAT_0012cf18) < (f.dVar53))) != 0))) != 0) || ((b(((b((3.0) < (f.fVar78))) != 0) && ((b((f.dVar42) < (3.9))) != 0))) != 0))) != 0))) != 0) 3632 else 3631
        }
        3634 -> {
            if ((b(((b(((b((f.dVar39) <= (DAT_0012cc80))) != 0) || ((b((f.dVar42) <= (DAT_0012cde0))) != 0))) != 0) || ((b((DAT_0012cca0) <= (f.dVar42))) != 0))) != 0) 3633 else 3625
        }
        3635 -> {
            if ((b(((b((f.dVar48) < (DAT_0012cdd8))) != 0) || ((b(((b(((b((f.dVar33) < (DAT_0012d000))) != 0) && ((b((f.dVar32) < (DAT_0012cc90))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x150))) < (9.5))) != 0))) != 0))) != 0) 3624 else 3634
        }
        3636 -> {
            if ((b(((b(((b((DAT_0012ccb8) < (f.dVar39))) != 0) && ((b((f.dVar53) < (5.8))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (84.0))) != 0))) != 0) 3635 else 3622
        }
        3637 -> {
            if ((b(((b(((b((DAT_0012cff0) <= (f.dVar48))) != 0) || ((b((f.dVar33) <= (DAT_0012cf78))) != 0))) != 0) || ((b(((b((f.fVar25) <= (6.5))) != 0) || ((b((4.5) <= (f.fVar54))) != 0))) != 0))) != 0) 3636 else 85
        }
        3638 -> {
            if ((b(((b((f.dVar53) <= (5.3))) != 0) || ((b((7.5) <= (readF32(f.param_1.plus(0x230))))) != 0))) != 0) 3637 else 3614
        }
        3639 -> {
            f.dVar53 = f.fVar54
            3638
        }
        3640 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x234)))
            3639
        }
        3641 -> {
            if ((b(((b((0.0) < (((f.fVar67) - (f.fVar27))))) != 0) && ((b((f.fVar27) < (0.3))) != 0))) != 0) 3640 else 3611
        }
        3642 -> {
            102
        }
        3643 -> {
            99
        }
        3644 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012cf70))) != 0) && ((b((0.3) <= (f.fVar26))) != 0))) != 0) || ((b((DAT_0012cf90) <= (readF32(f.param_1.plus(0x234))))) != 0))) != 0) 3643 else 3642
        }
        3645 -> {
            if ((b(((b(((b((f.dVar33) < (DAT_0012cf88))) != 0) && ((b((DAT_0012cfb8) < (((f.fVar27) - (f.fVar67))))) != 0))) != 0) && ((b((DAT_0012ced0) < (f.dVar32))) != 0))) != 0) 3644 else 3641
        }
        3646 -> {
            writeI32(f.pjVar1, 2)
            103
        }
        3647 -> {
            f.iVar20 = 2
            3646
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep114(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3648 -> {
            100
        }
        3649 -> {
            writeI32(f.pjVar1, 1)
            3648
        }
        3650 -> {
            if ((b(((b((9.0) < (f.fVar25))) != 0) && ((b((9.0) < (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) 3649 else 3647
        }
        3651 -> {
            85
        }
        3652 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012cf48))) != 0) && ((b((0.3) <= (f.fVar26))) != 0))) != 0) || ((b((DAT_0012cf90) <= (readF32(f.param_1.plus(0x234))))) != 0))) != 0) 3651 else 3650
        }
        3653 -> {
            if ((b(((b((f.dVar33) <= (DAT_0012cf88))) != 0) || ((b((f.dVar48) <= (DAT_0012cfb0))) != 0))) != 0) 3645 else 3652
        }
        3654 -> {
            f.dVar32 = f.fVar28
            3653
        }
        3655 -> {
            f.dVar48 = ((f.fVar67) - (f.fVar27))
            3654
        }
        3656 -> {
            f.fVar26 = f32(((f.fVar36) - (f.fVar78)))
            3655
        }
        3657 -> {
            f.dVar33 = f.fVar67
            3656
        }
        3658 -> {
            f.fVar27 = f32(kotlin.math.abs(f.fVar28))
            3657
        }
        3659 -> {
            f.fVar67 = f32(readF32(f.param_1.plus(0x248)))
            3658
        }
        3660 -> {
            f.fVar28 = f32(readF32(f.param_1.plus(0x24c)))
            3659
        }
        3661 -> {
            writeI32(f.pjVar1, 2)
            103
        }
        3662 -> {
            f.iVar20 = 2
            3661
        }
        3663 -> {
            99
        }
        3664 -> {
            if ((b(((b(((b(((b((6.0) <= (f.fVar54))) != 0) || ((b((readF32(f.param_1.plus(0x24c))) <= (-(0.3)))) != 0))) != 0) || ((b((0.3) <= (readF32(f.param_1.plus(0x248))))) != 0))) != 0) || ((b((DAT_0012cfa8) <= (((readF32(f.param_1.plus(0x248))) - (kotlin.math.abs(readF32(f.param_1.plus(0x24c)))))))) != 0))) != 0) 3663 else 102
        }
        3665 -> {
            93
        }
        3666 -> {
            if ((b(((b((5.0) < (f.fVar54))) != 0) && ((b((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) < (2.0))) != 0))) != 0) 3665 else 3664
        }
        3667 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x234)))
            3666
        }
        3668 -> {
            84
        }
        3669 -> {
            if ((b(((b((7.8) <= (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((1.0) <= (f.fVar60))) != 0))) != 0) 3668 else 3667
        }
        3670 -> {
            84
        }
        3671 -> {
            if ((b((7.8) <= (f.dVar31))) != 0) 3670 else 101
        }
        3672 -> {
            84
        }
        3673 -> {
            101
        }
        3674 -> {
            if ((b(((b(((b(((b((f.dVar31) < (7.8))) != 0) && ((b((5.5) < (f.fVar78))) != 0))) != 0) && ((b((f.fVar25) < (7.5))) != 0))) != 0) && ((b((48.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 3673 else 3672
        }
        3675 -> {
            if ((b(((b((f.fVar23) <= (0.25))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (60.0))) != 0))) != 0) 3674 else 3671
        }
        3676 -> {
            if ((b(((b((f.fVar54) <= (1.0))) != 0) || ((b((((f.bVar8).xor(1)).or(b((((readF32(f.param_1.plus(0x21c))) + (-(0.3)))) <= (f.fVar54)))) != 0)) != 0))) != 0) 84 else 3675
        }
        3677 -> {
            93
        }
        3678 -> {
            if ((b(((b(((b((DAT_0012ce68) < (f.dVar31))) != 0) && ((b((f.fVar78) < (3.5))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(8))) < (72.0))) != 0) && ((b((((f.fVar25) - (readF32(f.param_1.plus(0x1d8))))) < (1.0))) != 0))) != 0))) != 0) 3677 else 3676
        }
        3679 -> {
            f.dVar31 = f.fVar25
            3678
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep115(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3680 -> {
            f.fVar25 = f32(readF32(f.param_1.plus(0x1d4)))
            3679
        }
        3681 -> {
            100
        }
        3682 -> {
            writeI32(f.pjVar1, 1)
            3681
        }
        3683 -> {
            if ((b(((b(((b((f.fVar55) < (f.fVar71))) != 0) && ((b((f.fVar71) < (readF32(f.param_1.plus(0x164))))) != 0))) != 0) || ((b((((f.fVar55) / (f.fVar78))) < (0.6))) != 0))) != 0) 83 else 3680
        }
        3684 -> {
            f.fVar71 = f32(readF32(f.param_1.plus(4)))
            3683
        }
        3685 -> {
            86
        }
        3686 -> {
            82
        }
        3687 -> {
            if ((b(((b((f.fVar60) <= (3.5))) != 0) && ((run { run { f.fVar54 = f32(readF32(f.param_1.plus(0x1d4))); f32(readF32(f.param_1.plus(0x1d4))) }; b((f.fVar54) <= (9.0)) }) != 0))) != 0) 3686 else 3685
        }
        3688 -> {
            97
        }
        3689 -> {
            writeF32(f.param_1.plus(0x208), f32(((readF32(f.param_1.plus(0x20c))) * (0.95))))
            3688
        }
        3690 -> {
            if ((b((readF32(f.param_1.plus(0x208))) == (readF32(f.param_1.plus(0x20c))))) != 0) 3689 else 3688
        }
        3691 -> {
            if ((b(((b(((b((f.fVar54) <= (7.0))) != 0) || ((b((3.0) <= (f.fVar78))) != 0))) != 0) || ((b((12.0) <= (readF32(f.param_1.plus(0x150))))) != 0))) != 0) 3690 else 3685
        }
        3692 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x1d4)))
            82
        }
        3693 -> {
            if ((b((f.fVar60) <= (3.5))) != 0) 3692 else 3685
        }
        3694 -> {
            if ((b((9.0) < (readF32(f.param_1.plus(0x1d8))))) != 0) 3687 else 3693
        }
        3695 -> {
            103
        }
        3696 -> {
            writeI32(f.pjVar1, 0)
            3695
        }
        3697 -> {
            f.iVar20 = 0
            3696
        }
        3698 -> {
            if ((b(((b(((b(((b((((f.param_14) - (f.iVar14))) < (0x241))) != 0) || ((b(((b((((f.fVar78) - (f.fVar55))) <= (0.5))) != 0) || ((b((((f.fVar78) - (readF32(f.param_1.plus(4))))) <= (0.5))) != 0))) != 0))) != 0) || ((b((((f.fVar78) - (readF32(f.param_1.plus(0x164))))) <= (0.5))) != 0))) != 0) || ((b((9.5) <= (readF32(f.param_1.plus(0x230))))) != 0))) != 0) 3697 else 3694
        }
        3699 -> {
            if ((b(((b(((b(((b((0) < (f.iVar14))) != 0) && ((b((400) < (((f.param_14) - (f.iVar14))))) != 0))) != 0) && ((b((((f.fVar78) - (f.fVar55))) < (DAT_0012ce08))) != 0))) != 0) && ((b(((b((((f.fVar78) - (readF32(f.param_1.plus(4))))) < (DAT_0012ce08))) != 0) && ((b((((f.fVar78) - (readF32(f.param_1.plus(0x164))))) < (DAT_0012ce08))) != 0))) != 0))) != 0) 3698 else 3684
        }
        3700 -> {
            f.dVar62 = DAT_0012ce88
            3699
        }
        3701 -> {
            writeF32(f.param_1.plus(0x214), f32(f.fVar36))
            3700
        }
        3702 -> {
            f.fVar36 = f32(readF32(f.param_1.plus(0x154)))
            3701
        }
        3703 -> {
            f.iVar14 = readI32(f.param_1.plus(0x228))
            3702
        }
        3704 -> {
            93
        }
        3705 -> {
            if ((b(((b(!((f.bVar10) != 0))) != 0) || ((b((1) < (f.iVar20))) != 0))) != 0) 3704 else 3703
        }
        3706 -> {
            103
        }
        3707 -> {
            writeI32(f.pjVar1, 2)
            3706
        }
        3708 -> {
            f.iVar20 = 2
            3707
        }
        3709 -> {
            if ((b(((b(((b(((b(((b(((b((f.fVar60) < (1.0))) != 0) && ((b((0.35) < (f.fVar23))) != 0))) != 0) && ((b((0x120) < (((f.param_14) - (readI32(f.param_1.plus(0x228))))))) != 0))) != 0) && ((b(((b((f.fVar54) < (readF32(f.param_1.plus(0x21c))))) != 0) && ((b((f.iVar20) == (0))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) < (7.8))) != 0))) != 0) && ((b(((b(((b((readF32(f.param_1.plus(0x1d8))) < (7.8))) != 0) && ((b((readF32(f.param_1.plus(0x234))) < (7.5))) != 0))) != 0) && ((b(((f.bVar10).and(b((f.iVar15) == (0)))) != 0)) != 0))) != 0))) != 0) 3708 else 3705
        }
        3710 -> {
            f.fVar23 = f32(((f.fVar23) - (f.fVar40)))
            3709
        }
        3711 -> {
            f.dVar39 = f.fVar60
            3710
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep116(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3712 -> {
            f.dVar42 = f.fVar78
            3711
        }
        3713 -> {
            f.fVar60 = f32(((f.fVar24) - (f.fVar78)))
            3712
        }
        3714 -> {
            f.fVar78 = f32(readF32(f.param_1.plus(0x170)))
            3713
        }
        3715 -> {
            f.fVar24 = f32(readF32(f.param_1.plus(0x13c)))
            3714
        }
        3716 -> {
            f.iVar20 = 2
            3715
        }
        3717 -> {
            writeI32(f.pjVar1, 1)
            3715
        }
        3718 -> {
            f.iVar20 = 1
            3717
        }
        3719 -> {
            if ((b(((b((f.iVar15) != (1))) != 0) || ((b((3.5) <= (readF32(f.param_1.plus(0x170))))) != 0))) != 0) 3716 else 3718
        }
        3720 -> {
            if ((b((f.iVar20) == (2))) != 0) 3719 else 3715
        }
        3721 -> {
            f.pjVar1 = f.param_1.plus(0x210)
            3720
        }
        3722 -> {
            f.iVar20 = readI32(f.param_1.plus(0x210))
            3721
        }
        3723 -> {
            writeI64(f.param_1.plus(0x230), (0).toLong())
            3722
        }
        3724 -> {
            f.bVar8 = b((0) != 0)
            3723
        }
        3725 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x224)))
            3724
        }
        3726 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x1a8)))
            3725
        }
        3727 -> {
            81
        }
        3728 -> {
            if ((b((0xc) < (f.param_14))) != 0) 3727 else 80
        }
        3729 -> {
            writeI32(f.param_1.plus(0x200), 0)
            3728
        }
        3730 -> {
            writeI32(f.param_1.plus(0x204), readI32(f.param_1.plus(0x200)))
            3729
        }
        3731 -> {
            if ((b((readI32(f.param_1.plus(0x204))) < (readI32(f.param_1.plus(0x200))))) != 0) 3730 else 3729
        }
        3732 -> {
            f.fVar23 = f32(f.fVar40)
            3722
        }
        3733 -> {
            writeI32(f.param_1.plus(0x228), f.param_14)
            3732
        }
        3734 -> {
            writeF32(f.param_1.plus(0x224), f32(f.fVar40))
            3733
        }
        3735 -> {
            if ((b(((b((0x480) < (f.param_14))) != 0) && ((b((0.0) < (((f.fVar40) - (f.fVar23))))) != 0))) != 0) 3734 else 3722
        }
        3736 -> {
            f.bVar8 = b((b((0x480) < (f.param_14))) != 0)
            3735
        }
        3737 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x224)))
            3736
        }
        3738 -> {
            writeF32(f.param_1.plus(0x234), f32(((((f.fVar23) + (f.param_4))) / (f32((((f.iVar20) + (1))).toDouble())))))
            3737
        }
        3739 -> {
            writeI32(f.param_1.plus(0x240), ((f.iVar20) + (1)))
            3738
        }
        3740 -> {
            writeF32(f.param_1.plus(0x244), f32(((f.fVar23) + (f.param_4))))
            3739
        }
        3741 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x244)))
            3740
        }
        3742 -> {
            f.iVar20 = readI32(f.param_1.plus(0x240))
            3741
        }
        3743 -> {
            writeF32(f.param_1.plus(0x230), f32(((((f.fVar23) + (f.param_4))) / (f32((((f.iVar20) + (1))).toDouble())))))
            3737
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep117(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3744 -> {
            writeI32(f.param_1.plus(0x238), ((f.iVar20) + (1)))
            3743
        }
        3745 -> {
            writeF32(f.param_1.plus(0x23c), f32(((f.fVar23) + (f.param_4))))
            3744
        }
        3746 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x23c)))
            3745
        }
        3747 -> {
            f.iVar20 = readI32(f.param_1.plus(0x238))
            3746
        }
        3748 -> {
            if ((b((f.param_4) <= (f.fVar40))) != 0) 3742 else 3747
        }
        3749 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x1a8)))
            3748
        }
        3750 -> {
            80
        }
        3751 -> {
            if ((b((f.param_14) < (0xd))) != 0) 3750 else 81
        }
        3752 -> {
            writeI32(f.param_1.plus(0x200), ((readI32(f.param_1.plus(0x200))) + (1)))
            3751
        }
        3753 -> {
            if ((b((2.8) <= (f.dVar38))) != 0) 3731 else 3752
        }
        3754 -> {
            f.fVar55 = f32(f.param_5)
            3753
        }
        3755 -> {
            writeF32(f.param_1.plus(600), f32(f.param_5))
            3754
        }
        3756 -> {
            writeF32(f.param_1, f32(f.param_5))
            3755
        }
        3757 -> {
            if ((b((f.param_5) < (readF32(f.param_1)))) != 0) 3756 else 3753
        }
        3758 -> {
            f.fVar55 = f32(readF32(f.param_1))
            3757
        }
        3759 -> {
            writeF32(f.param_1.plus(0x180), f32(f.param_8))
            3758
        }
        3760 -> {
            writeF32(f.param_1.plus(0x184), f32(f.param_8))
            3759
        }
        3761 -> {
            writeI32(f.param_1.plus(0x17c), 0)
            3760
        }
        3762 -> {
            writeI32(f.param_1.plus(0x1f8), f.iVar14)
            3761
        }
        3763 -> {
            if ((b((readI32(f.param_1.plus(0x1f8))) < (f.iVar14))) != 0) 3762 else 3761
        }
        3764 -> {
            f.iVar14 = f.iVar20
            3763
        }
        3765 -> {
            writeI32(f.param_1.plus(0x188), f.iVar20)
            3764
        }
        3766 -> {
            if ((b((readI32(f.param_1.plus(0x188))) < (f.iVar20))) != 0) 3765 else 3763
        }
        3767 -> {
            f.iVar14 = readI32(f.param_1.plus(0x188))
            3766
        }
        3768 -> {
            f.iVar20 = readI32(f.param_1.plus(0x17c))
            3767
        }
        3769 -> {
            writeI32(f.param_1.plus(0x17c), ((readI32(f.param_1.plus(0x17c))) + (1)))
            3758
        }
        3770 -> {
            if ((b((DAT_0012cc40) <= (((f.fVar40) - (f.fVar55))))) != 0) 3768 else 3769
        }
        3771 -> {
            f.fVar35 = f32(f.fVar22)
            3770
        }
        3772 -> {
            writeF32(f.param_1.plus(0x138), f32(f.fVar22))
            3771
        }
        3773 -> {
            writeF32(f.param_1.plus(0x134), f32(f.fVar22))
            3772
        }
        3774 -> {
            writeF32(f.param_1, f32(f.fVar22))
            3773
        }
        3775 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x1a8)))
            3774
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep118(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3776 -> {
            f.fVar35 = f32(f.fVar22)
            3770
        }
        3777 -> {
            writeF32(f.param_1.plus(0x138), f32(f.fVar22))
            3776
        }
        3778 -> {
            writeF32(f.param_1.plus(0x134), f32(f.fVar22))
            3777
        }
        3779 -> {
            writeF32(f.param_1, f32(f.fVar22))
            3778
        }
        3780 -> {
            f.fVar22 = f32(f32(((f.dVar39) + (f.dVar42))))
            79
        }
        3781 -> {
            79
        }
        3782 -> {
            f.fVar22 = f32(((f.fVar22) + (-(0.5))))
            3781
        }
        3783 -> {
            if ((b((f.fVar22) < (3.5))) != 0) 3782 else 3780
        }
        3784 -> {
            f.dVar42 = DAT_0012cf98
            3783
        }
        3785 -> {
            f.dVar42 = 0.3
            3780
        }
        3786 -> {
            if ((b((3.0) <= (f.fVar22))) != 0) 3784 else 3785
        }
        3787 -> {
            f.dVar42 = 0.7
            3780
        }
        3788 -> {
            if ((b((2.0) <= (f.fVar22))) != 0) 3786 else 3787
        }
        3789 -> {
            f.dVar42 = 1.2
            3780
        }
        3790 -> {
            if ((b((1.0) <= (f.fVar22))) != 0) 3788 else 3789
        }
        3791 -> {
            f.dVar42 = -(0.7)
            3780
        }
        3792 -> {
            if ((b((f.dVar39) <= (3.9))) != 0) 3790 else 3791
        }
        3793 -> {
            f.fVar22 = f32(((f.fVar22) + (-(1.0))))
            79
        }
        3794 -> {
            if ((b((f.dVar39) <= (DAT_0012cf38))) != 0) 3792 else 3793
        }
        3795 -> {
            f.dVar39 = f.fVar22
            3794
        }
        3796 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x234)))
            3795
        }
        3797 -> {
            if ((b(((b(((b(!((f.bVar7) != 0))) != 0) || ((b((readI32(f.param_1.plus(0x17c))) < (0x1f))) != 0))) != 0) || ((b(((b((10.0) <= (readF32(f.param_1.plus(0x22c))))) != 0) || ((run { run { f.fVar22 = f32(readF32(f.param_1.plus(0x1a8))); f32(readF32(f.param_1.plus(0x1a8))) }; b((((f.fVar22) - (readF32(f.param_1)))) <= (1.5)) }) != 0))) != 0))) != 0) 3796 else 79
        }
        3798 -> {
            if ((b(((b(((f.bVar7) != 0) && ((b((0x24) < (readI32(f.param_1.plus(0x17c))))) != 0))) != 0) || ((b(((f.bVar9) != 0) && ((b((0x30) < (readI32(f.param_1.plus(0x17c))))) != 0))) != 0))) != 0) 3775 else 3797
        }
        3799 -> {
            if ((b(((b(((b(((b((f.param_14) < (0x360))) != 0) && ((b((0x12) < (readI32(f.param_1.plus(0x1f8))))) != 0))) != 0) && ((b((readF32(f.param_1)) < (3.0))) != 0))) != 0) && ((b((0xc) < (readI32(f.param_1.plus(0x204))))) != 0))) != 0) 3798 else 3770
        }
        3800 -> {
            f.fVar40 = f32(f.param_8)
            3799
        }
        3801 -> {
            writeF32(f.param_1.plus(0x184), f32(f.param_8))
            3800
        }
        3802 -> {
            if ((b((readF32(f.param_1.plus(0x184))) < (f.param_8))) != 0) 3801 else 3799
        }
        3803 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x184)))
            3802
        }
        3804 -> {
            f.fVar55 = f32(f.param_8)
            3803
        }
        3805 -> {
            writeF32(f.param_1.plus(0x180), f32(f.param_8))
            3804
        }
        3806 -> {
            if ((b((f.param_8) < (readF32(f.param_1.plus(0x180))))) != 0) 3805 else 3803
        }
        3807 -> {
            f.fVar55 = f32(readF32(f.param_1.plus(0x180)))
            3806
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep119(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3808 -> {
            f.fVar55 = f32(f.param_5)
            3753
        }
        3809 -> {
            writeI32(f.param_1.plus(0x188), 0)
            3808
        }
        3810 -> {
            writeF32(f.param_1.plus(0x18c), f32(((((f.fVar55) + (f32((f.iVar20).toDouble())))) / (f32((((f.param_14) / (0x120))).toDouble())))))
            3809
        }
        3811 -> {
            writeI64(f.param_1.plus(0x180), ((f.uVar6).toInt()).toLong())
            3810
        }
        3812 -> {
            writeI32(f.param_1.plus(4), f.uVar30)
            3811
        }
        3813 -> {
            writeF32(f.param_1.plus(600), f32(f.param_5))
            3812
        }
        3814 -> {
            writeF32(f.param_1, f32(f.param_5))
            3813
        }
        3815 -> {
            writeI32(f.param_1.plus(0x17c), 0)
            3814
        }
        3816 -> {
            writeI32(f.param_1.plus(0x164), readI32(f.param_1.plus(4)))
            3815
        }
        3817 -> {
            f.uVar6 = ((DAT_0012cfa0).toInt()).toLong()
            3816
        }
        3818 -> {
            writeF32(f.param_1.plus(400), f32(((f.fVar55) + (f32((f.iVar20).toDouble())))))
            3817
        }
        3819 -> {
            f.uVar30 = readI32(f.param_1)
            3818
        }
        3820 -> {
            f.fVar55 = f32(readF32(f.param_1.plus(400)))
            3819
        }
        3821 -> {
            writeI32(f.param_1.plus(0x1f8), f.iVar20)
            3820
        }
        3822 -> {
            if ((b((readI32(f.param_1.plus(0x1f8))) < (f.iVar20))) != 0) 3821 else 3820
        }
        3823 -> {
            f.iVar20 = readI32(f.param_1.plus(0x188))
            3822
        }
        3824 -> {
            if ((b(((b((f.param_14) < (5))) != 0) || ((b((((f.param_14) % (0x120))) != (0))) != 0))) != 0) 3807 else 3823
        }
        3825 -> {
            writeF32(f.param_1.plus(0x144), f32(f.fVar57))
            3824
        }
        3826 -> {
            writeI32(f.param_1.plus(0x148), f.param_14)
            3825
        }
        3827 -> {
            f.fVar57 = f32(f32(((f.dVar38) + (0.6))))
            3826
        }
        3828 -> {
            if ((b(((b((3) < (f.param_14))) != 0) && ((b((f.fVar57) < (f.param_4))) != 0))) != 0) 3827 else 3824
        }
        3829 -> {
            f.fVar57 = f32(readF32(f.param_1.plus(0x144)))
            3828
        }
        3830 -> {
            f.fVar35 = f32(f.param_7)
            3829
        }
        3831 -> {
            writeF32(f.param_1.plus(0x260), f32(f.param_7))
            3830
        }
        3832 -> {
            writeF32(f.param_1.plus(0x138), f32(f.param_7))
            3831
        }
        3833 -> {
            if ((b(((b((0x4f) < (f.param_14))) != 0) && ((b((f.param_7) < (f.fVar35))) != 0))) != 0) 3832 else 3829
        }
        3834 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x138)))
            3833
        }
        3835 -> {
            f.fVar22 = f32(f.param_6)
            3834
        }
        3836 -> {
            writeF32(f.param_1.plus(0x25c), f32(f.param_6))
            3835
        }
        3837 -> {
            writeF32(f.param_1.plus(0x134), f32(f.param_6))
            3836
        }
        3838 -> {
            if ((b(((b((0x17) < (f.param_14))) != 0) && ((b((f.param_6) < (f.fVar22))) != 0))) != 0) 3837 else 3834
        }
        3839 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x134)))
            3838
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep120(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3840 -> {
            writeF32(f.param_1.plus(0x274), f32(f.param_4))
            3839
        }
        3841 -> {
            if ((b(((b((f.param_4) < (readF32(f.param_1.plus(0x274))))) != 0) && ((b(((f.bVar8).and(b((0.0) < (readF32(f.param_1.plus(0x274)))))) != 0)) != 0))) != 0) 3840 else 3839
        }
        3842 -> {
            writeF32(f.param_1.plus(0x178), f32(f.param_4))
            3841
        }
        3843 -> {
            if ((b(((b((0.0) < (readF32(f.param_1.plus(0x178))))) != 0) && ((b(((f.bVar7).and(b((f.param_4) < (readF32(f.param_1.plus(0x178)))))) != 0)) != 0))) != 0) 3842 else 3841
        }
        3844 -> {
            f.fVar54 = f32(f.param_4)
            3843
        }
        3845 -> {
            writeF32(f.param_1.plus(0x218), f32(f.param_4))
            3844
        }
        3846 -> {
            if ((b((f.param_4) < (readF32(f.param_1.plus(0x218))))) != 0) 3845 else 3843
        }
        3847 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x218)))
            3846
        }
        3848 -> {
            78
        }
        3849 -> {
            if ((b(((b(!((f.bVar12) != 0))) != 0) && ((b(!((f.bVar13) != 0))) != 0))) != 0) 3848 else 76
        }
        3850 -> {
            writeF32(f.param_1.plus(500), f32(f.param_4))
            3849
        }
        3851 -> {
            77
        }
        3852 -> {
            writeF32(f.param_1.plus(0x26c), f32(f.fVar22))
            3851
        }
        3853 -> {
            writeF32(f.param_1.plus(0x268), f32(f.fVar54))
            3852
        }
        3854 -> {
            if ((b((0xc) < (f.param_14))) != 0) 3853 else 75
        }
        3855 -> {
            f.fVar35 = f32(f.param_7)
            3824
        }
        3856 -> {
            f.fVar22 = f32(f.param_6)
            3855
        }
        3857 -> {
            writeI32(f.param_1.plus(0x220), f.uVar30)
            3856
        }
        3858 -> {
            f.fVar57 = f32(0.0)
            3857
        }
        3859 -> {
            writeI32(f.param_1.plus(0x218), 0x42480000)
            3858
        }
        3860 -> {
            f.fVar54 = f32(50.0)
            3859
        }
        3861 -> {
            f.uVar30 = readI32(f.param_1.plus(0x218))
            3860
        }
        3862 -> {
            writeF32(f.param_1.plus(0x21c), f32(readF32(f.param_1.plus(0x220))))
            3861
        }
        3863 -> {
            if ((b(((b(uLt(((f.param_14) - (0x480)), 0x6c0))) != 0) && ((b((readF32(f.param_1.plus(0x220))) < (readF32(f.param_1.plus(0x21c))))) != 0))) != 0) 3862 else 3861
        }
        3864 -> {
            writeF32(f.param_1.plus(0x260), f32(f.param_7))
            3863
        }
        3865 -> {
            writeI32(f.param_1.plus(0x140), f.uVar30)
            3864
        }
        3866 -> {
            writeI32(f.param_1.plus(0x15c), readI32(f.param_1.plus(0x140)))
            3865
        }
        3867 -> {
            writeF32(f.param_1.plus(0x13c), f32(((f.fVar35) / (f.fVar54))))
            3866
        }
        3868 -> {
            writeF32(f.param_1.plus(0x154), f32(((f.fVar57) / (f.fVar54))))
            3867
        }
        3869 -> {
            writeF32(f.param_1.plus(0x170), f32(((f.fVar22) / (f.fVar54))))
            3868
        }
        3870 -> {
            writeF32(f.param_1.plus(0x138), f32(f.param_7))
            3869
        }
        3871 -> {
            f.uVar30 = readI32(f.param_1.plus(0x138))
            3870
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep121(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3872 -> {
            if ((b(((f.lVar18).toInt()) != (0x5c))) != 0) 3879 else 3871
        }
        3873 -> {
            f.fVar35 = f32(((f.fVar35) + (readF32(f.param_1.plus((f.lVar5).toInt())))))
            3872
        }
        3874 -> {
            f.fVar57 = f32(((f.fVar57) + (readF32(f.param_1.plus((f.lVar4).toInt())))))
            3873
        }
        3875 -> {
            f.fVar22 = f32(((f.fVar22) + (readF32(f.param_1.plus((f.lVar3).toInt())))))
            3874
        }
        3876 -> {
            f.lVar18 = (((f.lVar18).toInt()) + (4))
            3875
        }
        3877 -> {
            f.lVar5 = (((f.lVar18).toInt()) + (0xd8))
            3876
        }
        3878 -> {
            f.lVar4 = (((f.lVar18).toInt()) + (0x7c))
            3877
        }
        3879 -> {
            f.lVar3 = (((f.lVar18).toInt()) + (0x20))
            3878
        }
        3880 -> {
            f.lVar18 = 0
            3879
        }
        3881 -> {
            writeI32(f.param_1.plus(0x158), f.uVar30)
            3880
        }
        3882 -> {
            writeF32(f.param_1.plus(0x25c), f32(f.param_6))
            3881
        }
        3883 -> {
            writeF32(f.param_1.plus(0x134), f32(f.param_6))
            3882
        }
        3884 -> {
            writeI32(f.param_1.plus(0x144), 0)
            3883
        }
        3885 -> {
            writeI32(f.param_1.plus(0x130), readI32(f.param_1.plus(0x260)))
            3884
        }
        3886 -> {
            writeI32(f.param_1.plus(0xd4), readI32(f.param_1.plus(0x25c)))
            3885
        }
        3887 -> {
            writeI32(f.param_1.plus(0x78), readI32(f.param_1.plus(600)))
            3886
        }
        3888 -> {
            f.fVar35 = f32(0.0)
            3887
        }
        3889 -> {
            writeF32(f.param_1.plus(0x150), f32(((((f.fVar35) + (readF32(f.param_1.plus(0x144))))) / (f.fVar54))))
            3888
        }
        3890 -> {
            f.fVar57 = f32(0.0)
            3889
        }
        3891 -> {
            f.fVar22 = f32(0.0)
            3890
        }
        3892 -> {
            writeF32(f.param_1.plus(0x14c), f32(((f.fVar35) + (readF32(f.param_1.plus(0x144))))))
            3891
        }
        3893 -> {
            f.uVar30 = readI32(f.param_1.plus(0x134))
            3892
        }
        3894 -> {
            writeI32(f.param_1.plus(0x160), readI32(f.param_1.plus(0x158)))
            3893
        }
        3895 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x14c)))
            3894
        }
        3896 -> {
            f.fVar54 = f32(f32((((f.param_14) / (0x120))).toDouble()))
            3895
        }
        3897 -> {
            if ((b(((f.lVar18).toInt()) != (0))) != 0) 3902 else 3896
        }
        3898 -> {
            writeI32(f.pjVar1.plus(0xb4), readI32(f.pjVar1.plus(0xb8)))
            3897
        }
        3899 -> {
            writeI32(f.pjVar1.plus(0x58), readI32(f.pjVar1.plus(0x5c)))
            3898
        }
        3900 -> {
            writeI32(f.pjVar1.plus(-(4)), readI32(f.pjVar1))
            3899
        }
        3901 -> {
            f.lVar18 = (((f.lVar18).toInt()) + (4))
            3900
        }
        3902 -> {
            f.pjVar1 = f.param_1.plus((f.lVar18).toInt()).plus(0x7c)
            3901
        }
        3903 -> {
            f.lVar18 = -(0x58)
            3902
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep122(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3904 -> {
            76
        }
        3905 -> {
            if ((b(((f.bVar12) != 0) || ((f.bVar13) != 0))) != 0) 3904 else 78
        }
        3906 -> {
            writeF32(f.param_1.plus(500), f32(f.param_4))
            3905
        }
        3907 -> {
            writeF32(f.param_1.plus(0x1cc), f32(((((f.fVar54) + (readF32(f.param_1.plus(0x1cc))))) - (f.param_4))))
            3906
        }
        3908 -> {
            writeI32(f.param_1.plus(0x1d0), ((f.iVar20) + (1)))
            3907
        }
        3909 -> {
            75
        }
        3910 -> {
            writeI64(f.param_1.plus(0x1cc), (0).toLong())
            3909
        }
        3911 -> {
            writeF32(f.param_1.plus(0x1b0), f32(((readF32(f.param_1.plus(0x1b0))) + (readF32(f.param_1.plus(0x1cc))))))
            3910
        }
        3912 -> {
            writeF32(f.param_1.plus(0x1c0), f32(((readF32(f.param_1.plus(0x1c0))) + (f32((f.iVar20).toDouble())))))
            3911
        }
        3913 -> {
            writeI32(f.param_1.plus(0x1e0), f.iVar17)
            3912
        }
        3914 -> {
            f.iVar17 = ((f.iVar17) + (1))
            3913
        }
        3915 -> {
            if ((b((4) < (f.iVar20))) != 0) 3914 else 3910
        }
        3916 -> {
            if ((b((DAT_0012cdd0) < (((f.fVar54) - (f.param_4))))) != 0) 3915 else 3908
        }
        3917 -> {
            f.iVar20 = readI32(f.param_1.plus(0x1d0))
            3916
        }
        3918 -> {
            writeI64(f.param_1.plus(0x1c4), (0).toLong())
            3917
        }
        3919 -> {
            writeF32(f.param_1.plus(0x1bc), f32(((readF32(f.param_1.plus(0x1bc))) + (f32((f.iVar20).toDouble())))))
            3918
        }
        3920 -> {
            writeF32(f.param_1.plus(0x1ac), f32(((readF32(f.param_1.plus(0x1ac))) + (readF32(f.param_1.plus(0x1c4))))))
            3919
        }
        3921 -> {
            writeI32(f.param_1.plus(0x1dc), f.iVar16)
            3920
        }
        3922 -> {
            f.iVar16 = ((f.iVar16) + (1))
            3921
        }
        3923 -> {
            if ((b((4) < (f.iVar20))) != 0) 3922 else 3918
        }
        3924 -> {
            writeF32(f.param_1.plus(0x1c4), f32(((((f.fVar54) + (readF32(f.param_1.plus(0x1c4))))) - (f.param_4))))
            3917
        }
        3925 -> {
            writeI32(f.param_1.plus(0x1c8), ((f.iVar20) + (1)))
            3924
        }
        3926 -> {
            if ((b((((f.fVar54) - (f.param_4))) <= (DAT_0012cdc8))) != 0) 3923 else 3925
        }
        3927 -> {
            f.iVar20 = readI32(f.param_1.plus(0x1c8))
            3926
        }
        3928 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(500)))
            3927
        }
        3929 -> {
            75
        }
        3930 -> {
            if ((b((f.param_14) < (0xd))) != 0) 3929 else 77
        }
        3931 -> {
            writeF32(f.param_1.plus(0x26c), f32(((readF32(f.param_1.plus(0x1f0))) / (f.fVar54))))
            3930
        }
        3932 -> {
            writeF32(f.param_1.plus(0x268), f32(((readF32(f.param_1.plus(0x1e8))) / (f.fVar54))))
            3931
        }
        3933 -> {
            f.fVar54 = f32(f32((readI32(f.param_1.plus(0x264))).toDouble()))
            3932
        }
        3934 -> {
            if ((b((readI32(f.param_1.plus(0x264))) < (1))) != 0) 3854 else 3933
        }
        3935 -> {
            f.fVar22 = f32(f.param_4)
            3934
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep123(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3936 -> {
            writeF32(f.param_1.plus(0x1ec), f32(f.param_4))
            3935
        }
        3937 -> {
            if ((b((f.fVar22) < (f.param_4))) != 0) 3936 else 3934
        }
        3938 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x1ec)))
            3937
        }
        3939 -> {
            f.fVar54 = f32(f.param_4)
            3938
        }
        3940 -> {
            writeF32(f.param_1.plus(0x1e4), f32(f.param_4))
            3939
        }
        3941 -> {
            if ((b((f.param_4) < (readF32(f.param_1.plus(0x1e4))))) != 0) 3940 else 3938
        }
        3942 -> {
            f.fVar54 = f32(readF32(f.param_1.plus(0x1e4)))
            3941
        }
        3943 -> {
            f.fVar22 = f32(0.0)
            3934
        }
        3944 -> {
            writeI32(f.param_1.plus(0x1e4), 0x42c80000)
            3943
        }
        3945 -> {
            writeF32(f.param_1.plus(0x1f0), f32(((readF32(f.param_1.plus(0x1f0))) + (f.fVar22))))
            3944
        }
        3946 -> {
            writeI32(f.param_1.plus(0x1ec), 0)
            3945
        }
        3947 -> {
            f.fVar54 = f32(100.0)
            3946
        }
        3948 -> {
            writeF32(f.param_1.plus(0x1e8), f32(f.fVar54))
            3947
        }
        3949 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x1ec)))
            3948
        }
        3950 -> {
            f.fVar54 = f32(((readF32(f.param_1.plus(0x1e8))) + (readF32(f.param_1.plus(0x1e4)))))
            3949
        }
        3951 -> {
            f.fVar54 = f32(((readF32(f.param_1.plus(0x1e8))) + (((((readF32(f.param_1.plus(0x1e4))) + (f.fVar54))) * (0.5)))))
            3949
        }
        3952 -> {
            if ((b(((b((0x240) < (f.param_14))) != 0) || ((b((2.5) <= (readF32(f.param_1.plus(0x178))))) != 0))) != 0) 3950 else 3951
        }
        3953 -> {
            writeF32(f.param_1.plus(0x1b8), f32(((readF32(f.param_1.plus(0x1c0))) / (f32((f.iVar17).toDouble())))))
            3952
        }
        3954 -> {
            if ((b((0) < (f.iVar17))) != 0) 3953 else 3952
        }
        3955 -> {
            writeF32(f.param_1.plus(0x1b4), f32(((readF32(f.param_1.plus(0x1bc))) / (f32((f.iVar16).toDouble())))))
            3954
        }
        3956 -> {
            if ((b((0) < (f.iVar16))) != 0) 3955 else 3954
        }
        3957 -> {
            writeI32(f.param_1.plus(0x264), ((readI32(f.param_1.plus(0x264))) + (1)))
            3956
        }
        3958 -> {
            if ((b(((f.bVar12) != 0) || ((f.bVar13) != 0))) != 0) 3942 else 3957
        }
        3959 -> {
            f.bVar12 = b((b((f.param_14) < (1))) != 0)
            3958
        }
        3960 -> {
            f.bVar13 = b((b((((f.param_14) % (0x120))) != (0))) != 0)
            3959
        }
        3961 -> {
            writeF32(f.param_1.plus(0x24c), f32(((readF32(f.param_1.plus(0x1b0))) / (readF32(f.param_1.plus(0x1c0))))))
            3960
        }
        3962 -> {
            writeF32(f.param_1.plus(0x1d8), f32(((readF32(f.param_1.plus(0x1c0))) / (f32((f.iVar17).toDouble())))))
            3961
        }
        3963 -> {
            if ((b((0) < (f.iVar17))) != 0) 3962 else 3960
        }
        3964 -> {
            f.iVar17 = readI32(f.param_1.plus(0x1e0))
            3963
        }
        3965 -> {
            writeF32(f.param_1.plus(0x248), f32(((readF32(f.param_1.plus(0x1ac))) / (readF32(f.param_1.plus(0x1bc))))))
            3964
        }
        3966 -> {
            writeF32(f.param_1.plus(0x1d4), f32(((readF32(f.param_1.plus(0x1bc))) / (f32((f.iVar16).toDouble())))))
            3965
        }
        3967 -> {
            if ((b((0) < (f.iVar16))) != 0) 3966 else 3964
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep124(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        3968 -> {
            f.iVar16 = readI32(f.param_1.plus(0x1dc))
            3967
        }
        3969 -> {
            73
        }
        3970 -> {
            if ((b(((b(((b((f.iVar15) == (1))) != 0) && ((b((f.fVar55) < (7.5))) != 0))) != 0) && ((b(((b((12.0) < (readF32(f.param_1.plus(0x230))))) != 0) && ((b((0.6) < (((f.fVar55) + (((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) - (f.fVar54))))))) != 0))) != 0))) != 0) 3969 else 74
        }
        3971 -> {
            73
        }
        3972 -> {
            if ((b(((b(((b((f.dVar39) <= (4.8))) != 0) || ((b((7.8) <= (readF32(f.param_1.plus(0x230))))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x18c))) <= (72.0))) != 0) && ((b(((b((f.dVar39) <= (DAT_0012cf90))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (60.0))) != 0))) != 0))) != 0))) != 0) 3971 else 74
        }
        3973 -> {
            72
        }
        3974 -> {
            if ((b((DAT_0012cf88) <= (f.fVar35))) != 0) 3973 else 3972
        }
        3975 -> {
            if ((b(((b((f.iVar15) == (1))) != 0) || ((b((f.fVar40) < (f.fVar22))) != 0))) != 0) 3974 else 74
        }
        3976 -> {
            if ((b((f.dVar42) <= (DAT_0012cf80))) != 0) 72 else 3975
        }
        3977 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar40))
            74
        }
        3978 -> {
            writeI32(f.param_1.plus(0x174), 0)
            3977
        }
        3979 -> {
            f.iVar15 = 0
            3978
        }
        3980 -> {
            74
        }
        3981 -> {
            f.iVar15 = 1
            3980
        }
        3982 -> {
            if ((b(((b(((b((5.3) < (f.dVar39))) != 0) && ((b(((b((readF32(f.param_1.plus(0x230))) < (8.2))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (60.0))) != 0))) != 0))) != 0) || ((b(((b(((b((6.0) < (f.fVar55))) != 0) && ((b((readF32(f.param_1.plus(0x230))) < (8.6))) != 0))) != 0) || ((b(((b(((b(((b((6.5) < (f.fVar55))) != 0) && ((b((readF32(f.param_1.plus(0x230))) < (11.0))) != 0))) != 0) && ((b((1.2) < (((readF32(f.param_1.plus(0x13c))) - (readF32(f.param_1.plus(0x170))))))) != 0))) != 0) || ((b(((b(((b((5.3) < (f.dVar39))) != 0) && ((b((readF32(f.param_1.plus(0x230))) < (8.0))) != 0))) != 0) && ((b((((readF32(f.param_1.plus(0x13c))) - (readF32(f.param_1.plus(0x170))))) < (DAT_0012ccb8))) != 0))) != 0))) != 0))) != 0))) != 0) 3981 else 73
        }
        3983 -> {
            if ((b(((b(((b(((b((f.fVar22) < (f.fVar40))) != 0) || ((b((DAT_0012cf78) <= (kotlin.math.abs(f.fVar57)))) != 0))) != 0) || ((b((f.dVar42) <= (DAT_0012cdd8))) != 0))) != 0) || ((b((f.iVar15) != (1))) != 0))) != 0) 3976 else 3982
        }
        3984 -> {
            f.dVar42 = ((f.fVar35) - (kotlin.math.abs(f.fVar57)))
            3983
        }
        3985 -> {
            f.fVar22 = f32(f.fVar40)
            3984
        }
        3986 -> {
            writeI32(f.param_1.plus(0x174), 0)
            3985
        }
        3987 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar40))
            3986
        }
        3988 -> {
            f.iVar15 = 0
            3987
        }
        3989 -> {
            if ((b(((b(((b(((b((f.fVar35) < (0.3))) != 0) && ((b((((f.fVar35) + (f.fVar57))) < (DAT_0012cf60))) != 0))) != 0) || ((b((((f.fVar35) + (f.fVar57))) < (DAT_0012cf68))) != 0))) != 0) && ((b((DAT_0012cf70) < (f.fVar57))) != 0))) != 0) 3988 else 3984
        }
        3990 -> {
            f.iVar15 = 1
            3989
        }
        3991 -> {
            f.fVar57 = f32(readF32(f.param_1.plus(0x24c)))
            3990
        }
        3992 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x248)))
            3991
        }
        3993 -> {
            writeI32(f.param_1.plus(0x174), 1)
            70
        }
        3994 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar22))
            3993
        }
        3995 -> {
            f.fVar22 = f32(f32(f.dVar31))
            69
        }
        3996 -> {
            f.dVar31 = ((f.dVar31) + (f.dVar62))
            3995
        }
        3997 -> {
            f.dVar31 = ((((f.dVar31) + (f.dVar42))) / (f.dVar31))
            61
        }
        3998 -> {
            58
        }
        3999 -> {
            if ((b(((b(((b((f.dVar31) <= (DAT_0012ce60))) != 0) || ((b(((b((5.3) <= (f.dVar31))) != 0) || ((b((f.dVar48) <= (DAT_0012cdc0))) != 0))) != 0))) != 0) || ((run { run { f.dVar42 = DAT_0012ce58; DAT_0012ce58 }; b((((f.fVar55) - (f.fVar78))) <= (1.0)) }) != 0))) != 0) 3998 else 60
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep125(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4000 -> {
            71
        }
        4001 -> {
            f.iVar15 = 0
            4000
        }
        4002 -> {
            47
        }
        4003 -> {
            f.dVar42 = -(5.3)
            4002
        }
        4004 -> {
            47
        }
        4005 -> {
            f.dVar42 = -(5.6)
            4004
        }
        4006 -> {
            if ((b((5.6) < (f.dVar39))) != 0) 4005 else 55
        }
        4007 -> {
            46
        }
        4008 -> {
            if ((b((readF32(f.param_1.plus(8))) <= (60.0))) != 0) 4007 else 4006
        }
        4009 -> {
            if ((b(((b(((b(((b(((b((-(0.3)) <= (f.dVar42))) != 0) || ((b((0.3) <= (readF32(f.param_1.plus(0x248))))) != 0))) != 0) || ((b((DAT_0012cc78) <= (((f.fVar23) + (readF32(f.param_1.plus(0x248))))))) != 0))) != 0) && ((b((3.9) <= (readF32(f.param_1.plus(0x274))))) != 0))) != 0) && ((b(((b(((b((f.fVar57) <= (10.5))) != 0) || ((b((f.fVar35) <= (60.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (6.5))) != 0))) != 0))) != 0) 4008 else 58
        }
        4010 -> {
            56
        }
        4011 -> {
            69
        }
        4012 -> {
            f.fVar22 = f32(((f.fVar40) + (((((f.fVar55) + (-(6.0)))) / (f.fVar55)))))
            4011
        }
        4013 -> {
            if ((b(((b((8.5) <= (f.fVar71))) != 0) || ((b((6.5) <= (f.fVar55))) != 0))) != 0) 4012 else 4010
        }
        4014 -> {
            if ((b((6.0) < (f.fVar55))) != 0) 4013 else 4009
        }
        4015 -> {
            if ((b(((b(((b((f.fVar35) <= (60.0))) != 0) || ((b((f.fVar57) <= (11.0))) != 0))) != 0) || ((b(((b((f.fVar36) <= (6.5))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) <= (6.5))) != 0))) != 0))) != 0) 4014 else 58
        }
        4016 -> {
            64
        }
        4017 -> {
            f.dVar31 = ((((f.dVar39) + (f.dVar42))) / (f.dVar39))
            4016
        }
        4018 -> {
            f.dVar42 = -(7.3)
            4017
        }
        4019 -> {
            58
        }
        4020 -> {
            61
        }
        4021 -> {
            f.dVar31 = ((((f.dVar42) + (f.dVar39))) / (f.dVar39))
            4020
        }
        4022 -> {
            58
        }
        4023 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar22))
            4022
        }
        4024 -> {
            f.fVar22 = f32(f32(((((((f.dVar39) + (-(5.5)))) / (f.dVar39))) + (f.dVar62))))
            4023
        }
        4025 -> {
            if ((b((5.5) < (f.fVar55))) != 0) 4024 else 54
        }
        4026 -> {
            f.dVar42 = DAT_0012cf20
            4025
        }
        4027 -> {
            f.dVar42 = -(5.5)
            54
        }
        4028 -> {
            if ((b(((b((f.fVar55) <= (5.5))) != 0) || ((b(((b((f.dVar48) <= (DAT_0012ce68))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) <= (48.0))) != 0))) != 0))) != 0) 4026 else 4027
        }
        4029 -> {
            if ((b(((b(((b(((b(((b((DAT_0012cc80) < (f.dVar32))) != 0) && ((b((DAT_0012cf18) < (f.dVar39))) != 0))) != 0) && ((b((f.fVar55) < (6.0))) != 0))) != 0) && ((b(((b((7.0) < (readF32(f.param_1.plus(0x1d4))))) != 0) && ((b((f.fVar71) < (8.0))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (10.0))) != 0))) != 0) 4028 else 4019
        }
        4030 -> {
            50
        }
        4031 -> {
            f.dVar42 = -(6.3)
            4030
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep126(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4032 -> {
            if ((b(((b(((b((1.0) < (f.fVar60))) != 0) || ((b((8.5) < (f.fVar36))) != 0))) != 0) && ((b(((b((f.fVar71) < (11.0))) != 0) && ((b((6.5) < (f.fVar55))) != 0))) != 0))) != 0) 4031 else 4029
        }
        4033 -> {
            if ((b(((b(((b(((b((f.fVar60) <= (1.0))) != 0) && ((b((f.fVar36) <= (8.5))) != 0))) != 0) || ((b((11.5) <= (f.fVar71))) != 0))) != 0) || ((b((f.fVar55) <= (7.5))) != 0))) != 0) 4032 else 4018
        }
        4034 -> {
            f.dVar42 = -(6.3)
            4017
        }
        4035 -> {
            53
        }
        4036 -> {
            50
        }
        4037 -> {
            57
        }
        4038 -> {
            if ((b((DAT_0012cf28) <= (f.dVar39))) != 0) 4037 else 4036
        }
        4039 -> {
            f.dVar42 = -(5.5)
            4036
        }
        4040 -> {
            if ((b((f.fVar55) < (6.5))) != 0) 4039 else 4036
        }
        4041 -> {
            if ((b((9.0) <= (f.fVar71))) != 0) 4038 else 4040
        }
        4042 -> {
            f.dVar42 = DAT_0012cf30
            4041
        }
        4043 -> {
            if ((b(((b(((b(((b((DAT_0012ccb8) < (f.dVar32))) != 0) || ((b((8.5) < (f.fVar36))) != 0))) != 0) && ((b((6.0) < (f.fVar55))) != 0))) != 0) && ((b(((b((DAT_0012cde0) < (readF32(f.param_1.plus(0x274))))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (13.0))) != 0))) != 0))) != 0) 4042 else 4035
        }
        4044 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012ccb8))) != 0) || ((b((f.fVar55) <= (6.5))) != 0))) != 0) || ((b((60.0) <= (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 4043 else 4034
        }
        4045 -> {
            if ((b((10.0) <= (f.fVar71))) != 0) 53 else 4044
        }
        4046 -> {
            54
        }
        4047 -> {
            f.dVar42 = -(5.8)
            4046
        }
        4048 -> {
            if ((b((8.5) <= (f.fVar71))) != 0) 4047 else 4046
        }
        4049 -> {
            f.dVar42 = -(5.5)
            4048
        }
        4050 -> {
            if ((b(((b(((b((1.0) < (f.fVar60))) != 0) && ((b((f.fVar71) < (9.0))) != 0))) != 0) && ((b(((b((6.0) < (f.fVar55))) != 0) && ((b(((b((readF32(f.param_1.plus(0x18c))) < (60.0))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (13.0))) != 0))) != 0))) != 0))) != 0) 4049 else 4045
        }
        4051 -> {
            58
        }
        4052 -> {
            52
        }
        4053 -> {
            if ((b((f.fVar55) <= (6.0))) != 0) 4052 else 4051
        }
        4054 -> {
            55
        }
        4055 -> {
            47
        }
        4056 -> {
            f.dVar42 = -(5.5)
            4055
        }
        4057 -> {
            if ((b((readF32(f.param_1.plus(0x248))) < (0.3))) != 0) 4056 else 4054
        }
        4058 -> {
            46
        }
        4059 -> {
            if ((b(((b(((b(((b((2.0) < (f.fVar60))) != 0) && ((b((f.dVar31) < (DAT_0012cf38))) != 0))) != 0) && ((b((8.0) < (f.fVar36))) != 0))) != 0) && ((b((8.0) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) 4058 else 4057
        }
        4060 -> {
            63
        }
        4061 -> {
            f.fVar78 = f32(((((f.fVar55) + (-(5.0)))) / (f.fVar55)))
            4060
        }
        4062 -> {
            if ((b((f.fVar55) <= (5.5))) != 0) 4061 else 4059
        }
        4063 -> {
            if ((b(((b(((b((2.0) <= (f.fVar60))) != 0) || ((b(((b((f.dVar33) <= (8.2))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (8.2))) != 0))) != 0))) != 0) && ((b(((b((DAT_0012ce68) <= (f.dVar33))) != 0) || ((b(((b((3.5) <= (readF32(f.param_1.plus(0x274))))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (39.0))) != 0))) != 0))) != 0))) != 0) 4062 else 4051
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep127(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4064 -> {
            if ((b(((b((f.fVar55) <= (6.0))) != 0) && ((b(((b((f.dVar42) <= (-(0.35)))) != 0) || ((b((readF32(f.param_1.plus(0x21c))) <= (readF32(f.param_1.plus(0x218))))) != 0))) != 0))) != 0) 52 else 4051
        }
        4065 -> {
            if ((b((((f.param_14) - (readI32(f.param_1.plus(0x228))))) < (0x241))) != 0) 4053 else 4064
        }
        4066 -> {
            if ((b((f.fVar55) <= (7.0))) != 0) 4065 else 4051
        }
        4067 -> {
            if ((b(((b(((b(((b((DAT_0012cca8) < (f.dVar32))) != 0) && ((b(((b((f.dVar42) < (DAT_0012cf10))) != 0) || ((b((kotlin.math.abs(f.fVar23)) < (readF32(f.param_1.plus(0x248))))) != 0))) != 0))) != 0) && ((b((5.1) < (f.dVar39))) != 0))) != 0) && ((b((2.9) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 4066 else 4050
        }
        4068 -> {
            68
        }
        4069 -> {
            f.fVar36 = f32(((((f.fVar55) + (-(5.0)))) / (f.fVar55)))
            4068
        }
        4070 -> {
            66
        }
        4071 -> {
            f.dVar42 = ((((f.dVar39) + (DAT_0012cf20))) / (f.dVar39))
            4070
        }
        4072 -> {
            if ((b(((b((f.dVar31) <= (3.3))) != 0) || ((b((54.0) <= (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 4071 else 4069
        }
        4073 -> {
            if ((b(((b(((b((f.dVar48) < (DAT_0012cf08))) != 0) && ((b((DAT_0012cc80) < (f.dVar32))) != 0))) != 0) && ((b(((b((5.1) < (f.dVar39))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (10.0))) != 0))) != 0))) != 0) 4072 else 4067
        }
        4074 -> {
            if ((b(((b(((b((DAT_0012ce68) <= (f.dVar48))) != 0) || ((b((f.dVar39) <= (5.3))) != 0))) != 0) || ((b(((b((8.5) <= (f.fVar36))) != 0) || ((b(((run { run { f.fVar35 = f32(readF32(f.param_1.plus(0x18c))); f32(readF32(f.param_1.plus(0x18c))) }; b(((b((f.fVar35) <= (48.0))) != 0) || ((b((DAT_0012cca8) <= (((((f.fVar71) - (f.fVar54))) / (f.fVar25))))) != 0)) }) != 0) || ((run { run { f.fVar57 = f32(readF32(f.param_1.plus(0x22c))); f32(readF32(f.param_1.plus(0x22c))) }; b((14.0) <= (f.fVar57)) }) != 0))) != 0))) != 0))) != 0) 4073 else 4015
        }
        4075 -> {
            54
        }
        4076 -> {
            f.dVar42 = -(5.0)
            4075
        }
        4077 -> {
            if ((b((DAT_0012cd18) <= (f.fVar35))) != 0) 4076 else 4075
        }
        4078 -> {
            f.dVar42 = DAT_0012cf40
            4077
        }
        4079 -> {
            58
        }
        4080 -> {
            if ((b(((b((f.dVar32) < (DAT_0012ccb8))) != 0) || ((run { run { f.fVar35 = f32(readF32(f.param_1.plus(0x1d4))); f32(readF32(f.param_1.plus(0x1d4))) }; b((f.fVar35) < (7.0)) }) != 0))) != 0) 4079 else 4078
        }
        4081 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x1d4)))
            4078
        }
        4082 -> {
            if ((b((f.dVar31) < (DAT_0012ce60))) != 0) 4080 else 4081
        }
        4083 -> {
            47
        }
        4084 -> {
            if ((b(((b((f.fVar71) < (6.5))) != 0) && ((run { run { f.dVar42 = DAT_0012ce58; DAT_0012ce58 }; b((72.0) < (readF32(f.param_1.plus(0x18c)))) }) != 0))) != 0) 4083 else 4082
        }
        4085 -> {
            69
        }
        4086 -> {
            f.fVar22 = f32(((f.fVar40) + (((((f.fVar55) + (-(5.0)))) / (f.fVar55)))))
            4085
        }
        4087 -> {
            67
        }
        4088 -> {
            f.dVar31 = ((((f.dVar39) + (-(5.5)))) / (f.dVar39))
            4087
        }
        4089 -> {
            if ((b(((b(((b((8.0) <= (f.fVar71))) != 0) && ((b((DAT_0012cf48) <= (f.dVar42))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x248))) <= (DAT_0012cf50))) != 0))) != 0) 4088 else 4086
        }
        4090 -> {
            if ((b((5.5) < (f.fVar55))) != 0) 4089 else 4084
        }
        4091 -> {
            if ((b(((b(((b((f.dVar32) <= (0.85))) != 0) || ((b((readF32(f.param_1.plus(0x22c))) <= (10.0))) != 0))) != 0) || ((b((3.5) <= (readF32(f.param_1.plus(0x178))))) != 0))) != 0) 4090 else 58
        }
        4092 -> {
            69
        }
        4093 -> {
            f.fVar22 = f32(f32(((((((f.dVar39) + (-(5.8)))) / (f.dVar39))) + (f.dVar62))))
            4092
        }
        4094 -> {
            if ((b((6.0) < (f.fVar55))) != 0) 56 else 4091
        }
        4095 -> {
            if ((b(((b(((b(((b(((b(((b((7.8) <= (f.dVar48))) != 0) || ((b((f.dVar39) <= (5.1))) != 0))) != 0) || ((b((8.0) <= (f.fVar36))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (48.0))) != 0))) != 0) || ((b(((b((DAT_0012cc40) <= (f.fVar25))) != 0) && ((b((DAT_0012cca8) <= (((((f.fVar71) - (f.fVar54))) / (f.fVar25))))) != 0))) != 0))) != 0) || ((b((11.0) <= (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) 4074 else 4094
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep128(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4096 -> {
            f.dVar48 = f.fVar71
            4095
        }
        4097 -> {
            54
        }
        4098 -> {
            f.dVar42 = -(5.3)
            4097
        }
        4099 -> {
            if ((b(((b(((b(((b((5.0) < (f.fVar55))) != 0) && ((b((f.fVar26) < (2.3))) != 0))) != 0) && ((b((5.5) < (f.fVar55))) != 0))) != 0) && ((b((3.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) 4098 else 58
        }
        4100 -> {
            49
        }
        4101 -> {
            f.fVar22 = f32(((f.fVar55) + (-(6.0))))
            4100
        }
        4102 -> {
            50
        }
        4103 -> {
            f.dVar42 = -(5.6)
            4102
        }
        4104 -> {
            if ((b((f.dVar39) <= (6.3))) != 0) 4103 else 57
        }
        4105 -> {
            if ((b((6.0) < (f.fVar55))) != 0) 4104 else 4099
        }
        4106 -> {
            51
        }
        4107 -> {
            f.dVar42 = -(6.5)
            4106
        }
        4108 -> {
            if ((b((7.0) < (f.fVar55))) != 0) 4107 else 4105
        }
        4109 -> {
            if ((b(((b((10.0) <= (f.fVar71))) != 0) || ((b((DAT_0012cf00) <= (f.dVar42))) != 0))) != 0) 4096 else 4108
        }
        4110 -> {
            if ((b(((b((f.param_12) <= (13.5))) != 0) || ((b(((b((0.6) <= (f.fVar57))) != 0) && ((b((0.6) <= (f.fVar35))) != 0))) != 0))) != 0) 4109 else 58
        }
        4111 -> {
            60
        }
        4112 -> {
            if ((b(((b((f.fVar78) < (4.5))) != 0) && ((run { run { f.dVar42 = DAT_0012cf58; DAT_0012cf58 }; b((3.9) < (f.dVar31)) }) != 0))) != 0) 4111 else 58
        }
        4113 -> {
            if ((b(((b(((b((DAT_0012ce98) <= (f.dVar42))) != 0) || ((b((kotlin.math.abs(f.fVar23)) <= (readF32(f.param_1.plus(0x248))))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x248))) <= (DAT_0012ccb0))) != 0))) != 0) 4110 else 4112
        }
        4114 -> {
            f.dVar42 = f.fVar23
            4113
        }
        4115 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x24c)))
            4114
        }
        4116 -> {
            if ((b(((b((f.fVar24) <= (5.5))) != 0) || ((b(((b(((b((10.5) <= (readF32(f.param_1.plus(0x150))))) != 0) || ((b((5.5) <= (((readF32(f.param_1.plus(0x150))) - (f.fVar78))))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (66.0))) != 0))) != 0))) != 0) 4115 else 59
        }
        4117 -> {
            62
        }
        4118 -> {
            f.dVar31 = ((((f.dVar39) + (f.dVar42))) / (f.dVar39))
            4117
        }
        4119 -> {
            if ((b(((b(((b((5.0) < (f.fVar55))) != 0) && ((b((f.fVar26) < (1.5))) != 0))) != 0) && ((b(((b((3.9) < (readF32(f.param_1.plus(0x274))))) != 0) && ((b(((b((f.fVar71) < (7.0))) != 0) && ((run { run { f.dVar42 = DAT_0012ce58; DAT_0012ce58 }; b((60.0) < (readF32(f.param_1.plus(0x18c)))) }) != 0))) != 0))) != 0))) != 0) 51 else 4116
        }
        4120 -> {
            58
        }
        4121 -> {
            60
        }
        4122 -> {
            f.dVar42 = -(4.5)
            4121
        }
        4123 -> {
            if ((b(((b(((b((4.8) <= (f.dVar31))) != 0) || ((b((readF32(f.param_1.plus(8))) <= (54.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x22c))) <= (10.0))) != 0))) != 0) 4122 else 4120
        }
        4124 -> {
            if ((b(((b(((b(((b(((b(((b((kotlin.math.abs(f.fVar23)) < (1.0))) != 0) && ((b((f.fVar26) < (2.0))) != 0))) != 0) && ((b((72.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) && ((b(((b((((readF32(f.param_1.plus(0x150))) - (f.fVar24))) < (8.0))) != 0) && ((b((4.5) < (f.fVar78))) != 0))) != 0))) != 0) && ((b(((b((f.fVar26) < (DAT_0012cef8))) != 0) && ((b(((b((5.3) < (f.dVar39))) != 0) && ((b((readF32(f.param_1.plus(8))) < (60.0))) != 0))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (13.0))) != 0))) != 0) 4123 else 4119
        }
        4125 -> {
            54
        }
        4126 -> {
            58
        }
        4127 -> {
            60
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep129(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4128 -> {
            f.dVar42 = -(4.3)
            4127
        }
        4129 -> {
            59
        }
        4130 -> {
            if ((b((60.0) <= (readF32(f.param_1.plus(8))))) != 0) 4129 else 4128
        }
        4131 -> {
            if ((b(((b((4.3) <= (f.dVar31))) != 0) && ((b((((readF32(f.param_1.plus(0x150))) - (f.fVar24))) <= (9.0))) != 0))) != 0) 4130 else 4126
        }
        4132 -> {
            if ((b(((b((DAT_0012cca8) <= (f.fVar26))) != 0) || ((run { run { f.dVar42 = DAT_0012ce58; DAT_0012ce58 }; b((f.dVar39) <= (DAT_0012cf18)) }) != 0))) != 0) 4131 else 4125
        }
        4133 -> {
            45
        }
        4134 -> {
            f.dVar31 = ((((((f.dVar42) + (f.dVar31))) / (f.dVar31))) + (f.dVar62))
            4133
        }
        4135 -> {
            f.dVar42 = -(3.5)
            4134
        }
        4136 -> {
            if ((b((f.fVar60) <= (1.0))) != 0) 4135 else 4134
        }
        4137 -> {
            f.dVar42 = -(3.3)
            4136
        }
        4138 -> {
            if ((b(((b((3.5) < (f.fVar78))) != 0) && ((b(((b((f.dVar31) < (4.3))) != 0) && ((b((DAT_0012cf18) < (f.dVar39))) != 0))) != 0))) != 0) 4137 else 4132
        }
        4139 -> {
            if ((b(((b(((b(((b(((b(((b((f.dVar48) < (0.6))) != 0) && ((b((kotlin.math.abs(f.fVar23)) < (0.7))) != 0))) != 0) && ((b((66.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) && ((b(((b((f.fVar26) < (3.0))) != 0) && ((b(((b((f.dVar33) < (7.8))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) < (7.8))) != 0))) != 0))) != 0))) != 0) && ((b((6.5) < (f.fVar71))) != 0))) != 0) && ((b(((b((7.8) < (readF32(f.param_1.plus(0x150))))) != 0) && ((b((readF32(f.param_1.plus(0x22c))) < (11.0))) != 0))) != 0))) != 0) 4138 else 4124
        }
        4140 -> {
            f.dVar48 = ((f.fVar24) - (f.fVar78))
            4139
        }
        4141 -> {
            65
        }
        4142 -> {
            f.dVar32 = ((((f.dVar39) + (f.dVar42))) / (f.dVar39))
            4141
        }
        4143 -> {
            f.dVar42 = -(5.3)
            50
        }
        4144 -> {
            69
        }
        4145 -> {
            f.fVar22 = f32(((f.fVar40) + (((f.fVar22) / (f.fVar55)))))
            4144
        }
        4146 -> {
            f.fVar22 = f32(((f.fVar55) + (-(5.0))))
            49
        }
        4147 -> {
            if ((b(((b((f.fVar36) <= (6.0))) != 0) || ((b((f.fVar55) <= (5.5))) != 0))) != 0) 48 else 4143
        }
        4148 -> {
            58
        }
        4149 -> {
            69
        }
        4150 -> {
            f.fVar22 = f32(f32(((((((f.dVar39) + (f.dVar42))) / (f.dVar39))) + (f.dVar62))))
            4149
        }
        4151 -> {
            f.dVar42 = -(5.3)
            47
        }
        4152 -> {
            69
        }
        4153 -> {
            f.fVar22 = f32(((f.fVar40) + (((((f.fVar55) + (-(5.0)))) / (f.fVar55)))))
            4152
        }
        4154 -> {
            if ((b((f.fVar55) < (5.5))) != 0) 46 else 4151
        }
        4155 -> {
            f.dVar42 = -(5.5)
            47
        }
        4156 -> {
            if ((b((5.5) <= (f.fVar55))) != 0) 4155 else 47
        }
        4157 -> {
            if ((b((readF32(f.param_1.plus(8))) <= (60.0))) != 0) 4154 else 4156
        }
        4158 -> {
            if ((b(((b(((b(((b((6.0) < (f.fVar36))) != 0) && ((b((6.0) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) && ((b((5.3) < (f.dVar39))) != 0))) != 0) && ((b(((b(((b((f.fVar26) < (DAT_0012cca8))) != 0) && ((b(((b(((b((f.dVar32) <= (0.85))) != 0) || ((b((f.fVar27) <= (11.0))) != 0))) != 0) || ((b((3.5) <= (readF32(f.param_1.plus(0x178))))) != 0))) != 0))) != 0) && ((b(((b(((b((f.fVar35) <= (60.0))) != 0) || ((b((f.fVar27) <= (10.5))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (6.5))) != 0))) != 0))) != 0))) != 0) 4157 else 4148
        }
        4159 -> {
            50
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep130(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4160 -> {
            f.dVar42 = -(4.5)
            4159
        }
        4161 -> {
            48
        }
        4162 -> {
            if ((b((DAT_0012cf18) < (f.dVar39))) != 0) 4161 else 4160
        }
        4163 -> {
            if ((b((f.fVar27) < (10.0))) != 0) 4162 else 4158
        }
        4164 -> {
            54
        }
        4165 -> {
            f.dVar42 = ARR_0012d070[b((f.fVar55) < (5.5))]
            4164
        }
        4166 -> {
            if ((b(((b((f.fVar27) <= (10.5))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (6.5))) != 0))) != 0) 4165 else 4148
        }
        4167 -> {
            if ((b(((b(((b((DAT_0012ce18) <= (f.fVar26))) != 0) || ((b(((b((f.fVar35) <= (72.0))) != 0) || ((b((1.0) <= (f.fVar25))) != 0))) != 0))) != 0) || ((b((60.0) <= (readF32(f.param_1.plus(8))))) != 0))) != 0) 4163 else 4166
        }
        4168 -> {
            if ((b(((b((f.fVar55) <= (5.0))) != 0) || ((b((60.0) <= (f.fVar35))) != 0))) != 0) 4167 else 4147
        }
        4169 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x18c)))
            4168
        }
        4170 -> {
            if ((b(((b((f.fVar71) < (8.0))) != 0) && ((b(((b(((b(((b((4.5) < (f.fVar24))) != 0) && ((b((DAT_0012ce60) < (f.dVar39))) != 0))) != 0) && ((b((4.3) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) && ((run { run { f.fVar27 = f32(readF32(f.param_1.plus(0x22c))); f32(readF32(f.param_1.plus(0x22c))) }; b((f.fVar27) < (13.0)) }) != 0))) != 0))) != 0) 4169 else 4140
        }
        4171 -> {
            f.fVar25 = f32(((f.fVar54) - (f.fVar55)))
            4170
        }
        4172 -> {
            f.fVar26 = f32(((f.fVar71) - (f.fVar55)))
            4171
        }
        4173 -> {
            f.fVar71 = f32(readF32(f.param_1.plus(0x230)))
            4172
        }
        4174 -> {
            f.dVar31 = ((f.dVar62) * (DAT_0012ce38))
            3995
        }
        4175 -> {
            58
        }
        4176 -> {
            if ((b(((b(((b(((b((8.5) < (f.fVar36))) != 0) && ((b((f.dVar48) < (7.8))) != 0))) != 0) || ((b(((b((f.fVar60) < (2.0))) != 0) && ((b((39.0) < (f.fVar71))) != 0))) != 0))) != 0) || ((b(((b(((b(((b((f.fVar36) < (8.5))) != 0) || ((b((readF32(f.param_1.plus(0x274))) < (3.5))) != 0))) != 0) && ((b((39.0) < (f.fVar71))) != 0))) != 0) || ((b(((b(((b((8.2) < (f.dVar33))) != 0) && ((b((8.2) < (f.dVar48))) != 0))) != 0) && ((b((f.fVar60) < (2.0))) != 0))) != 0))) != 0))) != 0) 4175 else 4174
        }
        4177 -> {
            if ((b(((b(((b(((b((f.dVar32) <= (DAT_0012ce40))) != 0) || ((b((f.dVar33) <= (DAT_0012cd18))) != 0))) != 0) || ((run { run { f.dVar48 = readF32(f.param_1.plus(0x1d4)); readF32(f.param_1.plus(0x1d4)) }; b((f.dVar48) <= (DAT_0012cd18)) }) != 0))) != 0) || ((b(((b(((b((f.fVar78) <= (3.0))) != 0) || ((run { run { f.fVar71 = f32(readF32(f.param_1.plus(0x18c))); f32(readF32(f.param_1.plus(0x18c))) }; b((48.0) <= (f.fVar71)) }) != 0))) != 0) || ((b(((b((3.9) <= (f.dVar31))) != 0) || ((b(((b((readF32(f.param_1.plus(0x178))) <= (2.4))) != 0) || ((b((((f.fVar24) - (f.fVar78))) <= (DAT_0012cdf0))) != 0))) != 0))) != 0))) != 0))) != 0) 4173 else 4176
        }
        4178 -> {
            f.dVar33 = f.fVar36
            4177
        }
        4179 -> {
            69
        }
        4180 -> {
            f.fVar22 = f32(f32(f.dVar31))
            4179
        }
        4181 -> {
            f.dVar31 = ((f.dVar62) * (DAT_0012ce38))
            45
        }
        4182 -> {
            if ((b(((b(((b(((b(((b((8.5) < (f.fVar36))) != 0) && ((b((8.5) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) && ((b(((b((DAT_0012ce40) < (f.dVar32))) != 0) && ((b(((b(((b((7.8) < (f.dVar39))) != 0) && ((b((6.0) < (f.fVar78))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (72.0))) != 0))) != 0))) != 0))) != 0) && ((b((3.9) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0) || ((b(((b(((b(((b((7.5) < (f.fVar36))) != 0) && ((b((7.5) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) && ((b(((b((8.0) < (f.fVar55))) != 0) && ((b(((b((9.0) < (f.fVar78))) != 0) && ((b((readF32(f.param_1.plus(0x18c))) < (42.0))) != 0))) != 0))) != 0))) != 0) && ((b((4.5) < (readF32(f.param_1.plus(0x274))))) != 0))) != 0))) != 0) 4181 else 4178
        }
        4183 -> {
            f.fVar36 = f32(readF32(f.param_1.plus(0x1d8)))
            4182
        }
        4184 -> {
            f.fVar22 = f32(f32(((f.dVar31) + (f.dVar62))))
            69
        }
        4185 -> {
            f.dVar31 = ((((f.dVar31) + (-(3.5)))) / (f.dVar31))
            64
        }
        4186 -> {
            69
        }
        4187 -> {
            f.fVar22 = f32(((f.fVar40) + (f.fVar78)))
            4186
        }
        4188 -> {
            f.fVar78 = f32(((((f.fVar78) + (-(3.0)))) / (f.fVar78)))
            63
        }
        4189 -> {
            58
        }
        4190 -> {
            if ((b((f.fVar78) <= (3.0))) != 0) 4189 else 4188
        }
        4191 -> {
            if ((b((f.fVar78) <= (3.5))) != 0) 4190 else 4185
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep131(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4192 -> {
            45
        }
        4193 -> {
            f.dVar31 = ((f.dVar31) + (f.dVar62))
            4192
        }
        4194 -> {
            f.dVar31 = ((((f.dVar31) + (-(3.9)))) / (f.dVar31))
            62
        }
        4195 -> {
            if ((b((3.9) < (f.dVar31))) != 0) 4194 else 4191
        }
        4196 -> {
            44
        }
        4197 -> {
            if ((b(((b(((b(((b(((b(((b((84.0) <= (readF32(f.param_1.plus(8))))) != 0) || ((b((readF32(f.param_1.plus(0x1d8))) <= (8.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (8.0))) != 0))) != 0) || ((b(((b((4.5) <= (f.fVar78))) != 0) || ((b((f.dVar31) <= (2.8))) != 0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x178))) <= (DAT_0012cca8))) != 0))) != 0) || ((b((39.0) <= (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 4196 else 4195
        }
        4198 -> {
            58
        }
        4199 -> {
            60
        }
        4200 -> {
            f.dVar42 = -(2.8)
            4199
        }
        4201 -> {
            if ((b(((b((8.5) <= (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((readF32(f.param_1.plus(0x18c))) <= (39.0))) != 0))) != 0) 4200 else 4198
        }
        4202 -> {
            if ((b(((b(((b((readF32(f.param_1.plus(8))) < (60.0))) != 0) && ((b((7.8) < (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) && ((b(((b(((b((f.fVar78) < (3.5))) != 0) && ((b(((b((3.0) < (f.fVar78))) != 0) && ((b((7.8) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0))) != 0) && ((b((2.8) < (readF32(f.param_1.plus(0x178))))) != 0))) != 0))) != 0) 4201 else 4197
        }
        4203 -> {
            if ((b((f.dVar32) <= (DAT_0012ce18))) != 0) 44 else 4202
        }
        4204 -> {
            f.dVar31 = f.fVar78
            4203
        }
        4205 -> {
            f.dVar32 = f.fVar60
            4204
        }
        4206 -> {
            f.fVar60 = f32(((f.fVar60) - (f.fVar78)))
            4205
        }
        4207 -> {
            f.fVar78 = f32(readF32(f.param_1.plus(0x170)))
            4206
        }
        4208 -> {
            f.fVar22 = f32(f32(((f.dVar32) + (f.dVar62))))
            69
        }
        4209 -> {
            f.dVar32 = ((((f.dVar32) + (-(3.8)))) / (f.dVar32))
            65
        }
        4210 -> {
            47
        }
        4211 -> {
            58
        }
        4212 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar22))
            4211
        }
        4213 -> {
            f.fVar22 = f32(f32(((((((f.dVar39) + (DAT_0012cf40))) / (f.dVar39))) + (f.dVar62))))
            4212
        }
        4214 -> {
            if ((b((6.8) < (f.fVar78))) != 0) 4213 else 4210
        }
        4215 -> {
            58
        }
        4216 -> {
            if ((b(((b(((b(((b((7.8) <= (f.fVar78))) != 0) || ((b((f.dVar39) <= (DAT_0012cf18))) != 0))) != 0) || ((b(((b((f.fVar25) <= (48.0))) != 0) || ((b(((b((7.8) <= (readF32(f.param_1.plus(0x1d8))))) != 0) || ((b((0.3) < (f.fVar71))) != 0))) != 0))) != 0))) != 0) || ((b((7.0) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) 4215 else 4214
        }
        4217 -> {
            if ((b(((b((4.5) <= (f.fVar36))) != 0) || ((b(((b(((b((f.dVar32) <= (3.8))) != 0) || ((b((((f.fVar60) - (f.fVar36))) <= (DAT_0012cc40))) != 0))) != 0) || ((b((66.0) <= (f.fVar25))) != 0))) != 0))) != 0) 4216 else 4209
        }
        4218 -> {
            f.fVar22 = f32(f32(((f.dVar42) + (f.dVar62))))
            69
        }
        4219 -> {
            f.dVar42 = ((((f.fVar24) + (-(4.5)))) / (f.fVar24))
            66
        }
        4220 -> {
            if ((b(((b((f.fVar24) <= (5.0))) != 0) || ((b((f.dVar31) <= (5.6))) != 0))) != 0) 4217 else 4219
        }
        4221 -> {
            f.fVar22 = f32(f32(((f.dVar31) + (f.dVar62))))
            69
        }
        4222 -> {
            f.dVar31 = ((((f.dVar42) + (f.dVar31))) / (f.dVar31))
            67
        }
        4223 -> {
            f.dVar42 = -(5.3)
            4222
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep132(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4224 -> {
            if ((b(!((f.bVar12) != 0))) != 0) 4223 else 4222
        }
        4225 -> {
            f.bVar12 = b((b((f.fVar23) < (0.6))) != 0)
            4224
        }
        4226 -> {
            if ((b(((b((f.fVar71) < (0.5))) != 0) && ((run { run { f.bVar12 = b((0) != 0); b((0) != 0) }; b(!((b((f.fVar23).isNaN())) != 0)) }) != 0))) != 0) 4225 else 4224
        }
        4227 -> {
            f.bVar12 = b((0) != 0)
            4226
        }
        4228 -> {
            f.dVar42 = -(5.1)
            4227
        }
        4229 -> {
            if ((b((f.fVar54) <= (6.0))) != 0) 4228 else 4227
        }
        4230 -> {
            f.dVar42 = -(5.5)
            4229
        }
        4231 -> {
            58
        }
        4232 -> {
            if ((b(((b((f.fVar36) < (5.0))) != 0) && ((b((7.0) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) 4231 else 4230
        }
        4233 -> {
            f.fVar22 = f32(((f.fVar40) + (f.fVar36)))
            69
        }
        4234 -> {
            f.fVar36 = f32(((2.0) / (f.fVar36)))
            68
        }
        4235 -> {
            if ((b(((b((readF32(f.param_1.plus(0x150))) <= (15.0))) != 0) || ((b((f.fVar36) <= (6.0))) != 0))) != 0) 4232 else 4234
        }
        4236 -> {
            if ((b(((b(((b((f.dVar32) <= (DAT_0012ce60))) != 0) || ((b((0.6) <= (kotlin.math.abs(f.fVar71)))) != 0))) != 0) || ((b(((b((8.0) <= (f.fVar78))) != 0) || ((b((f.dVar31) <= (5.6))) != 0))) != 0))) != 0) 4220 else 4235
        }
        4237 -> {
            f.dVar31 = f.fVar54
            4236
        }
        4238 -> {
            f.dVar32 = f.fVar36
            4237
        }
        4239 -> {
            43
        }
        4240 -> {
            if ((b(((b(((b((DAT_0012cdc0) <= (f.fVar71))) != 0) || ((b((f.fVar78) <= (6.6))) != 0))) != 0) || ((b(((b((f.fVar60) <= (f.fVar24))) != 0) || ((b(((b(((b((6.0) <= (f.fVar24))) != 0) || ((run { run { f.fVar25 = f32(readF32(f.param_1.plus(0x18c))); f32(readF32(f.param_1.plus(0x18c))) }; b((f.fVar25) <= (66.0)) }) != 0))) != 0) || ((b((10.0) <= (readF32(f.param_1.plus(0x22c))))) != 0))) != 0))) != 0))) != 0) 4239 else 4238
        }
        4241 -> {
            f.fVar71 = f32(((f.fVar24) - (f.fVar36)))
            4240
        }
        4242 -> {
            f.fVar36 = f32(readF32(f.param_1.plus(0x170)))
            4241
        }
        4243 -> {
            if ((b(((b(((b((1.0) <= (f.fVar23))) != 0) || ((run { run { f.fVar78 = f32(readF32(f.param_1.plus(0x230))); f32(readF32(f.param_1.plus(0x230))) }; b((2.0) <= (((f.fVar78) - (f.fVar55)))) }) != 0))) != 0) || ((b((5.5) <= (((readF32(f.param_1.plus(0x150))) - (f.fVar24))))) != 0))) != 0) 43 else 4242
        }
        4244 -> {
            f.dVar42 = DAT_0012cf20
            4243
        }
        4245 -> {
            f.dVar62 = f.fVar40
            4244
        }
        4246 -> {
            f.fVar23 = f32(((f.fVar60) - (f.fVar24)))
            4245
        }
        4247 -> {
            f.fVar24 = f32(readF32(f.param_1.plus(0x154)))
            4246
        }
        4248 -> {
            f.fVar60 = f32(readF32(f.param_1.plus(0x13c)))
            4247
        }
        4249 -> {
            58
        }
        4250 -> {
            if ((b(((b(((b((f.dVar53) <= (11.2))) != 0) && ((b((f.param_12) <= (10.5))) != 0))) != 0) || ((b((2) < (readI32(f.param_1.plus(0x210))))) != 0))) != 0) 4249 else 4248
        }
        4251 -> {
            f.fVar57 = f32(readF32(f.param_1.plus(0x24c)))
            3984
        }
        4252 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x248)))
            4251
        }
        4253 -> {
            70
        }
        4254 -> {
            if ((b((f.iVar15) == (1))) != 0) 4253 else 71
        }
        4255 -> {
            if ((b(((b(((b((f.iVar16) == (0))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0) && ((b(uLt(((f.param_14) - (0x361)), 0x7e0))) != 0))) != 0) 4250 else 4254
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep133(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4256 -> {
            f.iVar15 = readI32(f.param_1.plus(0x174))
            4255
        }
        4257 -> {
            f.fVar22 = f32(f.fVar40)
            4256
        }
        4258 -> {
            writeI32(f.param_1.plus(0x210), 1)
            4257
        }
        4259 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar40))
            4258
        }
        4260 -> {
            if ((b(((b(((b((readI32(f.param_1.plus(0x174))) == (0))) != 0) && ((b(((b(((run { run { f.fVar23 = f32(((f.fVar55) + (((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) - (f.fVar54))))); f32(((f.fVar55) + (((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) - (f.fVar54))))) }; b(((b((f.dVar39) < (5.3))) != 0) && ((b((0.5) < (f.fVar23))) != 0)) }) != 0) && ((b((10.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0) || ((b(((b(((b((f.dVar39) < (5.3))) != 0) && ((b((0.3) < (f.fVar23))) != 0))) != 0) && ((b((12.0) < (readF32(f.param_1.plus(0x22c))))) != 0))) != 0))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x170))) < (3.0))) != 0) && ((b((66.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0))) != 0) 4259 else 4256
        }
        4261 -> {
            f.fVar22 = f32(f.fVar40)
            4256
        }
        4262 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar40))
            4261
        }
        4263 -> {
            if ((b(((b((readF32(f.param_1.plus(0x1d8))) <= (8.5))) != 0) || ((b(((b((readF32(f.param_1.plus(0x18c))) <= (72.0))) != 0) || ((b((readI32(f.param_1.plus(0x174))) != (0))) != 0))) != 0))) != 0) 4260 else 4262
        }
        4264 -> {
            if ((b(((b((f.fVar40) < (f.fVar22))) != 0) && ((b((readI32(f.param_1.plus(0x210))) < (2))) != 0))) != 0) 4263 else 4256
        }
        4265 -> {
            f.dVar39 = f.fVar55
            4264
        }
        4266 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4265
        }
        4267 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x208)))
            4266
        }
        4268 -> {
            f.local_178 = f.param_1.plus(0x1fc)
            4267
        }
        4269 -> {
            41
        }
        4270 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4269
        }
        4271 -> {
            if ((b(((b((readI32(f.param_1.plus(0x174))) == (0))) != 0) && ((b((f.iVar19) < (1))) != 0))) != 0) 8 else 42
        }
        4272 -> {
            f.iVar16 = f.iVar21
            4271
        }
        4273 -> {
            18
        }
        4274 -> {
            if ((b((0xb3) < (f.param_14))) != 0) 4273 else 7
        }
        4275 -> {
            f.bVar10 = b((0) != 0)
            6
        }
        4276 -> {
            f.iVar21 = readI32(f.param_1.plus(0x254))
            4275
        }
        4277 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.fVar40) * (f.dVar39)))))
            5
        }
        4278 -> {
            f.dVar39 = DAT_0012ce78
            4
        }
        4279 -> {
            f.bVar7 = b((1) != 0)
            4278
        }
        4280 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4279
        }
        4281 -> {
            14
        }
        4282 -> {
            if ((b(((b((0x11f) < (f.param_14))) != 0) || ((b((f.iVar19) != (1))) != 0))) != 0) 4281 else 4280
        }
        4283 -> {
            f.bVar7 = b((b((f.param_14) < (0x120))) != 0)
            4282
        }
        4284 -> {
            f.bVar12 = b((b((f.iVar19) == (1))) != 0)
            4283
        }
        4285 -> {
            f.iVar19 = readI32(f.param_1.plus(0x1fc))
            4284
        }
        4286 -> {
            writeI32(f.param_1.plus(0x1fc), 0)
            3
        }
        4287 -> {
            if ((b(((b((3.5) < (f.fVar40))) != 0) && ((b((((readF32(f.param_1.plus(0x1d8))) - (readF32(f.param_1.plus(0x1d4))))) <= (1.0))) != 0))) != 0) 4286 else 3
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep134(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4288 -> {
            1
        }
        4289 -> {
            if ((b((0x240) < (f.param_14))) != 0) 4288 else 2
        }
        4290 -> {
            11
        }
        4291 -> {
            if ((b(((b(((b(((b((DAT_0012cca8) < (f.fVar22))) != 0) && ((b((f.param_12) < (11.5))) != 0))) != 0) && ((b((0.0) < (f.param_12))) != 0))) != 0) && ((b((f.param_14) < (0x360))) != 0))) != 0) 4290 else 4289
        }
        4292 -> {
            13
        }
        4293 -> {
            writeI32(f.param_1.plus(0x210), 1)
            4292
        }
        4294 -> {
            writeI32(f.param_1.plus(0x254), 1)
            4293
        }
        4295 -> {
            if ((b(((b((((readF32(f.param_1.plus(0x13c))) - (readF32(f.param_1.plus(0x170))))) <= (2.0))) != 0) || ((b((60.0) <= (f.fVar24))) != 0))) != 0) 4294 else 4292
        }
        4296 -> {
            writeI32(f.param_1.plus(0x210), 2)
            4292
        }
        4297 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((((f.dVar39) + (1.0))) * (readF32(f.param_1.plus(0x20c)))))))
            4292
        }
        4298 -> {
            writeI32(f.param_1.plus(0x210), f.uVar30)
            4297
        }
        4299 -> {
            f.dVar39 = (((((f.param_14) / (0x120))).toDouble()) * (DAT_0012ce70))
            4298
        }
        4300 -> {
            f.uVar30 = 2
            4299
        }
        4301 -> {
            f.uVar30 = 1
            4299
        }
        4302 -> {
            if ((b((36.0) <= (readF32(f.param_1.plus(0x18c))))) != 0) 4300 else 4301
        }
        4303 -> {
            if ((f.bVar7) != 0) 4296 else 4302
        }
        4304 -> {
            writeI32(f.param_1.plus(0x254), 1)
            4303
        }
        4305 -> {
            f.bVar7 = b((b((DAT_0012ccb8) <= (((readF32(f.param_1.plus(4))) / (f.fVar40))))) != 0)
            4304
        }
        4306 -> {
            if ((b(((b((0.75) <= (((f.fVar23) / (f.fVar40))))) != 0) || ((b((readI32(f.param_1.plus(0x174))) != (0))) != 0))) != 0) 4295 else 4305
        }
        4307 -> {
            if ((b(((b(((b(((b(((b((readF32(f.param_1.plus(0x1d8))) <= (8.5))) != 0) && ((b((48.0) <= (f.fVar24))) != 0))) != 0) || ((b((84.0) <= (f.fVar24))) != 0))) != 0) || ((b(((b((readF32(f.param_1.plus(0x170))) <= (DAT_0012cde0))) != 0) || ((b((42.0) <= (readF32(f.param_1.plus(0x18c))))) != 0))) != 0))) != 0) && ((b(((b(((b(((b((readF32(f.param_1.plus(0x1d8))) <= (8.0))) != 0) || ((b((60.0) <= (f.fVar24))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x170))) <= (DAT_0012cdf8))) != 0))) != 0) || ((b(((b((48.0) <= (readF32(f.param_1.plus(0x18c))))) != 0) || ((b((((readF32(f.param_1.plus(0x13c))) - (readF32(f.param_1.plus(0x170))))) <= (DAT_0012cca8))) != 0))) != 0))) != 0))) != 0) 4306 else 4292
        }
        4308 -> {
            f.fVar24 = f32(readF32(f.param_1.plus(8)))
            4307
        }
        4309 -> {
            12
        }
        4310 -> {
            2
        }
        4311 -> {
            if ((b((f.param_14) < (0x360))) != 0) 4310 else 4309
        }
        4312 -> {
            if ((b(((b(((b((f.fVar40) <= (f.fVar23))) != 0) || ((b((((f.fVar40) - (f.fVar23))) <= (0.5))) != 0))) != 0) || ((b((((((f.fVar40) - (f.fVar23))) / (f.fVar40))) <= (DAT_0012cc98))) != 0))) != 0) 4311 else 4308
        }
        4313 -> {
            f.fVar23 = f32(readF32(f.param_1))
            4312
        }
        4314 -> {
            11
        }
        4315 -> {
            if ((b((f.param_14) < (0x360))) != 0) 4314 else 1
        }
        4316 -> {
            if ((b((f.fVar40) < (3.5))) != 0) 4315 else 4291
        }
        4317 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x178)))
            4316
        }
        4318 -> {
            11
        }
        4319 -> {
            if ((b(((b(((b(((b(((f.bVar7) != 0) && ((b((0.0) < (f.fVar55))) != 0))) != 0) && ((b((f.fVar55) < (5.8))) != 0))) != 0) && ((b(((b((13.0) < (readF32(f.param_1.plus(0x22c))))) != 0) && ((b((f.param_14) < (0x360))) != 0))) != 0))) != 0) && ((b((readF32(f.param_1.plus(0x1d4))) < (DAT_0012ce68))) != 0))) != 0) 4318 else 4317
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep135(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4320 -> {
            10
        }
        4321 -> {
            if ((b(((b((0.7) < (((f.fVar54) - (f.fVar55))))) != 0) && ((b(((b(((b(((b((f.fVar55) < (6.0))) != 0) && ((b((2.0) < (((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) / (((f.fVar54) - (f.fVar55))))))) != 0))) != 0) && ((b((f.param_14) < (0x360))) != 0))) != 0) && ((b((0.0) < (f.fVar55))) != 0))) != 0))) != 0) 4320 else 4319
        }
        4322 -> {
            f.bVar11 = b((0) != 0)
            0
        }
        4323 -> {
            f.bVar7 = b((0) != 0)
            4322
        }
        4324 -> {
            f.fVar55 = f32(readF32(f.param_1.plus(0x234)))
            4323
        }
        4325 -> {
            9
        }
        4326 -> {
            f.bVar11 = b((0) != 0)
            4325
        }
        4327 -> {
            if ((b((5) < (f.param_14))) != 0) 4326 else 4324
        }
        4328 -> {
            9
        }
        4329 -> {
            f.bVar11 = b((1) != 0)
            4328
        }
        4330 -> {
            writeI32(f.param_1.plus(0x1fc), 1)
            4328
        }
        4331 -> {
            writeI32(f.param_1.plus(0x210), 1)
            4330
        }
        4332 -> {
            writeI32(f.param_1.plus(0x254), 1)
            4331
        }
        4333 -> {
            if ((b((42.0) <= (readF32(f.param_1.plus(0x18c))))) != 0) 4332 else 4328
        }
        4334 -> {
            f.bVar11 = b((1) != 0)
            4333
        }
        4335 -> {
            if ((b(((b(((b((readF32(f.param_1.plus(4))) <= (readF32(f.param_1)))) != 0) || ((b((((readF32(f.param_1.plus(4))) / (readF32(f.param_1)))) <= (1.2))) != 0))) != 0) || ((b((9.0) <= (readF32(f.param_1.plus(0x1d8))))) != 0))) != 0) 4329 else 4334
        }
        4336 -> {
            if ((b(uLt(((f.param_14) - (0x121)), 0x11f))) != 0) 4335 else 4327
        }
        4337 -> {
            f.bVar8 = b((b((0x120) < (f.param_14))) != 0)
            4336
        }
        4338 -> {
            f.bVar9 = b((b((f.param_14) < (0x240))) != 0)
            4337
        }
        4339 -> {
            f.iVar16 = f.iVar21
            42
        }
        4340 -> {
            writeF32(f.param_1.plus(0x208), f32(f.fVar22))
            4339
        }
        4341 -> {
            42
        }
        4342 -> {
            if ((b((readF32(f.param_1.plus(0x208))) < (f.fVar22))) != 0) 4341 else 41
        }
        4343 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4342
        }
        4344 -> {
            8
        }
        4345 -> {
            if ((b((readI32(f.param_1.plus(0x210))) != (2))) != 0) 4344 else 4343
        }
        4346 -> {
            42
        }
        4347 -> {
            if ((b(((b((0) < (f.iVar19))) != 0) || ((b((f.iVar15) != (0))) != 0))) != 0) 4346 else 4345
        }
        4348 -> {
            42
        }
        4349 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4348
        }
        4350 -> {
            f.dVar39 = kotlin.math.exp(((((((f.dVar39) + (-(11.5)))) * (DAT_0012cea0))) * (f.fVar22)))
            4349
        }
        4351 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4350
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep136(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4352 -> {
            36
        }
        4353 -> {
            f.dVar39 = f.fVar40
            4352
        }
        4354 -> {
            f.fVar40 = f32(((f.param_12) + (-(11.0))))
            40
        }
        4355 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4354
        }
        4356 -> {
            37
        }
        4357 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4356
        }
        4358 -> {
            38
        }
        4359 -> {
            if ((b((f.param_12) <= (9.0))) != 0) 4358 else 4357
        }
        4360 -> {
            if ((b((f.param_12) <= (10.0))) != 0) 4359 else 4355
        }
        4361 -> {
            if ((b((f.param_12) <= (11.0))) != 0) 4360 else 4351
        }
        4362 -> {
            if ((b(((b((f.iVar15) == (0))) != 0) && ((b(((b((f.fVar54) <= (8.0))) != 0) || ((b((readF32(f.param_1.plus(0x170))) <= (8.0))) != 0))) != 0))) != 0) 4361 else 4348
        }
        4363 -> {
            if ((b(((b(((b((f.param_13) == (0.5))) != 0) && ((b((f.param_12) < (11.0))) != 0))) != 0) && ((b((0xc60) < (f.param_14))) != 0))) != 0) 4362 else 4347
        }
        4364 -> {
            42
        }
        4365 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4364
        }
        4366 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4365
        }
        4367 -> {
            f.dVar39 = ((f.dVar39) + (-(11.5)))
            39
        }
        4368 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4367
        }
        4369 -> {
            f.dVar39 = ((f.param_12) + (-(10.0)))
            39
        }
        4370 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4369
        }
        4371 -> {
            40
        }
        4372 -> {
            f.fVar40 = f32(((f.param_12) + (-(9.0))))
            4371
        }
        4373 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4372
        }
        4374 -> {
            f.fVar40 = f32(((f.param_12) + (-(8.0))))
            4371
        }
        4375 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4374
        }
        4376 -> {
            42
        }
        4377 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4376
        }
        4378 -> {
            if ((b((f.param_12) <= (7.0))) != 0) 4377 else 4375
        }
        4379 -> {
            if ((b((8.0) < (f.param_12))) != 0) 4373 else 4378
        }
        4380 -> {
            if ((b((f.param_12) <= (9.0))) != 0) 4379 else 4370
        }
        4381 -> {
            35
        }
        4382 -> {
            f.fVar40 = f32(((f.param_12) + (-(11.0))))
            4381
        }
        4383 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4382
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep137(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4384 -> {
            if ((b((10.0) < (f.param_12))) != 0) 4383 else 4380
        }
        4385 -> {
            if ((b((11.0) < (f.param_12))) != 0) 4368 else 4384
        }
        4386 -> {
            if ((b(((b(((b(((b((3.0) < (f.fVar22))) != 0) && ((b((f.param_11) < (14.5))) != 0))) != 0) && ((b((f.param_12) < (11.5))) != 0))) != 0) && ((b(((b((f.param_13) == (0.5))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0))) != 0) 4385 else 4363
        }
        4387 -> {
            42
        }
        4388 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4387
        }
        4389 -> {
            f.dVar39 = kotlin.math.exp(((((f.fVar40) * (DAT_0012cea0))) * (f.fVar22)))
            4388
        }
        4390 -> {
            f.fVar40 = f32(((f.param_12) + (-(8.0))))
            4389
        }
        4391 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4390
        }
        4392 -> {
            33
        }
        4393 -> {
            if ((b((f.param_12) <= (7.0))) != 0) 4392 else 4391
        }
        4394 -> {
            f.fVar40 = f32(((f.param_12) + (-(9.0))))
            4389
        }
        4395 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4394
        }
        4396 -> {
            if ((b((f.param_12) <= (8.0))) != 0) 4393 else 4395
        }
        4397 -> {
            36
        }
        4398 -> {
            f.dVar39 = ((f.param_12) + (-(10.0)))
            4397
        }
        4399 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            37
        }
        4400 -> {
            if ((b((9.0) < (f.param_12))) != 0) 4399 else 38
        }
        4401 -> {
            40
        }
        4402 -> {
            f.fVar40 = f32(((f.param_12) + (-(11.0))))
            4401
        }
        4403 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4402
        }
        4404 -> {
            if ((b((10.0) < (f.param_12))) != 0) 4403 else 4400
        }
        4405 -> {
            35
        }
        4406 -> {
            f.fVar40 = f32(((f.param_12) + (-(12.0))))
            4405
        }
        4407 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4406
        }
        4408 -> {
            if ((b((11.0) < (f.param_12))) != 0) 4407 else 4404
        }
        4409 -> {
            if ((b(((b((f.fVar54) <= (8.0))) != 0) || ((b((readF32(f.param_1.plus(0x170))) <= (8.0))) != 0))) != 0) 4408 else 4387
        }
        4410 -> {
            if ((b(((b(((b(((b((f.param_12) < (10.5))) != 0) && ((b((DAT_0012ce10) < (f.dVar31))) != 0))) != 0) && ((b((f.param_11) < (14.5))) != 0))) != 0) && ((b(((b(((b((DAT_0012cc98) < (kotlin.math.abs(((f.fVar40) + (f.param_12)))))) != 0) && ((b((f.param_13) == (0.5))) != 0))) != 0) && ((b(((b((readI32(f.param_1.plus(0x210))) == (0))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0))) != 0))) != 0) 4409 else 4386
        }
        4411 -> {
            42
        }
        4412 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4411
        }
        4413 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4412
        }
        4414 -> {
            f.dVar39 = ((f.dVar39) + (-(11.5)))
            36
        }
        4415 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4414
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep138(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4416 -> {
            40
        }
        4417 -> {
            f.fVar40 = f32(((f.param_12) + (-(11.0))))
            4416
        }
        4418 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4417
        }
        4419 -> {
            if ((b((f.param_12) < (10.5))) != 0) 4418 else 4415
        }
        4420 -> {
            26
        }
        4421 -> {
            f.dVar39 = ((f.dVar39) + (f.dVar42))
            4420
        }
        4422 -> {
            f.dVar42 = -(9.2)
            4421
        }
        4423 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4422
        }
        4424 -> {
            33
        }
        4425 -> {
            32
        }
        4426 -> {
            f.dVar39 = ((f.dVar39) + (-(8.2)))
            4425
        }
        4427 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4426
        }
        4428 -> {
            if ((b((7.0) < (f.param_12))) != 0) 4427 else 4424
        }
        4429 -> {
            if ((b((f.param_12) <= (8.0))) != 0) 4428 else 4423
        }
        4430 -> {
            f.dVar42 = -(9.5)
            4421
        }
        4431 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4430
        }
        4432 -> {
            42
        }
        4433 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4432
        }
        4434 -> {
            f.dVar39 = kotlin.math.exp(((((((f.param_12) + (-(10.0)))) * (DAT_0012cea0))) * (f.fVar22)))
            4433
        }
        4435 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4434
        }
        4436 -> {
            29
        }
        4437 -> {
            f.dVar39 = ((f.dVar39) + (-(10.2)))
            4436
        }
        4438 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4437
        }
        4439 -> {
            if ((b(((b((f.dVar53) <= (DAT_0012cec8))) != 0) && ((b((f.dVar42) <= (DAT_0012ced0))) != 0))) != 0) 4438 else 4435
        }
        4440 -> {
            if ((b((9.5) <= (f.param_12))) != 0) 4439 else 4431
        }
        4441 -> {
            if ((b((f.param_12) <= (9.0))) != 0) 4429 else 4440
        }
        4442 -> {
            if ((b((f.param_12) <= (10.0))) != 0) 4441 else 4419
        }
        4443 -> {
            39
        }
        4444 -> {
            f.dVar39 = f.fVar40
            4443
        }
        4445 -> {
            f.fVar40 = f32(((f.param_12) + (-(12.0))))
            35
        }
        4446 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4445
        }
        4447 -> {
            if ((b((11.0) < (f.param_12))) != 0) 4446 else 4442
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep139(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4448 -> {
            if ((b(((b((f.fVar54) <= (8.0))) != 0) || ((b((readF32(f.param_1.plus(0x170))) <= (8.0))) != 0))) != 0) 4447 else 4411
        }
        4449 -> {
            if ((b(((b(((b(((b(((b((f.param_12) < (11.0))) != 0) && ((b((3.0) < (f.fVar22))) != 0))) != 0) && ((b(((b((f.param_11) < (14.5))) != 0) || ((b(((b((f.dVar62) < (6.3))) != 0) && ((b((7.5) < (f.fVar23))) != 0))) != 0))) != 0))) != 0) && ((b((f.param_13) == (0.5))) != 0))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0) 4448 else 4410
        }
        4450 -> {
            42
        }
        4451 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4450
        }
        4452 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4451
        }
        4453 -> {
            f.dVar39 = ((f.param_10) + (-(12.0)))
            29
        }
        4454 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4453
        }
        4455 -> {
            31
        }
        4456 -> {
            if ((b(((b(((b((f.param_10) <= (11.5))) != 0) && ((b((10.5) <= (f.param_12))) != 0))) != 0) && ((b(((b((5.0) <= (f.fVar55))) != 0) || ((b((f.fVar23) <= (6.5))) != 0))) != 0))) != 0) 4455 else 4454
        }
        4457 -> {
            32
        }
        4458 -> {
            f.dVar39 = ((f.dVar53) + (-(12.2)))
            4457
        }
        4459 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4458
        }
        4460 -> {
            if ((b((11.5) <= (f.param_10))) != 0) 4459 else 4454
        }
        4461 -> {
            28
        }
        4462 -> {
            if ((b((11.5) <= (f.param_10))) != 0) 4461 else 4454
        }
        4463 -> {
            if ((b((10.2) <= (f.dVar39))) != 0) 4460 else 4462
        }
        4464 -> {
            27
        }
        4465 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4464
        }
        4466 -> {
            f.dVar42 = DAT_0012cea8
            28
        }
        4467 -> {
            if ((b(((b((DAT_0012cec0) < (f.dVar53))) != 0) && ((b((f.param_12) < (10.5))) != 0))) != 0) 4466 else 28
        }
        4468 -> {
            if ((b((12.0) < (f.param_10))) != 0) 4467 else 4463
        }
        4469 -> {
            if ((b(((b((f.dVar53) <= (DAT_0012ceb8))) != 0) || ((b((kotlin.math.abs(((f.fVar40) + (f.param_12)))) <= (0.3))) != 0))) != 0) 4456 else 4468
        }
        4470 -> {
            32
        }
        4471 -> {
            f.dVar39 = ((f.dVar53) + (f.dVar42))
            4470
        }
        4472 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            27
        }
        4473 -> {
            30
        }
        4474 -> {
            f.fVar40 = f32(((f.param_10) + (-(12.0))))
            4473
        }
        4475 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4474
        }
        4476 -> {
            if ((b((f.param_10) <= (11.5))) != 0) 4475 else 4472
        }
        4477 -> {
            if ((b(((b((f.param_12) < (10.5))) != 0) && ((b((((f.fVar55) - (readF32(f.param_1.plus(0x170))))) < (DAT_0012ccb8))) != 0))) != 0) 4476 else 4469
        }
        4478 -> {
            f.dVar42 = -(12.5)
            4477
        }
        4479 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4450
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep140(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4480 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4479
        }
        4481 -> {
            f.dVar39 = f.fVar40
            32
        }
        4482 -> {
            f.fVar40 = f32(((f.param_10) + (-(11.0))))
            30
        }
        4483 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4482
        }
        4484 -> {
            f.dVar39 = ((f.dVar53) + (-(11.5)))
            32
        }
        4485 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4484
        }
        4486 -> {
            if ((b((f.param_10) <= (10.5))) != 0) 4483 else 31
        }
        4487 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4450
        }
        4488 -> {
            32
        }
        4489 -> {
            f.dVar39 = ((f.dVar53) + (-(10.5)))
            4488
        }
        4490 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4489
        }
        4491 -> {
            f.dVar39 = ((f.param_10) + (-(10.0)))
            4488
        }
        4492 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4491
        }
        4493 -> {
            if ((b((9.5) < (f.param_10))) != 0) 4490 else 4492
        }
        4494 -> {
            if ((b((9.0) < (f.param_10))) != 0) 4493 else 33
        }
        4495 -> {
            if ((b((10.0) < (f.param_10))) != 0) 4486 else 4494
        }
        4496 -> {
            if ((b((11.0) < (f.param_10))) != 0) 4478 else 4495
        }
        4497 -> {
            42
        }
        4498 -> {
            if ((b(((b(((b((12.0) < (f.param_10))) != 0) && ((b((10.5) < (f.param_12))) != 0))) != 0) || ((b(((b((8.0) < (f.fVar54))) != 0) && ((b((8.0) < (readF32(f.param_1.plus(0x170))))) != 0))) != 0))) != 0) 4497 else 4496
        }
        4499 -> {
            34
        }
        4500 -> {
            if ((b(((b(((b((14.5) <= (f.param_11))) != 0) || ((b((11.0) <= (f.param_12))) != 0))) != 0) || ((b(((b(((b((13.0) <= (f.param_11))) != 0) && ((b((DAT_0012ceb0) <= (f.dVar39))) != 0))) != 0) || ((b(((b((9.0) <= (f.fVar54))) != 0) || ((b(((b((readI32(f.param_1.plus(0x210))) != (0))) != 0) || ((b(!((f.bVar12) != 0))) != 0))) != 0))) != 0))) != 0))) != 0) 4499 else 4498
        }
        4501 -> {
            if ((b(((b((2.3) < (f.dVar31))) != 0) && ((b(((b(((b((f.dVar39) < (DAT_0012ceb0))) != 0) || ((b((DAT_0012cdc8) < (((f.fVar40) + (f.param_12))))) != 0))) != 0) || ((b((f.dVar62) < (5.3))) != 0))) != 0))) != 0) 4500 else 34
        }
        4502 -> {
            42
        }
        4503 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4502
        }
        4504 -> {
            if ((b(((b(((b(((b((5.5) < (f.fVar55))) != 0) && ((b((f.param_12) < (10.5))) != 0))) != 0) && ((b((f.fVar23) < (8.0))) != 0))) != 0) && ((b(((b((readF32(f.param_1.plus(0x1d4))) < (6.8))) != 0) && ((f.bVar12) != 0))) != 0))) != 0) 4503 else 4501
        }
        4505 -> {
            42
        }
        4506 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4505
        }
        4507 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4506
        }
        4508 -> {
            f.dVar39 = ((f.dVar53) + (-(11.5)))
            26
        }
        4509 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4508
        }
        4510 -> {
            42
        }
        4511 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4510
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep141(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4512 -> {
            if ((b((f.param_10) <= (10.0))) != 0) 4511 else 4509
        }
        4513 -> {
            f.dVar39 = ((f.param_10) + (-(12.0)))
            26
        }
        4514 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4513
        }
        4515 -> {
            if ((b((f.param_10) <= (11.0))) != 0) 4512 else 4514
        }
        4516 -> {
            25
        }
        4517 -> {
            f.dVar39 = ((f.param_10) + (-(12.0)))
            4516
        }
        4518 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4517
        }
        4519 -> {
            if ((b((12.0) < (f.param_10))) != 0) 4518 else 4515
        }
        4520 -> {
            25
        }
        4521 -> {
            f.dVar39 = ((f.dVar53) + (DAT_0012cea8))
            4520
        }
        4522 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4521
        }
        4523 -> {
            if ((b((13.0) < (f.param_10))) != 0) 4522 else 4519
        }
        4524 -> {
            42
        }
        4525 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4524
        }
        4526 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4525
        }
        4527 -> {
            f.dVar39 = ((f.dVar53) + (-(13.5)))
            25
        }
        4528 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4527
        }
        4529 -> {
            if ((b((14.0) < (f.param_10))) != 0) 4528 else 4523
        }
        4530 -> {
            42
        }
        4531 -> {
            if ((b((15.0) < (f.param_10))) != 0) 4530 else 4529
        }
        4532 -> {
            if ((b(((b((4.0) < (f.fVar22))) != 0) && ((b(((b(((b((f.param_11) < (13.2))) != 0) && ((b((0.5) < (((f.fVar40) + (f.param_12))))) != 0))) != 0) && ((f.bVar12) != 0))) != 0))) != 0) 4531 else 4504
        }
        4533 -> {
            24
        }
        4534 -> {
            if ((b(((b(((b((5.6) < (f.dVar62))) != 0) && ((b((f.fVar23) < (8.2))) != 0))) != 0) && ((f.bVar12) != 0))) != 0) 4533 else 4532
        }
        4535 -> {
            f.fVar23 = f32(readF32(f.param_1.plus(0x230)))
            4534
        }
        4536 -> {
            f.bVar12 = b((b((f.iVar15) == (0))) != 0)
            4535
        }
        4537 -> {
            42
        }
        4538 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4537
        }
        4539 -> {
            if ((b((f.iVar19) == (0))) != 0) 4538 else 4537
        }
        4540 -> {
            if ((b(((b(((b((f.fVar22) < (1.5))) != 0) && ((b((readF32(f.param_1.plus(0x1d8))) < (7.0))) != 0))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0) 24 else 4536
        }
        4541 -> {
            42
        }
        4542 -> {
            f.iVar16 = 0
            4541
        }
        4543 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4542
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep142(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4544 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4543
        }
        4545 -> {
            f.dVar39 = ((f.dVar53) + (-(14.5)))
            4544
        }
        4546 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4545
        }
        4547 -> {
            23
        }
        4548 -> {
            f.fVar40 = f32(((f.param_10) + (-(14.0))))
            4547
        }
        4549 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4548
        }
        4550 -> {
            42
        }
        4551 -> {
            f.iVar16 = 0
            4550
        }
        4552 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4551
        }
        4553 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4552
        }
        4554 -> {
            f.dVar39 = ((f.dVar53) + (f.dVar39))
            22
        }
        4555 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4554
        }
        4556 -> {
            f.dVar39 = DAT_0012ced8
            4555
        }
        4557 -> {
            if ((b((13.5) < (f.param_10))) != 0) 4556 else 4555
        }
        4558 -> {
            f.dVar39 = DAT_0012cea8
            4557
        }
        4559 -> {
            if ((b((f.param_10) <= (14.0))) != 0) 4558 else 4549
        }
        4560 -> {
            if ((b((f.param_10) <= (14.5))) != 0) 4559 else 4546
        }
        4561 -> {
            f.dVar39 = f.fVar40
            4544
        }
        4562 -> {
            f.fVar40 = f32(((f.param_10) + (-(15.0))))
            23
        }
        4563 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4562
        }
        4564 -> {
            if ((b((f.param_10) <= (15.0))) != 0) 4560 else 4563
        }
        4565 -> {
            42
        }
        4566 -> {
            f.iVar16 = 0
            4565
        }
        4567 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4566
        }
        4568 -> {
            if ((b(((b(((b((readF32(f.param_1.plus(0x248))) < (0.3))) != 0) && ((b((((readF32(f.param_1.plus(0x24c))) + (readF32(f.param_1.plus(0x248))))) < (0.0))) != 0))) != 0) && ((b(((b(((b((-(0.35)) < (f.dVar42))) != 0) && ((b((readF32(f.param_1.plus(0x1d8))) < (7.3))) != 0))) != 0) || ((b(((b((-(0.35)) < (f.dVar42))) != 0) && ((b((readF32(f.param_1.plus(0x1d8))) < (7.3))) != 0))) != 0))) != 0))) != 0) 4567 else 4564
        }
        4569 -> {
            20
        }
        4570 -> {
            if ((b(((b((f.param_14) < (0x360))) != 0) && ((b((f.iVar19) == (1))) != 0))) != 0) 4569 else 4568
        }
        4571 -> {
            if ((b(((b(((b(((b(((b((0x240) < (f.param_14))) != 0) && ((b((14.0) < (f.param_11))) != 0))) != 0) && ((b(((b((13.0) < (f.param_10))) != 0) && ((b(((b((f.dVar31) < (2.3))) != 0) && ((b((f.iVar15) == (0))) != 0))) != 0))) != 0))) != 0) && ((b((1.5) < (f.fVar22))) != 0))) != 0) && ((b(((b(((b((f.param_10) < (14.0))) != 0) && ((b((1.2) < (f.dVar31))) != 0))) != 0) && ((b((f.iVar21) == (0))) != 0))) != 0))) != 0) 4570 else 4540
        }
        4572 -> {
            f.dVar31 = f.fVar22
            4571
        }
        4573 -> {
            42
        }
        4574 -> {
            f.iVar16 = 0
            4573
        }
        4575 -> {
            22
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep143(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4576 -> {
            f.dVar39 = ((f.param_10) + (-(15.0)))
            4575
        }
        4577 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4576
        }
        4578 -> {
            f.dVar39 = ((f.dVar53) + (-(14.5)))
            4575
        }
        4579 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4578
        }
        4580 -> {
            42
        }
        4581 -> {
            f.iVar16 = 0
            4580
        }
        4582 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.dVar39) * (f.fVar22)))))
            4581
        }
        4583 -> {
            f.dVar39 = kotlin.math.exp(((((f.dVar39) * (DAT_0012cea0))) * (f.fVar22)))
            4582
        }
        4584 -> {
            f.dVar39 = ((f.dVar53) + (f.dVar39))
            4583
        }
        4585 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4584
        }
        4586 -> {
            f.dVar39 = DAT_0012cee8
            4585
        }
        4587 -> {
            if ((b(((b(((b((f.param_10) <= (13.5))) != 0) && ((run { run { f.dVar39 = DAT_0012cea8; DAT_0012cea8 }; b((f.param_10) <= (13.0)) }) != 0))) != 0) && ((run { run { f.dVar39 = DAT_0012cee0; DAT_0012cee0 }; b((12.5) < (f.param_10)) }) != 0))) != 0) 4586 else 4585
        }
        4588 -> {
            f.dVar39 = DAT_0012cef0
            4587
        }
        4589 -> {
            f.dVar39 = ((f.param_10) + (-(14.0)))
            4583
        }
        4590 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x20c)))
            4589
        }
        4591 -> {
            if ((b((f.param_10) <= (14.0))) != 0) 4588 else 4590
        }
        4592 -> {
            if ((b((f.param_10) <= (14.5))) != 0) 4591 else 4579
        }
        4593 -> {
            if ((b((15.0) < (f.param_10))) != 0) 4577 else 4592
        }
        4594 -> {
            if ((b((f.iVar19) != (1))) != 0) 4593 else 20
        }
        4595 -> {
            42
        }
        4596 -> {
            writeF32(f.param_1.plus(0x208), f32(readF32(f.param_1.plus(0x20c))))
            4595
        }
        4597 -> {
            if ((b((readF32(f.param_1.plus(0x20c))) <= (readF32(f.param_1.plus(0x208))))) != 0) 4596 else 4595
        }
        4598 -> {
            f.iVar16 = 0
            4597
        }
        4599 -> {
            if ((b(((b((readF32(f.param_1.plus(0x274))) < (3.5))) != 0) && ((b((48.0) < (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 4598 else 4594
        }
        4600 -> {
            42
        }
        4601 -> {
            writeF32(f.param_1.plus(0x208), f32(readF32(f.param_1.plus(0x20c))))
            4600
        }
        4602 -> {
            if ((b((readF32(f.param_1.plus(0x20c))) <= (readF32(f.param_1.plus(0x208))))) != 0) 4601 else 4600
        }
        4603 -> {
            f.iVar16 = 0
            4602
        }
        4604 -> {
            if ((b((readF32(f.param_1.plus(0x274))) < (2.8))) != 0) 4603 else 4599
        }
        4605 -> {
            21
        }
        4606 -> {
            if ((b(((b((DAT_0012cc98) <= (((f.fVar40) + (f.param_12))))) != 0) || ((b((f.iVar21) != (0))) != 0))) != 0) 4605 else 4604
        }
        4607 -> {
            21
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep144(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4608 -> {
            if ((b((f.param_14) < (0x241))) != 0) 4607 else 19
        }
        4609 -> {
            21
        }
        4610 -> {
            19
        }
        4611 -> {
            if ((b(((b((0x240) < (f.param_14))) != 0) && ((b((1.0) < (((f.fVar55) - (readF32(f.param_1.plus(0x170))))))) != 0))) != 0) 4610 else 4609
        }
        4612 -> {
            if ((b((f.iVar19) != (0))) != 0) 4611 else 4608
        }
        4613 -> {
            if ((b(((b(((b(((b((f.iVar15) == (0))) != 0) && ((b((13.1) < (f.param_11))) != 0))) != 0) && ((b((12.0) < (f.param_10))) != 0))) != 0) && ((b((f.fVar22) < (2.5))) != 0))) != 0) 4612 else 21
        }
        4614 -> {
            f.fVar40 = f32(((f.fVar57) - (f.param_10)))
            4613
        }
        4615 -> {
            f.iVar15 = readI32(f.param_1.plus(0x174))
            4614
        }
        4616 -> {
            8
        }
        4617 -> {
            42
        }
        4618 -> {
            if ((b((readI32(f.param_1.plus(0x210))) < (2))) != 0) 4617 else 4616
        }
        4619 -> {
            if ((b(((b((13.0) < (f.param_12))) != 0) && ((b(((b((f.fVar57) < (0.6))) != 0) || ((b((f.fVar35) < (0.6))) != 0))) != 0))) != 0) 4618 else 4615
        }
        4620 -> {
            42
        }
        4621 -> {
            if ((b(((b(((b(((b((f.dVar62) < (DAT_0012ce60))) != 0) && ((run { run { f.fVar40 = f32(readF32(f.param_1.plus(0x170))); f32(readF32(f.param_1.plus(0x170))) }; b(((b((f.fVar40) < (3.5))) != 0) && ((b((1.2) < (((f.fVar55) - (f.fVar40))))) != 0)) }) != 0))) != 0) && ((b((3.0) < (f.fVar40))) != 0))) != 0) && ((b((6.5) < (readF32(f.param_1.plus(0x230))))) != 0))) != 0) 4620 else 4619
        }
        4622 -> {
            f.iVar16 = f.iVar21
            4621
        }
        4623 -> {
            f.dVar62 = f.fVar55
            4622
        }
        4624 -> {
            7
        }
        4625 -> {
            if ((b((f.dVar42) <= (DAT_0012ce98))) != 0) 4624 else 4623
        }
        4626 -> {
            f.dVar42 = readF32(f.param_1.plus(0x24c))
            4625
        }
        4627 -> {
            7
        }
        4628 -> {
            if ((b(((b(((b((DAT_0012ce90) <= (f.dVar39))) != 0) && ((b((9.0) <= (f.fVar54))) != 0))) != 0) || ((b((9.5) <= (f.fVar55))) != 0))) != 0) 4627 else 4626
        }
        4629 -> {
            f.dVar39 = f.param_12
            4628
        }
        4630 -> {
            f.iVar21 = 1
            18
        }
        4631 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((f.fVar40) * (f.dVar39)))))
            4630
        }
        4632 -> {
            f.dVar39 = DAT_0012ce80
            17
        }
        4633 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4632
        }
        4634 -> {
            if ((b((readI32(f.param_1.plus(0x174))) == (0))) != 0) 4633 else 4630
        }
        4635 -> {
            17
        }
        4636 -> {
            f.dVar39 = 0.95
            4635
        }
        4637 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4636
        }
        4638 -> {
            if ((b((readI32(f.param_1.plus(0x174))) == (0))) != 0) 4637 else 4630
        }
        4639 -> {
            18
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep145(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4640 -> {
            if ((b((f.iVar21) != (1))) != 0) 4639 else 4638
        }
        4641 -> {
            17
        }
        4642 -> {
            f.dVar39 = DAT_0012ce78
            4641
        }
        4643 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4642
        }
        4644 -> {
            if ((b((readI32(f.param_1.plus(0x174))) == (0))) != 0) 4643 else 4630
        }
        4645 -> {
            6
        }
        4646 -> {
            if ((b(((b((f.param_14) < (0xea1))) != 0) || ((b((f.iVar21) != (1))) != 0))) != 0) 4645 else 4644
        }
        4647 -> {
            if ((b(uLt(((f.param_14) - (0xd81)), 0x11f))) != 0) 4640 else 4646
        }
        4648 -> {
            if ((b(((b(uLt(((f.param_14) - (0xc61)), 0x11f))) != 0) && ((b((f.iVar21) == (1))) != 0))) != 0) 4634 else 4647
        }
        4649 -> {
            f.iVar21 = readI32(f.param_1.plus(0x254))
            4648
        }
        4650 -> {
            writeI32(f.param_1.plus(0x1fc), 1)
            4649
        }
        4651 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(f.dVar39)))
            4650
        }
        4652 -> {
            writeI32(f.param_1.plus(0x210), 2)
            4651
        }
        4653 -> {
            f.dVar39 = ((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce88))
            4652
        }
        4654 -> {
            f.iVar19 = 1
            4653
        }
        4655 -> {
            if ((b(((b(((b((f.fVar35) < (0.5))) != 0) && ((b((0x360) < (f.param_14))) != 0))) != 0) && ((b(((b((108.0) < (readF32(f.param_1.plus(8))))) != 0) && ((b((readF32(f.param_1.plus(0x170))) < (3.0))) != 0))) != 0))) != 0) 4654 else 4649
        }
        4656 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            16
        }
        4657 -> {
            5
        }
        4658 -> {
            writeI32(f.param_1.plus(0x208), readI32(f.param_1.plus(0x20c)))
            4657
        }
        4659 -> {
            f.iVar19 = 0
            4658
        }
        4660 -> {
            16
        }
        4661 -> {
            if ((b(((b(((b(((b((f.param_11) <= (13.2))) != 0) || ((b((f.iVar19) != (0))) != 0))) != 0) || ((b((f.param_12) <= (10.5))) != 0))) != 0) || ((b((0x35f) < (f.param_14))) != 0))) != 0) 4660 else 4659
        }
        4662 -> {
            if ((b(((b(((b((f.param_14) < (0x361))).or((f.bVar12).xor(1))) != 0)) != 0) || ((b((readI32(f.param_1.plus(0x174))) != (0))) != 0))) != 0) 4661 else 15
        }
        4663 -> {
            writeF32(f.param_1.plus(0x208), f32(f32(((readF32(f.param_1.plus(0x20c))) * (DAT_0012ce80)))))
            16
        }
        4664 -> {
            15
        }
        4665 -> {
            if ((b(((b((9.0) < (readF32(f.param_1.plus(0x1d8))))) != 0) && ((b((9.0) < (readF32(f.param_1.plus(0x1d4))))) != 0))) != 0) 4664 else 4663
        }
        4666 -> {
            4
        }
        4667 -> {
            f.dVar39 = 0.95
            4666
        }
        4668 -> {
            f.fVar40 = f32(readF32(f.param_1.plus(0x20c)))
            4667
        }
        4669 -> {
            if ((b((f.param_14) < (0x241))) != 0) 4668 else 4665
        }
        4670 -> {
            if ((b(((b((0x360) < (f.param_14))) != 0) || ((b(((f.bVar12).xor(1)) != 0)) != 0))) != 0) 4662 else 4669
        }
        4671 -> {
            f.bVar10 = b((b((0x360) < (f.param_14))) != 0)
            4670
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep146(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4672 -> {
            f.bVar12 = b((b((f.iVar19) == (1))) != 0)
            14
        }
        4673 -> {
            f.bVar7 = b((0) != 0)
            4672
        }
        4674 -> {
            f.iVar19 = readI32(f.param_1.plus(0x1fc))
            4673
        }
        4675 -> {
            writeI32(f.param_1.plus(0x1fc), 0)
            13
        }
        4676 -> {
            3
        }
        4677 -> {
            writeI32(f.param_1.plus(0x1fc), 1)
            4676
        }
        4678 -> {
            if ((b(((b(((b(((b(((b((f.param_14) < (0x241))) != 0) || ((b((readF32(f.param_1.plus(0x1d8))) <= (9.0))) != 0))) != 0) || ((b((readF32(f.param_1.plus(0x1d4))) <= (9.0))) != 0))) != 0) || ((b(((b((((readF32(f.param_1.plus(0x13c))) - (readF32(f.param_1.plus(0x170))))) <= (2.0))) != 0) || ((b((3.9) <= (readF32(f.param_1.plus(0x170))))) != 0))) != 0))) != 0) || ((b((48.0) <= (readF32(f.param_1.plus(0x18c))))) != 0))) != 0) 11 else 12
        }
        4679 -> {
            0
        }
        4680 -> {
            if ((b(((b((5.0) <= (f.fVar55))) != 0) || ((b((f.fVar55) <= (0.0))) != 0))) != 0) 4679 else 10
        }
        4681 -> {
            f.bVar7 = b((1) != 0)
            4680
        }
        4682 -> {
            f.fVar55 = f32(readF32(f.param_1.plus(0x234)))
            4681
        }
        4683 -> {
            f.bVar8 = b((1) != 0)
            9
        }
        4684 -> {
            f.bVar9 = b((0) != 0)
            4683
        }
        4685 -> {
            f.bVar11 = b((b(uLt(((f.param_14) - (0x121)), 0x11f))) != 0)
            4684
        }
        4686 -> {
            writeI32(f.param_1.plus(0x254), 1)
            4685
        }
        4687 -> {
            if ((b(((b((readF32(f.param_1.plus(0x234))) < (5.0))) != 0) || ((b((0.5) < (((((((readF32(f.param_1.plus(0x230))) - (f.fVar54))) - (f.fVar54))) - (readF32(f.param_1.plus(0x234))))))) != 0))) != 0) 4686 else 4685
        }
        4688 -> {
            if ((b((f.param_14) < (0xc61))) != 0) 4338 else 4687
        }
        4689 -> {
            writeF32(f.param_1.plus(0x194), f32(f.param_4))
            4688
        }
        4690 -> {
            f.fVar35 = f32(((f.param_10) - (f.param_12)))
            4689
        }
        4691 -> {
            f.dVar53 = f.param_10
            4690
        }
        4692 -> {
            f.fVar22 = f32(((f.param_11) - (f.param_12)))
            4691
        }
        4693 -> {
            f.fVar57 = f32(((f.param_11) - (f.param_10)))
            4692
        }
        4694 -> {
            writeI32(f.param_1.plus(0x198), 0)
            4693
        }
        4695 -> {
            writeF32(f.param_1.plus(0x19c), f32(f.param_4))
            4694
        }
        4696 -> {
            writeF32(f.param_1.plus(0x1a0), f32(f.fVar22))
            4695
        }
        4697 -> {
            if ((b(((b((6.0) < (((f.fVar22) - (f.fVar35))))) != 0) && ((run { run { f.fVar22 = f32(((((readF32(f.param_1.plus(0x19c))) - (f.param_4))) / (f32((readI32(f.param_1.plus(0x198))).toDouble())))); f32(((((readF32(f.param_1.plus(0x19c))) - (f.param_4))) / (f32((readI32(f.param_1.plus(0x198))).toDouble())))) }; b((readF32(f.param_1.plus(0x1a0))) < (f.fVar22)) }) != 0))) != 0) 4696 else 4695
        }
        4698 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x134)))
            4697
        }
        4699 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x144)))
            4698
        }
        4700 -> {
            f.fVar35 = f32(readF32(f.param_1.plus(0x154)))
            4697
        }
        4701 -> {
            f.fVar22 = f32(readF32(f.param_1.plus(0x150)))
            4700
        }
        4702 -> {
            if ((b((f.param_14) < (0x121))) != 0) 4699 else 4701
        }
        4703 -> {
            if ((b(((b((f.dVar38) < (DAT_0012cde0))) != 0) && ((b(((b((0.3) < (f.dVar38))) != 0) && ((b((4.5) < (((readF32(f.param_1.plus(0x19c))) - (f.param_4))))) != 0))) != 0))) != 0) 4702 else 4695
        }
        else -> error("bad C state: $pc")
    }
}

private fun ClippingfilterStep147(f: ClippingfilterFrame, pc: Int): Int {
    return when (pc) {
        4704 -> {
            writeI32(f.param_1.plus(0x198), ((readI32(f.param_1.plus(0x198))) + (1)))
            4693
        }
        4705 -> {
            if ((b(((b((f.param_14) < (0x1f))) != 0) || ((b((0.0) <= (((f.param_4) - (readF32(f.param_1.plus(0x194))))))) != 0))) != 0) 4703 else 4704
        }
        4706 -> {
            writeF32(f.param_1.plus(0x1a8), f32(f.fVar54))
            4705
        }
        4707 -> {
            writeF32(f.param_1.plus(0x1a4), f32(((readF32(f.param_1.plus(0x1a4))) + (f.param_4))))
            4706
        }
        4708 -> {
            f.fVar54 = f32(((((readF32(f.param_1.plus(0x1a4))) + (f.param_4))) / (f32((((f.param_14) + (1))).toDouble()))))
            4707
        }
        4709 -> {
            f.dVar38 = f.param_4
            4708
        }
        else -> error("bad C state: $pc")
    }
}

private fun Clipping_filter(param_1: Ptr, param_2: Ptr, param_3: Ptr, param_4: Double, param_5: Double, param_6: Double, param_7: Double, param_8: Double, param_9: Double, param_10: Double, param_11: Double, param_12: Double, param_13: Double, param_14: Int): Int {
    val f = ClippingfilterFrame(param_1, param_2, param_3, f32(param_4), f32(param_5), f32(param_6), f32(param_7), f32(param_8), f32(param_9), f32(param_10), f32(param_11), f32(param_12), f32(param_13), param_14)
    var pc = 4709
    while (true) {
        pc = when (pc / 32) {
            0 -> ClippingfilterStep0(f, pc)
            1 -> ClippingfilterStep1(f, pc)
            2 -> ClippingfilterStep2(f, pc)
            3 -> ClippingfilterStep3(f, pc)
            4 -> ClippingfilterStep4(f, pc)
            5 -> ClippingfilterStep5(f, pc)
            6 -> ClippingfilterStep6(f, pc)
            7 -> ClippingfilterStep7(f, pc)
            8 -> ClippingfilterStep8(f, pc)
            9 -> ClippingfilterStep9(f, pc)
            10 -> ClippingfilterStep10(f, pc)
            11 -> ClippingfilterStep11(f, pc)
            12 -> ClippingfilterStep12(f, pc)
            13 -> ClippingfilterStep13(f, pc)
            14 -> ClippingfilterStep14(f, pc)
            15 -> ClippingfilterStep15(f, pc)
            16 -> ClippingfilterStep16(f, pc)
            17 -> ClippingfilterStep17(f, pc)
            18 -> ClippingfilterStep18(f, pc)
            19 -> ClippingfilterStep19(f, pc)
            20 -> ClippingfilterStep20(f, pc)
            21 -> ClippingfilterStep21(f, pc)
            22 -> ClippingfilterStep22(f, pc)
            23 -> ClippingfilterStep23(f, pc)
            24 -> ClippingfilterStep24(f, pc)
            25 -> ClippingfilterStep25(f, pc)
            26 -> ClippingfilterStep26(f, pc)
            27 -> ClippingfilterStep27(f, pc)
            28 -> ClippingfilterStep28(f, pc)
            29 -> ClippingfilterStep29(f, pc)
            30 -> ClippingfilterStep30(f, pc)
            31 -> ClippingfilterStep31(f, pc)
            32 -> ClippingfilterStep32(f, pc)
            33 -> ClippingfilterStep33(f, pc)
            34 -> ClippingfilterStep34(f, pc)
            35 -> ClippingfilterStep35(f, pc)
            36 -> ClippingfilterStep36(f, pc)
            37 -> ClippingfilterStep37(f, pc)
            38 -> ClippingfilterStep38(f, pc)
            39 -> ClippingfilterStep39(f, pc)
            40 -> ClippingfilterStep40(f, pc)
            41 -> ClippingfilterStep41(f, pc)
            42 -> ClippingfilterStep42(f, pc)
            43 -> ClippingfilterStep43(f, pc)
            44 -> ClippingfilterStep44(f, pc)
            45 -> ClippingfilterStep45(f, pc)
            46 -> ClippingfilterStep46(f, pc)
            47 -> ClippingfilterStep47(f, pc)
            48 -> ClippingfilterStep48(f, pc)
            49 -> ClippingfilterStep49(f, pc)
            50 -> ClippingfilterStep50(f, pc)
            51 -> ClippingfilterStep51(f, pc)
            52 -> ClippingfilterStep52(f, pc)
            53 -> ClippingfilterStep53(f, pc)
            54 -> ClippingfilterStep54(f, pc)
            55 -> ClippingfilterStep55(f, pc)
            56 -> ClippingfilterStep56(f, pc)
            57 -> ClippingfilterStep57(f, pc)
            58 -> ClippingfilterStep58(f, pc)
            59 -> ClippingfilterStep59(f, pc)
            60 -> ClippingfilterStep60(f, pc)
            61 -> ClippingfilterStep61(f, pc)
            62 -> ClippingfilterStep62(f, pc)
            63 -> ClippingfilterStep63(f, pc)
            64 -> ClippingfilterStep64(f, pc)
            65 -> ClippingfilterStep65(f, pc)
            66 -> ClippingfilterStep66(f, pc)
            67 -> ClippingfilterStep67(f, pc)
            68 -> ClippingfilterStep68(f, pc)
            69 -> ClippingfilterStep69(f, pc)
            70 -> ClippingfilterStep70(f, pc)
            71 -> ClippingfilterStep71(f, pc)
            72 -> ClippingfilterStep72(f, pc)
            73 -> ClippingfilterStep73(f, pc)
            74 -> ClippingfilterStep74(f, pc)
            75 -> ClippingfilterStep75(f, pc)
            76 -> ClippingfilterStep76(f, pc)
            77 -> ClippingfilterStep77(f, pc)
            78 -> ClippingfilterStep78(f, pc)
            79 -> ClippingfilterStep79(f, pc)
            80 -> ClippingfilterStep80(f, pc)
            81 -> ClippingfilterStep81(f, pc)
            82 -> ClippingfilterStep82(f, pc)
            83 -> ClippingfilterStep83(f, pc)
            84 -> ClippingfilterStep84(f, pc)
            85 -> ClippingfilterStep85(f, pc)
            86 -> ClippingfilterStep86(f, pc)
            87 -> ClippingfilterStep87(f, pc)
            88 -> ClippingfilterStep88(f, pc)
            89 -> ClippingfilterStep89(f, pc)
            90 -> ClippingfilterStep90(f, pc)
            91 -> ClippingfilterStep91(f, pc)
            92 -> ClippingfilterStep92(f, pc)
            93 -> ClippingfilterStep93(f, pc)
            94 -> ClippingfilterStep94(f, pc)
            95 -> ClippingfilterStep95(f, pc)
            96 -> ClippingfilterStep96(f, pc)
            97 -> ClippingfilterStep97(f, pc)
            98 -> ClippingfilterStep98(f, pc)
            99 -> ClippingfilterStep99(f, pc)
            100 -> ClippingfilterStep100(f, pc)
            101 -> ClippingfilterStep101(f, pc)
            102 -> ClippingfilterStep102(f, pc)
            103 -> ClippingfilterStep103(f, pc)
            104 -> ClippingfilterStep104(f, pc)
            105 -> ClippingfilterStep105(f, pc)
            106 -> ClippingfilterStep106(f, pc)
            107 -> ClippingfilterStep107(f, pc)
            108 -> ClippingfilterStep108(f, pc)
            109 -> ClippingfilterStep109(f, pc)
            110 -> ClippingfilterStep110(f, pc)
            111 -> ClippingfilterStep111(f, pc)
            112 -> ClippingfilterStep112(f, pc)
            113 -> ClippingfilterStep113(f, pc)
            114 -> ClippingfilterStep114(f, pc)
            115 -> ClippingfilterStep115(f, pc)
            116 -> ClippingfilterStep116(f, pc)
            117 -> ClippingfilterStep117(f, pc)
            118 -> ClippingfilterStep118(f, pc)
            119 -> ClippingfilterStep119(f, pc)
            120 -> ClippingfilterStep120(f, pc)
            121 -> ClippingfilterStep121(f, pc)
            122 -> ClippingfilterStep122(f, pc)
            123 -> ClippingfilterStep123(f, pc)
            124 -> ClippingfilterStep124(f, pc)
            125 -> ClippingfilterStep125(f, pc)
            126 -> ClippingfilterStep126(f, pc)
            127 -> ClippingfilterStep127(f, pc)
            128 -> ClippingfilterStep128(f, pc)
            129 -> ClippingfilterStep129(f, pc)
            130 -> ClippingfilterStep130(f, pc)
            131 -> ClippingfilterStep131(f, pc)
            132 -> ClippingfilterStep132(f, pc)
            133 -> ClippingfilterStep133(f, pc)
            134 -> ClippingfilterStep134(f, pc)
            135 -> ClippingfilterStep135(f, pc)
            136 -> ClippingfilterStep136(f, pc)
            137 -> ClippingfilterStep137(f, pc)
            138 -> ClippingfilterStep138(f, pc)
            139 -> ClippingfilterStep139(f, pc)
            140 -> ClippingfilterStep140(f, pc)
            141 -> ClippingfilterStep141(f, pc)
            142 -> ClippingfilterStep142(f, pc)
            143 -> ClippingfilterStep143(f, pc)
            144 -> ClippingfilterStep144(f, pc)
            145 -> ClippingfilterStep145(f, pc)
            146 -> ClippingfilterStep146(f, pc)
            147 -> ClippingfilterStep147(f, pc)
            else -> error("bad C chunk: $pc")
        }
        if (pc == C_DONE) {
            return f.result
        }
    }
}


internal data class ExactV115GClipResult(
    val initialSensitivity: Float,
    val activeSensitivity: Float,
    val compensationSize: Float,
    val calibrationBaseline: Float,
)

/**
 * Generated managed port of v1.1.5G's Clipping_filter/adjustment_range/
 * Calibration_baseline trio.  The three byte arrays intentionally preserve the
 * recovered native layout; do not replace them with field-by-field state.
 */
internal class ExactV115GClip {
    private val clip = Ptr(ByteArray(CLIP_SIZE))
    private val adjustment = Ptr(ByteArray(ADJUSTMENT_SIZE))
    private val calibration = Ptr(ByteArray(CALIBRATION_SIZE))

    init {
        initClipContext(clip)
        initCalibrationContext(calibration)
    }

    val initialSensitivity: Float get() = readF32(clip.plus(0x20c)).toFloat()
    val activeSensitivity: Float get() = readF32(clip.plus(0x208)).toFloat()
    val compensationSize: Float get() = readF32(clip.plus(0x250)).toFloat()
    val calibrationBaseline: Float get() = readF32(clip.plus(0x008)).toFloat()

    /** Raw little-endian clipping-context reads for ExactV115G's base branch. */
    internal fun floatAt(offset: Int): Float {
        require(offset in 0..CLIP_SIZE - 4) { "clip float offset out of range: $offset" }
        return readF32(clip.plus(offset)).toFloat()
    }

    internal fun intAt(offset: Int): Int {
        require(offset in 0..CLIP_SIZE - 4) { "clip int offset out of range: $offset" }
        return readI32(clip.plus(offset))
    }

    fun state(): ExactV115GClipResult = ExactV115GClipResult(
        initialSensitivity = initialSensitivity,
        activeSensitivity = activeSensitivity,
        compensationSize = compensationSize,
        calibrationBaseline = calibrationBaseline,
    )

    fun update(
        adjusted: Float,
        filter1: Float,
        filter2: Float,
        filter3: Float,
        filter4: Float,
        filter5: Float,
        tempRunningM20: Float,
        tempUpAverage: Float,
        tempDownAverage: Float,
        base: Float,
        stageCount: Int,
    ): ExactV115GClipResult {
        Clipping_filter(
            clip, adjustment, calibration,
            adjusted.toDouble(), filter1.toDouble(), filter2.toDouble(),
            filter3.toDouble(), filter4.toDouble(), filter5.toDouble(),
            tempRunningM20.toDouble(), tempUpAverage.toDouble(), tempDownAverage.toDouble(),
            base.toDouble(), stageCount,
        )
        return state()
    }

    /** Versioned raw state; restore() validates before modifying any context. */
    fun snapshot(): ByteArray {
        val out = ByteArray(SNAPSHOT_SIZE)
        val header = Ptr(out)
        writeI32(header.plus(0), SNAPSHOT_MAGIC)
        writeI32(header.plus(4), SNAPSHOT_VERSION)
        writeI32(header.plus(8), CLIP_SIZE)
        writeI32(header.plus(12), ADJUSTMENT_SIZE)
        writeI32(header.plus(16), CALIBRATION_SIZE)
        clip.bytes.copyInto(out, HEADER_SIZE)
        adjustment.bytes.copyInto(out, HEADER_SIZE + CLIP_SIZE)
        calibration.bytes.copyInto(out, HEADER_SIZE + CLIP_SIZE + ADJUSTMENT_SIZE)
        return out
    }

    fun restore(snapshot: ByteArray): Boolean {
        if (snapshot.size != SNAPSHOT_SIZE) return false
        val header = Ptr(snapshot)
        if (
            readI32(header.plus(0)) != SNAPSHOT_MAGIC ||
            readI32(header.plus(4)) != SNAPSHOT_VERSION ||
            readI32(header.plus(8)) != CLIP_SIZE ||
            readI32(header.plus(12)) != ADJUSTMENT_SIZE ||
            readI32(header.plus(16)) != CALIBRATION_SIZE
        ) return false
        // All checks complete: each copy is now in-bounds, so state changes together.
        snapshot.copyInto(clip.bytes, 0, HEADER_SIZE, HEADER_SIZE + CLIP_SIZE)
        snapshot.copyInto(adjustment.bytes, 0, HEADER_SIZE + CLIP_SIZE, HEADER_SIZE + CLIP_SIZE + ADJUSTMENT_SIZE)
        snapshot.copyInto(calibration.bytes, 0, HEADER_SIZE + CLIP_SIZE + ADJUSTMENT_SIZE, SNAPSHOT_SIZE)
        return true
    }

    companion object {
        private const val CLIP_SIZE = 0x4e4
        private const val ADJUSTMENT_SIZE = 0x400
        private const val CALIBRATION_SIZE = 0x4c
        private const val HEADER_SIZE = 20
        private const val SNAPSHOT_SIZE = HEADER_SIZE + CLIP_SIZE + ADJUSTMENT_SIZE + CALIBRATION_SIZE
        private const val SNAPSHOT_MAGIC = 0x53434c50 // "SCLP" little-endian raw marker
        private const val SNAPSHOT_VERSION = 2
    }
}
