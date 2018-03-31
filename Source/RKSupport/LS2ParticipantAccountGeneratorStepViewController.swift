//
//  LS2ParticipantAccountGeneratorStepViewController.swift
//  LS2SDK
//
//  Created by James Kizer on 3/23/18.
//

import UIKit
import ResearchSuiteExtensions
import ResearchKit

open class LS2ParticipantAccountGeneratorStepViewController: RSQuestionViewController {
    
    
    open var ls2Provider: LS2ManagerProvider? = nil
    
    open var logInSuccessful: Bool? = nil
    
    open var didLoad: ((UIViewController) -> ())?
    
    open var activityIndicator: UIActivityIndicatorView?
    
    override open func viewDidLoad() {
        
        super.viewDidLoad()
        
        if let step = self.step as? LS2ParticipantAccountGeneratorStep {
            
            if let buttonText = step.buttonText {
                self.setContinueButtonTitle(title: buttonText)
            }
            
            step.viewControllerDidLoad?(self)
            
        }
        
    }
    
    open var isLoading: Bool = false {
        didSet {
            if isLoading != oldValue {
                let localIsLoading = isLoading
                DispatchQueue.main.async {
                    if localIsLoading {
                        self.activityIndicator?.startAnimating()
                        self.view.isUserInteractionEnabled = false
                        
                    }
                    else {
                        self.activityIndicator?.stopAnimating()
                        self.view.isUserInteractionEnabled = true
                    }
                }
            }
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.view.addSubview(activityIndicator)
        activityIndicator.center = self.view.center
        self.activityIndicator = activityIndicator
        
    }
    
    override open func continueTapped(_ sender: Any) {
        
        if let provider = self.ls2Provider,
            let manager = provider.getManager(),
            let generatorCredentials = provider.getParticipantAccountGeneratorCredentials() {
            
            self.isLoading = true
            
            manager.generateParticipantAccount(generatorCredentials: generatorCredentials, completion: { (error) in
                
                //if we got and error and its not already have credentials, throw error
                if let error = error as? LS2ManagerErrors,
                    error != LS2ManagerErrors.hasCredentials {
                    
                    self.isLoading = false
                    self.logInSuccessful = false
                    let message: String = "Unable to create log in credentials. Please contact support."
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertControllerStyle.alert)
                        
                        // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                            (result : UIAlertAction) -> Void in
                            print("OK")
                        }
                        
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
                else {
                    //if no error OR we alreay have credentials, try to log in with credentials
                    manager.signInWithCredentials(forceSignIn: true, completion: { (error) in
                        
                        self.isLoading = false
                        
                        if error == nil {
                            
                            self.logInSuccessful = true
                            DispatchQueue.main.async {
                                self.notifyDelegateAndMoveForward()
                            }
                            
                        }
                            
                        else {
                            self.logInSuccessful = false
                            let message: String = "Invalid log in credentials. Please contact support."
                            DispatchQueue.main.async {
                                let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertControllerStyle.alert)
                                
                                // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                                    (result : UIAlertAction) -> Void in
                                    print("OK")
                                }
                                
                                alertController.addAction(okAction)
                                self.present(alertController, animated: true, completion: nil)
                            }
                            
                        }
                        
                    })
                    
                }
            })
            
        }
        else {
            self.logInSuccessful = false
            let message: String = "Invalid configuration. Please contact support."
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertControllerStyle.alert)
                
                // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                    (result : UIAlertAction) -> Void in
                    print("OK")
                }
                
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        
        }
        
    }
    
    override open var result: ORKStepResult? {
        guard let result = super.result else {
            return nil
        }
        
        guard let logInSuccessful = self.logInSuccessful,
            let step = step else {
                return result
        }
        
        let boolResult = ORKBooleanQuestionResult(identifier: step.identifier)
        boolResult.booleanAnswer = NSNumber(booleanLiteral: logInSuccessful)
        
        result.results = [boolResult]
        return result
    }
    
}
