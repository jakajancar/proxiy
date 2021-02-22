//
//  ListenerConfigView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/17/21.
//

import SwiftUI
import Network

private let kLabelWidth: CGFloat = 100

struct ListenerEditorView: View {
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    private let nearbyDeviceNames: Set<String>
    private let saveAction: (Config.Listener?) -> UserError?
    private let addingNew: Bool
    
    // The whole structure is quite a bit different to `Config.Listener` since we:
    //   - want to start with the bind namespace (TCP/UDP) and have the three-section Listen->Via->To layout,
    //   - don't want to lose any data when switching,
    //   - want to allow incomplete state (nil port).
    @State private var bindNamespace: BindPort.Namespace = .tcp
    @State private var listenPort: Int?
    @State private var via: Config.Via = Config.Via()
    @State private var socks = false
    @State private var targetHost: String = ""
    @State private var targetPort: Int?
    @State private var presentedError: UserError?

    init(
        nearbyDeviceNames: Set<String>,
        initialValue initial: Config.Listener?,
        saveAction: @escaping (Config.Listener?) -> UserError?
    ) {
        self.nearbyDeviceNames = nearbyDeviceNames
        self.saveAction = saveAction
        addingNew = initial == nil
        
        if let initial = initial {
            _bindNamespace = State(initialValue: initial.bindPort.namespace)
            _listenPort = State(initialValue: Int(initial.bindPort.number.rawValue))
            _via = State(initialValue: initial.via)
            _socks = State(initialValue: initial.type == .socks)
            if let target = initial.target {
                _targetHost = State(initialValue: target.host)
                _targetPort = State(initialValue: Int(target.port.rawValue))
            }
        }
    }
    
    private func createConfig() -> Result<Config.Listener, UserError> {
        func validatePort(name: String, value: Int?) -> Result<NWEndpoint.Port, UserError> {
            guard let value = value else {
                return .failure(UserError("\(name) must not be empty."))
            }
            guard 1 <= value && value <= 65535 else {
                return .failure(UserError("\(name) must be between 1 and 65535."))
            }
            return .success(NWEndpoint.Port(rawValue: UInt16(exactly: value)!)!)
        }
        
        return validatePort(name: "Listen port", value: listenPort).flatMap { listenPort in
            switch bindNamespace {
            case .tcp:
                if socks {
                    return .success(.socks(listenPort, via))
                } else {
                    guard targetHost != "" else {
                        return .failure(UserError("Destination hostname must not be empty."))
                    }
                    return validatePort(name: "Destination port", value: targetPort).flatMap { targetPort in
                        return .success(.tcp(listenPort, via, .init(host: targetHost, port: targetPort)))
                    }
                }
            case .udp:
                return validatePort(name: "Destination port", value: targetPort).flatMap { targetPort in
                    return .success(.udp(listenPort, via, .init(host: targetHost, port: targetPort)))
                }
            }
        }
    }
    
