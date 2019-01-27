//
//  LS2TokenBasedAccountCreationURLDelegate.swift
//  LS2SDK
//
//  Created by James Kizer on 11/15/18.
//

import UIKit
import ResearchSuiteExtensions

open class LS2TokenBasedAccountCreationURLDelegate: NSObject, RSOpenURLDelegate {
    
    let path: String
    let ls2ManagerProvider: () -> LS2Manager?
    let creationStart: () -> ()
    let creationCompletion: (Bool, Error?) -> ()
    public init(path: String, ls2ManagerProvider: @escaping () -> LS2Manager?, creationStart: @escaping () -> (), creationCompletion: @escaping (Bool, Error?) -> ()) {
        self.path = path
        self.ls2ManagerProvider = ls2ManagerProvider
        self.creationStart = creationStart
        self.creationCompletion = creationCompletion
        super.init()
    }
    
    open func handleURL(app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey : Any], context: [String : AnyObject]) -> Bool {
        
        guard let ls2Manger = self.ls2ManagerProvider() else {
            return false
        }
        
        if ls2Manger.isSignedIn {
            return false
        }
        
        let queryParams: [String: String] = url.queryDictionary ?? [:]
        let path = url.path
        
        guard let host = url.host,
            self.path == host + path,
            let token = queryParams["token"],
            let generatorId = queryParams["generator_id"] else {
                return false
        }
        
        DispatchQueue.main.async {
            self.creationStart()
        }
        
        ls2Manger.generateParticipantAccountWithToken(generatorId: generatorId, token: token) { [unowned self] (error) in
            
            switch error {
                
            case .none:
                fallthrough
            case .some(LS2ManagerErrors.hasCredentials):
                //if no error OR we alreay have credentials, try to log in with credentials
                ls2Manger.signInWithCredentials(forceSignIn: true, completion: { (error) in
                    DispatchQueue.main.async {
                        self.creationCompletion(error == nil, nil)
                    }
                })
                
            default:
                DispatchQueue.main.async {
                    self.creationCompletion(false, error)
                }
            }
            
        }
        
        return true
        
    }

}

extension URL {
    var queryDictionary: [String: String]? {
        guard let query = URLComponents(string: self.absoluteString)?.query else { return nil}
        
        var queryStrings = [String: String]()
        for pair in query.components(separatedBy: "&") {
            
            let key = pair.components(separatedBy: "=")[0]
            
            let value = pair
                .components(separatedBy:"=")[1]
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? ""
            
            queryStrings[key] = value
        }
        return queryStrings
    }
}
