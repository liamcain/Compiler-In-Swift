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
    case t_identifier = "identifier"
    case t_type = "type"
    case t_if = "if"
    case t_while = "while"
    case t_print = "print"
    case t_string = "string"
    case t_digit = "digit"
    case t_parenL = "left parentheses"
    case t_parenR = "right parentheses"
    case t_operator = "operator"
    case t_boolop = "boolean operator"
    case t_assign = "assignment"
    case t_boolval = "boolean value"
    case t_intop = "int operator"
    case t_quote = "quote"
    case t_braceL = "left brace"
    case t_braceR = "right brace"
    case t_eof = "end of file"
}

//public enum Type: String {
//    
//    public enum Kind {
//        case NonTerminal
//        case Terminal
//    }
//    
//    var kind: Kind {
//        switch self {
//        case t_digit, t_parenL, t_parenR, t_operator, t_boolop, t_assign, t_boolval, t_intop, t_quote, t_braceL, t_braceR, t_eof:
//            return Kind.Terminal
//        default:
//            return Kind.NonTerminal
//        }
//    }
//}

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
    var tokenStream: [Token]?
    var lineNum: Int = 1;
    var linePos: Int = 1;
    
    let reservedWords: Dictionary<String, TokenType> = [
        "if":TokenType.t_if,
        "while":TokenType.t_while,
        "print":TokenType.t_print,
        "int":TokenType.t_type,
        "char":TokenType.t_type,
        "string":TokenType.t_type,
        "boolean":TokenType.t_type,
        "false":TokenType.t_boolval,
        "true":TokenType.t_boolval ]
    
    init(outputView: NSTextView?){
        console = outputView
    }
    
    func log(string:String, color: NSColor) {
        console!.font = NSFont(name: "Menlo", size: 12.0)
        let attributedString = NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName: color])
        console!.textStorage?.appendAttributedString(attributedString)
    }
    
    func log(output: String, type: LogType, tokenType:TokenType?=nil){
        var finalOutput = output
        var attributes: [NSObject : AnyObject]
        switch type {
            case .Error:
                log("[Lex Error at position \(lineNum):\(linePos)] ", color: errorColor())
                log(output+"\n", color: mutedColor())
            case .Warning:
                log("[Lex Warning at position \(lineNum):\(linePos)] ", color: warningColor())
                log(output+"\n", color: mutedColor())
            case .Match:
                log(output, color:mutedColor())
                log("[\(tokenType!.rawValue)]\n", color: matchColor())
            default:
                log(output, color: mutedColor())
        }
    }
    
    func createToken(str: String, type: TokenType){
        log("Lexing:  \(str)      \t... ", type: LogType.Match, tokenType:type)
        tokenStream!.append(Token(str: str, type: type, position:(lineNum,linePos)))
    }
    
    func lex(input: String) -> [Token]? {
        var lexState: LexState = LexState.Default
        tokenStream = []
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
            case .Searching:
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
            case .Default:
                switch s {
                    case "$":
                        createToken(s, type: TokenType.t_eof)
                        if i < count(arr) - 1{
                            log("Unreachable code. All code after the '$' has been ignored.",type:LogType.Warning)
                        }
                        return tokenStream
                    case "\n":
                        ++lineNum
                        linePos = 0
                    case ~/"[\\s\\t]":
                        break
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
            case .String:
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
                i++
                linePos++
            }
        }
    }
    
}

