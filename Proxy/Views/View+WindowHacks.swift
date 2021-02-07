//
//  View+WindowHacks.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/2/21.
//

import Foundation
import SwiftUI

extension View {
    func withHostingWindow(_ callback: @escaping (UIWindow?) -> Void) -> some View {
        self.background(HostingWindowFinder(callback: callback))
    }
}

fileprivate struct HostingWindowFinder: UIViewRepresentable {
    var callback: (UIWindow?) -> ()

    func makeUIView(context: Context) -> UIView {
        class MyView: UIView {
            var callback: ((UIWindow?) -> ())? = nil
            override func willMove(toWindow newWindow: UIWindow?) {
                self.callback!(newWindow)
            }
        }
        let view = MyView()
        view.callback = self.callback
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
//
//fileprivate func hideZoomButtonsOnAllNSWindows(window: UIWindow) {
//    func bitSet(_ bits: [Int]) -> UInt {
//        return bits.reduce(0) { $0 | (1 << $1) }
//    }
//
//    func property(_ property: String, object: NSObject, set: [Int], clear: [Int]) {
//        if let value = object.value(forKey: property) as? UInt {
//            object.setValue((value & ~bitSet(clear)) | bitSet(set), forKey: property)
//        }
//    }
//
//    // disable full-screen button
//    
//    if let nsWindow = window.nsWindow {
//        print("got nswindow")
//    } else {
//        print("didn't find nswindow")
//    }
////    if  let NSApplication = NSClassFromString("NSApplication") as? NSObject.Type,
////        let sharedApplication = NSApplication.value(forKeyPath: "sharedApplication") as? NSObject,
////    {
////        if let nsWindow =
//////        let windows = sharedApplication.value(forKeyPath: "windows") as? [NSObject]
//////        print("FOO")
//////        for window in windows {
//////            print("WINDOW")
//////            let resizable = 3
//////            property("styleMask", object: window, set: [], clear: [resizable])
//////            let fullScreenPrimary = 7
//////            let fullScreenAuxiliary = 8
//////            let fullScreenNone = 9
//////            property("collectionBehavior", object: window, set: [fullScreenNone], clear: [fullScreenPrimary, fullScreenAuxiliary])
//////        }
////    }
//}
//
//extension UIWindow {
//    var nsWindow: NSObject? {
//        Dynamic.NSApplication.sharedApplication.delegate.hostWindowForUIWindow(self)
//    }
//}
//
////extension UIWindow {
////    var nsWindow: Any? {
////        let windows = Dynamic.NSApplication.sharedApplication.windows.asArray
////        return windows?.first { Dynamic($0).uiWindows.containsObject(self) == true }
////    }
////}
