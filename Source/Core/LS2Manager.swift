//
//  LS2Manager.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import SecureQueue
import Alamofire
import OMHClient

public protocol LS2CredentialStore {
    func set(value: NSSecureCoding?, key: String)
    func get(key: String) -> NSSecureCoding?
}

public protocol LS2Logger {
    func log(_ debugString: String)
}

public protocol LS2ManagerDelegate: class {
    
    func onInvalidToken(manager: LS2Manager) -> Bool
    func onSignIn(manager: LS2Manager)
    func onSignOut(manager: LS2Manager)
    
}

open class LS2Manager: NSObject {
    
    static let kAuthToken = "AuthToken"
    static let kPublicKeyID = "PublicKeyID"
    
    var client: LS2Client!
    var secureQueue: SecureQueue!
    var clientConfig: LS2ClientConfiguration?
    
    var credentialsQueue: DispatchQueue!
    var credentialStore: LS2CredentialStore!
    var credentialStoreQueue: DispatchQueue!
    
    var authToken: String?

    var publicKeyID: String?
    var publicKey: String?
    
    var uploadQueue: DispatchQueue!
    var isUploading: Bool = false
    
    let reachabilityManager: NetworkReachabilityManager
    
    var protectedDataAvaialbleObserver: NSObjectProtocol!
    
    var logger: LS2Logger?
    public weak var delegate: LS2ManagerDelegate?
    
