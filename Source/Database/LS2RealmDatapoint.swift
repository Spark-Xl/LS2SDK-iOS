//
//  LS2RealmDatapoint.swift
//  LS2SDK
//
//  Created by James Kizer on 5/3/18.
//

import UIKit
import RealmSwift
import Realm
import Gloss

public enum LS2RealmDatapointError: Error {
    case corruptedBody
    case corruptedHeader
}

open class LS2RealmDatapoint: Object, LS2Datapoint, LS2DatapointBuilder {
    
    @objc dynamic var idString: String = ""
    @objc dynamic var schemaNamespace: String = ""
    @objc dynamic var schemaName: String = ""
    @objc dynamic var schemaVersionMajor: Int = 0
    @objc dynamic var schemaVersionMinor: Int = 0
    @objc dynamic var schemaVersionPatch: Int = 0
    @objc dynamic var apSourceName: String = ""
    @objc dynamic var apSourceCreationDateTime: Date = Date(timeIntervalSince1970: 1)
    @objc dynamic var apModalityString: String = ""
    @objc dynamic var metadataJSONString: String? = nil
    
    
    @objc dynamic var bodyJSONString: String = ""
    
    
    public static func createDatapoint(header: LS2DatapointHeader, body: JSON) -> LS2Datapoint? {
        return LS2RealmDatapoint(header: header, body: body)
    }
    
    private func configureHeader(header: LS2DatapointHeader) {
        
        self.idString = header.id.uuidString
        self.schemaNamespace = header.schemaID.namespace
        self.schemaName = header.schemaID.name
        self.schemaVersionMajor = header.schemaID.version.major
        self.schemaVersionMinor = header.schemaID.version.minor
        self.schemaVersionPatch = header.schemaID.version.patch
        self.apSourceName = header.acquisitionProvenance.sourceName
        self.apSourceCreationDateTime = header.acquisitionProvenance.sourceCreationDateTime
        self.apModalityString = header.acquisitionProvenance.modality.rawValue
        
        if let metadata = header.metadata {
            do {
                let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])
                guard let metadataString = String(data: metadataData, encoding: .utf8) else {
                    throw LS2RealmDatapointError.corruptedBody
                }
                self.metadataJSONString = metadataString
            }
                
            catch let error {
                //Do a better job of handling this here!!
                assertionFailure("Cannot convert datapoint")
                debugPrint(error)
            }
        }
        
        self._header = header
    }
    
    private func configureBody(body: JSON) {
        //first, serialize body to string, save in bodyJSONString
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            guard let bodyString = String(data: bodyData, encoding: .utf8) else {
                throw LS2RealmDatapointError.corruptedBody
            }
            self.bodyJSONString = bodyString
            self._body = body
        }
        
        catch let error {
            //Do a better job of handling this here!!
            assertionFailure("Cannot convert datapoint")
            debugPrint(error)
        }
        
        //set _body to body
    }
    
    private func jsonForString(_ string: String) -> JSON? {
        do {
            guard let jsonData = string.data(using: .utf8),
                let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? JSON else {
                    throw LS2RealmDatapointError.corruptedBody
            }
            
            return json
            
            
        }
        catch let error {
            //Do a better job of handling this here!!
            assertionFailure("Cannot convert datapoint")
            debugPrint(error)
            return nil
        }

    }
    
    private var _header: LS2DatapointHeader?
    public var header: LS2DatapointHeader? {
        
        if let header = _header {
            return header
        }
        else {
            
            guard let id = UUID(uuidString: self.idString) else {
                return nil
            }
            
            let schemaVersion = LS2SchemaVersion(
                major: self.schemaVersionMajor,
                minor: self.schemaVersionMinor,
                patch: self.schemaVersionPatch
            )
            
            guard let schema = LS2Schema(
                name: self.schemaName,
                version: schemaVersion,
                namespace: self.schemaNamespace
                ) else {
                    return nil
            }
            
            guard let modality = LS2AcquisitionProvenanceModality(rawValue: self.apModalityString) else {
                return nil
            }
            
            let acquisitionProvenance = LS2AcquisitionProvenance(
                sourceName: self.apSourceName,
                sourceCreationDateTime: self.apSourceCreationDateTime,
                modality: modality
            )
            
            var metadata: JSON? = nil
            if let metadataString = self.metadataJSONString {
                guard let json = self.jsonForString(metadataString) else {
                        return nil
                }
                
                metadata = json
            }
            
            let header = LS2DatapointHeader(
                id: id,
                schemaID: schema,
                acquisitionProvenance: acquisitionProvenance,
                metadata: metadata
            )
            
            self._header = header
            return header
        }
    }
    
    private var _body: JSON?
    public var body: JSON? {
        if let json = _body {
            return json
        }
        else {
            
            guard let json = self.jsonForString(self.bodyJSONString) else {
                return nil
            }
            
            self._body = json
            return json
            
        }
    }

    public convenience init?(header: LS2DatapointHeader, body: JSON) {
        self.init()
        self.configureHeader(header: header)
        self.configureBody(body: body)
    }
    
    public required convenience init?(json: JSON) {
        guard let header: LS2DatapointHeader = "header" <~~ json,
            let body: JSON = "body" <~~ json else {
                return nil
        }
        
        self.init(header: header, body: body)
    }
    
    public required init() {
        super.init()
    }
    
    public required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    public required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }

    public func toJSON() -> JSON? {
        
        return jsonify([
            "header" ~~> self.header,
            "body" ~~> self.body
            ])
    }

}
