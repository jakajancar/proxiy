//
//  LocationListener.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/23/21.
//

import Foundation
import CoreLocation
import Combine
import UIKit

class LocationListener {
    static var bindPort: BindPort {
        BindPort(namespace: .tcp, number: 4225)
    }
}
