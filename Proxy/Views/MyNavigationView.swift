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
    @Environment(\.forcedColorScheme) private var colorScheme: ColorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .colorScheme(colorScheme)
    }
}

/// SwiftUI resets .colorScheme on every `NavigationView` so have this custom environment value which `MyNavigationView` reads.
private struct ForcedColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    var forcedColorScheme: ColorScheme {
        get { self[ForcedColorSchemeKey.self] }
        set { self[ForcedColorSchemeKey.self] = newValue }
    }
}
