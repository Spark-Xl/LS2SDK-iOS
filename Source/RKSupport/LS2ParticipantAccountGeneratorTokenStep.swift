//
//  LS2ParticipantAccountGeneratorTokenStep.swift
//  LS2SDK
//
//  Created by James Kizer on 11/15/18.
//

import UIKit
import ResearchSuiteExtensions

open class LS2ParticipantAccountGeneratorTokenStep: RSLoginStep {
    
    public let manager: LS2Manager
    
    public let generatorID: String
    
    public init(identifier: String,
                title: String? = nil,
                text: String? = nil,
                buttonText: String? = nil,
                manager: LS2Manager,
                generatorID: String,
                passwordFieldName: String? = nil
        ) {
        
        let title = title ?? "Log in"
        let text = text ?? "Please log in"
        
        let buttonText = buttonText ?? "Create Account"
        
        self.manager = manager
        
        self.generatorID = generatorID
        let passwordFieldName = passwordFieldName ?? "Token"
        
        super.init(
            identifier: identifier,
            title: title,
            text: text,
            showIdentityField: false,
            passwordFieldName: passwordFieldName,
            passwordFieldAnswerFormat: RSLoginStep.usernameAnswerFormat(),
            loginViewControllerClass: LS2ParticipantAccountGeneratorTokenStepViewController.self,
            loginButtonTitle: buttonText
        )
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
