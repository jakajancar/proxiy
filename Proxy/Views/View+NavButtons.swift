//
//  View+DoneCancel.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/21/21.
//

import SwiftUI

/// Adds buttons to navigation bar on iOS, bottom toolbar on macOS, for a more native-ish look.
extension View {
    func primaryButton(
        _ text: String,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action, label: { Text(text) })
//            .keyboardShortcut(.defaultAction) -- add when confirmed working
        
        #if targetEnvironment(macCatalyst)
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline) // otherwise wierd space at top, plus heading looks funny
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            button
                        }
                    }
            )
        #else
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) { button }
                    }
            )
        #endif
    }
    
    func confirmCancelButtons(
        confirmText: String,
        confirmAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> some View {
        let confirmButton = Button(action: confirmAction, label: { Text(confirmText) })
//            .keyboardShortcut(.defaultAction) -- add when confirmed working
        let cancelButton = Button(action: cancelAction, label: { Text("Cancel") })
//            .keyboardShortcut(.cancelAction) -- add when confirmed working

        #if targetEnvironment(macCatalyst)
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline) // otherwise wierd space at top, plus heading looks funny
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            cancelButton.padding(.trailing, 10)
                            confirmButton
                        }
                    }
            )
        #else
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { confirmButton }
                        ToolbarItem(placement: .cancellationAction) { cancelButton }
                    }
            )
        #endif
    }
}
