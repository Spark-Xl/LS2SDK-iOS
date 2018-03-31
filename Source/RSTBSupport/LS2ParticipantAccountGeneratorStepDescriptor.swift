//
//  LS2ParticipantAccountGeneratorStepDescriptor.swift
//  LS2SDK
//
//  Created by James Kizer on 3/23/18.
//

import UIKit
import ResearchSuiteExtensions
import Gloss
import ResearchSuiteTaskBuilder

open class LS2ParticipantAccountGeneratorStepDescriptor: RSTBInstructionStepDescriptor {
    
    public let buttonText: String?
    public let formattedTitle: RSTemplatedTextDescriptor?
    public let formattedText: RSTemplatedTextDescriptor?
    
    required public init?(json: JSON) {
        
        self.buttonText = "buttonText" <~~ json
        self.formattedTitle = "formattedTitle" <~~ json
        self.formattedText = "formattedText" <~~ json
        
        super.init(json: json)
    }

}
