//
//  dejson.swift
//  dejson
//
//  Created by Johannes Schriewer on 30.01.15.
//  Copyright (c) 2015 anfema. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the conditions of the 3-clause
// BSD license (see LICENSE.txt for full license text)


import Foundation

public class JSONDecoder {
    public let string : String.UnicodeScalarView?
    
    public init(_ string: String) {
        self.string = string.unicodeScalars
    }

    public var jsonObject: JSONObject {
        var generator = self.string!.generate()
        return self.scanObject(&generator)
    }
    
    func scanObject(inout generator: String.UnicodeScalarView.Generator, currentChar: UnicodeScalar = UnicodeScalar(0)) -> (JSONObject) {
        func parse(c: UnicodeScalar, inout generator: String.UnicodeScalarView.Generator) -> (JSONObject?) {
            switch c.value {
            case 9, 10, 13, 32: // space, tab, newline, cr
                return nil
            case 123: // {
                if let dict = self.parseDict(&generator) {
                    return .JSONDictionary(dict)
                } else {
                    return .JSONInvalid
                }
            case 91: // [
                return .JSONArray(self.parseArray(&generator))
            case 34: // "
                return .JSONString(self.parseString(&generator))
            case 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0-9, -, +
                if let num = self.parseNumber(&generator, currentChar: c) {
                    return .JSONNumber(num)
                } else {
                    return .JSONInvalid
                }
            case 102, 110, 116: // f, n, t
                if let b = self.parseStatement(&generator, currentChar: c) {
					return .JSONBoolean(b)
                } else {
                    return .JSONNull
                }
            default:
                // found an invalid char
                return .JSONInvalid
            }
        }

        if currentChar.value != 0 {
            if let obj = parse(currentChar, generator: &generator) {
                return obj
            }
        } else {
            while let c = generator.next() {
                if let obj = parse(c, generator: &generator) {
                    return obj
                }
            }
        }
        
        
        return .JSONInvalid
    }
    
    // TODO: Add tests for escaped characters
    func parseString(inout generator: String.UnicodeScalarView.Generator) -> (String) {
        var stringEnded = false
        var slash = false
        var string = String()
        while let c = generator.next() {
            
            if slash {
                switch c.value {
                case 34: // "
                    string.append(UnicodeScalar(34))
                case 110: // n -> linefeed
                    string.append(UnicodeScalar(10))
                case 98: // b -> backspace
                    string.append(UnicodeScalar(8))
                case 102: // f -> formfeed
                    string.append(UnicodeScalar(12))
                case 114: // r -> carriage return
                    string.append(UnicodeScalar(13))
                case 116: // t -> tab
                    string.append(UnicodeScalar(9))
                case 92: // \ -> \
                    string.append(UnicodeScalar(92))
                case 117: // u -> unicode value
                    // gather 4 chars
                    let d1 = self.parseHexDigit(generator.next())
                    let d2 = self.parseHexDigit(generator.next())
                    let d3 = self.parseHexDigit(generator.next())
                    let d4 = self.parseHexDigit(generator.next())
                    let codepoint = (d1 << 12) | (d2 << 8) | (d3 << 4) | d4;
                    string.append(UnicodeScalar(codepoint))
                default:
                    string.append(c)
                }
                slash = false
                continue
            }
            
            switch c.value {
            case 92: // \
                // skip next char (could be a ")
                slash = true
            case 34: // "
                stringEnded = true
            default:
                string.append(c)
            }
            
            if stringEnded {
                break
            }
        }
        return string.stringByReplacingOccurrencesOfString("\\n", withString: "\n")
    }

    func parseHexDigit(digit: UnicodeScalar?) -> UInt32 {
        guard let digit = digit else {
            return 0
        }
        switch digit.value {
        case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
            return digit.value - 48
        case 97, 98, 99, 100, 101, 102:
            return digit.value - 87
        default:
            return 0
        }
    }
    
    func parseDict(inout generator: String.UnicodeScalarView.Generator) -> (Dictionary<String, JSONObject>?) {
        var dict : Dictionary<String, JSONObject> = Dictionary()
        var dictKey: String? = nil
        var dictEnded = false

        while let c = generator.next() {
            switch c.value {
            case 9, 10, 13, 32, 44: // space, tab, newline, cr, ','
                continue
            case 34: // "
                dictKey = self.parseString(&generator)
            case 58: // :
                if let key = dictKey {
                    dict.updateValue(self.scanObject(&generator), forKey: key)
                    dictKey = nil
                } else {
                    dictEnded = true
                }
            case 125: // }
                dictEnded = true
            default:
                return nil
            }
            if dictEnded {
                break
            }
        }
       
        return dict
    }

