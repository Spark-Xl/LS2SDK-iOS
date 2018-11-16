//
//  LS2MainViewController.swift
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


class LS2MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func signOut(_ sender: Any) {
        AppDelegate.appDelegate.signOut()
    }
    
    @IBAction func launchSurvey(_ sender: Any) {
        
        let filename = "survey.json"
        guard let scheduleItem = AppDelegate.loadScheduleItem(filename: filename) else {
            return
        }
        
        guard let steps = AppDelegate.appDelegate.taskBuilder.steps(forElement: scheduleItem.activity as JsonElement) else {
            return
        }
        
        let task = ORKOrderedTask(identifier: scheduleItem.identifier, steps: steps)
        
        let taskFinishedHandler: ((ORKTaskViewController, ORKTaskViewControllerFinishReason, Error?) -> ()) = { [weak self] (taskViewController, reason, error) in
            
//            if reason == ORKTaskViewControllerFinishReason.completed &&
//                AppDelegate.appDelegate.signedIn() {
//                self?.dismiss(animated: true, completion: {
//                    AppDelegate.appDelegate.showViewController(animated: true)
//                })
//            }
//            else {
//                self?.dismiss(animated: true, completion: {
//
//                })
//            }
            
            let taskResult = taskViewController.result
            AppDelegate.appDelegate.resultsProcessor.processResult(
                taskResult: taskResult,
                resultTransforms: scheduleItem.resultTransforms
            )
            
            self?.dismiss(animated: true, completion: {
                
            })
        }
        
        let tvc = RSAFTaskViewController(
            activityUUID: UUID(),
            task: task,
            taskFinishedHandler: taskFinishedHandler
        )
        
        self.present(tvc, animated: true, completion: nil)
        
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
