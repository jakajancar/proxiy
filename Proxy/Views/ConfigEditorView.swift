//
//  ConfigEditorView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/17/21.
//

import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    let nearbyDeviceNames: Set<String>
    @Binding var config: Config
    @State private var showingAddListener = false

    var body: some View {
        let sortedListeners = config.listeners.sorted { $0.bindPort < $1.bindPort }
        
        Form {
            Section(
                header: Text("Network Key"),
                footer: Text("Nearby devices configured with the same key will connect using a peer-to-peer mesh network. ")
            ) {
                TextField("Required", text: $config.psk)
            }

            Toggle(isOn: $config.acceptInbound) {
                Text("Allow Connections from Peers")
            }
            
            // Dark mode is primarily useful on iOS where we have to remain in the foreground
            #if !targetEnvironment(macCatalyst)
            Toggle(isOn: $config.alwaysDark) {
                Text("Always Use Dark Mode")
            }
            #endif

            Section(
                header: Text("Local Listeners")
            ) {
                List {
                    ForEach(sortedListeners, id: \.bindPort) { listener in
                        
                        NavigationLink(
                            destination: ListenerEditorView(
                                nearbyDeviceNames: nearbyDeviceNames,
                                initialValue: listener,
                                saveAction: { new in
                                    updateListener(old: listener, new: new)
                                }
                            )
                        ) {
                            VStack(alignment: .leading) {
                                Text(listener.cellTitle)
                                
                                Text(listener.cellViaDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(listener.cellDestinationDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: { indexSet in
                        let error = updateListener(old: sortedListeners[indexSet.first!], new: nil)
                        precondition(error == nil)
                    })
                    
                    Button(action: {
                        showingAddListener = true
                    }) {
                        Text("Add Listener...")
                    }
                    .sheet(isPresented: $showingAddListener) {
                        MyNavigationView {
                            ListenerEditorView(
                                nearbyDeviceNames: nearbyDeviceNames,
                                initialValue: nil,
                                saveAction: { new in
                                    updateListener(old: nil, new: new)
                                }
                            )
                        }
                    }
                }
            }
            
            #if !targetEnvironment(macCatalyst)
            NavigationLink(
                destination: AboutView(config: config)
            ) {
                Text("About")
            }
            #endif
        }
        .navigationTitle("Settings")
        .primaryButton("Done") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func updateListener(old: Config.Listener?, new: Config.Listener?) -> UserError? {
        if let conflict = config.updateListener(old: old, new: new) {
            return UserError("A listener already exists for \(conflict.namespace.rawValue) port \(conflict.number).")
        } else {
            return nil
        }
    }
}

struct ConfigEditorView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var config: Config = Config()
        var body: some View {
            ConfigEditorView(
                nearbyDeviceNames: Set([
                    "Jaka's iPhone",
                    "Jaka's MacBook Pro",
                ]),
                config: $config
            )
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
}

private extension Config.Listener {
    var cellTitle: String {
        "\(self.bindPort.namespace.rawValue) \(String(self.bindPort.number.rawValue))"
    }
    
    var cellViaDescription: String {
        "via \(self.via.nameFilter ?? "any peer")"
    }
    
    var cellDestinationDescription: String {
        switch self {
        case .tcp(_, _, let endpoint),
             .udp(_, _, let endpoint):
            return "to \(endpoint.host):\(endpoint.port.rawValue)"
        case .socks(_, _):
            return "to any destination using SOCKS5"
        }
    }
}
