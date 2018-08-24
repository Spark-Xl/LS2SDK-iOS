//
//  LS2DatabaseManager.swift
//  LS2SDK
//
//  Created by James Kizer on 5/3/18.
//

import UIKit
import RealmSwift
import ResearchSuiteExtensions
import Gloss

open class LS2DatabaseManager: NSObject {
    
    public class LS2RealmProxy: NSObject {
        
        weak var realm: Realm?
        init(realm: Realm?) {
            self.realm = realm
        }
        
        public func objects<Element: Object>(_ type: Element.Type) -> Results<Element>? {
            return self.realm?.objects(type)
        }

    }
    
    static let kDatabaseKey = "ls2_database_key"
    static let kFileUUID = "ls2_file_uuid"
    
//    var credentialsQueue: DispatchQueue!
    var credentialStore: RSCredentialsStore!
    
    let datapointQueue: RSGlossyQueue<LS2RealmDatapoint>
    
    static var TAG = "LS2DatabaseManager"
    public var logger: RSLogger?
    
    var syncQueue: DispatchQueue!
    var isSyncing: Bool = false
    
    open let realmFile: URL
    let encryptionEnabled: Bool
    let fileProtection: FileProtectionType
//    let realmEncryptionKey: Data?
    let schemaVersion: UInt64 = 0
    
    var realm: Realm?
    
    var protectedDataAvaialbleObserver: NSObjectProtocol!
    
    
    //Also, specify data protection setting
    public init?(
        databaseStorageDirectory: String,
        databaseFileName: String,
        queueStorageDirectory: String,
        encrypted: Bool,
        credentialStore: RSCredentialsStore,
        fileProtection: FileProtectionType,
        logger: RSLogger? = nil
        ) {
        
        self.logger = logger
        
        self.datapointQueue = RSGlossyQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])!
        self.syncQueue = DispatchQueue(label: "\(queueStorageDirectory)/UploadQueue")
        
        self.credentialStore = credentialStore
        
        let fileUUID: UUID = {
            if let uuid = credentialStore.get(key: LS2DatabaseManager.kFileUUID) as? NSUUID {
                return uuid as UUID
            }
            else {
                let uuid = UUID()
                credentialStore.set(value: uuid as NSUUID, key: LS2DatabaseManager.kFileUUID)
                return uuid
            }
        }()

        self.encryptionEnabled = encrypted
        if encrypted {
            //check to see if a db key has been set
            if let _ = self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) {
                
            }
            else {
                var key = Data(count: 64)
                _ = key.withUnsafeMutableBytes { bytes in
                    SecRandomCopyBytes(kSecRandomDefault, 64, bytes)
                }
                
                self.credentialStore.set(value: key as NSData, key: LS2DatabaseManager.kDatabaseKey)
            }
            
            
        }
        
        
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first else {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "Database failed initialization")
            return nil
        }
        
        let finalDatabaseDirectory = documentsPath.appending("/\(databaseStorageDirectory)/\(fileUUID.uuidString)")
        var isDirectory : ObjCBool = false
        if FileManager.default.fileExists(atPath: finalDatabaseDirectory, isDirectory: &isDirectory) {
            
            //if a file, remove file and add directory
            if isDirectory.boolValue {
                
            }
            else {
                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "File found at database directory. Removing...")
                do {
                    try FileManager.default.removeItem(atPath: finalDatabaseDirectory)
                } catch let error as NSError {
                    //TODO: handle this
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "An error occurred removing the file: \(error)")
                    print(error.localizedDescription);
                }
            }
            
        }
        
        do {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Configuring database directory: \(finalDatabaseDirectory)")
            self.fileProtection = fileProtection
            try FileManager.default.createDirectory(atPath: finalDatabaseDirectory, withIntermediateDirectories: true, attributes: [.protectionKey: fileProtection])
            var url: URL = URL(fileURLWithPath: finalDatabaseDirectory)
            var resourceValues: URLResourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
            
        } catch let error as NSError {
            //TODO: Handle this
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "An error occurred configuring the database directory: \(error)")
            print(error.localizedDescription);
        }
//
        let finalDatabaseFilePath = finalDatabaseDirectory.appending("/\(databaseFileName)")
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "The final database file is: \(finalDatabaseFilePath)")
        self.realmFile = URL(fileURLWithPath: finalDatabaseFilePath)
        
        super.init()
        
