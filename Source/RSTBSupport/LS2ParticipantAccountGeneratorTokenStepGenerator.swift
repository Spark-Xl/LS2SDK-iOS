//
//  LS2ParticipantAccountGeneratorTokenStepGenerator.swift
//  LS2SDK
//
//  Created by James Kizer on 11/15/18.
//

import UIKit
import ResearchSuiteTaskBuilder
import Gloss
import ResearchSuiteExtensions
import ResearchKit

open class LS2ParticipantAccountGeneratorTokenStepGenerator: RSTBBaseStepGenerator {
    
    public init(){}
    
    let _supportedTypes = [
        "LS2ParticipantAccountGeneratorTokenStepGenerator"
    ]
    
    public var supportedTypes: [String]! {
        return self._supportedTypes
    }
    
    open func generateStep(type: String, jsonObject: JSON, helper: RSTBTaskBuilderHelper) -> ORKStep? {
        
        
        guard let stepDescriptor = LS2ParticipantAccountGeneratorTokenStepDescriptor(json:jsonObject) else {
            return nil
        }
        
        let ls2ManagerKey = stepDescriptor.ls2ManagerKey ?? "ls2Manager"
        guard let stateHelper = helper.stateHelper,
            let manager = stateHelper.objectInState(forKey: ls2ManagerKey) as? LS2Manager else {
                return nil
        }
        
        guard let generatorID = stateHelper.objectInState(forKey: stepDescriptor.generatorIDKey) as? String else {
            return nil
        }
        
        let step = LS2ParticipantAccountGeneratorTokenStep(
            identifier: stepDescriptor.identifier,
            title: stepDescriptor.title,
            text: stepDescriptor.text,
            manager: manager,
            generatorID: generatorID,
            passwordFieldName: stepDescriptor.tokenFieldName
        )
        
        step.isOptional = false
        
        return step
        
    }
    
    open func processStepResult(type: String,
                                jsonObject: JsonObject,
                                result: ORKStepResult,
                                helper: RSTBTaskBuilderHelper) -> JSON? {
        return nil
    }
    
    
    
}
