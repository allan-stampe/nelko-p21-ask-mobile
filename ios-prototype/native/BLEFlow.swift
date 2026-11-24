import Foundation

// Independently implemented from published wire-format facts; no upstream code copied.
// FF03 reports are diagnostic observations, NOT permits for FF02 writes.
// Hardware log 2026-11-24: no replenishment after the initial 01 07; gating
// FF02 on that counter deadlocked both print jobs before bitmap/PRINT.
struct BLEFlow {
    private(set) var reportedCredits: Int? = nil
    private(set) var payloadLimit = 20
    mutating func reset() { reportedCredits = nil; payloadLimit = 20 }
    mutating func receive(_ data: Data) -> Bool {
        let b = Array(data)
        if b.count == 2 && b[0] == 1 {
            reportedCredits = min(4096, (reportedCredits ?? 0) + Int(b[1]))
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
    func packetLength(remaining: Int, maximumWriteLength: Int, canSend: Bool) -> Int {
        guard canSend, remaining > 0, maximumWriteLength > 0 else { return 0 }
        return min(20, payloadLimit, maximumWriteLength, remaining)
    }
}
