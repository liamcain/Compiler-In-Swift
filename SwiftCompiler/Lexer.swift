//
//  Lexer.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/18/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

public enum TokenType: String {
    case t_identifier = "t_identifier"
    case t_type = "t_type"
    case t_if = "t_if"
    case t_while = "t_while"
    case t_print = "t_print"
    case t_string = "t_string"
    case t_digit = "t_digit"
    case t_parenL = "t_parenL"
    case t_parenR = "t_parenR"
    case t_operator = "t_operator"
    case t_boolop = "t_boolop"
    case t_assign = "t_assign"
    case t_boolval = "t_boolval"
    case t_intop = "t_intop"
    case t_quote = "t_quote"
    case t_braceL = "t_braceL"
    case t_braceR = "t_braceR"
    case t_eof = "t_eof"
}

public enum LogType {
    case Message
    case Match
    case Error
    case Warning
}

public struct Token {
    var str: String
    var type: TokenType
    var position: (Int, Int)
}

public enum LexState {
    case Searching
    case String
    case Default
}

func ~=(pattern: NSRegularExpression, str: String) -> Bool {
    return pattern.numberOfMatchesInString(str, options: nil, range: NSRange(location: 0,  length: 1)) > 0
}

prefix operator ~/ {}

prefix func ~/(pattern: String) -> NSRegularExpression {
    return NSRegularExpression(pattern: pattern, options: nil, error: nil)!
}

class Lexer {
    
    var console: NSTextView?
    var tokenStream: [Token]? = []
    var lineNum: Int = 1;
    var linePos: Int = 1;
    
    let reservedWords: Dictionary<String, TokenType> = ["if":TokenType.t_if,
        "while":TokenType.t_while,
        "print":TokenType.t_print,
        "int":TokenType.t_type,
        "char":TokenType.t_type,
        "string":TokenType.t_type,
        "false":TokenType.t_boolval,
        "true":TokenType.t_boolval ]
    
    init(outputView: NSTextView?){
        console = outputView
    }
    
    func log(output: String, type: LogType){
        var finalOutput = output
        var attributes: [NSObject : AnyObject]
        switch type {
            case LogType.Error:
                finalOutput = "[Lex Error at position \(lineNum):\(linePos)] " + output
                attributes = [NSForegroundColorAttributeName: NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.4, alpha: 1.0),
                              NSUnderlineStyleAttributeName: NSUnderlineStyleSingle]
            case LogType.Warning:
                finalOutput = "[Lex Warning] " + output
                attributes = [NSForegroundColorAttributeName: NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)]
            case LogType.Match:
                finalOutput = "[Token] " + output
                attributes = [NSForegroundColorAttributeName: NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.3, alpha: 1.0)]
            default:
                attributes = [NSForegroundColorAttributeName: NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)]
        }
        var str: NSAttributedString = NSAttributedString(string: (finalOutput + "\n"), attributes: attributes)
        console!.textStorage?.appendAttributedString(str)
        console?.scrollToEndOfDocument(self)
    }
    
    func createToken(str: String, type: TokenType){
        log(str, type: LogType.Match)
        tokenStream!.append(Token(str: str, type: type, position:(lineNum,linePos)))
    }
    
    func lex(input: String) -> [Token]? {
        var lexState: LexState = LexState.Default
        let arr = Array(input)
        let quote = "\""
        var i: Int = 0;
        var forward: Int = 0;
        lineNum = 1
        linePos = 0
        var s :String, s2: String
        var err: NSMutableString = NSMutableString()
        
        while true {
            if i >= count(arr) || forward >= count(arr) {
                log("Reached EOL without finding $.", type: LogType.Warning)
                return tokenStream
            }
            s = String(arr[i])
            s2 = String(arr[forward])
            
            switch lexState {
            case LexState.Searching:
                switch s2 {
                case ~/"[a-z]":
                    var tokenSoFar = String(arr[i...forward]);
                    if let token = reservedWords[tokenSoFar] {
                        createToken(tokenSoFar, type: token)
                        lexState = LexState.Default
                        linePos += forward-i
                        i = forward
                    } else {
                        ++forward
                    }
                default:
                    lexState = LexState.Default
                    createToken(s, type:TokenType.t_identifier)
                }
            case LexState.Default:
                switch s {
                    case "$":
                        createToken(s, type: TokenType.t_eof)
                        return tokenStream
                    case "\n":
                        ++lineNum
                        linePos = 0
                    case ~/"[\\s\\t]":
                        println("ignore whitespace")
                    case quote:
                        lexState = LexState.String
                        createToken(s, type:TokenType.t_quote)
                    case ~/"[a-z]":
                        lexState = LexState.Searching
                        forward = i+1
                    case ~/"[0-9]":
                        createToken(s, type:TokenType.t_digit)
                    case "+":
                        createToken(s, type:TokenType.t_intop)
                    case "(":
                        createToken(s, type: TokenType.t_parenL)
                    case ")":
                        createToken(s, type: TokenType.t_parenR)
                    case "{":
                        createToken(s, type:TokenType.t_braceL)
                    case "}":
                        createToken(s, type:TokenType.t_braceR)
                    case "=":
                        if i+1 < count(arr) && arr[i+1] == "=" {
                            createToken(s+[arr[i+1]], type:TokenType.t_boolop)
                            ++i
                        } else {
                            createToken(s, type:TokenType.t_assign)
                        }
                    case "!":
                        if i+1 < count(arr) && arr[i+1] == "=" {
                            createToken(s+[arr[i+1]], type:TokenType.t_boolop)
                            ++i
                        } else {
                            log("Unexpected '!'", type:LogType.Error)
                            return nil
                        }
                    default:
                        log("Unknown char \(s)", type:LogType.Error)
                        return nil
                }
            case LexState.String:
                switch s {
                    case quote:
                        createToken(s, type:TokenType.t_quote)
                        lexState = LexState.Default
                    case ~/"[a-z ]":
                        createToken(s, type:TokenType.t_string)
                    case "\n": // Special case so that '\n' prints out correctly
                        log("Unexpected '\\n' found within a string. Strings only support lowercase characters and spaces.", type:LogType.Error)
                        return nil
                    case "\t": // Special case so that '\t' prints out correctly
                        log("Unexpected '\\t' found within a string. Strings only support lowercase characters and spaces.", type:LogType.Error)
                        return nil
                    default:
                        log("Unexpected '\(s)' found within a string. Strings only support lowercase characters and spaces.", type:LogType.Error)
                        return nil
                }
            }
            if lexState != LexState.Searching {
                ++i
                ++linePos
            }
        }
    }
    
}

