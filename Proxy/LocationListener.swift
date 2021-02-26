//
//  LocationListener.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/23/21.
//

import Foundation
import Network
import CoreLocation

class LocationListener {
    static var bindPort: BindPort {
        BindPort(namespace: .tcp, number: 4225)
    }
    
//    var locationMode: Config.LocationMode
//    var runInBackground: Bool
//    private var manager: CLLocationManager
//    
//    init() {
//        
//    }
}