//        self.instantiateRealm { (realm, error) in
//
//            if realm == nil || error != nil {
//                assertionFailure()
//            }
//
//            self.realm = realm
//            self.testRealmFileSettings()
//
//        }

        
        // this failing is not necessarily an issue, it's probably due to not being able to open the file
        // this means that we should still allow the queue to accept datapoints
        // we still need to figure out a way to instantiate the realm db when someone asks for a ref to the realm db if not instantiated
        self.instantiateRealm()
        
        if self.realm != nil {
            self.sync()
        }
        
        self.protectedDataAvaialbleObserver = NotificationCenter.default.addObserver(forName: .UIApplicationProtectedDataDidBecomeAvailable, object: nil, queue: nil) { [weak self](notification) in
            
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Protected data available. Attempting to sync")
            
            if strongSelf.realm == nil {
                strongSelf.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "Realm is nil, attempting to instantitate it")
                strongSelf.instantiateRealm()
            }
            
            strongSelf.sync()
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.protectedDataAvaialbleObserver)
    }
    
    @discardableResult
    func instantiateRealm() -> Realm? {
        do {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Instantiating the realm instance")
            let configuration = self.realmConfig
            self.realm = try Realm(configuration: configuration)
            self.testRealmFileSettings()
            return self.realm
        }
        catch let error {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "An error occurred instantiating the realm instance: \(error)")
            return nil
        }
    }
    
    func expectedFileProtection() -> FileProtectionType {
        #if targetEnvironment(simulator)
        return .completeUntilFirstUserAuthentication
        #else
        return self.fileProtection
        #endif
    }
    
    func testRealmFileSettings() {
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Testing realm settings")
        //test that directory holding realm file does not back stuff up
        let realmDirectory = self.realmFile.deletingLastPathComponent()
        do {
            let resourceValues = try realmDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
            assert(resourceValues.isExcludedFromBackup == true)
        }
        catch _ {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "The realm directory is NOT excluded fromn backup")
            assertionFailure()
        }
        
        
        //only do it if the realm file exists
        if FileManager.default.fileExists(atPath: self.realmFile.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: self.realmFile.path)
                if let protectionKey = attributes[.protectionKey] as? FileProtectionType {
                    let expectedFileProtection = self.expectedFileProtection()
                    if protectionKey != expectedFileProtection {
                        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "The protection key \(protectionKey.rawValue) is not the configured key \(expectedFileProtection.rawValue)")
                    }
                    
                    assert(protectionKey == expectedFileProtection)
                }
                else {
                    #if targetEnvironment(simulator)
                    #else
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Unable to query the file protection key")
                    assertionFailure()
                    #endif
                    
                }
            }
            catch let error {
                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "An error occurred when testing the file protection \(error)")
                assertionFailure()
            }
        }
        
        if self.encryptionEnabled && self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) == nil {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Encryption is misconfigured")
            assertionFailure()
        }
        
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Realm is configured properly")
    }
    
    public func deleteRealm(completion: @escaping ((Error?) -> ())) {
        
        do {
            
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Deleting realm")
            
            //clear file key first so that even if an error occurs, the encryption key is no longer available
            self.credentialStore.set(value: nil, key: LS2DatabaseManager.kDatabaseKey)
            self.credentialStore.set(value: nil, key: LS2DatabaseManager.kFileUUID)
            
            try self.datapointQueue.clear()
            
            assert(self.realm != nil)
            self.realm!.invalidate()
            self.realm = nil
            
            try autoreleasepool {
                let configuration = self.realmConfig
                let realm = try Realm(configuration: configuration)
                
                try realm.write {
                    realm.deleteAll()
                }
                
            }
            
            try FileManager.default.removeItem(at: self.realmFile)
            try FileManager.default.removeItem(at: self.realmFile.deletingLastPathComponent())
            
            completion(nil)

        } catch let error {
            
            
            try? FileManager.default.removeItem(at: self.realmFile)
            try? FileManager.default.removeItem(at: self.realmFile.deletingLastPathComponent())
            
            completion(error)
            
        }

        
    }
    
    var realmConfig: Realm.Configuration {
        return Realm.Configuration(
            fileURL: self.realmFile,
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: self.encryptionEnabled ? (self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) as? NSData)! as Data: nil,
            readOnly: false,
            schemaVersion: self.schemaVersion,
            migrationBlock: nil,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: nil,
            objectTypes: nil)
    }
    
//    func instantiateRealm(completion: @escaping (Realm?, Error?) -> Void) {
//
//        self.testRealmFileSettings()
//
//        let configuration = self.realmConfig
//
//        Realm.asyncOpen(configuration: configuration, callbackQueue: .main, callback: completion)
//    }

