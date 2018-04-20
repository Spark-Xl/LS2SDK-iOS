//
//  LS2IntermediateDatapointTranformer.swift
//  Alamofire
//
//  Created by James Kizer on 4/19/18.
//

import UIKit
import ResearchSuiteResultsProcessor

public protocol LS2IntermediateDatapointTranformer {
    static func transform(intermediateResult: RSRPIntermediateResult, additionalMetadata: [String: Any]?) -> LS2Datapoint?
}
