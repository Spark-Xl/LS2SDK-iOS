//
//  PAMSample.swift
//  LS2SDK_Example
//
//  Created by James Kizer on 12/26/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import OMHClient

final class PAMSample: OMHDataPointBase {
    
    var affectValence: Int!
    var affectArousal: Int!
    var positiveAffect: Int!
    var negativeAffect: Int!
    var mood: String!
    
    required init() {
        super.init()
        self.acquisitionSourceName = "example"
        self.acquisitionModality = .SelfReported
        self.acquisitionSourceCreationDateTime = Date()
    }
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    override var schema: OMHSchema {
        return OMHSchema(
            name: "photographic-affect-meter-scores",
            version: "1.0.0",
            namespace: "cornell")
    }
    
    override var body: [String: Any] {
        
        return [
            "affect_valence": self.affectValence,
            "affect_arousal": self.affectArousal,
            "positive_affect": self.positiveAffect,
            "negative_affect": self.negativeAffect,
            "mood": self.mood,
            "effective_time_frame": [
                "date_time": self.stringFromDate(self.creationDateTime)
            ]
            
        ]
    }
}
