import Foundation
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
var flow = BLEFlow()
check(flow.credits == nil && flow.maySend, "Optional credit channel: paced-only until configured")
check(!flow.receive(Data([1])), "Reject truncated credits")
check(!flow.receive(Data([2,0,0])), "Reject zero payload")
check(!flow.receive(Data([3,7])), "Reject unknown type")
check(flow.receive(Data([1,0])) && !flow.maySend, "Do not invent credits")
check(!flow.consume(), "No send at zero credits")
check(flow.receive(Data([1,7])), "Initial seven credits")
for _ in 0..<7 { check(flow.consume(), "Consume one packet credit") }
check(!flow.consume(), "Stop after seven packets")
check(flow.receive(Data([1,2])) && flow.receive(Data([1,3])) && flow.credits == 5, "Credits are additive")
check(flow.receive(Data([2,127,0])) && flow.payloadLimit == 20, "Cap advertised 127 at 20")
check(flow.receive(Data([2,8,0])) && flow.payloadLimit == 8, "Honor smaller advertised payload")
for _ in 0..<100 { _ = flow.receive(Data([1,255])) }
check(flow.credits == 4096, "Bound credit accumulator")
flow.reset()
check(flow.credits == nil && flow.payloadLimit == 20, "Reset across connections")
print("BLEFlow: framing, additive credits, exhaustion, payload cap, bounds and reset passed")
