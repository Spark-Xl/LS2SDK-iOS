//
//  LS2DatabaseManager.swift
//  LS2SDK
//
//  Created by James Kizer on 5/3/18.
//

import UIKit
import RealmSwift
import ResearchSuiteExtensions

open class LS2DatabaseManager: NSObject {
    
    static let kDatabaseKey = "ls2_database_key"
    
//    var credentialsQueue: DispatchQueue!
    var credentialStore: RSCredentialsStore!
    
    let datapointQueue: RSGlossyQueue<LS2RealmDatapoint>
    
    var logger: LS2Logger?
    
    var syncQueue: DispatchQueue!
    var isSyncing: Bool = false
    
    let realmFile: URL
    let encryptionEnabled: Bool
//    let realmEncryptionKey: Data?
    let schemaVersion: UInt64 = 0
    
    public init?(
        databaseStorageDirectory: String,
        databaseFileName: String,
        queueStorageDirectory: String,
        encrypted: Bool,
        credentialStore: RSCredentialsStore
        ) {
        
        self.datapointQueue = RSGlossyQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])!
        self.syncQueue = DispatchQueue(label: "\(queueStorageDirectory)/UploadQueue")
        
        self.credentialStore = credentialStore
        
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
            return nil
        }
        
        let finalDatabaseDirectory = documentsPath.appending("/\(databaseStorageDirectory)")
        var isDirectory : ObjCBool = false
        if FileManager.default.fileExists(atPath: finalDatabaseDirectory, isDirectory: &isDirectory) {
            
            //if a file, remove file and add directory
            if isDirectory.boolValue {
                
            }
            else {
                
                do {
                    try FileManager.default.removeItem(atPath: finalDatabaseDirectory)
                } catch let error as NSError {
                    //TODO: handle this
                    print(error.localizedDescription);
                }
            }
            
        }
        
        do {
            
            try FileManager.default.createDirectory(atPath: finalDatabaseDirectory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var url: URL = URL(fileURLWithPath: finalDatabaseDirectory)
            var resourceValues: URLResourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
            
        } catch let error as NSError {
            //TODO: Handle this
            print(error.localizedDescription);
        }
//
        let finalDatabaseFilePath = documentsPath.appending("/\(databaseStorageDirectory)/\(databaseFileName)")
        self.realmFile = URL(fileURLWithPath: finalDatabaseFilePath)
        
        super.init()
        
        self.testRealmFileSettings()
        
    }
    
    func expectedFileProtection() -> FileProtectionType {
        #if targetEnvironment(simulator)
        return .completeUntilFirstUserAuthentication
        #else
        return .complete
        #endif
    }
    
    func testRealmFileSettings() {
        //test that directory holding realm file does not back stuff up
        let realmDirectory = self.realmFile.deletingLastPathComponent()
        do {
            let resourceValues = try realmDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
            assert(resourceValues.isExcludedFromBackup == true)
        }
        catch _ {
            assertionFailure()
        }
        
        
        //only do it if the realm file exists
        if FileManager.default.fileExists(atPath: self.realmFile.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: self.realmFile.path)
                if let protectionKey = attributes[.protectionKey] as? FileProtectionType {
                    let expectedFileProtection = self.expectedFileProtection()
                    assert(protectionKey == expectedFileProtection)
                }
                else {
                    assertionFailure()
                }
            }
            catch _ {
                assertionFailure()
            }
        }
        
        if self.encryptionEnabled {
            assert(self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) != nil)
        }
        
    }
    
    public func deleteRealm(completion: @escaping ((Error?) -> ())) {
        
        do {
            
            try self.datapointQueue.clear()
            
            self.getRealm(queue: .main) { (realm, error) in
                
                if error != nil {
                    completion(error)
                }
                
                guard let realm = realm else {
                    fatalError("Could not get realm")
                    completion(nil)
                }
                
                do {
                    
                    try realm.write {
                        realm.deleteAll()
                    }
                    
                    try FileManager.default.removeItem(at: self.realmFile)
                    self.credentialStore.set(value: nil, key: LS2DatabaseManager.kDatabaseKey)
                    
                    completion(nil)
                    
                }
                catch let error {
                    fatalError("Could not remove realm")
                    completion(error)
                }
                
                
                
            }

        } catch let error {
            completion(error)
        }
        
    }

    public func getRealm(queue: DispatchQueue, completion: @escaping (Realm?, Error?) -> Void) {
        
        self.testRealmFileSettings()
        
        
        
        let configuration = Realm.Configuration(
            fileURL: self.realmFile,
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: self.encryptionEnabled ? (self.credentialStore.get(key: LS2DatabaseManager.kDatabaseKey) as? NSData) as! Data: nil,
            readOnly: false,
            schemaVersion: self.schemaVersion,
            migrationBlock: nil,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: nil,
            objectTypes: nil)
        
        Realm.asyncOpen(configuration: configuration, callbackQueue: queue, callback: completion)
    }

    public func addDatapoint(datapoint: LS2RealmDatapoint, completion: @escaping ((Error?) -> ())) {
        
        do {
            
            try self.datapointQueue.addGlossyElement(element: datapoint)
            
        } catch let error {
            completion(error)
            return
        }
        
        self.sync()
        completion(nil)

    }
    
    public func addDatapoint(datapointConvertible: LS2DatapointConvertible, completion: @escaping ((Error?) -> ())) {
        
        //this will always pass, but need to wrap in concrete datapoint type
        guard let realmDatapoint =  datapointConvertible.toDatapoint(builder: LS2RealmDatapoint.self) as? LS2RealmDatapoint else {
            return
        }
        
        self.addDatapoint(datapoint: realmDatapoint, completion: completion)
        
    }
    
    private func sync() {
        
        self.syncQueue.async {
            
            let queue = self.datapointQueue
            guard !queue.isEmpty,
                !self.isSyncing else {
                    return
            }

            do {
                
                let elementPairs = try self.datapointQueue.getGlossyElements()
                if elementPairs.count > 0 {
                    
                    self.isSyncing = true
//                    self.logger?.log("posting datapoint with id: \(datapoint.header.id)")
                    
                    self.getRealm(queue: self.syncQueue, completion: { (realm, error) in
                        
                        guard let realm = realm,
                            error == nil else {
                                debugPrint(error!)
                                fatalError("what's the deal with realm errors?")
                                self.isSyncing = false
                                return
                        }

                        do {
                            try realm.write {
                                
                                realm.add(elementPairs.map { $0.element })
                                
                            }
                            
                            try elementPairs.forEach({ (pair) in
                                try self.datapointQueue.removeGlossyElement(element: pair)
                            })
                        }
                        catch let error {
                            debugPrint(error)
                            fatalError("what's the deal with realm / datapoint queue errors?")
                            self.isSyncing = false
                            return
                        }
                        
                        self.isSyncing = false
                        
                    })
                    
                }
                    
                else {
                    self.logger?.log("either we couldnt load a valid datapoint or there is no token")
                }
                
                
            } catch let error {
                //assume file system encryption error when tryong to read
                self.logger?.log("secure queue threw when trying to get elements: \(error)")
                
            }
            
        }
        
    }
    
}
