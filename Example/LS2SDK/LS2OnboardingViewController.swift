//
//  LS2OnboardingViewController.swift
//  LS2SDK_Example
//
//  Created by James Kizer on 11/15/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import ResearchKit
import ResearchSuiteTaskBuilder
import Gloss
import ResearchSuiteAppFramework

class LS2OnboardingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func signInWithUsername(_ sender: Any) {
        self.launchActivity(identifier: "signInWithUsername")
    }
    
    @IBAction func automaticAccountCreation(_ sender: Any) {
        self.launchActivity(identifier: "autoGenerateAccount")
    }
    
    @IBAction func passwordProtectedAccountGeneration(_ sender: Any) {
        self.launchActivity(identifier: "passwordProtectedGenerateAccount")
    }
    open func launchActivity(identifier: String) {
        
        let filename = "\(identifier).json"
        guard let scheduleItem = AppDelegate.loadScheduleItem(filename: filename) else {
            return
        }
        
        guard let steps = AppDelegate.appDelegate.taskBuilder.steps(forElement: scheduleItem.activity as JsonElement) else {
            return
        }
        
        let task = ORKOrderedTask(identifier: scheduleItem.identifier, steps: steps)
        
        let taskFinishedHandler: ((ORKTaskViewController, ORKTaskViewControllerFinishReason, Error?) -> ()) = { [weak self] (taskViewController, reason, error) in
            
            if reason == ORKTaskViewControllerFinishReason.completed &&
                AppDelegate.appDelegate.signedIn() {
                self?.dismiss(animated: true, completion: {
                    AppDelegate.appDelegate.showViewController(animated: true)
                })
            }
            else {
                self?.dismiss(animated: true, completion: {
                    
                })
            }
        }
        
        let tvc = RSAFTaskViewController(
            activityUUID: UUID(),
            task: task,
            taskFinishedHandler: taskFinishedHandler
        )
        
        self.present(tvc, animated: true, completion: nil)
        
        
    }
    
    

}
