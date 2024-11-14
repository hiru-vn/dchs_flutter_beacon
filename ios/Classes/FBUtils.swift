import CoreLocation

class FBUtils {
    
    /// Converte un oggetto CLBeacon in un dizionario [String: Any]
    /// - Parameter beacon: L'istanza di CLBeacon da convertire
    /// - Returns: Un dizionario contenente le informazioni del beacon
    static func dictionary(from beacon: CLBeacon) -> [String: Any] {
        return [
            "proximityUUID": beacon.uuid.uuidString,
            "major": beacon.major.uint16Value,
            "minor": beacon.minor.uint16Value,
            "rssi": beacon.rssi,
            "accuracy": String(format: "%.2f", beacon.accuracy),
            "proximity": proximityString(from: beacon.proximity)
        ]
    }
    
    /// Converte un oggetto CLBeaconRegion in un dizionario [String: Any]
    /// - Parameter region: L'istanza di CLBeaconRegion da convertire
    /// - Returns: Un dizionario contenente le informazioni della regione del beacon
    static func dictionary(from beaconRegion: CLBeaconRegion) -> [String: Any] {
        var dict: [String: Any] = [
            "identifier": beaconRegion.identifier,
            "proximityUUID": beaconRegion.uuid.uuidString
        ]
        
        if let major = beaconRegion.major {
            dict["major"] = major.uint16Value
        } else {
            dict["major"] = NSNull()
        }
        
        if let minor = beaconRegion.minor {
            dict["minor"] = minor.uint16Value
        } else {
            dict["minor"] = NSNull()
        }
        
        return dict
    }
    
    /// Crea un'istanza di CLBeaconRegion a partire da un dizionario [String: Any]
    /// - Parameter dict: Il dizionario contenente le informazioni della regione del beacon
    /// - Returns: Un'istanza di CLBeaconRegion se la conversione ha successo, altrimenti nil
    static func region(from dict: [String: Any]) -> CLBeaconRegion? {
        guard let identifier = dict["identifier"] as? String,
              let proximityUUIDString = dict["proximityUUID"] as? String,
              let uuid = UUID(uuidString: proximityUUIDString) else {
            return nil
        }
        
        let major = dict["major"] as? CLBeaconMajorValue
        let minor = dict["minor"] as? CLBeaconMinorValue
        
        if let major = major, let minor = minor {
            return CLBeaconRegion(uuid: uuid, major: major, minor: minor, identifier: identifier)
        } else if let major = major {
            return CLBeaconRegion(uuid: uuid, major: major, identifier: identifier)
        } else {
            return CLBeaconRegion(uuid: uuid, identifier: identifier)
        }
    }
    
    /// Converte un valore CLProximity in una stringa descrittiva
    /// - Parameter proximity: Il valore di CLProximity da convertire
    /// - Returns: Una stringa che rappresenta la prossimità
    private static func proximityString(from proximity: CLProximity) -> String {
        switch proximity {
        case .unknown:
            return "unknown"
        case .immediate:
            return "immediate"
        case .near:
            return "near"
        case .far:
            return "far"
        @unknown default:
            return "unknown"
        }
    }
}
