//
//  AppDelegate.swift
//  LS2SDK
//
//  Created by jdkizer9 on 12/26/2017.
//  Copyright (c) 2017 jdkizer9. All rights reserved.
//

import UIKit
import LS2SDK
import ResearchSuiteExtensions
import ResearchSuiteResultsProcessor
import ResearchSuiteTaskBuilder
import ResearchSuiteAppFramework
import Gloss
import ResearchKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    public static var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var window: UIWindow?
    
    var store: LS2Store!
    var taskBuilder: RSTBTaskBuilder!
    var resultsProcessor: RSRPResultsProcessor!
    //    var CSVBackend: RSRPCSVBackEnd!
    var ls2Manager: LS2Manager!
    var ls2Backend: LS2BackEnd!
    
    var ls2URLDelegate: LS2TokenBasedAccountCreationURLDelegate!
    
    var participantAccountGeneratorID: String {
        return "8e502133-d1c6-4784-8f26-c9c41d95b5b8"
    }
    
    var shortTokenBasedParticipantAccountGeneratorID: String {
        return "8d432160-3613-40fb-9ab6-9d5eef35c040"
    }
    
    var participantAccountGeneratorPassword: String {
        return "ls2sdkpassword"
    }
    
    var automaticParticipantAccountCredentials: LS2ParticipantAccountGeneratorCredentials {
        return LS2ParticipantAccountGeneratorCredentials(
            generatorId: self.participantAccountGeneratorID,
            generatorPassword: self.participantAccountGeneratorPassword
        )
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        if UserDefaults.standard.object(forKey: "FirstRun") == nil {
            UserDefaults.standard.set("1stRun", forKey: "FirstRun")
            UserDefaults.standard.synchronize()
            
            RSKeychainHelper.clearKeychain()
        }
        
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        self.store = LS2Store()
        
        self.taskBuilder = RSTBTaskBuilder(
            stateHelper: self.store,
            localizationHelper: nil,
            elementGeneratorServices: AppDelegate.elementGeneratorServices,
            stepGeneratorServices: AppDelegate.stepGeneratorServices,
            answerFormatGeneratorServices: AppDelegate.answerFormatGeneratorServices
        )
        
        self.ls2Manager = LS2Manager(baseURL: "http://localhost:8001/dsu", queueStorageDirectory: "LS2SDK", store: LS2Store())
        
        self.ls2Backend = LS2BackEnd(ls2Mananager: self.ls2Manager, transformers: [LS2DefaultTransformer.self])
        self.resultsProcessor = RSRPResultsProcessor(
            frontEndTransformers: AppDelegate.resultsTransformers,
            backEnd: self.ls2Backend
        )
        
        self.ls2URLDelegate = LS2TokenBasedAccountCreationURLDelegate(
            path: "account/generate/token",
            ls2ManagerProvider: self.ls2ManagerProvider,
            creationStart: self.ls2AccountCreationStart,
            creationCompletion: self.ls2AccountCreationCompletion
        )
        
        self.showViewController(animated: false)
        
        return true
    }
    
    //note that this is invoked after application didFinishLauchingWithOptions
    open func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return self.handleURL(app: app, url: url, options: options)
    }
    
    open func handleURL(app: UIApplication, url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        let delegates = self.openURLDelegates

        for delegate in delegates {
            let context: [String: AnyObject] = [:]
            let handled = delegate.handleURL(app: app, url: url, options: options, context: context)
            if handled { return true }
        }
        return false
    }
    
    open func showViewController(animated: Bool) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        
        if(signedIn()){
            let vc = storyboard.instantiateViewController(withIdentifier: "main")
            self.transition(toRootViewController: vc, animated: animated)
        }
        else {
            let vc = storyboard.instantiateViewController(withIdentifier: "onboarding")
            self.transition(toRootViewController: vc, animated: animated)
        }
        
    }
    
    func signedIn () -> Bool {
        return self.ls2Manager.isSignedIn
    }
    
    open func signOut() {
        
        ls2Manager.signOut(completion:  { (error) in
            
            RSKeychainHelper.clearKeychain()
            
            DispatchQueue.main.async {
                self.showViewController(animated: true)
            }
            
        })
        
        
    }
    
    open func transition(toRootViewController: UIViewController, animated: Bool, completion: ((Bool) -> Swift.Void)? = nil) {
        guard let window = self.window else { return }
        if (animated) {
            let snapshot:UIView = (self.window?.snapshotView(afterScreenUpdates: true))!
            toRootViewController.view.addSubview(snapshot);
            
            self.window?.rootViewController = toRootViewController;
            
            UIView.animate(withDuration: 0.3, animations: {() in
                snapshot.layer.opacity = 0;
            }, completion: {
                (value: Bool) in
                snapshot.removeFromSuperview()
                completion?(value)
            })
        }
        else {
            window.rootViewController = toRootViewController
            completion?(true)
        }
    }
    
    open var ls2ManagerProvider: () -> LS2Manager? {
        return { [unowned self] in
            return self.ls2Manager
        }
    }
    
    open var ls2AccountCreationStart: () -> () {
        return { [unowned self] in
            
            guard let onboardingVC = self.window?.rootViewController as? LS2OnboardingViewController else {
                return
            }
            
            
            
            onboardingVC.activityIndicator.startAnimating()
            
            
//            self.store?.dispatch(RSActionCreators.setValueInState(key: "landingIsLoading", value: true as NSObject))
            
        }
    }
    
    open var ls2AccountCreationCompletion: (Bool, Error?) -> () {
        return { [unowned self] success, error in
            
            guard let onboardingVC = self.window?.rootViewController as? LS2OnboardingViewController else {
                return
            }
            
            onboardingVC.activityIndicator.stopAnimating()
            
            if success {
                
                DispatchQueue.main.async {
                    self.showViewController(animated: true)
                }
                
            }
            else {
                //set error message
                let errorMessage: String = {
                    switch error {
                    case .some(LS2ClientError.invalidAccountCreationToken):
                        return "The specified token is invalid. Please contact the research team to get a new token."
                    case .some(LS2ClientError.accountCreationThrottled):
                        return "Too many attempts. Please wait a while and try again. If the problem persists, please contact the research team."
                    default:
                        return "An error occurred during account creation. Please wait a while and try again. If the problem persists, please contact the research team."
                    }
                }()
                
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Log in failed", message: errorMessage, preferredStyle: UIAlertControllerStyle.alert)
                    
                    // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                    let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                        (result : UIAlertAction) -> Void in
                        
                    }
                    
                    alertController.addAction(okAction)
                    onboardingVC.present(alertController, animated: true)
                }
                
                
            }
        }
    }
    
    open var openURLDelegates: [RSOpenURLDelegate] {
        return [
            self.ls2URLDelegate
            ]
    }
    
    open class var elementGeneratorServices: [RSTBElementGenerator] {
        return [
            RSTBElementListGenerator(),
            RSTBElementFileGenerator(),
            RSTBElementSelectorGenerator()
        ]
    }
    
    // Make sure to include all step generators needed for your survey steps here
    open class var stepGeneratorServices: [RSTBStepGenerator] {
        return [
            RSTBLocationStepGenerator(),
            RSTBLocationStepGenerator(),
            RSTBInstructionStepGenerator(),
            RSTBTextFieldStepGenerator(),
            RSTBIntegerStepGenerator(),
            RSTBDecimalStepGenerator(),
            RSTBTimePickerStepGenerator(),
            RSTBFormStepGenerator(),
            RSTBDatePickerStepGenerator(),
            RSTBSingleChoiceStepGenerator(),
            RSTBMultipleChoiceStepGenerator(),
            RSTBBooleanStepGenerator(),
            RSTBPasscodeStepGenerator(),
            RSTBScaleStepGenerator(),
            LS2LoginStepGenerator(),
            LS2ParticipantAccountGeneratorStepGenerator(),
            LS2ParticipantAccountGeneratorRequestingCredentialsStepGenerator(),
            RSEnhancedInstructionStepGenerator(),
            LS2ParticipantAccountGeneratorTokenStepGenerator()
        ]
    }
    
    // Make sure to include all step generators needed for your survey steps here also
    open class var answerFormatGeneratorServices:  [RSTBAnswerFormatGenerator] {
        return [
            RSTBLocationStepGenerator(),
            RSTBTextFieldStepGenerator(),
            RSTBSingleChoiceStepGenerator(),
            RSTBIntegerStepGenerator(),
            RSTBDecimalStepGenerator(),
            RSTBTimePickerStepGenerator(),
            RSTBDatePickerStepGenerator(),
            RSTBScaleStepGenerator()
        ]
    }
    
    // Make sure to include any result transforms for custom steps here
    open class var resultsTransformers: [RSRPFrontEndTransformer.Type] {
        return [
            LS2AutoResult.self
        ]
    }
    
    static func configJSONBaseURL() -> String {
        return Bundle.main.resourceURL!.appendingPathComponent("config").absoluteString
    }
    
    static func loadScheduleItem(filename: String) -> RSAFScheduleItem? {
        
        guard let json = AppDelegate.getJSON(fileName: filename, inDirectory: nil, configJSONBaseURL: self.configJSONBaseURL()) else {
            return nil
        }
        
        return RSAFScheduleItem(json: json)
    }
    
    static func getJson(forFilename filename: String, inBundle bundle: Bundle = Bundle.main) -> JsonElement? {
        
        guard let filePath = bundle.path(forResource: filename, ofType: "json")
            else {
                assertionFailure("unable to locate file \(filename)")
                return nil
        }
        
        guard let fileContent = try? Data(contentsOf: URL(fileURLWithPath: filePath))
            else {
                assertionFailure("Unable to create NSData with content of file \(filePath)")
                return nil
        }
        
        let json = try! JSONSerialization.jsonObject(with: fileContent, options: JSONSerialization.ReadingOptions.mutableContainers)
        
        return json as JsonElement?
    }
    
    open static func getJSON(fileName: String, inDirectory: String? = nil, configJSONBaseURL: String? = nil) -> JSON? {
        
        let urlPath: String = inDirectory != nil ? inDirectory! + "/" + fileName : fileName
        guard let urlBase = configJSONBaseURL,
            let url = URL(string: urlBase + urlPath) else {
                return nil
        }
        
        return self.getJSON(forURL: url)
    }
    
    open static func getJSON(forURL url: URL) -> JSON? {
        
        print(url)
        guard let fileContent = try? Data(contentsOf: url)
            else {
                assertionFailure("Unable to create NSData with content of file \(url)")
                return nil
        }
        
        guard let json = (try? JSONSerialization.jsonObject(with: fileContent, options: JSONSerialization.ReadingOptions.mutableContainers)) as? JSON else {
            return nil
        }
        
        return json
    }

}