    public init?(
        baseURL: String,
        queueStorageDirectory: String,
        store: LS2CredentialStore,
        logger: LS2Logger? = nil,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil
        ) {
        
        self.uploadQueue = DispatchQueue(label: "UploadQueue")
        
        self.client = LS2Client(baseURL: baseURL, dispatchQueue: self.uploadQueue, serverTrustPolicyManager: serverTrustPolicyManager)
        self.secureQueue = SecureQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])
        
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
        
        if let (publicKeyID, publicKey) = self.loadPublicKey() {
            self.publicKeyID = publicKeyID
            self.publicKey = publicKey
        }
        
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
                self.setCredentials(authToken: response.authToken)
            }
            
            self.reachabilityManager.startListening()
            self.delegate?.onSignIn(manager: self)
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
    
    private func readPublicKeyFromFile(publicKeyID: String) -> String? {
        guard let documentsPathString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first else {
            return nil
        }
        
        let documentsPath: URL = URL(fileURLWithPath: documentsPathString)
        let publicKeyURL: URL = documentsPath.appendingPathComponent("\(publicKeyID).pem")
        do {
            return try String(contentsOf: publicKeyURL, encoding: .utf8)
        } catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }
    
    //This should probably throw an error if fails
    private func writePublicKeyToFile(publicKeyID: String, publicKey: String) {
        guard let documentsPathString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first else {
            return
        }
        
        let documentsPath: URL = URL(fileURLWithPath: documentsPathString)
        let publicKeyURL: URL = documentsPath.appendingPathComponent("\(publicKeyID).pem")
        guard let publicKeyData: Data = publicKey.data(using: .utf8) else {
            return
        }
        
        do {
            try publicKeyData.write(to: publicKeyURL, options: [Data.WritingOptions.completeFileProtectionUntilFirstUserAuthentication, Data.WritingOptions.atomic])
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        
        debugPrint("Wrote public key to \(publicKeyURL.absoluteString)")
    }
    
    private func loadPublicKey() -> (String, String)? {
        
        return self.credentialsQueue.sync {
            guard let publicKeyID = self.credentialStore.get(key: LS2Manager.kPublicKeyID) as? String,
                let publicKey = self.readPublicKeyFromFile(publicKeyID: publicKeyID) else {
                    return nil
            }
            
            return (publicKeyID, publicKey)
        }
    }
    
    private func savePublicKey(publicKeyID: String, publicKey: String) {
        
        self.credentialsQueue.sync {
            self.writePublicKeyToFile(publicKeyID: publicKeyID, publicKey: publicKey)
            self.credentialStore.set(value: publicKeyID as NSString, key: LS2Manager.kPublicKeyID)
        }
        
    }
    
    private func clearPublicKey(publicKeyID: String) {
        
        self.credentialsQueue.sync {
            self.credentialStore.set(value: nil, key: LS2Manager.kPublicKeyID)
        }
        
    }
    
    public func checkPublicKey(completion: @escaping ((Bool?, Error?) -> ())) {
        if !self.isSignedIn {
            completion(nil, LS2ManagerErrors.notSignedIn)
        }
        
        self.uploadQueue.async {
            if let token = self.authToken {
                
                self.client.getClientConfiguration(token: token, completion: { (clientConfig, error) in
                    
                    guard let config = clientConfig else {
                        completion(nil, error)
                        return
                    }
                    
                    self.clientConfig = config
                    
                    let getPublicKey: (String) -> () = { publicKeyID in
                        self.client.getPublicKey(token: token, publicKeyID: publicKeyID, completion: { (publicKeyStruct, error) in
                            
                            if let publicKeyStruct = publicKeyStruct {
                                //check that public key IDs match
                                //this is an error if this happend!
                                assert(publicKeyID == publicKeyStruct.publicKeyID)
                                self.savePublicKey(publicKeyID: publicKeyStruct.publicKeyID, publicKey: publicKeyStruct.publicKey)
                                self.publicKey = publicKeyStruct.publicKeyID
                                self.publicKeyID = publicKeyStruct.publicKeyID
                                DispatchQueue.main.async {
                                    completion(true, nil)
                                }
                                
                            }
                            else {
                                DispatchQueue.main.async {
                                    completion(nil, error)
                                }
                            }
                        })
                    }
                    
                    //check to see if public key id matches what we have locally
                    
                    if let currentPublicKeyID = self.publicKeyID {
                        
                        if let publicKeyID = config.publicKeyID {
                            
                            //download and update public key
                            if publicKeyID != currentPublicKeyID {
                                getPublicKey(publicKeyID)
                            }
                            else {
                                //if we are here, everything is already up to date
                                DispatchQueue.main.async {
                                    completion(false, nil)
                                }
                            }
                        }
                        else {
                            //if we are here, it looks like we no longer have a public key for the study
                            self.clearPublicKey()
                            DispatchQueue.main.async {
                                completion(true, nil)
                            }
                        }
                        
                    }
                    else {
                        //we don't yet have a public key
                        //try to load it from the server
                        if let publicKeyID = config.publicKeyID {
                            getPublicKey(publicKeyID)
                        }
                        else {
                            DispatchQueue.main.async {
                                completion(false, nil)
                            }
                            return
                        }
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
                
                try self.secureQueue.clear()
                self.clearCredentials()
                self.delegate?.onSignOut(manager: self)
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
    
    public var queueIsEmpty: Bool {
        return self.secureQueue.isEmpty
    }
    
    public var queueItemCount: Int {
        return self.secureQueue.count
    }
    
    private func clearPublicKey() {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: nil, key: LS2Manager.kPublicKeyID)
            }
            self.publicKey = nil
            self.publicKeyID = nil
            return
        }
    }
    
    private func clearCredentials() {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: nil, key: LS2Manager.kAuthToken)
            }
            self.authToken = nil
            return
        }
    }
    
    private func setCredentials(authToken: String) {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: authToken as NSString, key: LS2Manager.kAuthToken)
            }
            self.authToken = authToken
            return
        }
    }
    
    private func getAuthToken() -> String? {
        return self.credentialsQueue.sync {
            return self.authToken
        }
    }
    
    public func addDatapoint(datapoint: OMHDataPoint, completion: @escaping ((Error?) -> ())) {
        
        if !self.isSignedIn {
            completion(LS2ManagerErrors.notSignedIn)
            return
        }
        
        if !self.client.validateSample(sample: datapoint) {
            completion(LS2ManagerErrors.invalidDatapoint)
            return
        }
        
        do {
            
            var elementDictionary: [String: Any] = [
                "datapoint": datapoint.toDict()
            ]
            
            if let mediaDatapoint = datapoint as? OMHMediaDataPoint {
                assertionFailure("media not yet supported!!")
                elementDictionary["mediaAttachments"] = mediaDatapoint.attachments as NSArray
            }
            
            try self.secureQueue.addElement(element: elementDictionary as NSDictionary)
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
            
            guard let queue = self.secureQueue,
                !queue.isEmpty,
                !self.isUploading else {
                    return
            }
            
            let wappedGetFunction: () throws -> (String, NSSecureCoding)? = {
                
                if fromMemory {
                    return self.secureQueue.getFirstInMemoryElement()
                }
                else {
                    return try self.secureQueue.getFirstElement()
                }
                
            }
            
            do {
                
                if let (elementId, value) = try wappedGetFunction(),
                    let dataPointDict = value as? [String: Any],
                    let datapoint = dataPointDict["datapoint"] as? [String: Any],
                    let token = self.authToken {
                    
                    assert(dataPointDict["mediaAttachments"] == nil, "Media attachments are not yet supported")
//                    let mediaAttachments: [OMHMediaAttachment]? = dataPointDict["mediaAttachments"] as? [OMHMediaAttachment]
//                    let mediaAttachmentUploadSuccess = self.onMediaAttachmentUploaded
//                    let datapointUploadSuccess = self.onDatapointUploaded
                    
                    self.isUploading = true
                    
                    if let datapointHeader = datapoint["header"] as? [String: Any],
                        let datapointId = datapointHeader["id"] as? String {
                        self.logger?.log("posting datapoint with id: \(datapointId)")
                    }
                    
                    self.client.postSample(sampleDict: datapoint, token: token, completion: { (success, error) in
                        
                        self.isUploading = false
                        self.processUploadResponse(elementId: elementId, fromMemory: fromMemory, success: success, error: error)
                        
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
    
    private func processUploadResponse(elementId: String, fromMemory: Bool, success: Bool, error: Error?) {
        
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
                    try self.secureQueue.removeElement(elementId: elementId)
                    
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
                    try self.secureQueue.removeElement(elementId: elementId)
                    
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
                try self.secureQueue.removeElement(elementId: elementId)
                
            } catch let error {
                //we tried to delete,
                debugPrint(error)
            }
            
            self.upload(fromMemory: fromMemory)
            
        }
        
    }
    
    

}
