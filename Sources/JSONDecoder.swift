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
        let result = self.scanObject(&generator)
        return result.obj
    }
    
    func scanObject(inout generator: String.UnicodeScalarView.Generator, currentChar: UnicodeScalar = UnicodeScalar(0)) -> (obj: JSONObject, backtrackChar: UnicodeScalar?) {
        func parse(c: UnicodeScalar, inout generator: String.UnicodeScalarView.Generator) -> (obj: JSONObject?, backtrackChar: UnicodeScalar?) {
            switch c.value {
            case 9, 10, 13, 32: // space, tab, newline, cr
                return (obj: nil, backtrackChar: nil)
            case 123: // {
                if let dict = self.parseDict(&generator) {
                    return (obj: .JSONDictionary(dict), backtrackChar: nil)
                } else {
                    return (obj: .JSONInvalid, backtrackChar: nil)
                }
            case 91: // [
                return (obj: .JSONArray(self.parseArray(&generator)), backtrackChar: nil)
            case 34: // "
                return (obj: .JSONString(self.parseString(&generator)), backtrackChar: nil)
            case 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0-9, -, +
                let result = self.parseNumber(&generator, currentChar: c)
                if let num = result.number {
                    return (obj: .JSONNumber(num), backtrackChar: result.backtrackChar)
                } else {
                    return (obj: .JSONInvalid, backtrackChar: result.backtrackChar)
                }
            case 102, 110, 116: // f, n, t
                if let b = self.parseStatement(&generator, currentChar: c) {
					return (obj: .JSONBoolean(b), backtrackChar: nil)
                } else {
                    return (obj: .JSONNull, backtrackChar: nil)
                }
            default:
                // found an invalid char
                return (obj: .JSONInvalid, backtrackChar: nil)
            }
        }

        if currentChar.value != 0 {
            let obj = parse(currentChar, generator: &generator)
            if obj.obj != nil {
                return (obj: obj.obj!, backtrackChar: obj.backtrackChar)
            }
        } else {
            while let c = generator.next() {
                let obj = parse(c, generator: &generator)
                if obj.obj != nil {
                    return (obj: obj.obj!, backtrackChar: obj.backtrackChar)
                }
            }
        }
        
        return (obj: .JSONInvalid, backtrackChar: nil)
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

        while var c = generator.next() {
            while true {
                switch c.value {
                case 9, 10, 13, 32, 44: // space, tab, newline, cr, ','
                    break
                case 34: // "
                    dictKey = self.parseString(&generator)
                case 58: // :
                    if let key = dictKey {
                        let result = self.scanObject(&generator)
                        dict.updateValue(result.obj, forKey: key)
                        dictKey = nil
                        
                        // Backtrack one character
                        if let backTrack = result.backtrackChar {
                            c = backTrack
                            continue
                        }
                    } else {
                        dictEnded = true
                    }
                case 125: // }
                    dictEnded = true
                default:
                    return nil
                }
                break
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

        while var c = generator.next() {
            while true {
                switch c.value {
                case 9, 10, 13, 32, 44: // space, tab, newline, cr, ','
                    break
                case 93: // ]
                    arrayEnded = true
                default:
                    let result = self.scanObject(&generator, currentChar: c)
                    arr.append(result.obj)

                    // Backtrack one character
                    if let backTrack = result.backtrackChar {
                        c = backTrack
                        continue
                    }
                }
                break
            }
            if (arrayEnded) {
                break
            }
        }

        return arr
    }

    // TODO: Add tests for negative numbers and exponential notations
    func parseNumber(inout generator: String.UnicodeScalarView.Generator, currentChar: UnicodeScalar) -> (number: Double?, backtrackChar: UnicodeScalar?) {
        var numberEnded = false
        var numberStarted = false
        var exponentStarted = false
        var exponentNumberStarted = false
        var decimalStarted = false

        var sign : Double = 1.0
        var exponent : Int = 0
        var decimalCount : Int = 0
        var number : Double = 0.0

        func parse(c: UnicodeScalar, inout generator: String.UnicodeScalarView.Generator) -> (numberEnded: Bool?, backtrackChar: UnicodeScalar?) {
            var backtrack: UnicodeScalar? = nil
            switch (c.value) {
            case 9, 10, 13, 32: // space, tab, newline, cr
                if numberStarted {
                    numberEnded = true
                }
            case 43, 45: // +, -
                if (numberStarted && !exponentStarted) || (exponentStarted && exponentNumberStarted) {
                    // error
                    return (numberEnded: nil, backtrackChar: nil)
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
                    return (numberEnded: nil, backtrackChar: nil)
                } else {
                    decimalStarted = true
                }
            case 69, 101: // E, e
                if exponentStarted {
                    // error
                    return (numberEnded: nil, backtrackChar: nil)
                } else {
                    exponentStarted = true
                }
            default:
                if numberStarted {
                    backtrack = c
                    numberEnded = true
                } else {
                    return (numberEnded: nil, backtrackChar: nil)
                }
            }
            if numberEnded {
                let e = __exp10(Double(exponent - decimalCount))
                number = number * e
                number *= sign
                return (numberEnded: true, backtrackChar: backtrack)
            }
            return (numberEnded: false, backtrackChar: backtrack)
        }
        
        let result = parse(currentChar, generator: &generator)
        if let numberEnded = result.numberEnded {
            if numberEnded {
                return (number: number, backtrackChar: result.backtrackChar)
            }
        } else {
            return (number: nil, backtrackChar: result.backtrackChar)
        }
        
        while let c = generator.next() {
            let result = parse(c, generator: &generator)
            if let numberEnded = result.numberEnded {
                if numberEnded {
                    return (number: number, backtrackChar: result.backtrackChar)
                }
            } else {
                return (number: nil, backtrackChar: result.backtrackChar)
            }
        }

        let e = __exp10(Double(exponent - decimalCount))
        number = number * e
        number *= sign
        return (number: number, backtrackChar: nil)
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

