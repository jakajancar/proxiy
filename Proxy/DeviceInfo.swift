//
//  DeviceInfo.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/2/21.
//

import Foundation
import UIKit

/// The bits of data sent about peers that are not user-configurable and update live. Really just a `Codable` subset of `UIDevice`.
struct DeviceInfo: Codable {
    var name: String
    let machine: String
    
    static var current: Self {
        return DeviceInfo(
            name: UIDevice.current.name,
            machine: bestEffortModelIdentifier()
        )
    }
    
    // Symbol name from SF Symbols
    var machineSymbolName: String {
             if self.machine.starts(with: "iMac")    { return "desktopcomputer" } // 􀙗
        else if self.machine.starts(with: "Macmini") { return "desktopcomputer" } // 􀙗
        else if self.machine.starts(with: "MacPro")  { return "desktopcomputer" } // 􀙗
        else if self.machine.starts(with: "MacBook") { return "laptopcomputer" } // 􀟛
        else if self.machine.starts(with: "iPhone")  { return "iphone" } // 􀟜
        else if self.machine.starts(with: "iPod")    { return "ipodtouch" } // 􀫧
        else if self.machine.starts(with: "iPad")    { return "ipad.landscape" } // 􀥔
        else                                         { return "questionmark.square" } // 􀃬
    }
}

//private func getModelIdentifier() -> String? {
//    let service = IOServiceGetMatchingService(kIOMasterPortDefault,
//                                              IOServiceMatching("IOPlatformExpertDevice"))
//    var modelIdentifier: String?
//    if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
//        modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
//    }
//
//    IOObjectRelease(service)
//    return modelIdentifier
//}

//extension UIDevice {
//    var modelIdentifier: String? {
//        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
//        defer { IOObjectRelease(service) }
//
//        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
//            if let cString = modelData.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }) {
//                return String(cString: cString)
//            }
//        }
//
//        return nil
//    }
//}

// Mac Catalyst, iPhone Simulator, Mac native:
//  hw.machine: Optional("x86_64")
//  hw.model: Optional("MacBookPro16,1")
//
// iPhone:
//  hw.machine: Optional("iPhone13,1")
//  hw.model: Optional("D52gAP")
//
// Mac with Apple Silicon:
// (https://developer.apple.com/forums/thread/668704)
//  hw.machine: Optional("iPad8,6") <-- wrong
//  hw.model: Optional("MacBookProXX,X") - presumed
//
private func bestEffortModelIdentifier() -> String {
    func looksRight(_ model: String) -> Bool {
        model.contains(",")
    }
    
    if let model = sysctl(name: "hw.model"), looksRight(model) {
        return model
    }
    if let machine = sysctl(name: "hw.machine"), looksRight(machine) {
        return machine
    }
    return "Unknown"
}


private func sysctl(name: String) -> String? {
    // read length
    var size = 0
    if sysctlbyname(name, nil, &size, nil, 0) != 0 {
        return nil
    }
    
    // read content
    var machine = [CChar](repeating: 0,  count: size)
    if sysctlbyname(name, &machine, &size, nil, 0) != 0 {
        return nil
    }
    
    return String(cString: machine)
}
