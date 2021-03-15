//
//  IntField.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/8/21.
//

import SwiftUI
import Combine

struct IntField: View {
    let title: String
    @Binding var int: Int?
    
//    @State private var intString: String  = ""
    var body: some View {
        TextField(
            title,
            text: Binding(
                get: {
                    if let int = int {
                        return String(int)
                    } else {
                        return ""
                    }
                },
                set: { newValue in
                    if newValue == "" {
                        int = nil
                    } else if let newValue = Int(newValue) {
                        int = newValue
                    } else {
                        // ignore change
                    }
                }
            )
        )
        .keyboardType(.numberPad)
    }
}
