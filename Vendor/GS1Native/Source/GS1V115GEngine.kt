package gs1.nativecore

import gs1.compat.ByteArrayInputStream
import gs1.compat.ByteArrayOutputStream
import gs1.compat.DataInputStream
import gs1.compat.DataOutputStream
import tk.glucodata.drivers.sibionics.SibionicsExactV115GCore

private const val CORE_REVISION = "11e6e29db7d9055c8fd2e96261812e16f2095f3d:V115G:compat1"

/** Transport-neutral statuses. A correction is a final core result, never the raw input. */
enum class GS1CoreStatus { CORRECTION, NO_CORRECTION, INVALID_CONFIGURATION, INVALID_INPUT, NON_CONTIGUOUS_INDEX, INVALID_OUTPUT }

class GS1CoreResult internal constructor(
    val status: GS1CoreStatus,
    val sensorIndex: Int,
    val finalMmol: Float?,
)

/**
 * Isolated V1.1.5G conversion core. No BLE, activation, timestamps or CGM export.
 * Feed every minute in order. The first supplied index is caller-controlled:
 * the caller must establish complete history and warmup before treating results as CGM.
 * This engine emits only five-minute final corrections; it never carries raw values.
 * Calls must be serialized by the caller.
 */
class GS1V115GEngine(private val sensorIdentity: String, private val factorySensitivity: Float) {
    private val configured = sensorIdentity.isNotEmpty() && sensorIdentity.encodeToByteArray().size <= 256 &&
        factorySensitivity.isFinite() && factorySensitivity in 0.8f..2.5f
    private var core = SibionicsExactV115GCore(factorySensitivity)
    private var lastIndex = -1

    val algorithmVersion: String get() = CORE_REVISION
    val lastAcceptedIndex: Int get() = lastIndex

    fun accept(rawMmol: Float, temperatureC: Float, index: Int): GS1CoreResult {
        fun result(status: GS1CoreStatus, value: Float? = null) = GS1CoreResult(status, index, value)
        if (!configured) return result(GS1CoreStatus.INVALID_CONFIGURATION)
        if (!rawMmol.isFinite() || rawMmol < 0f || !temperatureC.isFinite() || index !in 1..65535) {
            return result(GS1CoreStatus.INVALID_INPUT)
        }
        if (lastIndex >= 0 && index != lastIndex + 1) return result(GS1CoreStatus.NON_CONTIGUOUS_INDEX)
        // Zero is a real no-reading sample. Feed it unchanged and advance the
        // sensor index; the upstream core returns null and never publishes it.
        val correction = core.process(rawMmol, temperatureC, index)
        lastIndex = index
        if (correction == null) return result(GS1CoreStatus.NO_CORRECTION)
        if (!correction.isFinite() || correction <= 0f || correction > 50f) return result(GS1CoreStatus.INVALID_OUTPUT)
        return result(GS1CoreStatus.CORRECTION, correction)
    }

    fun snapshot(): ByteArray? {
        if (!configured) return null
        val body = ByteArrayOutputStream().use { bytes ->
            DataOutputStream(bytes).use { output ->
                output.writeInt(0x4753314e) // GS1N
                output.writeInt(2) // Envelope format; core revision is mandatory.
                output.writeInt(115)
                val revision = CORE_REVISION.encodeToByteArray()
                output.writeInt(revision.size)
                output.write(revision)
                val identity = sensorIdentity.encodeToByteArray()
                output.writeInt(identity.size)
                output.write(identity)
                output.writeFloat(factorySensitivity)
                output.writeInt(lastIndex)
                val state = core.snapshot()
                output.writeInt(state.size)
                output.write(state)
            }
            bytes.toByteArray()
        }
        return ByteArrayOutputStream().use { bytes ->
            DataOutputStream(bytes).use { output ->
                output.write(body)
                output.writeInt(crc32(body))
            }
            bytes.toByteArray()
        }
    }

    /** Failed restore leaves the active engine intact, including its accepted index. */
    fun restore(snapshot: ByteArray): Boolean = runCatching {
        if (!configured || snapshot.size !in 36..131072) return false
        val body = snapshot.copyOfRange(0, snapshot.size - 4)
        val suppliedCrc = DataInputStream(ByteArrayInputStream(snapshot.copyOfRange(snapshot.size - 4, snapshot.size))).readInt()
        if (suppliedCrc != crc32(body)) return false
        DataInputStream(ByteArrayInputStream(body)).use { input ->
            if (input.readInt() != 0x4753314e || input.readInt() != 2 || input.readInt() != 115) return false
            val revisionSize = input.readInt()
            if (revisionSize !in 1..128) return false
            val revision = ByteArray(revisionSize)
            input.readFully(revision)
            if (!revision.contentEquals(CORE_REVISION.encodeToByteArray())) return false
            val identitySize = input.readInt()
            if (identitySize !in 1..256) return false
            val identity = ByteArray(identitySize)
            input.readFully(identity)
            if (!identity.contentEquals(sensorIdentity.encodeToByteArray())) return false
            if (input.readFloat().toRawBits() != factorySensitivity.toRawBits()) return false
            val restoredIndex = input.readInt()
            if (restoredIndex != -1 && restoredIndex !in 1..65535) return false
            val stateSize = input.readInt()
            if (stateSize !in 1..65536 || stateSize != input.available()) return false
            val state = ByteArray(stateSize)
            input.readFully(state)
            val candidate = SibionicsExactV115GCore(factorySensitivity)
            if (!candidate.restore(state)) return false
            core = candidate
            lastIndex = restoredIndex
            true
        }
    }.getOrDefault(false)
}

/** Accidental-corruption protection for local checkpoints, not an authentication mechanism. */
private fun crc32(bytes: ByteArray): Int {
    var crc = -1
    bytes.forEach { byte ->
        crc = crc xor (byte.toInt() and 0xff)
        repeat(8) { crc = (crc ushr 1) xor (if (crc and 1 != 0) 0xedb88320.toInt() else 0) }
    }
    return crc.inv()
}
