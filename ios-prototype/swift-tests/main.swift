import Foundation
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
var flow = BLEFlow()
check(flow.reportedCredits == nil, "No invented credit reports")
check(!flow.receive(Data([1])), "Reject truncated credit report")
check(!flow.receive(Data([2,0,0])), "Reject zero payload")
check(!flow.receive(Data([3,7])), "Reject unknown type")
check(flow.receive(Data([1,7])), "Replay real initial FF03 report 01 07")
check(flow.receive(Data([2,127,0])) && flow.payloadLimit == 20, "Replay real payload report 02 7F 00; retain 20-byte cap")
check(flow.packetLength(remaining:100,maximumWriteLength:127,canSend:false)==0, "Apple backpressure must block writes")
check(flow.packetLength(remaining:100,maximumWriteLength:8,canSend:true)==8, "Honor CoreBluetooth maximum")
check(flow.packetLength(remaining:3,maximumWriteLength:127,canSend:true)==3, "Short final packet")
check(flow.packetLength(remaining:0,maximumWriteLength:127,canSend:true)==0, "No empty packet")
check(flow.packetLength(remaining:20,maximumWriteLength:0,canSend:true)==0, "No invalid capacity")
// Regression: the exact hardware sequence must pass packet seven with NO
// further FF03 notifications. The actual native pump uses packetLength too.
let fixture = try Data(contentsOf:URL(fileURLWithPath:"../test/fixtures/windows_reference.bin"))
var job=Data([0x1b,0x21,0x6f]);job.append(fixture)
var offset=0, packets=0
var emitted=Data()
while offset<job.count {
    let count=flow.packetLength(remaining:job.count-offset,maximumWriteLength:127,canSend:true)
    check(count>0 && count<=20, "No deadlock after seventh packet")
    emitted.append(job.subdata(in:offset..<offset+count));offset+=count;packets+=1
}
check(packets>7 && emitted==job, "Deliver complete Windows reference byte-exactly, not just seven packets")
check(emitted.suffix(9)==Data("PRINT 1\r\n".utf8), "Reach PRINT after all bitmap bytes")
check(flow.reportedCredits==7, "Preserve observed credit value; do not fabricate/decrement permits")
var zero = BLEFlow()
check(zero.receive(Data([1,0])) && zero.reportedCredits==0 && zero.packetLength(remaining:20,maximumWriteLength:127,canSend:true)==20, "Zero reported FF03 credits cannot deadlock paced FF02")
check(flow.receive(Data([2,8,0])) && flow.packetLength(remaining:20,maximumWriteLength:127,canSend:true)==8, "Honor smaller reported payload")
for _ in 0..<100 { _ = flow.receive(Data([1,255])) }
check(flow.reportedCredits==4096, "Bound diagnostic counter")
flow.reset()
check(flow.reportedCredits==nil && flow.payloadLimit==20, "Reset across connections")
print("BLEFlow: hardware 01 07 / 02 7F 00 replay, full reference past seven packets, Apple backpressure, caps, bounds and reset passed")
