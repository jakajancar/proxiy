//
//  View+DoneCancel.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/21/21.
//

import SwiftUI

let isMac = UIDevice.current.userInterfaceIdiom == .mac

extension View {
    func buttons(
        doneText: String,
        doneAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> some View {
        let doneButton = Button(action: doneAction, label: { Text(doneText) })
            .keyboardShortcut(.defaultAction)
        let cancelButton = Button(action: cancelAction, label: { Text("Cancel") })
            .keyboardShortcut(.cancelAction)

        if isMac {
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline) // otherwise wierd space at top, plus heading looks funny
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            cancelButton.padding(.trailing, 10)
                            doneButton
                        }
                    }
            )
        } else {
            return AnyView(
                self
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { doneButton }
                        ToolbarItem(placement: .cancellationAction) { cancelButton }
                    }
            )
        }
    }
}
