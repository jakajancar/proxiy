//
//  ConfigEditorView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/17/21.
//

import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    private let nearbyDeviceNames: Set<String>
    private let saveAction: (Config) -> Void

    @State private var draft: Config
    @State private var showingAddListener = false
    @State private var presentedError: UserError?

    init(
        nearbyDeviceNames: Set<String>,
        initialValue initial: Config,
        saveAction: @escaping (Config) -> Void
    ) {
        self.nearbyDeviceNames = nearbyDeviceNames
        self.saveAction = saveAction
        _draft = State(initialValue: initial)
    }
    
    private func validate() -> UserError? {
        if draft.psk.isEmpty {
            return UserError("The network key must not be empty.")
        }
        return nil
    }
    
    var body: some View {
        let sortedListeners = draft.listeners.sorted { $0.bindPort < $1.bindPort }
        
        NavigationView {
            Form {
                Section(
                    header: Text("Network Key"),
                    footer: Text("Nearby devices configured with the same key will connect using a peer-to-peer mesh network. ")
                ) {
                    TextField("Required", text: $draft.psk)
                }

                Toggle(isOn: $draft.acceptInbound) {
                    Text("Allow Connections from Peers")
                }
                
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
                            NavigationView {
                                ListenerEditorView(
                                    nearbyDeviceNames: nearbyDeviceNames,
                                    initialValue: nil,
                                    saveAction: { new in
                                        updateListener(old: nil, new: new)
                                    }
                                )
                            }
                            .navigationViewStyle(StackNavigationViewStyle())
                        }
                    }
                }

            }
            .navigationTitle("Settings")
            .buttons(
                doneText: "Save",
                doneAction: {
                    if let error = validate() {
                        presentedError = error
                    } else {
                        saveAction(draft)
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                cancelAction: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(item: $presentedError, content: { userError in
                return Alert(
                    title: Text("Error"),
                    message: Text(userError.message),
                    dismissButton: .default(Text("OK"))
                )
            })
        }
    }

    private func updateListener(old: Config.Listener?, new: Config.Listener?) -> UserError? {
        if let conflict = draft.updateListener(old: old, new: new) {
            return UserError("A listener already exists for \(conflict.namespace.rawValue) port \(conflict.number).")
        } else {
            return nil
        }
    }
}

struct ConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigEditorView(
            nearbyDeviceNames: Set([
                "Jaka's iPhone",
                "Jaka's MacBook Pro",
            ]),
            initialValue: Config.initial,
            saveAction: { new in }
        )
        .previewDevice("iPhone 12 mini")
        .previewLayout(.sizeThatFits)
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
