//
//  AboutView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/24/21.
//

import SwiftUI

struct AboutView: View {
    static let kJakaEmail = "Jaka Jancar <jaka@kubje.org>"
    let config: Config
    @State private var showingBuild = false
    
    var body: some View {
        let info = Bundle.main.infoDictionary!
        let version = info["CFBundleShortVersionString"] as! String
        let build = info["CFBundleVersion"] as! String

        List {
            Section(
                header:
                    VStack(alignment: .center) {
                        Image("Icon")
                            .resizable()
                            .frame(width: 128, height: 128, alignment: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        
                        Spacer().frame(height: 18)

                        Text("\(kAppName) \(version)" + (showingBuild ? " (\(build))" : ""))
                            .bold()
                            .foregroundColor(.primary)
                            .onTapGesture {
                                showingBuild.toggle()
                            }
                        
                        Spacer().frame(height: 5)
                        
                        Text("© 2021 Jaka Jančar")
                            .font(.subheadline)

                            
                    }
                    .frame(maxWidth: .infinity)
                    .font(.none)
                    .textCase(.none)
                    .padding()
            ) {
                ContactUsButton(config: config)

//                NavigationLink(
//                    destination: Text("Foo"),
//                    label: {
//                        Text("Legal Notices")
//                    }
//                )
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        MyNavigationView {
            AboutView(config: Config())
        }
        .previewDevice("iPhone 12 mini")
    }
}
