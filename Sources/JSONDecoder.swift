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

open class JSONDecoder {
    public let string : String.UnicodeScalarView?
    
    public init(_ string: String) {
        self.string = string.unicodeScalars
    }

    open var jsonObject: JSONObject {
        var generator = self.string!.makeIterator()
        let result = self.scanObject(&generator)
        return result.obj
    }
    
    func scanObject(_ generator: inout String.UnicodeScalarView.Iterator, currentChar: UnicodeScalar = UnicodeScalar(0)) -> (obj: JSONObject, backtrackChar: UnicodeScalar?) {
        func parse(_ c: UnicodeScalar, generator: inout String.UnicodeScalarView.Iterator) -> (obj: JSONObject?, backtrackChar: UnicodeScalar?) {
            switch c.value {
            case 9, 10, 13, 32: // space, tab, newline, cr
                return (obj: nil, backtrackChar: nil)
            case 123: // {
                if let dict = self.parseDict(&generator) {
                    return (obj: .jsonDictionary(dict), backtrackChar: nil)
                } else {
                    return (obj: .jsonInvalid, backtrackChar: nil)
                }
            case 91: // [
                return (obj: .jsonArray(self.parseArray(&generator)), backtrackChar: nil)
            case 34: // "
                return (obj: .jsonString(self.parseString(&generator)), backtrackChar: nil)
            case 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0-9, -, +
                let result = self.parseNumber(&generator, currentChar: c)
                if let num = result.number {
                    return (obj: .jsonNumber(num), backtrackChar: result.backtrackChar)
                } else {
                    return (obj: .jsonInvalid, backtrackChar: result.backtrackChar)
                }
            case 102, 110, 116: // f, n, t
                if let b = self.parseStatement(&generator, currentChar: c) {
					return (obj: .jsonBoolean(b), backtrackChar: nil)
                } else {
                    return (obj: .jsonNull, backtrackChar: nil)
                }
            default:
                // found an invalid char
                return (obj: .jsonInvalid, backtrackChar: nil)
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
        
        return (obj: .jsonInvalid, backtrackChar: nil)
    }
    
    // TODO: Add tests for escaped characters
    func parseString(_ generator: inout String.UnicodeScalarView.Iterator) -> (String) {
        var stringEnded = false
        var slash = false
        var string = String()
        while let c = generator.next() {
            
            if slash {
                switch c.value {
                case 34: // "
                    string.append(String(describing: UnicodeScalar(34)!))
                case 110: // n -> linefeed
                    string.append(String(describing: UnicodeScalar(10)!))
                case 98: // b -> backspace
                    string.append(String(describing: UnicodeScalar(8)!))
                case 102: // f -> formfeed
                    string.append(String(describing: UnicodeScalar(12)!))
                case 114: // r -> carriage return
                    string.append(String(describing: UnicodeScalar(13)!))
                case 116: // t -> tab
                    string.append(String(describing: UnicodeScalar(9)!))
                case 92: // \ -> \
                    string.append(String(describing: UnicodeScalar(92)!))
                case 117: // u -> unicode value
                    // gather 4 chars
                    let d1 = self.parseHexDigit(generator.next())
                    let d2 = self.parseHexDigit(generator.next())
                    let d3 = self.parseHexDigit(generator.next())
                    let d4 = self.parseHexDigit(generator.next())
                    var codepoint = (d1 << 12) | (d2 << 8) | (d3 << 4) | d4;
                    
                    // validate that the codepoint is actually valid unicode, else apple likes to crash our app
                    // see: https://bugs.swift.org/browse/SR-1930
                    if (codepoint > 0xD800 && codepoint < 0xDFFF) || (codepoint > 0x10FFFF) {
                        codepoint = 0x3F
                    }
                    
                    string.append(String(describing: UnicodeScalar(codepoint)!))
                default:
                    string.append(String(c))
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
                string.append(String(c))
            }
            
            if stringEnded {
                break
            }
        }
        return string.replacingOccurrences(of: "\\n", with: "\n")
    }

    func parseHexDigit(_ digit: UnicodeScalar?) -> UInt32 {
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
    
    func parseDict(_ generator: inout String.UnicodeScalarView.Iterator) -> (Dictionary<String, JSONObject>?) {
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

    func parseArray(_ generator: inout String.UnicodeScalarView.Iterator) -> (Array<JSONObject>) {
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
    func parseNumber(_ generator: inout String.UnicodeScalarView.Iterator, currentChar: UnicodeScalar) -> (number: Double?, backtrackChar: UnicodeScalar?) {
        var numberEnded = false
        var numberStarted = false
        var exponentStarted = false
        var exponentNumberStarted = false
        var decimalStarted = false

        var sign : Double = 1.0
        var exponent : Int = 0
        var decimalCount : Int = 0
        var number : Double = 0.0

        func parse(_ c: UnicodeScalar, generator: inout String.UnicodeScalarView.Iterator) -> (numberEnded: Bool?, backtrackChar: UnicodeScalar?) {
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
                    decimalCount += 1
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
    func parseStatement(_ generator: inout String.UnicodeScalarView.Iterator, currentChar: UnicodeScalar) -> (Bool?) {
        enum parseState {
            case parseStateUnknown
            case parseStateTrue(Int)
            case parseStateNull(Int)
            case parseStateFalse(Int)
            
            init() {
                self = .parseStateUnknown
            }
        }
        
        var state = parseState()
        
        switch currentChar.value {
        case 116: // t
            state = .parseStateTrue(1)
        case 110: // n
            state = .parseStateNull(1)
        case 102: // f
            state = .parseStateFalse(1)
        default:
            return nil
        }

        while let c = generator.next() {
            switch state {
            case .parseStateUnknown:
                return nil
            case .parseStateTrue(let index):
                    let search = "true"
                    let i = search.unicodeScalars.index(search.unicodeScalars.startIndex, offsetBy: index)
                    if c == search.unicodeScalars[i] {
                         state = .parseStateTrue(index+1)
                        if index == search.count - 1 {
                            return true
                        }
                    }
            case .parseStateFalse(let index):
                let search = "false"
                let i = search.unicodeScalars.index(search.unicodeScalars.startIndex, offsetBy: index)
                if c == search.unicodeScalars[i] {
                    state = .parseStateFalse(index+1)
                    if index == search.count - 1 {
                        return false
                    }
                }
            case .parseStateNull(let index):
                let search = "null"
                let i = search.unicodeScalars.index(search.unicodeScalars.startIndex, offsetBy: index)
                if c == search.unicodeScalars[i] {
                    state = .parseStateNull(index+1)
                    if index == search.count - 1{
                        return nil
                    }
                }
            }
        }
        return nil
    }
}

