//
//  ContactUsButton.swift
//  Proxiy
//
//  Created by Jaka Jancar on 2/25/21.
//

import SwiftUI

// Included in the About dialog as well as in the Help menu on macOS
struct ContactUsButton: View {
    /// Used to include details into the email
    let config: Config
    
    var body: some View {
        Button(
            action: {
//                let configJson: String = {
//                    var censoredConfig = self.config
//                    censoredConfig.psk = "***"
//                    
//                    return String(data: try! JSONEncoder().encode(censoredConfig), encoding: .utf8)!
//                }()
//                
//                let body = """
//                    Please describe your problem here.
//                    
//                    ------------------------------------
//                    
//                    Configuration:
//                    
//                    \(configJson)
//                    """
                let body = ""
                
                // TODO: add logs here once it works:
                // https://steipete.com/posts/logging-in-swift/#does-oslogstore-work-yet
                
                let url = mailtoURL(address: "jaka@kubje.org", subject: "Proxiy Support", body: body)

                UIApplication.shared.open(url)
            },
            label: {
                Text("Contact Developer...")
            }
        )
    }
}

struct ContactUsButton_Previews: PreviewProvider {
    static var previews: some View {
        ContactUsButton(config: Config())
    }
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