    var body: some View {
        Form {
            Section(
                header: Text("Listen On")
            ) {
                Picker(selection: $bindNamespace, label: Text("Protocol")) {
                    Text("TCP").tag(BindPort.Namespace.tcp)
                    Text("UDP").tag(BindPort.Namespace.udp)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                HStack {
                    Text("Port")
                        .frame(minWidth: kLabelWidth, alignment: .leading)

                    IntField(title: "Required", int: $listenPort)
                }
                
            }

            Section(
                header: Text("Connect Via")
            ) {
                List {
                    ForEach(offeredNameFilters, id: \.self) { offered in
                        Button(action: {
                            via.nameFilter = offered.nameFilter
                        }) {
                            HStack {
                                let checkmark = Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                
                                if offered.currentlySelected {
                                    checkmark
                                } else {
                                    checkmark.hidden()
                                }
                                
                                Text(offered.displayName)
                                    .foregroundColor(offered.outdated ? .secondary : .primary)
                            }
                        }
                    }
                }
            }

            Section(
                header: Text("To Destination"),
                footer: Text(bindNamespace == .tcp && socks ? "The client connecting to localhost\(listenPort == nil ? "" : ":"+String(listenPort!)) must support the SOCKS5 protocol." : "")
            ) {
                if bindNamespace == .tcp {
                    Picker(selection: $socks, label: Text("Protocol")) {
                        Text("Static").tag(false)
                        Text("Dynamic").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if bindNamespace == .tcp && !socks || bindNamespace == .udp {
                    HStack {
                        Text("Hostname")
                            .frame(minWidth: kLabelWidth, alignment: .leading)
                        TextField("Required", text: $targetHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    HStack {
                        Text("Port")
                            .frame(minWidth: kLabelWidth, alignment: .leading)
                        
                        IntField(title: "Required", int: $targetPort)
                    }
                }
            }
            
            if !addingNew {
                Button(action: {
                    let userError = saveAction(nil)
                    precondition(userError == nil)
                    presentationMode.wrappedValue.dismiss()
                    
                }) {
                    HStack {
                        Spacer()
                        Text("Delete Listener")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(addingNew ? "Add Listener" : "Edit Listener")
        .navigationBarTitleDisplayMode(.inline)
        .buttons(
            doneText: addingNew ? "Add" : "Save",
            doneAction: {
                switch createConfig() {
                case .success(let config):
                    if let parentError = saveAction(config) {
                        presentedError = parentError
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                case .failure(let ourError):
                    presentedError = ourError
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
    
    private struct OfferedNameFilter: Hashable {
        let displayName: String
        let nameFilter: String?
        let currentlySelected: Bool
        let outdated: Bool
    }
    
    private var offeredNameFilters: [OfferedNameFilter] {
        // Nearby ones
        var ret: [OfferedNameFilter] = nearbyDeviceNames.sorted {
            $0.compare($1, options: .caseInsensitive) == .orderedAscending
        }.map {
            OfferedNameFilter(
                displayName: $0,
                nameFilter: $0,
                currentlySelected: via.nameFilter == $0,
                outdated: false
            )
        }
        
        // Any at the beginning
        ret.insert(
            OfferedNameFilter(
                displayName: "Any Peer",
                nameFilter: nil,
                currentlySelected: via.nameFilter == nil,
                outdated: false
            ),
            at: 0)
        
        // Outdated at the end, if applicable
        if let current = via.nameFilter {
            if !nearbyDeviceNames.contains(current) {
                ret.append(OfferedNameFilter(
                    displayName: current,
                    nameFilter: current,
                    currentlySelected: true,
                    outdated: true
                ))
            }
        }
        return ret
    }
}

struct ListenerConfigView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(configs, id: \.0) { (name, config, parentError) in
                // TODO: add NavigationView
                NavigationView {
                    ListenerEditorView(
                        nearbyDeviceNames: nearbyDeviceNames,
                        initialValue: config,
                        saveAction: { new in parentError }
                    )
                }
                .previewDevice("iPhone 12 mini")
                .previewLayout(.sizeThatFits)
                .previewDisplayName(name)
            }
        }
    }
    
    static var configs: [(String, Config.Listener?, UserError?)] {
        [
            (
                "New",
                nil,
                nil
            ),
            (
                "TCP / Any peer / SOCKS / Parent error!",
                .socks(
                    .socks,
                    Config.Via(nameFilter: nil)
                ),
                UserError("Parent doesn't like the listener.")
            ),
            (
                "TCP / Specific peer / Static",
                .tcp(
                    .init(integerLiteral: 8080),
                    Config.Via(nameFilter: "Jaka's iPhone"),
                    Config.Endpoint(
                        host: "example.com",
                        port: .init(integerLiteral: 80)
                    )
                ),
                nil
            ),
            (
                "UDP / Outdated peer / Static",
                .udp(
                    .init(integerLiteral: 5353),
                    Config.Via(nameFilter: "Old non-existent device"),
                    Config.Endpoint(
                        host: "8.8.8.8",
                        port: .init(integerLiteral: 53)
                    )
                ),
                nil
            ),
        ]
    }
    
    static var nearbyDeviceNames: Set<String> {
        Set([
            "Jaka's iPhone",
            "Jaka's MacBook Pro",
        ])
    }
}
