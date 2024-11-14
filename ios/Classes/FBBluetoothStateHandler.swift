import Flutter

class FBBluetoothStateHandler: NSObject, FlutterStreamHandler {
    
    // MARK: - Properties
    
    /// Riferimento debole al plugin principale per evitare cicli di riferimento
    private weak var flutterBeaconPlugin: DchsFlutterBeaconPlugin?
    
    /// Event sink per inviare eventi a Flutter
    var eventSink: FlutterEventSink?
    
    // MARK: - Initializer
    
    /// Inizializza l'handler con un'istanza del plugin principale
    /// - Parameter flutterBeaconPlugin: L'istanza del plugin principale
    init(flutterBeaconPlugin: DchsFlutterBeaconPlugin) {
        self.flutterBeaconPlugin = flutterBeaconPlugin
    }
    
    // MARK: - FlutterStreamHandler Methods
    
    /// Gestisce l'ascolto degli eventi (onListen)
    /// - Parameters:
    ///   - arguments: Argomenti passati dal lato Flutter (se presenti)
    ///   - events: L'event sink per inviare eventi a Flutter
    /// - Returns: Eventuali errori durante l'ascolto
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        flutterBeaconPlugin?.flutterEventSinkBluetooth = events
        flutterBeaconPlugin?.initializeCentralManager()
        return nil
    }
    
    /// Gestisce la cancellazione dell'ascolto degli eventi (onCancel)
    /// - Parameter arguments: Argomenti passati dal lato Flutter (se presenti)
    /// - Returns: Eventuali errori durante la cancellazione
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        flutterBeaconPlugin?.flutterEventSinkBluetooth = nil
        self.eventSink = nil
        return nil
    }
}
