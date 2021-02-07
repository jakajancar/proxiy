//
//  SettingsView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/2/21.
//

import SwiftUI

struct SettingsView: View {
//    @Binding var config: Config
    var dismiss: () -> ()
    
    var body: some View {
        Button(action: dismiss) {
            Text("Dismiss")
        }
        
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}
