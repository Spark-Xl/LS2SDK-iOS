//
//  LS2AutoResult.swift
//  LS2SDK
//
//  Created by James Kizer on 4/19/18.
//

import UIKit
import ResearchSuiteResultsProcessor
import ResearchKit
import Gloss

open class LS2AutoResult: RSRPIntermediateResult, RSRPFrontEndTransformer {
    
    private static let supportedTypes = [
        "auto"
    ]
    
    public static func supportsType(type: String) -> Bool {
        return self.supportedTypes.contains(type)
    }
    
    public class func extractResults(parameters: [String : AnyObject], forSerialization: Bool) -> [String: AnyObject]? {
        
        //look for arrays of step results
        
        let selector: (RSRPDefaultValueTransformer) -> AnyObject? = {
            if forSerialization { return { $0.defaultSerializedValue } }
            else { return { $0.defaultValue } }
        }()
        
        var resultsMap: [String: AnyObject] = [:]
        
        parameters.forEach { (key,value) in
            
            guard let stepResultArray = value as? [ORKStepResult] else {
                return
            }
            
            stepResultArray.forEach { stepResult in
                
                guard let resultArray =  stepResult.results else {
                    return
                }
                
                resultArray.forEach({ (result) in
                    
                    //get identifier
                    let identifierComponentArray = result.identifier.components(separatedBy: ".")
                    assert(identifierComponentArray.count > 0)
                    
                    let identifier: String = identifierComponentArray.last!
                    if  let transformable = result as? RSRPDefaultValueTransformer {
                        if let resultValue: AnyObject = selector(transformable) {
                            assert(resultsMap[identifier] == nil, "Duplicate values for key \(identifier)")
                            resultsMap[identifier] = resultValue
                        }
                    }
                    else {
                        assertionFailure("value for \(identifier) is not transformable")
                    }
                    
                })
                
            }
            
        }
        
        return resultsMap
        
    }
    
    public class func transform(taskIdentifier: String, taskRunUUID: UUID, parameters: [String : AnyObject]) -> RSRPIntermediateResult? {

        guard let schema: LS2Schema = "schema" <~~ parameters else {
            return nil
        }
        
        guard let resultDict = LS2AutoResult.extractResults(parameters: parameters, forSerialization: true) else {
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
            type: "LS2AutoResult",
            uuid: uuid,
            taskIdentifier: taskIdentifier,
            taskRunUUID: taskRunUUID
        )
    }
}

extension LS2AutoResult: LS2DatapointConvertible {
    public func toDatapoint() -> LS2Datapoint? {
        
        let sourceName = LS2AcquisitionProvenance.defaultAcquisitionSourceName
        let creationDate = self.startDate ?? Date()
        let acquisitionSource = LS2AcquisitionProvenance(sourceName: sourceName, sourceCreationDateTime: creationDate, modality: .SelfReported)
        
        let header = LS2DatapointHeader(id: self.uuid, schemaID: self.schema, acquisitionProvenance: acquisitionSource)
        let datapoint = LS2Datapoint(header: header, body: self.resultDict)
        return datapoint
        
    }

}


