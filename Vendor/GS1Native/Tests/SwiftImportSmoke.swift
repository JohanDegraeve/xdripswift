import Foundation
import GS1Native

let core = GS1V115GEngine(sensorIdentity: "synthetic-swift-smoke", factorySensitivity: 1.4)
let zero = core.accept(rawMmol: 0, temperatureC: 33, index: 1)
precondition(zero.status == .noCorrection && zero.finalMmol == nil)
precondition(core.lastAcceptedIndex == 1)
let next = core.accept(rawMmol: 10, temperatureC: 33, index: 2)
precondition(next.status == .noCorrection && next.finalMmol == nil)
let snapshot = core.snapshot()!
let data = Data((0..<snapshot.size).map { UInt8(bitPattern: snapshot.get(index: $0)) })
let restoredBytes = KotlinByteArray(size: Int32(data.count))
for (i, byte) in data.enumerated() {
    restoredBytes.set(index: Int32(i), value: Int8(bitPattern: byte))
}
let restored = GS1V115GEngine(sensorIdentity: "synthetic-swift-smoke", factorySensitivity: 1.4)
precondition(restored.restore(snapshot: restoredBytes))
precondition(restored.lastAcceptedIndex == 2)
precondition(!GS1V115GEngine(sensorIdentity: "other", factorySensitivity: 1.4).restore(snapshot: restoredBytes))
for index: Int32 in 3...100 {
    let a = core.accept(rawMmol: 10, temperatureC: 33, index: index)
    let b = restored.accept(rawMmol: 10, temperatureC: 33, index: index)
    precondition(a.status == b.status)
    precondition(a.finalMmol?.floatValue == b.finalMmol?.floatValue)
}
print("Swift interop smoke: snapshot roundtrip, identity rejection, zero input and continuation succeeded")
