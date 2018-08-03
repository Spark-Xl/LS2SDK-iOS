//
//  LS2ParticipantAccountGeneratorRequestingCredentialsStep.swift
//  LS2SDK
//
//  Created by James Kizer on 8/2/18.
//

import UIKit
import ResearchSuiteExtensions

//try to handle cases where we request:
// - id + password
// - password with supplied id


open class LS2ParticipantAccountGeneratorRequestingCredentialsStep: RSLoginStep {
    
//    public var buttonText: String? = nil
//    public var viewControllerDidLoad: ((UIViewController) -> ())?
    
    public let manager: LS2Manager
//    public let participantAccountGeneratorCredentials: LS2ParticipantAccountGeneratorCredentials
    
    public let generatorID: String?
    
    public init(identifier: String,
                title: String? = nil,
                text: String? = nil,
                buttonText: String? = nil,
                manager: LS2Manager,
                generatorID: String? = nil,
                identityFieldName: String? = nil,
                passwordFieldName: String? = nil
        ) {
        
        let title = title ?? "Log in"
        let text = text ?? "Please log in"
        
        let identityFieldName = identityFieldName ?? "Study ID"
        let passwordFieldName = passwordFieldName ?? "Study Passphrase"
        
        self.manager = manager
        
        if let generatorID = generatorID {
            self.generatorID = generatorID
            super.init(
                identifier: identifier,
                title: title,
                text: text,
                showIdentityField: false,
                passwordFieldName: passwordFieldName,
                passwordFieldAnswerFormat: RSLoginStep.usernameAnswerFormat(),
                loginViewControllerClass: LS2ParticipantAccountGeneratorRequestingCredentialsStepViewController.self,
                loginButtonTitle: "Create Account"
            )
        }
        else {
            self.generatorID = nil
            super.init(
                identifier: identifier,
                title: title,
                text: text,
                identityFieldName: identityFieldName,
                identityFieldAnswerFormat: RSLoginStep.usernameAnswerFormat(),
                passwordFieldName: passwordFieldName,
                passwordFieldAnswerFormat: RSLoginStep.usernameAnswerFormat(),
                loginViewControllerClass: LS2ParticipantAccountGeneratorRequestingCredentialsStepViewController.self,
                loginButtonTitle: "Create Account"
            )
        }
        
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    

}
