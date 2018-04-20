//
//  LS2DefaultResult.swift
//  LS2SDK
//
//  Created by James Kizer on 4/20/18.
//

import UIKit
import ResearchSuiteResultsProcessor
import ResearchKit
import Gloss

open class LS2DefaultResult: RSRPIntermediateResult, RSRPFrontEndTransformer {
    
    private static let supportedTypes = [
        "defaultResult"
    ]
    
    public static func supportsType(type: String) -> Bool {
        return self.supportedTypes.contains(type)
    }
    
    public class func transform(taskIdentifier: String, taskRunUUID: UUID, parameters: [String : AnyObject]) -> RSRPIntermediateResult? {
        
        guard let schema: LS2Schema = "schema" <~~ parameters else {
            return nil
        }
        
        guard let resultDict = RSRPDefaultResultHelpers.extractResults(parameters: parameters, forSerialization: true) else {
            return nil
        }
        
        let result = LS2AutoResult(
            uuid: UUID(),
            taskIdentifier: taskIdentifier,
            taskRunUUID: taskRunUUID,
            schema: schema,
            resultDict: resultDict
        )
        
        result.startDate = RSRPDefaultResultHelpers.startDate(parameters: parameters)
        result.endDate = RSRPDefaultResultHelpers.endDate(parameters: parameters)
        
        return result
        
    }
    
    public let schema: LS2Schema
    public let resultDict: JSON
    
    public init(
        uuid: UUID,
        taskIdentifier: String,
        taskRunUUID: UUID,
        schema: LS2Schema,
        resultDict: JSON
        ) {
        
        self.schema = schema
        self.resultDict = resultDict
        
        super.init(
            type: "LS2DefaultResult",
            uuid: uuid,
            taskIdentifier: taskIdentifier,
            taskRunUUID: taskRunUUID
        )
    }
}

extension LS2DefaultResult: LS2DatapointConvertible {
    public func toDatapoint() -> LS2Datapoint? {
        
        let sourceName = LS2AcquisitionProvenance.defaultAcquisitionSourceName
        let creationDate = self.startDate ?? Date()
        let acquisitionSource = LS2AcquisitionProvenance(sourceName: sourceName, sourceCreationDateTime: creationDate, modality: .SelfReported)
        
        let header = LS2DatapointHeader(id: self.uuid, schemaID: self.schema, acquisitionProvenance: acquisitionSource)
        let datapoint = LS2Datapoint(header: header, body: self.resultDict)
        return datapoint
        
    }
    
}
