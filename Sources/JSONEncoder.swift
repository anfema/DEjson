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


// TODO: Add tests for JSONEncoder
open class JSONEncoder {
    let jsonObject: JSONObject
    
    public init(_ jsonObject: JSONObject) {
        self.jsonObject = jsonObject
    }
    
    open var jsonString: String? {
        return decodeObject(self.jsonObject)
    }

    open var prettyJSONString: String? {
        return decodeObject(self.jsonObject, prettyPrint: true)
    }

    
    func decodeObject(_ jsonObject: JSONObject, prettyPrint: Bool = false, indent: Int = 0) -> String? {
        var result: String

        switch jsonObject {
        case .jsonNumber(let number):
            result = "\(number)"
        case .jsonString(let string):
            result = "\"" + self.encodeString(string) + "\""
        case .jsonBoolean(let value):
			if value {
				result = "true"
			} else {
				result = "false"
			}
        case .jsonNull:
            result = "null"
        case .jsonInvalid:
            return nil
        case .jsonArray(let arr):
            result = prettyPrint ? "[\n" : "["
            for (index, item) in arr.enumerated() {
                if let string = decodeObject(item, prettyPrint: prettyPrint, indent: indent + 4) {
                    if index > 0 {
                        if prettyPrint &&  result[result.index(before: result.endIndex)] == "\n" {
                            result.remove(at: result.index(before: result.endIndex))
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
        case .jsonDictionary(let dict):
            result = prettyPrint ? "{\n" : "{"
            var first = true
            for (key, value) in dict {
                if let string = decodeObject(value, prettyPrint: prettyPrint, indent: indent + 4) {
                    if !first {
                        if prettyPrint && result[result.index(before: result.endIndex)] == "\n" {
                            result.remove(at: result.index(before: result.endIndex))
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
    
    func encodeString(_ string: String) -> String {
        var result:String = ""
        var generator = string.unicodeScalars.makeIterator()

        while let c = generator.next() {
            switch c.value {
            case 8: // b -> backspace
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(describing: UnicodeScalar(98)!))
            case 9: // t -> tab
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(describing: UnicodeScalar(116)!))
            case 10: // n -> linefeed
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(describing: UnicodeScalar(110)!))
            case 12: // f -> formfeed
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(describing: UnicodeScalar(102)!))
            case 13: // r -> carriage return
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(describing: UnicodeScalar(114)!))
            case 34: // "
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(c))
            case 92: // \ -> \
                result.append(String(describing: UnicodeScalar(92)!))
                result.append(String(c))
            default:
                if c.value > 128 {
                    result.append(String(describing: UnicodeScalar(92)!))
                    result.append(String(describing: UnicodeScalar(117)!)) // u

                    let high = UInt8((c.value >> 8) & 0xff)
                    let low = UInt8(c.value & 0xff)
                    
                    // This is so convoluted because of Swift compiler bug on iOS 8.4 (works simpler on 9.0+)
                    let highString = self.makeHexString(high)
                    let lowString = self.makeHexString(low)
                    var lowGen = lowString.unicodeScalars.makeIterator()
                    var highGen = highString.unicodeScalars.makeIterator()
                    result.append(String(highGen.next()!))
                    result.append(String(highGen.next()!))
                    result.append(String(lowGen.next()!))
                    result.append(String(lowGen.next()!))
                } else {
                    result.append(String(c))
                }
            }
        }
        return result
    }
    
    func makeHexString(_ value: UInt8) -> String {
        return NSString(format: "%02x", value) as String
    }
}
