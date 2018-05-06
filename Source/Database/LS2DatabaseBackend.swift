//
//  LS2DatabaseBackend.swift
//  LS2SDK
//
//  Created by James Kizer on 5/3/18.
//

import UIKit
import ResearchSuiteResultsProcessor

open class LS2DatabaseBackEnd: RSRPBackEnd {
    
    let databaseManager: LS2DatabaseManager
    let transformers: [LS2IntermediateDatapointTranformer.Type]
    
    public init(databaseManager: LS2DatabaseManager,
                transformers: [LS2IntermediateDatapointTranformer.Type] = [LS2DefaultTransformer.self]) {
        
        self.databaseManager = databaseManager
        self.transformers = transformers
    }
    
    open func add(intermediateResult: RSRPIntermediateResult) {
        
        for transformer in self.transformers {
            let additionalMetadata: [String: Any]? = {
                if let closure = self.getAdditionalMetadata {
                    return closure()
                }
                else {
                    return nil
                }
            }()
            
            if let convertible: LS2DatapointConvertible = transformer.transform(intermediateResult: intermediateResult, additionalMetadata: additionalMetadata),
                let datapoint = convertible.toDatapoint(builder: LS2RealmDatapoint.self) as? LS2RealmDatapoint {

                self.databaseManager.addDatapoint(datapoint: datapoint) { (error) in

                }
                
            }
        }
        
    }
    
    open var getAdditionalMetadata: (() -> [String: Any]?)?
    
}
