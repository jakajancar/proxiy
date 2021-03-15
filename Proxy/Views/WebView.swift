//
//  WebView.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/15/21.
//

import SwiftUI
import WebKit

struct WebView : UIViewRepresentable {
    
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
    
}

struct WebView_Previews : PreviewProvider {
    static var previews: some View {
        WebView(url: URL(string: "https://www.apple.com")!)
    }
}
