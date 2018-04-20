//
//  LS2Manager.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import Alamofire
import ResearchSuiteExtensions

public protocol LS2Logger {
    func log(_ debugString: String)
}

public protocol LS2ManagerDelegate: class {
    func onInvalidToken(manager: LS2Manager) -> Bool
}

open class LS2Manager: NSObject {
    
    static let kAuthToken = "ls2_auth_token"
    static let kUsername = "ls2_username"
    static let kPassword = "ls2_password"
    
    var client: LS2Client!
    var datapointQueue: RSGlossyQueue<LS2Datapoint>
    
    var credentialsQueue: DispatchQueue!
    var credentialStore: RSCredentialsStore!
    var credentialStoreQueue: DispatchQueue!
    var authToken: String?
    
    var uploadQueue: DispatchQueue!
    var isUploading: Bool = false
    
    let reachabilityManager: NetworkReachabilityManager
    
    var protectedDataAvaialbleObserver: NSObjectProtocol!
    
    var logger: LS2Logger?
    public weak var delegate: LS2ManagerDelegate?
    
    public init?(
        baseURL: String,
        queueStorageDirectory: String,
        store: RSCredentialsStore,
        logger: LS2Logger? = nil,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil
        ) {
        
        self.uploadQueue = DispatchQueue(label: "UploadQueue")
        
        self.client = LS2Client(baseURL: baseURL, dispatchQueue: self.uploadQueue, serverTrustPolicyManager: serverTrustPolicyManager)
        self.datapointQueue = RSGlossyQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])!
        
        self.credentialsQueue = DispatchQueue(label: "CredentialsQueue")
        
        self.credentialStore = store
        self.credentialStoreQueue = DispatchQueue(label: "CredentialStoreQueue")
        
        if let authToken = self.credentialStore.get(key: LS2Manager.kAuthToken) as? String {
            self.authToken = authToken
        }
        
        guard let url = URL(string: baseURL),
            let host = url.host,
            let reachabilityManager = NetworkReachabilityManager(host: host) else {
                return nil
        }
        
        self.reachabilityManager = reachabilityManager
        
        self.logger = logger
        
        super.init()
        
        //set up listeners for the following events:
        // 1) we have access to the internet
        // 2) we have access to protected data
        
        let startUploading = self.startUploading
        
        reachabilityManager.listener = { [weak self] status in
            if reachabilityManager.isReachable {
                do {
                    try startUploading()
                } catch let error {
                    debugPrint(error)
                }
            }
        }
        
        if self.isSignedIn {
            reachabilityManager.startListening()
        }
        
        
        self.protectedDataAvaialbleObserver = NotificationCenter.default.addObserver(forName: .UIApplicationProtectedDataDidBecomeAvailable, object: nil, queue: nil) { [weak self](notification) in
            do {
                try startUploading()
            } catch let error as NSError {
                self?.logger?.log("error occurred when starting upload after device unlock: \(error.localizedDescription)")
                debugPrint(error)
            }
            
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.protectedDataAvaialbleObserver)
    }
    
    public func generateParticipantAccount(generatorCredentials: LS2ParticipantAccountGeneratorCredentials, completion: @escaping ((Error?) -> ())) {
        //check for credentials
        if self.hasCredentials {
            completion(LS2ManagerErrors.hasCredentials)
            return
        }
        
        self.client.generateParticipantAccount(generatorCredentials: generatorCredentials) { (response, error) in
            
            if let err = error {
                
                completion(err)
                return
                
            }
            
            if let credentials = response {
                self.setCredentials(username: credentials.username, password: credentials.password)
            }
            
            completion(nil) 
            
        }
        
        //call client
    }
    
    public func signInWithCredentials(forceSignIn:Bool = false, completion: @escaping ((Error?) -> ())) {
        guard let username = self.getUsername(),
            let password = self.getPassword() else {
                completion(LS2ManagerErrors.doesNotHaveCredentials)
                return
        }
        
        self.signIn(username: username, password: password, forceSignIn: forceSignIn, completion: completion)
    }
    
    public func signIn(username: String, password: String, forceSignIn:Bool = false, completion: @escaping ((Error?) -> ())) {
        
        if self.isSignedIn && forceSignIn == false {
            completion(LS2ManagerErrors.alreadySignedIn)
            return
        }
        
        
        self.client.signIn(username: username, password: password) { (signInResponse, error) in
            
            if let err = error {
                
                completion(err)
                return
                
            }
            
            if let response = signInResponse {
                self.setAuthToken(authToken: response.authToken)
            }
            
            self.reachabilityManager.startListening()
            completion(nil)
            
        }
        
    }
    
    //nil Bool value here means that the check is inconclusive
    public func checkTokenIsValid(completion: @escaping ((Bool?, Error?) -> ())) {
        if !self.isSignedIn {
            completion(nil, LS2ManagerErrors.notSignedIn)
        }
        
        self.uploadQueue.async {
            if let token = self.authToken {
                self.client.checkTokenIsValid(token: token, completion: { (valid, error) in
                    
                    DispatchQueue.main.async {
                        //there was a conclusive answer that the token is invalid
                        if let isValid = valid,
                            !isValid {
                            
                            if let delegate = self.delegate {
                                let shouldLogOut = delegate.onInvalidToken(manager: self)
                                if shouldLogOut { self.signOut(completion: { (error) in }) }
                            }
                            else {
                                self.logger?.log("invalid access token: clearing")
                                self.signOut(completion: { (error) in })
                            }
                            
                        }
                        
                        completion(valid, error)
                    }
                    
                })
            }
            else {
                DispatchQueue.main.async {
                    completion(nil, LS2ManagerErrors.notSignedIn)
                }
            }
        }
        
    }
    
    public func signOut(completion: @escaping ((Error?) -> ())) {
        
//        self.client
        
        let onFinishClosure = {
            do {
                
                self.reachabilityManager.stopListening()
                
                try self.datapointQueue.clear()
                self.clearCredentials()
                
                completion(nil)
                
            } catch let error {
                completion(error)
            }
        }
        
        guard let authToken = self.getAuthToken() else {
            onFinishClosure()
            return
        }
        
        self.client.signOut(token: authToken, completion: { (success, error) in
            onFinishClosure()
        })
    }
    
    public var isSignedIn: Bool {
        return self.getAuthToken() != nil
    }
    
    public var hasCredentials: Bool {
        return self.credentialsQueue.sync {
            
            guard let _ = self.credentialStore.get(key: LS2Manager.kUsername),
                let _ = self.credentialStore.get(key: LS2Manager.kPassword) else {
                    return false
            }
            
            return true
        }
    }
    
    
    
    public var queueIsEmpty: Bool {
        return self.datapointQueue.isEmpty
    }
    
    public var queueItemCount: Int {
        return self.datapointQueue.count
    }
    
    private func clearCredentials() {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: nil, key: LS2Manager.kAuthToken)
                self.credentialStore.set(value: nil, key: LS2Manager.kUsername)
                self.credentialStore.set(value: nil, key: LS2Manager.kPassword)
            }
            self.authToken = nil
            return
        }
    }
    
    private func setCredentials(username: String, password: String) {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: username as NSString, key: LS2Manager.kUsername)
                self.credentialStore.set(value: password as NSString, key: LS2Manager.kPassword)
            }
            return
        }
    }
    
    private func setAuthToken(authToken: String) {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: authToken as NSString, key: LS2Manager.kAuthToken)
            }
            self.authToken = authToken
            return
        }
    }
    
    public func getUsername() -> String? {
        return self.credentialsQueue.sync {
            return self.credentialStoreQueue.sync {
                return self.credentialStore.get(key: LS2Manager.kUsername) as? String
            }
        }
    }

    public func getPassword() -> String? {
        return self.credentialsQueue.sync {
            return self.credentialStoreQueue.sync {
                return self.credentialStore.get(key: LS2Manager.kPassword) as? String
            }
        }
    }

    private func getAuthToken() -> String? {
        return self.credentialsQueue.sync {
            return self.authToken
        }
    }
    
    public func addDatapoint(datapoint: LS2Datapoint, completion: @escaping ((Error?) -> ())) {
        
        if !self.isSignedIn {
            completion(LS2ManagerErrors.notSignedIn)
            return
        }

        //vaidation is done by the queue
//        if !self.client.validateDatapoint(datapoint: datapoint) {
//            completion(LS2ManagerErrors.invalidDatapoint)
//            return
//        }

        do {
            
            try self.datapointQueue.addGlossyElement(element: datapoint)
            
        } catch let error {
            completion(error)
            return
        }
        
        self.upload(fromMemory: false)
        completion(nil)
        
    }
    
    public func startUploading() throws {
        
        if !self.isSignedIn {
            throw LS2ManagerErrors.notSignedIn
        }
        
        self.upload(fromMemory: false)
    }
    
    private func upload(fromMemory: Bool) {
        
        self.uploadQueue.async {
            
            let queue = self.datapointQueue
            guard !queue.isEmpty,
                !self.isUploading else {
                    return
            }
            
            let wappedGetFunction: () throws -> RSGlossyQueue<LS2Datapoint>.RSGlossyQueueElement? = {
                
                if fromMemory {
                    return try self.datapointQueue.getFirstInMemoryGlossyElement()
                }
                else {
                    return try self.datapointQueue.getFirstGlossyElement()
                }
                
            }
            
            do {
                
                if let elementPair = try wappedGetFunction(),
                    let token = self.authToken {

                    let datapoint: LS2Datapoint = elementPair.element
                    self.isUploading = true
                    self.logger?.log("posting datapoint with id: \(datapoint.header.id)")
                    
                    self.client.postDatapoint(datapoint: datapoint, token: token, completion: { (success, error) in
                        
                        self.isUploading = false
                        self.processUploadResponse(element: elementPair, fromMemory: fromMemory, success: success, error: error)
                        
                    })

                }
                
                else {
                    self.logger?.log("either we couldnt load a valid datapoint or there is no token")
                }
                
                
            } catch let error {
                //assume file system encryption error when tryong to read
                self.logger?.log("secure queue threw when trying to get first element: \(error)")
                debugPrint(error)
                
                //try uploading datapoint from memory
                self.upload(fromMemory: true)
                
            }

        }
    
    }
    
    private func processUploadResponse(element: RSGlossyQueue<LS2Datapoint>.RSGlossyQueueElement, fromMemory: Bool, success: Bool, error: Error?) {
        
        if let err = error {
            debugPrint(err)
            self.logger?.log("Got error while posting datapoint: \(error.debugDescription)")
            //should we retry here?
            // and if so, under what conditions
            
            //may need to refresh
            switch error {
            case .some(LS2ClientError.invalidAuthToken):
                
                // Check for delegate and allow it to try to handle invalid token
                // if onInvalidToken returns true, go through signOut
                // If delegate does not exist (i.e., default), go through sign out
                if let delegate = self.delegate {
                    let shouldLogOut = delegate.onInvalidToken(manager: self)
                    if shouldLogOut { self.signOut(completion: { (error) in }) }
                }
                else {
                    self.logger?.log("invalid access token: clearing")
                    self.signOut(completion: { (error) in })
                }
                
                return
            //we've already tried to upload this data point
            //we can remove it from the queue
            case .some(LS2ClientError.dataPointConflict):
                
                self.logger?.log("datapoint conflict: removing")
                
                do {
                    try self.datapointQueue.removeGlossyElement(element: element)
                    
                } catch let error {
                    //we tried to delete,
                    debugPrint(error)
                }
                
                self.upload(fromMemory: fromMemory)
                return
            
            //this datapoint is invalid and won't ever be accepted
            //we can remove it from the queue
            case .some(LS2ClientError.invalidDatapoint):
                
                self.logger?.log("datapoint invalid: removing")
                
                do {
                    try self.datapointQueue.removeGlossyElement(element: element)
                    
                } catch let error {
                    //we tried to delete,
                    debugPrint(error)
                }
                
                self.upload(fromMemory: fromMemory)
                return
                
            case .some(LS2ClientError.badGatewayError):
                self.logger?.log("bad gateway")
                return
                
            default:
                
                let nsError = err as NSError
                switch (nsError.code) {
                case NSURLErrorNetworkConnectionLost:
                    self.logger?.log("We have an internet connecction, but cannot connect to the server. Is it down?")
                    return
                    
                default:
                    self.logger?.log("other error: \(nsError)")
                    break
                }
            }
            
        } else if success {
            //remove from queue
            self.logger?.log("success: removing data point")
            do {
                try self.datapointQueue.removeGlossyElement(element: element)
                
            } catch let error {
                //we tried to delete,
                debugPrint(error)
            }
            
            self.upload(fromMemory: fromMemory)
            
        }
        
    }
    
    

}
