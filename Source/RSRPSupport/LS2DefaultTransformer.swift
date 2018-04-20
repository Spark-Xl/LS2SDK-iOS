//
//  LS2DefaultTransformer.swift
//  LS2SDK
//
//  Created by James Kizer on 4/19/18.
//
//
// Copyright 2018, Curiosity Health Company
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
