//
//  OMHDefaultTransformer.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import OMHClient
import ResearchSuiteResultsProcessor

open class OMHDefaultTransformer: OMHIntermediateDatapointTransformer {
    
    open static func transform(intermediateResult: RSRPIntermediateResult) -> OMHDataPoint? {
        return intermediateResult as? OMHDataPoint
    }
    
}
