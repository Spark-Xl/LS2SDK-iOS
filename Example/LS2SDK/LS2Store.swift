//
//  LS2Store.swift
//  LS2SDK_Example
//
//  Created by James Kizer on 12/26/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import LS2SDK

class LS2Store: NSObject, LS2CredentialStore {
    
    public func set(value: NSSecureCoding?, key: String) {
        UserDefaults().set(value, forKey: key)
    }
    
    public func get(key: String) -> NSSecureCoding? {
        let val = UserDefaults().object(forKey: key) as? NSSecureCoding
        return val
    }

}
