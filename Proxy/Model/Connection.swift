//
//  Connection.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/4/21.
//

import Foundation

protocol Connection: AnyObject, Hashable {
    func forceCancel()
    var completedHandler: (() -> Void)? { get set }
}
