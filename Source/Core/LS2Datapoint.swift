//
//  LS2Datapoint.swift
//  LS2SDK
//
//  Created by James Kizer on 4/19/18.
//

import UIKit
import Gloss

extension Glossy {
    public func prettyPrint() -> String? {
        
        do {
            guard let json = self.toJSON() else {
                return nil
            }
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8)
        }
        catch let error {
            return error.localizedDescription
        }
        
    }
}

public struct LS2SchemaVersion: CustomStringConvertible {
    
    let major: Int
    let minor: Int
    let patch: Int
    
    public init?(versionString: String) {
        
        let versionComponents = versionString.components(separatedBy: ".").compactMap { Int($0) }
        guard versionComponents.count == 3 else {
            return nil
        }
        
        self.major = versionComponents[0]
        self.minor = versionComponents[1]
        self.patch = versionComponents[2]
        
    }
    
    public var versionString: String {
        return "\(self.major).\(self.minor).\(self.patch)"
    }
    
    public var description: String {
        return "\(self.major).\(self.minor).\(self.patch)"
    }
    
}

public struct LS2Schema: Glossy, CustomStringConvertible {
    let name: String
    let version: LS2SchemaVersion
    let namespace: String
    
    public init?(name: String, version: LS2SchemaVersion?, namespace: String) {
        
        guard let version = version else {
            return nil
        }
        
        self.name = name
        self.version = version
        self.namespace = namespace
        
    }
    
    
    public init?(json: JSON) {
        guard let name: String = "name" <~~ json,
            let namespace: String = "namespace" <~~ json else {
                return nil
        }

        guard let versionString: String = "version" <~~ json,
            let version = LS2SchemaVersion(versionString: versionString) else {
            return nil
        }
        
        self.name = name
        self.namespace = namespace
        self.version = version
    }
    
    public func toJSON() -> JSON? {

        return jsonify([
            "name" ~~> self.name,
            "namespace" ~~> self.namespace,
            "version" ~~> self.version.versionString
            ])
    }
    
    public var description: String {
        return self.prettyPrint() ?? ""
    }
}

public enum LS2AcquisitionProvenanceModality: String {
    case Sensed = "sensed"
    case SelfReported = "self-reported"
}

public struct LS2AcquisitionProvenance: Glossy, CustomStringConvertible {
    
    let sourceName: String
    let sourceCreationDateTime: Date
    let modality: LS2AcquisitionProvenanceModality
    
    public init(sourceName: String, sourceCreationDateTime: Date, modality: LS2AcquisitionProvenanceModality) {
        self.sourceName = sourceName
        self.sourceCreationDateTime = sourceCreationDateTime
        self.modality = modality
    }
    
    public init?(json: JSON) {
        guard let sourceName: String = "source_name" <~~ json,
            let sourceCreationDateTime: Date = Gloss.Decoder.decode(dateISO8601ForKey: "source_creation_date_time")(json),
            let modality: LS2AcquisitionProvenanceModality = "modality" <~~ json else {
                return nil
        }
        
        self.sourceName = sourceName
        self.sourceCreationDateTime = sourceCreationDateTime
        self.modality = modality
    }
    
    public func toJSON() -> JSON? {
        
        return jsonify([
            "source_name" ~~> self.sourceName,
            Gloss.Encoder.encode(dateISO8601ForKey: "source_creation_date_time")(self.sourceCreationDateTime),
            "modality" ~~> self.modality
            ])
        
    }
    
    public static var defaultAcquisitionSourceName: String {
        if let info = Bundle.main.infoDictionary {
            let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
            let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
            let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
            
            let osNameVersion: String = {
                let version = ProcessInfo.processInfo.operatingSystemVersion
                let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                
                let osName: String = {
                    #if os(iOS)
                    return "iOS"
                    #elseif os(watchOS)
                    return "watchOS"
                    #elseif os(tvOS)
                    return "tvOS"
                    #elseif os(macOS)
                    return "OS X"
                    #elseif os(Linux)
                    return "Linux"
                    #else
                    return "Unknown"
                    #endif
                }()
                
                return "\(osName) \(versionString)"
            }()
            
            return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
        }
        else {
            return "Unknown"
        }
    }
    
    public var description: String {
        return self.prettyPrint() ?? ""
    }
    
}

public struct LS2DatapointHeader: Glossy, CustomStringConvertible {
    
    let id: UUID
    let schemaID: LS2Schema
    let acquisitionProvenance: LS2AcquisitionProvenance
    var metadata: JSON?
    
    public init(id: UUID, schemaID: LS2Schema, acquisitionProvenance: LS2AcquisitionProvenance, metadata: JSON? = nil) {
        
        self.id = id
        self.schemaID = schemaID
        self.acquisitionProvenance = acquisitionProvenance
        self.metadata = metadata
        
    }
    
    public init?(json: JSON) {
        guard let id: UUID = "id" <~~ json,
            let schemaID: LS2Schema = "schema_id" <~~ json,
            let acquisitionProvenance: LS2AcquisitionProvenance = "acquisition_provenance" <~~ json else {
                return nil
        }
        
        self.id = id
        self.schemaID = schemaID
        self.acquisitionProvenance = acquisitionProvenance
        self.metadata = "metadata" <~~ json
        
    }
    
    public func toJSON() -> JSON? {
        
        return jsonify([
            "id" ~~> self.id,
            "schema_id" ~~> self.schemaID,
            "acquisition_provenance" ~~> self.acquisitionProvenance,
            "metadata" ~~> self.metadata
            ])
        
    }
    
    public var description: String {
        return self.prettyPrint() ?? ""
    }
    
}

public struct LS2Datapoint: Glossy, CustomStringConvertible {
    
    let header: LS2DatapointHeader
    let body: JSON
    
    public init(header: LS2DatapointHeader, body: JSON) {
        self.header = header
        self.body = body
    }
    
    public init?(json: JSON) {
        guard let header: LS2DatapointHeader = "header" <~~ json,
            let body: JSON = "body" <~~ json else {
                return nil
        }
        
        self.header = header
        self.body = body
    }
    
    public func toJSON() -> JSON? {
        
        return jsonify([
            "header" ~~> self.header,
            "body" ~~> self.body
            ])
    }
    
    public var description: String {
        return self.prettyPrint() ?? ""
    }
}

public protocol LS2DatapointConvertible {
    func toDatapoint() -> LS2Datapoint?
}

