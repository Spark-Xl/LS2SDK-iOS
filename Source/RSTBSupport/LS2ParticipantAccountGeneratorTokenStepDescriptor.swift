//
//  LS2ParticipantAccountGeneratorTokenStepDescriptor.swift
//  LS2SDK
//
//  Created by James Kizer on 11/15/18.
//

import UIKit
import ResearchSuiteExtensions
import Gloss
import ResearchSuiteTaskBuilder

open class LS2ParticipantAccountGeneratorTokenStepDescriptor: LS2ParticipantAccountGeneratorStepDescriptor {
    
    public let ls2ManagerKey: String?
    public let generatorIDKey: String
    public let tokenFieldName: String?
    
    required public init?(json: JSON) {
        
        guard let generatorIDKey: String = "generatorIDKey" <~~ json else {
            return nil
        }
        
        self.ls2ManagerKey = "ls2ManagerKey" <~~ json
        self.generatorIDKey = generatorIDKey
        self.tokenFieldName = "tokenFieldName" <~~ json
        
        super.init(json: json)
    }
    
    
}