//    public func getRealm(queue: DispatchQueue, completion: @escaping (Realm?, Error?) -> Void) {
//
//        self.testRealmFileSettings()
//
//        let configuration = Realm.Configuration(
//            fileURL: self.realmFile,
//            inMemoryIdentifier: nil,
//            syncConfiguration: nil,
//            encryptionKey: self.encryptionEnabled ? (self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) as? NSData) as! Data: nil,
//            readOnly: false,
//            schemaVersion: self.schemaVersion,
//            migrationBlock: nil,
//            deleteRealmIfMigrationNeeded: false,
//            shouldCompactOnLaunch: nil,
//            objectTypes: nil)
//
//        Realm.asyncOpen(configuration: configuration, callbackQueue: queue, callback: completion)
//    }
    
    public func getRealm() -> LS2RealmProxy? {
        
        //if realm exists, return proxy
        //else, try to instantitae it (note, instantitate saves ref to realm)
        //otherwise, return nil
        
        if let realm = self.realm {
            return LS2RealmProxy(realm: realm)
        }
        else if let realm = self.instantiateRealm() {
            return LS2RealmProxy(realm: realm)
        }
        else {
            return nil
        }
    }

    public func addDatapoint(datapoint: LS2RealmDatapoint, completion: @escaping ((Error?) -> ())) {
        
        do {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Adding a datapoint to queue")
            try self.datapointQueue.addGlossyElement(element: datapoint)
            
        } catch let error {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "An error occurred adding a datapoint to the queue \(error)")
            completion(error)
            return
        }
        
        //we should really only try this if we know the phone is unlocked
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Added datapoint to queue, syncing")
        self.sync()
        completion(nil)

    }
    
    public func addDatapoint(datapointConvertible: LS2DatapointConvertible, completion: @escaping ((Error?) -> ())) {
        
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Converting datapoint")
        //this will always pass, but need to wrap in concrete datapoint type
        guard let realmDatapoint =  datapointConvertible.toDatapoint(builder: LS2RealmDatapoint.self) as? LS2RealmDatapoint else {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Datapoint conversion failed")
            return
        }
        
        self.addDatapoint(datapoint: realmDatapoint, completion: completion)
        
    }
    
    private func sync() {
        
        self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Starting sync")
        
        //this is possibly ok
//        if self.realm == nil {
//            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "Realm is nil, attempting to instantitate it")
//            guard _ self.instantiateRealm() else {
//                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "Realm is nil, returning")
//                return
//            }
//        }
        
        //this is possibly ok, data has already been added to datapoints, will be sync'd next time the app is open
        guard self.realm != nil else {
            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .warn, message: "Realm is nil, returning")
            return
        }
        
        self.syncQueue.async {
            
            let queue = self.datapointQueue
            guard !queue.isEmpty,
                !self.isSyncing else {
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Queue is empty or sync is ongoing")
                    return
            }

            do {
                
                let elementPairs = try self.datapointQueue.getGlossyElements()
                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "There are \(elementPairs.count) datapoints to sync")
                if elementPairs.count > 0 {
                    
                    self.isSyncing = true
//                    self.logger?.log("posting datapoint with id: \(datapoint.header.id)")
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Syncing \(elementPairs.count) datapoints")
                    
                    DispatchQueue.main.async {
                        
                        autoreleasepool {
                            guard let realm = self.realm else {
                                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Syncing failed, could not get realm handle")
                                self.syncQueue.async {
                                    self.isSyncing = false
                                }
                                
                                return
                            }
                            
                            do {
                                try realm.write {
                                    realm.add(elementPairs.map { $0.element })
                                }
                            }
                            catch let error {
                                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "A realm write failed with error \(error)")
                                self.syncQueue.async {
                                    self.isSyncing = false
                                }
                                return
                            }
                            
                            
                            do {
                                try elementPairs.forEach({ (pair) in
                                    try self.datapointQueue.removeGlossyElement(element: pair)
                                })
                            }
                            catch let error {
                                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "A failure occurred removing a datapoint from the queue with \(error)")
                                self.syncQueue.async {
                                    self.isSyncing = false
                                }
                                return
                            }
                            
                            self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "Syncing successful")
                            
                            self.syncQueue.async {
                                self.isSyncing = false
                                
                                //if sync was successful, try to sync again
                                //a race condition exists where we are in the process of syncing and new datapoints
                                //are added to the queue
                                self.sync()
                            }
                        }
                        
                    }
                    
                }
                    
                else {
//                    self.logger?.log("There are no datapoints to sync")
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .info, message: "There are no datapoints to sync")
                }
                
                
            } catch let error {
                //assume file system encryption error when tryong to read
//                self.logger?.log("secure queue threw when trying to get elements: \(error)")
                self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Secure queue threw when trying to get elements: \(error)")
                
            }
            
        }
        
    }
    
    public func exportDatapoints(predicate: NSPredicate? = nil, completion: @escaping (Data?, Error?)->() ) {
        
        DispatchQueue.main.async {
        
            autoreleasepool {
                guard let realm = self.realm else {
                    self.logger?.log(tag: LS2DatabaseManager.TAG, level: .error, message: "Export failed, could not get realm handle")
                    completion(nil, nil)
                    return
                }
                
                let datapoints: Results<LS2RealmDatapoint> = {
                    if let predicate = predicate {
                        return realm.objects(LS2RealmDatapoint.self).filter(predicate)
                    }
                    else {
                        return realm.objects(LS2RealmDatapoint.self)
                    }
                }()
                
                let datapointsJSONArray: [JSON] = datapoints.compactMap({ (datapoint) -> JSON? in
                    return datapoint.toJSON()
                })
                
                if JSONSerialization.isValidJSONObject(datapointsJSONArray) {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: datapointsJSONArray, options: [.prettyPrinted])
                        completion(data, nil)
                    }
                    catch let error {
                        completion(nil, error)
                    }
                }
                else {
                    completion(nil, nil)
                }
                
            }
            
        }
        
    }
    
}
