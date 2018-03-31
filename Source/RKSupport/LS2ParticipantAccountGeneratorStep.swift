//
//  LS2ParticipantAccountGeneratorStep.swift
//  LS2SDK
//
//  Created by James Kizer on 3/23/18.
//

import UIKit
import ResearchSuiteExtensions

open class LS2ParticipantAccountGeneratorStep: RSStep {
    
    override open func stepViewControllerClass() -> AnyClass {
        return LS2ParticipantAccountGeneratorStepViewController.self
    }
    
    public var buttonText: String? = nil
    public var viewControllerDidLoad: ((UIViewController) -> ())?
    
    public init(identifier: String,
                title: String? = nil,
                text: String? = nil,
                buttonText: String? = nil,
                ls2Provider: LS2ManagerProvider?) {
        
        let didLoad: (UIViewController) -> Void = { viewController in
            
            if let vc = viewController as? LS2ParticipantAccountGeneratorStepViewController {
                vc.ls2Provider = ls2Provider
            }
            
        }
        
        let title = title ?? "Log in"
        let text = text ?? "Please log in"
        
        super.init(identifier: identifier)
        self.title = title
        self.text = text
        self.buttonText = buttonText
        self.viewControllerDidLoad = didLoad
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
