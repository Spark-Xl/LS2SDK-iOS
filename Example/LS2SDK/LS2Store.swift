//
//  LS2Store.swift
//  LS2SDK_Example
//
//  Created by James Kizer on 12/26/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import LS2SDK
import ResearchSuiteExtensions
import ResearchSuiteTaskBuilder

class LS2Store: NSObject, RSCredentialsStore, RSTBStateHelper {
    
    let store = RSKeychainCredentialsStore(namespace: "ls2sdk_example")
    
    func objectInState(forKey: String) -> AnyObject? {
        switch forKey {
        case "ls2Manager":
            return AppDelegate.appDelegate.ls2Manager
        case "ls2ParticipantAccountCredentials":
            return AppDelegate.appDelegate.automaticParticipantAccountCredentials
        case "ls2ParticipantAccountGeneratorID":
            return AppDelegate.appDelegate.participantAccountGeneratorID as AnyObject
        case "ls2ShortTokenBasedParticipantAccountGeneratorID":
            return AppDelegate.appDelegate.shortTokenBasedParticipantAccountGeneratorID as AnyObject
        default:
            return nil
        }
    }
    
    
    func valueInState(forKey: String) -> NSSecureCoding? {
        return self.get(key: forKey)
    }
    
    func setValueInState(value: NSSecureCoding?, forKey: String) {
        self.set(value: value, key: forKey)
    }
    
    func set(value: NSSecureCoding?, key: String) {
        self.store.set(value: value, key: key)
    }
    func get(key: String) -> NSSecureCoding? {
        return self.store.get(key:key)
    }

}
