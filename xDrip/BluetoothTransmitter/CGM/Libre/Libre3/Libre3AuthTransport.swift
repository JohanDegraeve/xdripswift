//
//  Libre3AuthTransport.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// One transport per BLE connection. CoreBluetooth callbacks feed this actor, the
/// transmitter supplies writes on BluetoothTransmitter's existing central queue.
/// A terminated connection cannot satisfy operations belonging to its successor.
actor Libre3AuthTransport: Libre3CommandPairingTransport {
    enum Channel: Hashable, Sendable { case certificate, challenge, command }
    typealias Writer = @Sendable (Data, Channel) async throws -> Void
    private let writer: Writer
    private var buffered: [Channel: [Data]] = [:]
    private var waiters: [Channel: (UUID, CheckedContinuation<Data, Error>)] = [:]
    private var failure: Error?

    init(writer: @escaping Writer) { self.writer = writer }

    func write(_ message: Data, to characteristic: Libre3BleCharRef) async throws {
        let channel: Channel = characteristic == .certHandshake ? .certificate : .challenge
        for fragment in Libre3BleFraming.fragmentForWrite(message) {
            try Task.checkCancellation()
            if let failure { throw failure }
            try await writer(fragment, channel)
        }
    }

    func writeCommand(_ command: UInt8) async throws {
        if let failure { throw failure }
        try Task.checkCancellation()
        try await writer(Data([command]), .command)
    }

    func awaitNotify(on characteristic: Libre3BleCharRef, exactly n: Int) async throws -> Data {
        guard n > 0, n <= 512 else { throw Libre3ConnectionError.malformed }
        let channel: Channel = characteristic == .certHandshake ? .certificate : .challenge
        // Sequence numbering starts again for each logical security message.
        let assembler = Libre3BleFraming.NotifyReassembler()
        while assembler.availableBytes < n {
            let fragment = try await next(on: channel, timeout: 15)
            try assembler.feed(fragment)
            guard assembler.availableBytes <= n else { throw Libre3ConnectionError.malformed }
        }
        return try assembler.take(n)
    }

    func awaitCommandResponse(timeout: TimeInterval) async throws -> Data {
        try await next(on: .command, timeout: timeout)
    }

    func receive(_ data: Data, on channel: Channel) {
        guard failure == nil else { return }
        guard !data.isEmpty, data.count <= 512 else {
            finish(Libre3ConnectionError.malformed)
            return
        }
        if let (_, waiter) = waiters.removeValue(forKey: channel) {
            waiter.resume(returning: data)
        } else {
            // Bound unsolicited traffic, including when authentication has stopped.
            guard buffered[channel, default: []].count < 64 else {
                finish(Libre3ConnectionError.malformed)
                return
            }
            buffered[channel, default: []].append(data)
        }
    }

    func finish(_ error: Error = Libre3ConnectionError.disconnected) {
        guard failure == nil else { return }
        failure = error
        let pending = waiters.values.map { $0.1 }
        waiters.removeAll()
        buffered.removeAll()
        pending.forEach { $0.resume(throwing: error) }
    }

    private func next(on channel: Channel, timeout: TimeInterval) async throws -> Data {
        try Task.checkCancellation()
        if let failure { throw failure }
        if var queue = buffered[channel], !queue.isEmpty {
            let data = queue.removeFirst()
            buffered[channel] = queue
            return data
        }
        guard waiters[channel] == nil else { throw Libre3ConnectionError.malformed }
        let id = UUID()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                waiters[channel] = (id, continuation)
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(min(max(timeout, 0.1), 60) * 1_000_000_000))
                    self.expire(channel, id: id)
                }
            }
        }, onCancel: {
            Task { await self.cancel(channel, id: id) }
        })
    }

    private func expire(_ channel: Channel, id: UUID) {
        guard waiters[channel]?.0 == id else { return }
        finish(Libre3ConnectionError.timeout)
    }

    private func cancel(_ channel: Channel, id: UUID) {
        guard waiters[channel]?.0 == id else { return }
        finish(CancellationError())
    }
}
