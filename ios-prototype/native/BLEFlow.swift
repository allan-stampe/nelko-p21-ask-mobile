import Foundation

// Independently implemented from published wire-format facts; no upstream code copied.
struct BLEFlow {
    private(set) var credits: Int? = nil
    private(set) var payloadLimit = 20
    mutating func reset() { credits = nil; payloadLimit = 20 }
    mutating func receive(_ data: Data) -> Bool {
        let b = Array(data)
        if b.count == 2 && b[0] == 1 {
            credits = min(4096, (credits ?? 0) + Int(b[1]))
            return true
        }
        if b.count == 3 && b[0] == 2 {
            let reported = Int(b[1]) | (Int(b[2]) << 8)
            guard reported > 0 else { return false }
            payloadLimit = min(20, reported)
            return true
        }
        return false
    }
    var maySend: Bool { credits == nil || credits! > 0 }
    mutating func consume() -> Bool {
        guard maySend else { return false }
        if let n = credits { credits = n - 1 }
        return true
    }
}
