//
//  LocationListener.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/23/21.
//

import Foundation
import CoreLocation
import NWHTTPServer

class LocationListener {
    static var bindPort: BindPort {
        BindPort(namespace: .tcp, number: 4225)
    }
    
    private let manager: CLLocationManager
    private let server: HTTPServer
    
    init(accuracy: CLLocationAccuracy) {
        manager = CLLocationManager()
        manager.activityType = .other
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.desiredAccuracy = accuracy
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()

        server = try! HTTPServer(port: Self.bindPort.number) { [unowned manager] request, response in
            if let location = manager.location {
                let body = LocationResponse(
                    desiredAccuracy: manager.desiredAccuracy,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    speed: location.speed,
                    course: location.course,
                    horizontalAccuracy: location.horizontalAccuracy,
                    verticalAccuracy: location.verticalAccuracy,
                    speedAccuracy: location.speedAccuracy,
                    courseAccuracy: location.courseAccuracy,
                    unixTimestamp: location.timestamp.timeIntervalSince1970
                )
                response.status = .ok
                try! response.sendJSON(body)
            } else {
                let body = ErrorResponse(
                    message: "Location is not yet available."
                )
                response.status = .notFound
                try! response.sendJSON(body)
            }
        }
        server.resume()
    }
    
    func cancel() {
        server.suspend()
    }
}

private struct LocationResponse: Encodable {
    let desiredAccuracy: Double
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speedAccuracy: Double
    let courseAccuracy: Double
    let unixTimestamp: Double
}

private struct ErrorResponse: Encodable {
    let message: String
}
