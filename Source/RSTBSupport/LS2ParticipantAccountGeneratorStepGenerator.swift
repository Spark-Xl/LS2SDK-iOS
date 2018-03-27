//
//  LS2ParticipantAccountGeneratorStep.swift
//  LS2SDK
//
//  Created by James Kizer on 3/23/18.
//

import UIKit
import ResearchSuiteTaskBuilder
import Gloss
import ResearchSuiteExtensions
import ResearchKit

open class LS2ParticipantAccountGeneratorStepGenerator: RSTBBaseStepGenerator {
    
    public init(){}
    
    let _supportedTypes = [
        "LS2ParticipantAccountGeneratorStep"
    ]
    
    public var supportedTypes: [String]! {
        return self._supportedTypes
    }
    
    open func generateStep(type: String, jsonObject: JSON, helper: RSTBTaskBuilderHelper) -> ORKStep? {
        
        guard let stepDescriptor = LS2ParticipantAccountGeneratorStepDescriptor(json:jsonObject),
            let managerProvider = helper.stateHelper as? LS2ManagerProvider,
            let stateHelper = helper.stateHelper else {
                return nil
        }
        
        let step = LS2ParticipantAccountGeneratorStep(
            identifier: stepDescriptor.identifier,
            title: stepDescriptor.title,
            text: stepDescriptor.text,
            buttonText: stepDescriptor.buttonText,
            ls2Provider: managerProvider
        )
        
        if let formattedTitle = stepDescriptor.formattedTitle {
            step.attributedTitle = self.generateAttributedString(descriptor: formattedTitle, stateHelper: stateHelper)
        }
        
        if let formattedText = stepDescriptor.formattedText {
            step.attributedText = self.generateAttributedString(descriptor: formattedText, stateHelper: stateHelper)
        }
        
        return step
    }
    
    open func processStepResult(type: String,
                                jsonObject: JsonObject,
                                result: ORKStepResult,
                                helper: RSTBTaskBuilderHelper) -> JSON? {
        return nil
    }

}
