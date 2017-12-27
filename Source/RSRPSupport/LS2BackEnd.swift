//
//  LS2BackEnd.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import OMHClient
import ResearchSuiteResultsProcessor

open class LS2BackEnd: RSRPBackEnd {
    
    let ls2Mananager: LS2Manager
    let transformers: [OMHIntermediateDatapointTransformer.Type]
    
    public init(ls2Mananager: LS2Manager,
                transformers: [OMHIntermediateDatapointTransformer.Type] = [OMHDefaultTransformer.self]) {
        
        self.ls2Mananager = ls2Mananager
        self.transformers = transformers
    }
    
    open func add(intermediateResult: RSRPIntermediateResult) {

        for transformer in self.transformers {
            if let datapoint: OMHDataPoint = transformer.transform(intermediateResult: intermediateResult) {
                
                //submit data point
                self.ls2Mananager.addDatapoint(datapoint: datapoint) { (error) in
                    debugPrint(error)
                }
            }
        }
        
    }
    
}
