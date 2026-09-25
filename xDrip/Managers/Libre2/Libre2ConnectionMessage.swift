import Foundation
import WatchConnectivity

/// Live request/reply messages are used for transfers; only revocations are queued.
struct Libre2ConnectionMessage: Codable {
    enum Kind: String, Codable { case prepare, ready, activate, returnPrepare, returnCommit, acknowledged, revoke, failed }
    static let key = "directLibreConnection"
    let kind: Kind
    var session: Libre2WatchSession?
    var id: UUID?
    var retiredIDs: Set<UUID>?
    var error: String?

    func dictionary() throws -> [String: Any] { [Self.key: try JSONEncoder().encode(self)] }
    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data else { throw Libre2ConnectionError("Missing Libre transfer message.") }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func send(using connectivity: WCSession = .default, completion: @escaping (Result<Self, Error>) -> Void) {
        guard connectivity.activationState == .activated, connectivity.isReachable else {
            completion(.failure(Libre2ConnectionError("Open the companion app and retry the transfer.")))
            return
        }
        do {
            connectivity.sendMessage(try dictionary(), replyHandler: { response in
                DispatchQueue.main.async {
                    do {
                        let message = try Self.decode(response)
                        if message.kind == .failed { throw Libre2ConnectionError(message.error ?? "Transfer failed.") }
                        completion(.success(message))
                    } catch { completion(.failure(error)) }
                }
            }, errorHandler: { error in DispatchQueue.main.async { completion(.failure(error)) } })
        } catch { completion(.failure(error)) }
    }

    static func reply(_ result: Result<Self, Error>, to handler: @escaping ([String: Any]) -> Void) {
        let message: Self
        switch result {
        case .success(let value): message = value
        case .failure(let error): message = Self(kind: .failed, error: error.localizedDescription)
        }
        handler((try? message.dictionary()) ?? [:])
    }
}
