package gs1.compat

/** Minimal big-endian java.io subset used by upstream snapshots. No algorithm math here. */
internal class ByteArrayOutputStream : AutoCloseable {
    private var bytes = ByteArray(1024)
    private var size = 0
    fun write(value: Int) {
        if (size == bytes.size) bytes = bytes.copyOf(bytes.size * 2)
        bytes[size++] = value.toByte()
    }
    fun write(value: ByteArray) = value.forEach { write(it.toInt()) }
    fun toByteArray(): ByteArray = bytes.copyOf(size)
    override fun close() = Unit
}

internal class ByteArrayInputStream(private val bytes: ByteArray) : AutoCloseable {
    private var position = 0
    fun read(): Int {
        require(position < bytes.size) { "Truncated GS1 snapshot" }
        return bytes[position++].toInt() and 0xff
    }
    fun available(): Int = bytes.size - position
    override fun close() = Unit
}

internal class DataOutputStream(private val output: ByteArrayOutputStream) : AutoCloseable {
    fun writeInt(value: Int) { for (shift in 24 downTo 0 step 8) output.write(value ushr shift) }
    // java.io.DataOutputStream.writeFloat uses Float.floatToIntBits (canonical NaN).
    fun writeFloat(value: Float) = writeInt(if (value.isNaN()) 0x7fc00000 else value.toRawBits())
    fun writeBoolean(value: Boolean) = output.write(if (value) 1 else 0)
    fun write(value: ByteArray) = output.write(value)
    override fun close() = Unit
}

internal class DataInputStream(private val input: ByteArrayInputStream) : AutoCloseable {
    fun readInt(): Int = (input.read() shl 24) or (input.read() shl 16) or (input.read() shl 8) or input.read()
    fun readFloat(): Float = Float.fromBits(readInt())
    fun readBoolean(): Boolean = input.read() != 0
    fun readFully(bytes: ByteArray) { bytes.indices.forEach { bytes[it] = input.read().toByte() } }
    fun available(): Int = input.available()
    override fun close() = Unit
}

/** Kotlin copyInto has the same overlapping-array semantics required by System.arraycopy. */
internal fun arrayCopy(source: FloatArray, sourceStart: Int, destination: FloatArray, destinationStart: Int, size: Int) {
    source.copyInto(destination, destinationStart, sourceStart, sourceStart + size)
}

internal fun compareUnsigned(a: Int, b: Int): Int = a.toUInt().compareTo(b.toUInt())
