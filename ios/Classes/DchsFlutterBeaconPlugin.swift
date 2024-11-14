import Flutter
import UIKit
import CoreBluetooth
import CoreLocation

/*

public class DchsFlutterBeaconPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dchs_flutter_beacon", binaryMessenger: registrar.messenger())
    let instance = DchsFlutterBeaconPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}


*/


public class DchsFlutterBeaconPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    
    // MARK: - Properties
    
    // Event Sinks per gestire gli eventi di ranging, monitoring, Bluetooth e autorizzazione
    var flutterEventSinkRanging: FlutterEventSink?
    var flutterEventSinkMonitoring: FlutterEventSink?
    var flutterEventSinkBluetooth: FlutterEventSink?
    var flutterEventSinkAuthorization: FlutterEventSink?
    
    private var defaultLocationAuthorizationType: CLAuthorizationStatus = .authorizedAlways
    private var shouldStartAdvertise: Bool = false
    
    private var locationManager: CLLocationManager?
    private var bluetoothManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var regionRanging: [CLBeaconRegion] = []
    private var regionMonitoring: [CLBeaconRegion] = []
    private var beaconPeripheralData: [String: Any]?
    
    private var flutterResult: FlutterResult?
    private var flutterBluetoothResult: FlutterResult?
    private var flutterBroadcastResult: FlutterResult?
    
    // MARK: - FlutterPlugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dchs_flutter_beacon", binaryMessenger: registrar.messenger())
        let instance = DchsFlutterBeaconPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Initialize Event Channels
        instance.rangingHandler = FBRangingStreamHandler(flutterBeaconPlugin: instance)
        let streamChannelRanging = FlutterEventChannel(name: "flutter_beacon_event", binaryMessenger: registrar.messenger())
        streamChannelRanging.setStreamHandler(instance.rangingHandler)
        
        instance.monitoringHandler = FBMonitoringStreamHandler(flutterBeaconPlugin: instance)
        let streamChannelMonitoring = FlutterEventChannel(name: "flutter_beacon_event_monitoring", binaryMessenger: registrar.messenger())
        streamChannelMonitoring.setStreamHandler(instance.monitoringHandler)
        
        instance.bluetoothHandler = FBBluetoothStateHandler(flutterBeaconPlugin: instance)
        let streamChannelBluetooth = FlutterEventChannel(name: "flutter_bluetooth_state_changed", binaryMessenger: registrar.messenger())
        streamChannelBluetooth.setStreamHandler(instance.bluetoothHandler)
        
        instance.authorizationHandler = FBAuthorizationStatusHandler(flutterBeaconPlugin: instance)
        let streamChannelAuthorization = FlutterEventChannel(name: "flutter_authorization_status_changed", binaryMessenger: registrar.messenger())
        streamChannelAuthorization.setStreamHandler(instance.authorizationHandler)
    }
    
    // MARK: - Initializer
    
    override init() {
        super.init()
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        // Initialize other managers if necessary
    }
    
    // MARK: - Handle Method Calls
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeLocationManager()
            initializeCentralManager()
            result(true)
            
        case "initializeAndCheck":
            initializeWithResult(result: result)
            
        case "setLocationAuthorizationTypeDefault":
            if let argumentAsString = call.arguments as? String {
                switch argumentAsString {
                case "ALWAYS":
                    self.defaultLocationAuthorizationType = .authorizedAlways
                    result(true)
                case "WHEN_IN_USE":
                    self.defaultLocationAuthorizationType = .authorizedWhenInUse
                    result(true)
                default:
                    result(false)
                }
            } else {
                result(false)
            }
            
        case "authorizationStatus":
            initializeLocationManager()
            let status = CLLocationManager.authorizationStatus()
            switch status {
            case .notDetermined:
                result("NOT_DETERMINED")
            case .restricted:
                result("RESTRICTED")
            case .denied:
                result("DENIED")
            case .authorizedAlways:
                result("ALWAYS")
            case .authorizedWhenInUse:
                result("WHEN_IN_USE")
            @unknown default:
                result("UNKNOWN")
            }
            
        case "checkLocationServicesIfEnabled":
            result(CLLocationManager.locationServicesEnabled())
            
        case "bluetoothState":
            self.flutterBluetoothResult = result
            initializeCentralManager()
            
            // Delay 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, let bluetoothResult = self.flutterBluetoothResult else { return }
                switch self.bluetoothManager?.state {
                case .unknown:
                    bluetoothResult("STATE_UNKNOWN")
                case .resetting:
                    bluetoothResult("STATE_RESETTING")
                case .unsupported:
                    bluetoothResult("STATE_UNSUPPORTED")
                case .unauthorized:
                    bluetoothResult("STATE_UNAUTHORIZED")
                case .poweredOff:
                    bluetoothResult("STATE_OFF")
                case .poweredOn:
                    bluetoothResult("STATE_ON")
                case .none:
                    bluetoothResult("STATE_UNKNOWN")
                @unknown default:
                    bluetoothResult("STATE_UNKNOWN")
                }
                self.flutterBluetoothResult = nil
            }
            
        case "requestAuthorization":
            if let locationManager = self.locationManager {
                self.flutterResult = result
                requestDefaultLocationManagerAuthorization()
            } else {
                result(true)
            }
            
        case "openBluetoothSettings":
            // Non implementato per evitare il rifiuto dell'app da parte di Apple
            // Vedi commenti nel codice Objective-C per implementare se necessario
            result(true)
            
        case "openLocationSettings":
            // Non implementato per evitare il rifiuto dell'app da parte di Apple
            // Vedi commenti nel codice Objective-C per implementare se necessario
            result(true)
            
        case "setScanPeriod", "setBetweenScanPeriod":
            // Non implementato
            result(true)
            
        case "openApplicationSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            result(true)
            
        case "close":
            stopRangingBeacon()
            stopMonitoringBeacon()
            result(true)
            
        case "startBroadcast":
            if let arguments = call.arguments {
                self.flutterBroadcastResult = result
                startBroadcast(arguments: arguments)
            } else {
                result(FlutterError(code: "Invalid Arguments", message: "Arguments are missing", details: nil))
            }
            
        case "stopBroadcast":
            if let peripheralManager = self.peripheralManager {
                peripheralManager.stopAdvertising()
            }
            result(nil)
            
        case "isBroadcasting":
            if let peripheralManager = self.peripheralManager {
                result(peripheralManager.isAdvertising)
            } else {
                result(false)
            }
            
        case "isBroadcastSupported":
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Initialization Methods
    
    private func initializeCentralManager() {
        if self.bluetoothManager == nil {
            self.bluetoothManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        }
    }
    
    private func initializeLocationManager() {
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
        }
    }
    
    private func initializeWithResult(result: @escaping FlutterResult) {
        self.flutterResult = result
        initializeLocationManager()
        initializeCentralManager()
    }
    
    // MARK: - Authorization
    
    private func requestDefaultLocationManagerAuthorization() {
        switch self.defaultLocationAuthorizationType {
        case .authorizedWhenInUse:
            self.locationManager?.requestWhenInUseAuthorization()
        case .authorizedAlways:
            fallthrough
        default:
            self.locationManager?.requestAlwaysAuthorization()
        }
    }
    
    // MARK: - Broadcasting
    
    private func startBroadcast(arguments: Any) {
        guard let dict = arguments as? [String: Any] else {
            self.flutterBroadcastResult?(FlutterError(code: "Invalid Arguments", message: "Arguments are not a dictionary", details: nil))
            self.flutterBroadcastResult = nil
            return
        }
        
        let measuredPower = dict["txPower"] as? NSNumber
        guard let region = FBUtils.region(from: dict) else {
            self.flutterBroadcastResult?(FlutterError(code: "Invalid Region", message: "Could not create CLBeaconRegion from arguments", details: nil))
            self.flutterBroadcastResult = nil
            return
        }
        
        self.shouldStartAdvertise = true
        self.beaconPeripheralData = region.peripheralData(withMeasuredPower: measuredPower)?.copy() as? [String: Any]
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Ranging
    
    private func startRangingBeacon(arguments: Any) {
        self.regionRanging.removeAll()
        
        guard let array = arguments as? [[String: Any]] else { return }
        for dict in array {
            if let region = FBUtils.region(from: dict) {
                self.regionRanging.append(region)
            }
        }
        
        for region in self.regionRanging {
            print("START: \(region)")
            self.locationManager?.startRangingBeacons(in: region)
        }
    }
    
    private func stopRangingBeacon() {
        for region in self.regionRanging {
            self.locationManager?.stopRangingBeacons(in: region)
        }
        self.rangingHandler?.eventSink = nil
    }
    
    // MARK: - Monitoring
    
    private func startMonitoringBeacon(arguments: Any) {
        self.regionMonitoring.removeAll()
        
        guard let array = arguments as? [[String: Any]] else { return }
        for dict in array {
            if var region = FBUtils.region(from: dict) {
                region.notifyOnEntry = true
                region.notifyOnExit = true
                self.regionMonitoring.append(region)
            }
        }
        
        for region in self.regionMonitoring {
            print("START: \(region)")
            self.locationManager?.startMonitoring(for: region)
        }
    }
    
    private func stopMonitoringBeacon() {
        for region in self.regionMonitoring {
            self.locationManager?.stopMonitoring(for: region)
        }
        self.monitoringHandler?.eventSink = nil
    }
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var message: String?
        
        switch central.state {
        case .unknown:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_UNKNOWN")
                self.flutterBluetoothResult = nil
                return
            }
            message = "CBManagerStateUnknown"
            flutterEventSinkBluetooth?("STATE_UNKNOWN")
            
        case .resetting:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_RESETTING")
                self.flutterBluetoothResult = nil
                return
            }
            message = "CBManagerStateResetting"
            flutterEventSinkBluetooth?("STATE_RESETTING")
            
        case .unsupported:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_UNSUPPORTED")
                self.flutterBluetoothResult = nil
                return
            }
            message = "CBManagerStateUnsupported"
            flutterEventSinkBluetooth?("STATE_UNSUPPORTED")
            
        case .unauthorized:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_UNAUTHORIZED")
                self.flutterBluetoothResult = nil
                return
            }
            message = "CBManagerStateUnauthorized"
            flutterEventSinkBluetooth?("STATE_UNAUTHORIZED")
            
        case .poweredOff:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_OFF")
                self.flutterBluetoothResult = nil
                return
            }
            message = "CBManagerStatePoweredOff"
            flutterEventSinkBluetooth?("STATE_OFF")
            
        case .poweredOn:
            if let bluetoothResult = self.flutterBluetoothResult {
                bluetoothResult("STATE_ON")
                self.flutterBluetoothResult = nil
                return
            }
            flutterEventSinkBluetooth?("STATE_ON")
            
            if CLLocationManager.locationServicesEnabled() {
                switch CLLocationManager.authorizationStatus() {
                case .notDetermined:
                    requestDefaultLocationManagerAuthorization()
                    return
                case .denied:
                    message = "CLAuthorizationStatusDenied"
                case .restricted:
                    message = "CLAuthorizationStatusRestricted"
                default:
                    break
                }
            } else {
                message = "LocationServicesDisabled"
            }
            
        @unknown default:
            message = "Unknown State"
        }
        
        if let flutterResult = self.flutterResult {
            if let message = message {
                flutterResult(FlutterError(code: "Beacon", message: message, details: nil))
            } else {
                flutterResult(nil)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var message: String?
        
        switch status {
        case .authorizedAlways:
            flutterEventSinkAuthorization?("ALWAYS")
            // Gestisci lo scanning se necessario
        case .authorizedWhenInUse:
            flutterEventSinkAuthorization?("WHEN_IN_USE")
            // Gestisci lo scanning se necessario
        case .denied:
            flutterEventSinkAuthorization?("DENIED")
            message = "CLAuthorizationStatusDenied"
        case .restricted:
            flutterEventSinkAuthorization?("RESTRICTED")
            message = "CLAuthorizationStatusRestricted"
        case .notDetermined:
            flutterEventSinkAuthorization?("NOT_DETERMINED")
            message = "CLAuthorizationStatusNotDetermined"
        @unknown default:
            flutterEventSinkAuthorization?("UNKNOWN")
            message = "Unknown Authorization Status"
        }
        
        if let flutterResult = self.flutterResult {
            if let message = message {
                flutterResult(FlutterError(code: "Beacon", message: message, details: nil))
            } else {
                flutterResult(nil)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], in region: CLBeaconRegion) {
        guard let eventSink = flutterEventSinkRanging else { return }
        
        let dictRegion = FBUtils.dictionary(from: region)
        let array = beacons.map { FBUtils.dictionary(from: $0) }
        
        eventSink([
            "region": dictRegion,
            "beacons": array
        ])
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let beaconRegion = region as? CLBeaconRegion else { return }
        guard let eventSink = flutterEventSinkMonitoring else { return }
        
        let dictRegion = FBUtils.dictionary(from: beaconRegion)
        eventSink([
            "event": "didEnterRegion",
            "region": dictRegion
        ])
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let beaconRegion = region as? CLBeaconRegion else { return }
        guard let eventSink = flutterEventSinkMonitoring else { return }
        
        let dictRegion = FBUtils.dictionary(from: beaconRegion)
        eventSink([
            "event": "didExitRegion",
            "region": dictRegion
        ])
    }
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let beaconRegion = region as? CLBeaconRegion else { return }
        guard let eventSink = flutterEventSinkMonitoring else { return }
        
        let dictRegion = FBUtils.dictionary(from: beaconRegion)
        let stateString: String
        switch state {
        case .inside:
            stateString = "INSIDE"
        case .outside:
            stateString = "OUTSIDE"
        case .unknown:
            stateString = "UNKNOWN"
        @unknown default:
            stateString = "UNKNOWN"
        }
        
        eventSink([
            "event": "didDetermineStateForRegion",
            "region": dictRegion,
            "state": stateString
        ])
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if shouldStartAdvertise, let peripheralData = beaconPeripheralData {
                peripheral.startAdvertising(peripheralData)
                shouldStartAdvertise = false
            }
        default:
            break
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard let flutterBroadcastResult = self.flutterBroadcastResult else { return }
        
        if let error = error {
            flutterBroadcastResult(FlutterError(code: "Broadcast", message: error.localizedDescription, details: error))
        } else {
            flutterBroadcastResult(peripheral.isAdvertising)
        }
        self.flutterBroadcastResult = nil
    }
    
    // MARK: - Helper Methods
    
    private func _parseBoolResult(_ result: Any?) -> Bool {
        if let boolResult = result as? Bool {
            return boolResult
        } else if let intResult = result as? Int {
            return intResult == 1
        }
        return false
    }
}
