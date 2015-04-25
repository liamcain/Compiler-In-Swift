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
    
    var appdelegate: AppDelegate?
    var tokenStream: [Token]?
    var lineNum: Int = 1
    var linePos: Int = 1
    var hasError: Bool = false
    
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
    
    init(){
        appdelegate = (NSApplication.sharedApplication().delegate as! AppDelegate)
    }
    
    func log(output: String, type: LogType?=LogType.Message, tokenType:TokenType?=nil, profile:OutputProfile = .EndUser){
        if type == LogType.Error {
            hasError = true
        }
        
        let log: Log = Log(output: output, phase: "Lex")
        log.position = (lineNum, linePos)
        log.type = type!
        log.profile = profile
        appdelegate!.log(log)
    }
    
    func stringOutput(str: String) -> String {
        var spaces = ""
        for i in 1...(10 - count(str)) {
            spaces = "\(spaces) "
        }
        return str + spaces
    }
    
    func createToken(str: String, type: TokenType){
        log("Lexing:  \(stringOutput(str))... ", type: LogType.Match, tokenType:type)
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
        hasError = false
        
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
                        log("'\(tokenSoFar)' did not match any keywords. Must continue to look forward.", profile:.Verbose)
                        ++forward
                    }
                default:
                    log("Reached word barrier without finding keyword. Will lex single character as identifier and move on.", profile:.Verbose)
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
                        log("Found whitespace. Ignoring.", type:LogType.Message, profile:.Verbose)
                        break
                    case quote:
                        lexState = LexState.String
                        createToken(s, type:TokenType.t_quote)
                        log("Entering 'string' state. Subsequent characters will be parsed as chars.", profile:.Verbose)
                    case ~/"[a-z]":
                        lexState = LexState.Searching
                        forward = i+1
                        log("Found character. Checking if this is the start of a keyword.", profile:.Verbose)
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
                        log("Exiting 'string' state. Subsequent characters will be parsed normally.", profile:.Verbose)
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