    func parseArray(inout generator: String.UnicodeScalarView.Generator) -> (Array<JSONObject>) {
        var arr : Array<JSONObject> = Array()
        var arrayEnded = false

        while let c = generator.next() {
            switch c.value {
            case 9, 10, 13, 32, 44: // space, tab, newline, cr, ','
                continue
            case 93: // ]
                arrayEnded = true
            default:
                arr.append(self.scanObject(&generator, currentChar: c))
            }
            if (arrayEnded) {
                break
            }
        }

        return arr
    }

    // TODO: Add tests for negative numbers and exponential notations
    func parseNumber(inout generator: String.UnicodeScalarView.Generator, currentChar: UnicodeScalar) -> (Double?) {
        var numberEnded = false
        var numberStarted = false
        var exponentStarted = false
        var exponentNumberStarted = false
        var decimalStarted = false

        var sign : Double = 1.0
        var exponent : Int = 0
        var decimalCount : Int = 0
        var number : Double = 0.0

        func parse(c: UnicodeScalar, inout generator: String.UnicodeScalarView.Generator) -> (Bool?) {
            switch (c.value) {
            case 9, 10, 13, 32: // space, tab, newline, cr
                if numberStarted {
                    numberEnded = true
                }
            case 43, 45: // +, -
                if (numberStarted && !exponentStarted) || (exponentStarted && exponentNumberStarted) {
                    // error
                    return nil
                } else if !numberStarted {
                    numberStarted = true
                    if c.value == 45 {
                        sign = -1.0
                    }
                }
            case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0-9
                if !numberStarted {
                    numberStarted = true
                }
                if exponentStarted && !exponentNumberStarted {
                    exponentNumberStarted = true
                }
                if decimalStarted {
                    decimalCount++
                    number = number * 10.0 + Double(c.value - 48)
                } else if numberStarted {
                    number = number * 10.0 + Double(c.value - 48)
                } else if exponentStarted {
                    exponent = exponent * 10 + Int(c.value - 48)
                }
            case 46: // .
                if decimalStarted {
                    // error
                    return nil
                } else {
                    decimalStarted = true
                }
            case 69, 101: // E, e
                if exponentStarted {
                    // error
                    return nil
                } else {
                    exponentStarted = true
                }
            default:
                if numberStarted {
                    numberEnded = true
                } else {
                    return nil
                }
            }
            if numberEnded {
                let e = __exp10(Double(exponent - decimalCount))
                number = number * e
                number *= sign
                return true
            }
            return false
        }
        
        if let numberEnded = parse(currentChar, generator: &generator) {
            if numberEnded {
                return number
            }
        } else {
            return nil
        }
        
        while let c = generator.next() {
            if let numberEnded = parse(c, generator: &generator) {
                if numberEnded {
                    return number
                }
            } else {
                return nil
            }
        }

        let e = __exp10(Double(exponent - decimalCount))
        number = number * e
        number *= sign
        return number
    }

    // TODO: Add tests for true, false and null
    func parseStatement(inout generator: String.UnicodeScalarView.Generator, currentChar: UnicodeScalar) -> (Bool?) {
        enum parseState {
            case ParseStateUnknown
            case ParseStateTrue(Int)
            case ParseStateNull(Int)
            case ParseStateFalse(Int)
            
            init() {
                self = .ParseStateUnknown
            }
        }
        
        var state = parseState()
        
        switch currentChar.value {
        case 116: // t
            state = .ParseStateTrue(1)
        case 110: // n
            state = .ParseStateNull(1)
        case 102: // f
            state = .ParseStateFalse(1)
        default:
            return nil
        }

        while let c = generator.next() {
            switch state {
            case .ParseStateUnknown:
                return nil
            case .ParseStateTrue(let index):
                    let search = "true"
                    let i = search.unicodeScalars.startIndex.advancedBy(index)
                    if c == search.unicodeScalars[i] {
                         state = .ParseStateTrue(index+1)
                        if index == search.characters.count - 1 {
                            return true
                        }
                    }
            case .ParseStateFalse(let index):
                let search = "false"
                let i = search.unicodeScalars.startIndex.advancedBy(index)
                if c == search.unicodeScalars[i] {
                    state = .ParseStateFalse(index+1)
                    if index == search.characters.count - 1 {
                        return false
                    }
                }
            case .ParseStateNull(let index):
                let search = "null"
                let i = search.unicodeScalars.startIndex.advancedBy(index)
                if c == search.unicodeScalars[i] {
                    state = .ParseStateNull(index+1)
                    if index == search.characters.count - 1{
                        return nil
                    }
                }
            }
        }
        return nil
    }
}

