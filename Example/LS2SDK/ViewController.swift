//
//  ViewController.swift
//  LS2SDK
//
//  Created by jdkizer9 on 12/26/2017.
//  Copyright (c) 2017 jdkizer9. All rights reserved.
//

import UIKit
import LS2SDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let manager:LS2Manager = (UIApplication.shared.delegate! as! AppDelegate).ls2Manager!
        
        let signInCallback = {
            
            let pam = PAMSample()
            pam.affectArousal = 1
            pam.affectValence = 2
            pam.negativeAffect = 3
            pam.positiveAffect = 4
            pam.mood = "awesome!!"
            
            manager.addDatapoint(datapoint: pam, completion: { (error) in
                debugPrint(error)
            })
            
            manager.addDatapoint(datapoint: pam, completion: { (error) in
                debugPrint(error)
            })
        }
        
        
        if !manager.isSignedIn {
            manager.signIn(username: "TestUser1", password: "password123", completion: { (error) in
                if error == nil {
                    signInCallback()
                }
            })
        }
        else {
            signInCallback()
        }
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

