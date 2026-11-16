package dk.ask.nelko_p21_ask_mobile

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

// Bluetooth permissions are checked before adapter/device/socket access. Blocking
// connect, write, close and file operations never run on Android's UI thread.
@SuppressLint("MissingPermission")
class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val files = Executors.newSingleThreadExecutor()
    private val closer = Executors.newCachedThreadPool()
    private val guard = Any()
    private var sink: EventChannel.EventSink? = null
    private var adapter: BluetoothAdapter? = null
    private var serial = 0L
    private var pending: BluetoothSocket? = null
    private var active: BluetoothSocket? = null
    private var activeEpoch = -1
    private var activeAddress = ""
    private var receiverRegistered = false
    private var permissionResult: MethodChannel.Result? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportText: String? = null
    private val spp = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    private val prefs by lazy { getSharedPreferences("ask_mobile_local_v1", Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dk.ask.nelko_p21_ask_mobile/bluetooth").setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dk.ask.nelko_p21_ask_mobile/events").setStreamHandler(this)
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        else registerReceiver(receiver, filter)
        receiverRegistered = true
    }
    private fun permissions(): Array<String> = if (Build.VERSION.SDK_INT >= 31)
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    private fun hasAccess() = permissions().all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    private fun requireAdapter(): BluetoothAdapter {
        if (!hasAccess()) throw SecurityException("Bluetooth runtime permissions not granted")
        val a = adapter ?: throw IllegalStateException("Bluetooth unavailable")
        if (!a.isEnabled) throw IllegalStateException("Bluetooth disabled")
        return a
    }
    private fun emit(event: Map<String, Any?>) { main.post { if (!isDestroyed) sink?.success(event) } }
    private fun success(result: MethodChannel.Result, value: Any? = null) { main.post { result.success(value) } }
    private fun failure(result: MethodChannel.Result, e: Throwable, code: String = "io") {
        main.post { result.error(if (e is SecurityException) "permission_denied" else code, e.message ?: e.javaClass.simpleName, null) }
    }
    private fun describe(d: BluetoothDevice): Map<String, Any?> = mapOf(
        "type" to "device", "address" to d.address, "name" to (d.name ?: ""),
        "paired" to (d.bondState == BluetoothDevice.BOND_BONDED), "typeId" to d.type,
        "uuids" to (d.uuids?.map { it.uuid.toString() } ?: emptyList<String>())
    )
    private fun deviceMap(d: BluetoothDevice): Map<String, Any?> = describe(d).toMutableMap().apply {
        remove("typeId"); put("type", d.type)
    }
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            try {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        if (!hasAccess()) return
                        val d = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        else @Suppress("DEPRECATION") intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        if (d != null) emit(mapOf("type" to "device", "device" to deviceMap(d)))
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> emit(mapOf("type" to "discoveryFinished"))
                    BluetoothAdapter.ACTION_STATE_CHANGED -> {
                        val enabled = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.STATE_OFF) == BluetoothAdapter.STATE_ON
                        emit(mapOf("type" to "adapter", "enabled" to enabled))
                        if (!enabled) closeConnection("Bluetooth adapter off", null)
                    }
                }
            } catch (e: Exception) { emit(mapOf("type" to "error", "message" to (e.message ?: "Bluetooth broadcast error"))) }
        }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "state" -> result.success(mapOf("available" to (adapter != null), "access" to hasAccess(),
                    "enabled" to (hasAccess() && adapter?.isEnabled == true), "sdk" to Build.VERSION.SDK_INT))
                "requestAccess" -> {
                    if (hasAccess()) result.success(true)
                    else if (permissionResult != null) result.error("permission_busy", "Permission request already open", null)
                    else { permissionResult = result; requestPermissions(permissions(), 100) }
                }
                "enableBluetooth" -> {
                    if (!hasAccess()) throw SecurityException("Grant Nearby Devices / legacy discovery permissions first")
                    if (adapter == null) { result.error("unsupported", "Bluetooth unavailable", null); return }
                    if (adapter?.isEnabled != true) startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                    result.success(null)
                }
                "openBluetoothSettings" -> { startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)); result.success(null) }
                "bondedDevices" -> result.success(requireAdapter().bondedDevices.map { deviceMap(it) })
                "startDiscovery" -> {
                    val a = requireAdapter()
                    a.cancelDiscovery()
                    if (!a.startDiscovery()) result.error("scan_failed", "Discovery rejected; check permissions and legacy Location Services", null)
                    else result.success(null)
                }
                "stopDiscovery" -> { if (hasAccess()) adapter?.cancelDiscovery(); result.success(null) }
                "connect" -> connect(call, result)
                "disconnect" -> closeConnection("Requested disconnect", result)
                "write" -> write(call, result)
                "loadPreferences" -> result.success(mapOf("language" to prefs.getString("language", "da"),
                    "autoReconnect" to prefs.getBoolean("autoReconnect", true), "address" to prefs.getString("address", ""), "name" to prefs.getString("name", "")))
                "savePreferences" -> {
                    val data = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    files.execute {
                        val ok = prefs.edit().putString("language", if (data["language"] == "en") "en" else "da")
                            .putBoolean("autoReconnect", data["autoReconnect"] != false)
                            .putString("address", data["address"] as? String ?: "")
                            .putString("name", data["name"] as? String ?: "").commit()
                        if (ok) success(result) else failure(result, IOException("Could not persist local preferences"), "storage")
                    }
                }
                "exportLog" -> {
                    if (exportResult != null) { result.error("export_busy", "Export picker already open", null); return }
                    val text = call.argument<String>("text") ?: ""
                    if (text.length > 1024 * 1024) { result.error("storage", "Log too large", null); return }
                    exportResult = result; exportText = text
                    try {
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE); type = "text/plain"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "ASK-Mobile.log")
                            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                        }, 101)
                    } catch (e: Exception) { exportResult = null; exportText = null; throw e }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            failure(result, e, if (adapter == null) "unsupported" else if (hasAccess() && adapter?.isEnabled != true) "bluetooth_off" else "io")
        }
    }
    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val a = requireAdapter()
        val address = call.argument<String>("address") ?: ""
        val epoch = call.argument<Number>("epoch")?.toInt() ?: -1
        if (!BluetoothAdapter.checkBluetoothAddress(address) || epoch < 0) { result.error("invalid_argument", "Invalid address/session", null); return }
        val device = a.getRemoteDevice(address)
        if (device.type == BluetoothDevice.DEVICE_TYPE_LE) { result.error("ble_unsupported", "v0.0.1 uses Classic SPP; BLE transport is deferred", null); return }
        a.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(spp)
        val id: Long
        synchronized(guard) {
            if (active != null || pending != null) { socket.close(); result.error("connect_busy", "Close previous session first", null); return }
            serial++; id = serial; pending = socket
        }
        io.execute {
            try {
                synchronized(guard) { if (serial != id || pending !== socket) throw IOException("Cancelled connection") }
                socket.connect()
                synchronized(guard) {
                    if (serial != id || pending !== socket) throw IOException("Cancelled late connection")
                    active = socket; pending = null; activeEpoch = epoch; activeAddress = address
                }
                Thread({ readSocket(socket, id, epoch, address) }, "ASK-Bluetooth-RX").start()
                success(result)
            } catch (e: Exception) {
                synchronized(guard) { if (pending === socket) pending = null; if (active === socket) active = null }
                try { socket.close() } catch (_: Exception) {}
                failure(result, e, "connect_failed")
            }
        }
    }
    private fun readSocket(socket: BluetoothSocket, id: Long, epoch: Int, address: String) {
        try {
            val buffer = ByteArray(4096)
            while (true) {
                val n = socket.inputStream.read(buffer)
                if (n < 0) throw IOException("Bluetooth input stream closed")
                if (n > 0) emit(mapOf("type" to "rx", "bytes" to buffer.copyOf(n), "epoch" to epoch, "address" to address))
            }
        } catch (e: Exception) {
            val current = synchronized(guard) {
                if (serial == id && active === socket) { active = null; serial++; true } else false
            }
            try { socket.close() } catch (_: Exception) {}
            if (current) emit(mapOf("type" to "disconnected", "epoch" to epoch, "address" to address, "reason" to (e.message ?: "Read failed")))
        }
    }
    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("bytes")
        val epoch = call.argument<Number>("epoch")?.toInt() ?: -1
        if (data == null || data.size > 65536) { result.error("invalid_argument", "Invalid byte buffer", null); return }
        val socket: BluetoothSocket
        val id: Long
        synchronized(guard) {
            if (active == null || epoch != activeEpoch) { result.error("not_connected", "No matching session", null); return }
            socket = active!!; id = serial
        }
        io.execute {
            try {
                synchronized(guard) { if (serial != id || active !== socket) throw IOException("Stale write session") }
                socket.outputStream.write(data)
                socket.outputStream.flush()
                // OutputStream has no partial-count result. On IOException delivery
                // is unknown; never fabricate an accepted byte count or replay.
                success(result, data.size)
            } catch (e: Exception) { failure(result, e) }
        }
    }
    private fun closeConnection(reason: String, result: MethodChannel.Result?) {
        val sockets: List<BluetoothSocket>
        val epoch: Int
        val address: String
        synchronized(guard) {
            serial++; sockets = listOfNotNull(active, pending).distinct()
            epoch = activeEpoch; address = activeAddress
            active = null; pending = null; activeEpoch = -1; activeAddress = ""
        }
        closer.execute {
            sockets.forEach { try { it.close() } catch (_: Exception) {} }
            if (epoch >= 0) emit(mapOf("type" to "disconnected", "epoch" to epoch, "address" to address, "reason" to reason))
            if (result != null) success(result)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) { permissionResult?.success(hasAccess()); permissionResult = null }
    }
    @Deprecated("Android activity-result compatibility for the local document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 101) return
        val result = exportResult ?: return
        val text = exportText ?: ""
        exportResult = null; exportText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(false); return }
        files.execute {
            try {
                val output = contentResolver.openOutputStream(uri, "wt") ?: throw IOException("Could not open destination")
                output.bufferedWriter(Charsets.UTF_8).use { it.write(text) }
                success(result, true)
            } catch (e: Exception) { failure(result, e, "storage") }
        }
    }
    override fun onDestroy() {
        if (receiverRegistered) { unregisterReceiver(receiver); receiverRegistered = false }
        closeConnection("Activity destroyed", null)
        permissionResult?.error("cancelled", "Activity destroyed", null); permissionResult = null
        exportResult?.error("cancelled", "Activity destroyed", null); exportResult = null; exportText = null
        sink = null
        io.shutdownNow(); files.shutdown(); closer.shutdown()
        super.onDestroy()
    }
}
