//
//  View+ColorScheme.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/23/21.
//

import SwiftUI

/// For some reason:
///  - we need to apply color scheme to every modal separately, duplicating the code, and
///  - after setting `.preferredColorScheme(.dark)`, it does not reset when you set ``.preferredColorScheme(nil)`
/// Utility function is extracted here.
extension View {
    func colorScheme(alwaysDark: Bool) -> some View {
        let style: UIUserInterfaceStyle = alwaysDark ? .dark : UITraitCollection.current.userInterfaceStyle
        return self.colorScheme(ColorScheme(style)!)
    }
}
