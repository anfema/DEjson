//
//  JSONEncoder.swift
//  DeJSON
//
//  Created by Johannes Schriewer on 04.02.15.
//  Copyright (c) 2015 anfema. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the conditions of the 3-clause
// BSD license (see LICENSE.txt for full license text)

import Foundation

func * (left: String, right: Int) -> String {
    if right <= 0 {
        return ""
    }
    
    var result = left
    for _ in 1..<right {
        result += left
    }
    
    return result
}

func -(left: String.Index, right: Int) -> String.Index {
	return left.advancedBy(-right)
}

// TODO: Add tests for JSONEncoder
public class JSONEncoder {
    let jsonObject: JSONObject
    
    public init(_ jsonObject: JSONObject) {
        self.jsonObject = jsonObject
    }
    
    public var jsonString: String? {
        return decodeObject(self.jsonObject)
    }

    public var prettyJSONString: String? {
        return decodeObject(self.jsonObject, prettyPrint: true)
    }

    
    func decodeObject(jsonObject: JSONObject, prettyPrint: Bool = false, indent: Int = 0) -> String? {
        var result: String

        switch jsonObject {
        case .JSONNumber(let number):
            result = "\(number)"
        case .JSONString(let string):
            result = "\"" + self.encodeString(string) + "\""
        case .JSONBoolean(let value):
			if value {
				result = "true"
			} else {
				result = "false"
			}
        case .JSONNull:
            result = "null"
        case .JSONInvalid:
            return nil
        case .JSONArray(let arr):
            result = prettyPrint ? "[\n" : "["
            for (index, item) in arr.enumerate() {
                if let string = decodeObject(item, prettyPrint: prettyPrint, indent: indent + 4) {
                    if index > 0 {
                        if prettyPrint && result[result.endIndex - 1] == "\n" {
                            result.removeAtIndex(result.endIndex - 1)
                        }
                        result += prettyPrint ? ",\n" : ","
                    }
                    if prettyPrint {
                        result += " " * (indent + 4) + string + "\n"
                    } else {
                        result += string
                    }
                }
            }
            result += prettyPrint ? " " * indent + "]" : "]"
        case .JSONDictionary(let dict):
            result = prettyPrint ? "{\n" : "{"
            var first = true
            for (key, value) in dict {
                if let string = decodeObject(value, prettyPrint: prettyPrint, indent: indent + 4) {
                    if !first {
                        if prettyPrint && result[result.endIndex - 1] == "\n" {
                            result.removeAtIndex(result.endIndex - 1)
                        }
                        result += prettyPrint ? ",\n" : ","
                    } else {
                        first = false
                    }
                    
                    if prettyPrint {
                        result += " " * (indent + 4) + "\"\(key)\" : \(string)"
                    } else {
                        result += "\"\(key)\":\(string)"
                    }
                }
            }
            result += prettyPrint ? "\n" + " " * indent + "}" : "}"
        }
        return result
    }
    
    func encodeString(string: String) -> String {
        var result:String = ""
        var generator = string.unicodeScalars.generate()

        while let c = generator.next() {
            switch c.value {
            case 8: // b -> backspace
                result.append(UnicodeScalar(92))
                result.append(UnicodeScalar(98))
            case 9: // t -> tab
                result.append(UnicodeScalar(92))
                result.append(UnicodeScalar(116))
            case 10: // n -> linefeed
                result.append(UnicodeScalar(92))
                result.append(UnicodeScalar(110))
            case 12: // f -> formfeed
                result.append(UnicodeScalar(92))
                result.append(UnicodeScalar(102))
            case 13: // r -> carriage return
                result.append(UnicodeScalar(92))
                result.append(UnicodeScalar(114))
            case 34: // "
                result.append(UnicodeScalar(92))
                result.append(c)
            case 92: // \ -> \
                result.append(UnicodeScalar(92))
                result.append(c)
            default:
                if c.value > 128 {
                    result.append(UnicodeScalar(92))
                    result.append(UnicodeScalar(117)) // u

                    let high = UInt8((c.value >> 8) & 0xff)
                    let low = UInt8(c.value & 0xff)
                    
                    // This is so convoluted because of Swift compiler bug on iOS 8.4 (works simpler on 9.0+)
                    var highString = self.makeHexString(high)
                    var lowString = self.makeHexString(low)
                    var lowGen = lowString.unicodeScalars.generate()
                    var highGen = highString.unicodeScalars.generate()
                    result.append(highGen.next()!)
                    result.append(highGen.next()!)
                    result.append(lowGen.next()!)
                    result.append(lowGen.next()!)
                } else {
                    result.append(c)
                }
            }
        }
        return result
    }
    
    func makeHexString(value: UInt8) -> String {
        return NSString(format: "%02x", value) as String
    }
}