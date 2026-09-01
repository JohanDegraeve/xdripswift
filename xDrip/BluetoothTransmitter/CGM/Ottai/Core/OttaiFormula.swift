//
//  OttaiFormula.swift
//  xdrip
//
//  Ottai / Syai CGM driver — runs the glucose formula from the cloud.
//
//  This is a Swift copy of OttaiFormula.kt from JugglucoNG. The cloud sends a
//  `method` (a small program in reverse Polish notation) and `coefficient`
//  (numbers). We put the values in and run it to get the glucose in mmol/L.
//
//  Method format: groups are separated by `;`. Tokens in a group are separated by
//  spaces. A token is an operator, a number, or a name that we replace first:
//    C{i}  coefficient number i
//    V{i}  V0..V5 = current, temperature, runtime, dataNo, runtime/3600 (int), voltage
//    B{i}  byte i of the 12-byte record, read as a signed number
//    R{i}  the result of group i (an earlier group)
//  The result of the LAST group is the glucose. Values under 0.1 become 0.0.
//

import Foundation

enum OttaiFormula {

    /// The 29 operators. Same order as in the official app.
    private static let operators: Set<String> = [
        "AD", "SB", "ML", "DV", "NG", "AB", "SQ", "PW", "BW", "BE", "GT", "GE",
        "LT", "LE", "RD", "LN", "MX", "MI", "SN", "CS", "TN", "AS", "AC", "AT",
        "BA", "BO", "BN", "BX", "MD",
    ]

    /// Run the [methodText] for one record.
    ///
    /// - Parameters:
    ///   - coefficients: the decrypted numbers (C0..Cn)
    ///   - v: V0..V5: [current, temperature, runtime, dataNo, runtime/3600(int), voltage]
    ///   - recordBytes: the 12-byte record; B{i} uses the SIGNED byte value
    /// - Returns: the glucose value (last group result; under 0.1 becomes 0.0)
    static func evaluate(methodText: String, coefficients: [Double], v: [Double], recordBytes: [UInt8]) -> Double {
        if methodText.trimmingCharacters(in: .whitespaces).isEmpty { return 0.0 }
        let groups = methodText.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        var groupResults: [Double] = []

        for group in groups {
            let rawTokens = group.split(separator: " ").map(String.init).filter { !$0.isEmpty }
            if rawTokens.isEmpty { continue }
            let tokens = rawTokens.map { substitute($0, coefficients: coefficients, v: v, recordBytes: recordBytes, priorResults: groupResults) }
            groupResults.append(evalGroup(tokens))
        }

        guard var adjust = groupResults.last else { return 0.0 }
        if adjust < 0.1 { adjust = 0.0 }
        return adjust
    }

    private static func substitute(_ token: String, coefficients: [Double], v: [Double], recordBytes: [UInt8], priorResults: [Double]) -> String {
        if token.count >= 2 {
            let first = token.first!
            let idxStr = String(token.dropFirst())
            if let idx = Int(idxStr), idx >= 0 {
                switch first {
                case "C": if idx < coefficients.count { return String(coefficients[idx]) }
                case "V": if idx < v.count { return String(v[idx]) }
                case "B": if idx < recordBytes.count { return String(Int(Int8(bitPattern: recordBytes[idx]))) } // signed
                case "R": if idx < priorResults.count { return String(priorResults[idx]) }
                default: break
                }
            }
        }
        return token
    }

    /// Run one group as a stack machine. `sp` starts at -1. A number is pushed
    /// (sp goes up). An operator reads from the stack and writes its result. The
    /// group result is stack[0].
    private static func evalGroup(_ tokens: [String]) -> Double {
        if tokens.isEmpty { return 0.0 }
        var stack = [Double](repeating: 0.0, count: tokens.count)
        var sp = -1
        for tok in tokens {
            let op = tok.uppercased()
            if operators.contains(op) {
                var r = 1.0 // default value in the original app
                switch op {
                case "AD": sp -= 1; r = stack[sp + 1] + stack[sp]
                case "SB": sp -= 1; r = stack[sp] - stack[sp + 1]
                case "ML": sp -= 1; r = stack[sp + 1] * stack[sp]
                case "DV": sp -= 1; r = stack[sp] / stack[sp + 1]
                case "NG": r = -stack[sp]
                case "AB": r = abs(stack[sp])
                case "SQ": r = sqrt(stack[sp])
                case "PW": sp -= 1; r = pow(stack[sp], stack[sp + 1])
                case "BW":
                    sp -= 3
                    r = (stack[sp + 1] >= stack[sp] || stack[sp] >= stack[sp + 2]) ? 0.0
                        : (stack[sp + 3] != 1.0 ? stack[sp] : 1.0)
                case "BE":
                    sp -= 3
                    r = (stack[sp + 1] <= stack[sp] && stack[sp] <= stack[sp + 2] && stack[sp + 3] != 1.0)
                        ? stack[sp] : 1.0
                case "GT": sp -= 2; r = stack[sp] > stack[sp + 1] ? stack[sp + 2] : 0.0
                case "GE": sp -= 2; r = stack[sp] >= stack[sp + 1] ? stack[sp + 2] : 0.0
                case "LT": sp -= 2; r = stack[sp] < stack[sp + 1] ? stack[sp + 2] : 0.0
                case "LE": sp -= 2; r = stack[sp] <= stack[sp + 1] ? stack[sp + 2] : 0.0
                case "RD":
                    sp -= 1
                    let decimals = Int(stack[sp + 1])
                    r = Double(String(format: "%.\(max(0, decimals))f", stack[sp])) ?? stack[sp]
                case "LN": r = log(stack[sp])
                case "MX": sp -= 1; r = max(stack[sp], stack[sp + 1])
                case "MI": sp -= 1; r = min(stack[sp], stack[sp + 1])
                case "SN": r = sin(stack[sp])
                case "CS": r = cos(stack[sp])
                case "TN": r = tan(stack[sp])
                case "AS": r = asin(stack[sp])
                case "AC": r = acos(stack[sp])
                case "AT": r = atan(stack[sp])
                case "BA": sp -= 1; r = Double(Int(stack[sp]) & Int(stack[sp + 1]))
                case "BO": sp -= 1; r = Double(Int(stack[sp]) | Int(stack[sp + 1]))
                case "BN": r = Double(~Int(stack[sp]))
                case "BX": sp -= 1; r = Double(Int(stack[sp]) ^ Int(stack[sp + 1]))
                case "MD": sp -= 1; r = Double(Int(stack[sp]) % Int(stack[sp + 1]))
                default: break
                }
                if sp < 0 { sp = 0 } // protect against a bad formula
                stack[sp] = r
            } else {
                sp += 1
                if sp >= stack.count { return stack.isEmpty ? 0.0 : stack[0] }
                stack[sp] = Double(tok) ?? 0.0
            }
        }
        return stack.isEmpty ? 0.0 : stack[0]
    }

    /// Build the V0..V5 list from one record.
    static func buildVariables(rawCurrent: Int, temperature: Double, runtimeSec: Int, dataNo: Int, voltage: Int) -> [Double] {
        [
            Double(rawCurrent),
            temperature,
            Double(runtimeSec),
            Double(dataNo),
            Double(runtimeSec / 3600), // whole number division, like the original
            Double(voltage),
        ]
    }
}
