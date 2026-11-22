import CoreBluetooth
import Flutter
import UIKit

final class AskBLE: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let methods: FlutterMethodChannel
    private let events: FlutterEventChannel
    private var sink: FlutterEventSink?
    private var central: CBCentralManager?
    private var discovered: [UUID: CBPeripheral] = [:]
    private var closing: Set<UUID> = []
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?
    private var notifications: [CBUUID: CBCharacteristic] = [:]
    private var flow = BLEFlow()
    private var ready = false
    private var active = true
    private var opening: FlutterResult?
    private var connectionTimer: Timer?
    private var scanTimer: Timer?
    private var epoch = 0
    private var writeResult: FlutterResult?
    private var writeBytes = Data()
    private var writeOffset = 0
    private var writeTimer: Timer?
    private var writeDeadline: Timer?
    private var nextWriteAt = 0.0
    private weak var presenter: UIViewController?
    private let service = CBUUID(string: "FF00")
    private let command = CBUUID(string: "FF02")
    private let response = CBUUID(string: "FF01")
    private let flowID = CBUUID(string: "FF03")
    private let indication = CBUUID(string: "FF05")

    init(messenger: FlutterBinaryMessenger, presenter: UIViewController) {
        self.presenter = presenter
        methods = FlutterMethodChannel(name: "dk.ask.p21.ios/methods", binaryMessenger: messenger)
        events = FlutterEventChannel(name: "dk.ask.p21.ios/events", binaryMessenger: messenger)
        super.init()
        events.setStreamHandler(self)
        methods.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    private func emit(_ value: [String: Any]) { sink?(value) }
    private func note(_ text: String) { emit(["type":"note", "message":text]) }
    private func error(_ result: FlutterResult, _ code: String, _ message: String) { result(FlutterError(code:code,message:message,details:nil)) }
    private func ensureCentral() {
        if central == nil { central = CBCentralManager(delegate:self,queue:.main) }
    }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink=events; return nil }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { sink=nil; return nil }
    @objc private func background() { active=false; close("App backgrounded; no replay") }
    @objc private func foreground() { active=true; emitState() }
    private func emitState() {
        let state = central?.state ?? .unknown
        emit(["type":"state", "state":stateName(state)])
    }
    private func stateName(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn:return "poweredOn"
        case .poweredOff:return "poweredOff"
        case .unauthorized:return "unauthorized"
        case .unsupported:return "unsupported"
        case .resetting:return "resetting"
        default:return "unknown"
        }
    }
    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let a=call.arguments as? [String:Any] ?? [:]
        switch call.method {
        case "access":ensureCentral(); emitState(); result(nil)
        case "scan":
            ensureCentral()
            guard active, central?.state == .poweredOn else { error(result,"bluetooth_unavailable","Enable Bluetooth and grant access, then search again"); return }
            guard peripheral == nil else { error(result,"busy","Disconnect before searching");return }
            central?.stopScan(); discovered.removeAll(); scanTimer?.invalidate()
            // Deliberately unfiltered: some revisions may not advertise FF00.
            central?.scanForPeripherals(withServices:nil,options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
            note("BLE discovery, 10 seconds; FF00 is a candidate profile, not hardware proof")
            scanTimer=Timer.scheduledTimer(withTimeInterval:10,repeats:false) { [weak self] _ in self?.central?.stopScan();self?.emit(["type":"scanDone"]) }
            result(nil)
        case "stopScan":central?.stopScan();scanTimer?.invalidate();emit(["type":"scanDone"]);result(nil)
        case "connect":
            guard active, central?.state == .poweredOn else { error(result,"bluetooth_unavailable","Bluetooth not ready");return }
            guard peripheral == nil, opening == nil else { error(result,"busy","A session is already open");return }
            guard let idText=a["id"] as? String, let id=UUID(uuidString:idText), let p=discovered[id] ?? central?.retrievePeripherals(withIdentifiers:[id]).first else {
                error(result,"not_found","Search for the printer again");return
            }
            guard !closing.contains(id) else { error(result,"disconnect_pending","Previous BLE disconnect is pending; retry shortly");return }
            central?.stopScan();scanTimer?.invalidate();epoch+=1
            peripheral=p;p.delegate=self;ready=false;flow.reset();tx=nil;notifications.removeAll();opening=result
            connectionTimer=Timer.scheduledTimer(withTimeInterval:20,repeats:false) { [weak self] _ in self?.close("BLE service/notification/credit setup timed out") }
            note("Connecting \(idText); FF00 / FF02 write / FF01 notify; iOS BLE NOT hardware-confirmed")
            central?.connect(p,options:nil)
        case "disconnect":close("Manual disconnect");result(nil)
        case "write":
            guard active,ready,let p=peripheral,let c=tx,p.state == .connected else { error(result,"not_connected","No ready BLE session");return }
            guard writeResult == nil else { error(result,"busy","A BLE write is pending");return }
            guard let bytes=a["bytes"] as? FlutterStandardTypedData, !bytes.data.isEmpty, bytes.data.count<=65536 else { error(result,"invalid_data","Invalid binary write");return }
            guard c.properties.contains(.writeWithoutResponse) else { error(result,"profile","FF02 lacks writeWithoutResponse");return }
            writeBytes=bytes.data;writeOffset=0;writeResult=result
            writeDeadline=Timer.scheduledTimer(withTimeInterval:12,repeats:false) { [weak self] _ in self?.close("BLE write timed out; partial delivery unknown; never replayed") }
            pump()
        case "export":
            guard let text=a["text"] as? String,text.utf8.count<1024*1024, let presenter=presenter,presenter.presentedViewController == nil else { error(result,"export_busy","Cannot open local export sheet");return }
            do {
                let folder=FileManager.default.temporaryDirectory.appendingPathComponent("ASKLogs",isDirectory:true)
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                // One export file; avoid unbounded local diagnostic copies.
                let url=folder.appendingPathComponent("NELKO-P21-ASK-iOS-test.log")
                try text.write(to:url,atomically:true,encoding:.utf8)
                let picker=UIActivityViewController(activityItems:[url],applicationActivities:nil)
                picker.popoverPresentationController?.sourceView=presenter.view
                picker.popoverPresentationController?.sourceRect=CGRect(x:presenter.view.bounds.midX,y:presenter.view.bounds.midY,width:1,height:1)
                picker.completionWithItemsHandler={ _,done,_,_ in result(done) }
                presenter.present(picker,animated:true)
            } catch { self.error(result,"storage",error.localizedDescription) }
        default:result(FlutterMethodNotImplemented)
        }
    }
    private func close(_ reason: String) {
        central?.stopScan(); scanTimer?.invalidate();connectionTimer?.invalidate();connectionTimer=nil
        writeTimer?.invalidate();writeTimer=nil;writeDeadline?.invalidate();writeDeadline=nil
        let pendingOpen=opening;opening=nil;let pendingWrite=writeResult;writeResult=nil
        if let p=peripheral {
            if p.state != .disconnected { closing.insert(p.identifier); central?.cancelPeripheralConnection(p) }
            p.delegate=nil
        }
        peripheral=nil;tx=nil;ready=false;flow.reset();notifications.removeAll();writeBytes=Data();writeOffset=0;nextWriteAt=0
        if let r=pendingOpen { error(r,"connection_closed",reason) }
        if let r=pendingWrite { error(r,"connection_closed",reason) }
        epoch+=1;emit(["type":"closed","reason":reason,"epoch":epoch])
    }
    private func checkReady() {
        guard !ready,tx != nil,notifications[response]?.isNotifying == true else { return }
        guard notifications.values.allSatisfy({ $0.isNotifying }) else { return }
        if notifications[flowID] != nil && flow.credits == nil { return }
        ready=true;connectionTimer?.invalidate();connectionTimer=nil
        note("BLE profile ready; 20-byte cap / >=12ms spacing; \(notifications[flowID] == nil ? "paced-only (no FF03)" : "FF03 credits enabled"); NOT proof of printing")
        let result=opening;opening=nil;result?(nil)
    }
    private func pump() {
        guard writeResult != nil,active,ready,let p=peripheral,let c=tx else { return }
        guard p.canSendWriteWithoutResponse,flow.maySend else { return }
        let now=ProcessInfo.processInfo.systemUptime
        if now<nextWriteAt {
            if writeTimer == nil { writeTimer=Timer.scheduledTimer(withTimeInterval:nextWriteAt-now,repeats:false) { [weak self] _ in self?.writeTimer=nil;self?.pump() } }
            return
        }
        let size=min(20,flow.payloadLimit,p.maximumWriteValueLength(for:.withoutResponse),writeBytes.count-writeOffset)
        guard size>0,flow.consume() else { close("Invalid BLE packet capacity");return }
        let packet=writeBytes.subdata(in:writeOffset..<writeOffset+size)
        p.writeValue(packet,for:c,type:.withoutResponse)
        writeOffset+=size;nextWriteAt=now+0.012
        emit(["type":"tx","bytes":FlutterStandardTypedData(bytes:packet),"epoch":epoch,"characteristic":"FF02"])
        if writeOffset==writeBytes.count {
            let result=writeResult;let count=writeOffset;writeResult=nil;writeDeadline?.invalidate();writeDeadline=nil;writeBytes=Data();writeOffset=0
            result?(count) // CoreBluetooth API acceptance, not a printer acknowledgement.
        } else { pump() }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emitState()
        if central.state != .poweredOn && peripheral != nil { close("Bluetooth state changed: \(stateName(central.state))") }
    }
    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String:Any], rssi RSSI: NSNumber) {
        discovered[p.identifier]=p
        let ids=(advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map{$0.uuidString}
        emit(["type":"device","id":p.identifier.uuidString,"name":p.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unnamed BLE device","rssi":RSSI.intValue,"services":ids])
    }
    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        guard !closing.contains(p.identifier), p === peripheral else { central.cancelPeripheralConnection(p);return }
        note("Connected; discovering FF00 services");p.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        if closing.remove(p.identifier) != nil { return }
        if p === peripheral { close("Connect failed: \(error?.localizedDescription ?? "unknown")") }
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        if closing.remove(p.identifier) != nil { return }
        if p === peripheral { close("Disconnected: \(error?.localizedDescription ?? "link closed")") }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard p === peripheral else { return }
        if let e=error { close("Service discovery: \(e.localizedDescription)");return }
        note("GATT services: \((p.services ?? []).map{$0.uuid.uuidString}.joined(separator:", "))")
        guard let s=p.services?.first(where:{$0.uuid==service}) else { close("FF00 service not found; unsupported candidate profile");return }
        p.discoverCharacteristics(nil,for:s)
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard p === peripheral else { return }
        if let e=error { close("Characteristic discovery: \(e.localizedDescription)");return }
        note("GATT characteristics: \((service.characteristics ?? []).map{ "\($0.uuid.uuidString) props=\($0.properties.rawValue)" }.joined(separator:", "))")
        guard let c=service.characteristics?.first(where:{$0.uuid==command && $0.properties.contains(.writeWithoutResponse)}),
              let r=service.characteristics?.first(where:{$0.uuid==response && $0.properties.contains(.notify)}) else { close("FF02 writeWithoutResponse / FF01 notify profile missing");return }
        tx=c;notifications[response]=r
        for candidate in service.characteristics ?? [] {
            if (candidate.uuid==flowID || candidate.uuid==indication) && (candidate.properties.contains(.notify) || candidate.properties.contains(.indicate)) { notifications[candidate.uuid]=candidate }
        }
        for c in notifications.values { p.setNotifyValue(true,for:c) }
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        guard p === peripheral else { return }
        if let e=error { close("Subscribe \(c.uuid): \(e.localizedDescription)");return }
        guard c.isNotifying else { close("Required notification stopped: \(c.uuid)");return }
        checkReady()
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard p === peripheral else { return }
        if let e=error { close("RX \(c.uuid): \(e.localizedDescription)");return }
        guard let data=c.value else { return }
        emit(["type":"rx","bytes":FlutterStandardTypedData(bytes:data),"characteristic":c.uuid.uuidString,"epoch":epoch])
        if c.uuid==flowID {
            if !flow.receive(data) { note("Unknown FF03 frame; raw bytes preserved") }
            checkReady();pump()
        }
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { if peripheral === self.peripheral { pump() } }
}
