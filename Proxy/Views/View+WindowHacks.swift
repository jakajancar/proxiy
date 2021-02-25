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
