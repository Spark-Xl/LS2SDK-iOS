//
//  LS2DefaultTransformer.swift
//  LS2SDK
//
//  Created by James Kizer on 4/19/18.
//

import UIKit
import ResearchSuiteResultsProcessor

open class LS2DefaultTransformer: LS2IntermediateDatapointTranformer {
    public static func transform(intermediateResult: RSRPIntermediateResult, additionalMetadata: [String : Any]?) -> LS2Datapoint? {
        guard let datapointConvertible = intermediateResult as? LS2DatapointConvertible else {
            return nil
        }

        return datapointConvertible.toDatapoint()
    }
}
