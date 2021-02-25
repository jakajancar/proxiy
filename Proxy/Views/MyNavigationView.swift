//
//  MyNavigationController.swift
//  Proxiy
//
//  Created by Jaka Jancar on 2/25/21.
//

import SwiftUI

/// NavigationView with different defaults.
struct MyNavigationView<Content: View>: View  {
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
