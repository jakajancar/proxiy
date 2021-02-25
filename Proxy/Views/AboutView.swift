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
        let appName = info["CFBundleDisplayName"] as! String
        let version = info["CFBundleShortVersionString"] as! String
        let build = info["CFBundleVersion"] as! String


        List {
            Section(
                header:
                    VStack(alignment: .center) {
                        Image("Icon")
                            .resizable()
                            .frame(width: 128, height: 128, alignment: .center)
                        
                        Spacer().frame(height: 18)

                        Text("\(appName) \(version)" + (showingBuild ? " (\(build))" : ""))
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
                Button(
                    action: {
                        UIApplication.shared.open(supportURL)
                    },
                    label: {
                        Text("Support")
                            .foregroundColor(.primary)
                    }
                )
                
                Button(
                    action: {
                        UIApplication.shared.open(feedbackURL)
                    },
                    label: {
                        Text("Feedback")
                            .foregroundColor(.primary)
                    }
                )

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
    
    private var supportURL: URL {
        let config: String = {
            var censoredConfig = self.config
            censoredConfig.psk = "***"
            
            return String(data: try! JSONEncoder().encode(censoredConfig), encoding: .utf8)!
        }()
        
        let body = """
            Please describe your problem here.
            
            ------------------------------------
            
            Configuration:
            
            \(config)
        """
        // TODO: loggign
        
        return mailtoURL(address: Self.kJakaEmail, subject: "Proxiy Support", body: body)
    }
    
    private var feedbackURL: URL {
        mailtoURL(address: Self.kJakaEmail, subject: "Proxiy Feedback", body: "")
    }
    
    private func mailtoURL(address: String, subject: String, body: String) -> URL {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body.replacingOccurrences(of: "\n", with: "\r\n")),
        ]
        return c.url!
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView(config: Config())
        }
        .previewDevice("iPhone 12 mini")
    }
}
