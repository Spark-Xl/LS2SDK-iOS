//
//  LS2BackEnd.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import ResearchSuiteResultsProcessor

open class LS2BackEnd: RSRPBackEnd {
    
    let ls2Mananager: LS2Manager
    let transformers: [LS2IntermediateDatapointTranformer.Type]
    
    public init(ls2Mananager: LS2Manager,
                transformers: [LS2IntermediateDatapointTranformer.Type] = [LS2DefaultTransformer.self]) {
        
        self.ls2Mananager = ls2Mananager
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
            
            if let datapoint: LS2Datapoint = transformer.transform(intermediateResult: intermediateResult, additionalMetadata: additionalMetadata) {
                
                //submit data point
                self.ls2Mananager.addDatapoint(datapoint: datapoint) { (error) in
                    debugPrint(error)
                }
            }
        }
        
    }
    
    open var getAdditionalMetadata: (() -> [String: Any]?)?
    
}
