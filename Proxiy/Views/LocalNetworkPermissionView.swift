//
//  LocalNetworkPermissionView.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/21/21.
//

import SwiftUI

struct LocalNetworkPermissionView: View {
    var body: some View {
        VStack {
            Image(systemName: "location.slash.fill")
                .resizable()
                .frame(width: 128, height: 128, alignment: .center)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
            
            Text("No Local Network Access")
                .font(.title2)
            
            Text("Proxiy needs the Local Network Access permission to connect to other instances of Proxiy using the local network and peer-to-peer Wi-Fi.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding()
            
            Button(
                action: {
                    let url = URL(string: UIApplication.openSettingsURLString)!
                    UIApplication.shared.open(url)
                },
                label: {
                    Text("Open Settings")
                }
            )
        }
    }
}

struct LocalNetworkPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        LocalNetworkPermissionView()
            .previewDevice("iPhone 12 mini")
    }
}
