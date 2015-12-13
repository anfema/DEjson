//
//  JSONObject.swift
//  DeJSON
//
//  Created by Johannes Schriewer on 04.02.15.
//  Copyright (c) 2015 anfema. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the conditions of the 3-clause
// BSD license (see LICENSE.txt for full license text)

import Foundation

public enum JSONObject {
    case JSONArray(Array<JSONObject>)
    case JSONDictionary(Dictionary<String, JSONObject>)
    case JSONString(String)
    case JSONNumber(Double)
    case JSONBoolean(Bool)
    case JSONNull
    case JSONInvalid
    
    public init(_ string: String) {
        self = .JSONInvalid
    }
}
