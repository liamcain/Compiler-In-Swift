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

public struct Token {
    var str: String
    var type: TokenType
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
    var tokenStream: [Token] = []
    
    init(outputView: NSTextView?){
        console = outputView
    }
    
    func log(output: String){
        var str: NSAttributedString = NSAttributedString(string: (output + "\n"))
        console!.textStorage?.appendAttributedString(str)
    }
    
    func lex(input: String) -> [Token] {
        let reservedWords: Dictionary<String, TokenType> = ["if":TokenType.t_if,
            "while":TokenType.t_while,
            "print":TokenType.t_print,
            "int":TokenType.t_type,
            "char":TokenType.t_type,
            "string":TokenType.t_type,
            "false":TokenType.t_boolval,
            "true":TokenType.t_boolval ]
        
        var lexState: LexState = LexState.Default
        let arr = Array(input)
        let quote = "\""
        var i: Int = 0;
        var forward: Int = 0;
        var lineNum: Int = 0;
        var linePos: Int = 0;
        var s :String, s2: String
        var err: NSMutableString = NSMutableString()
        
        while true {
            if i >= count(arr) || forward >= count(arr) {
                log("Lex error. Reached EOL without finding $.")
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
                        tokenStream += [Token(str: tokenSoFar, type: token)]
                        lexState = LexState.Default
                        i = forward
                    } else {
                        ++forward
                    }
                case ~/"[\n\\s\\t]":
                    tokenStream.append(Token(str: s, type:TokenType.t_identifier))
                    
                    lexState = LexState.Default
                    
                    if forward - i == 1 {
//                        lexState = LexState.Default
                    } else {
//                      println("Lex Error at position " + String(i) + ". Identifiers must be a single character.")
                        return tokenStream
                    }
                default:
                    lexState = LexState.Default
                    tokenStream.append(Token(str:s, type:TokenType.t_identifier))
                    if forward - i == 1 {
                        
                    } else {
                        
//                        println("Lex error at position " + String(forward))
//                        return tokenStream
                    }
                }
            case LexState.Default:
                switch s {
                    case "$":
                        return tokenStream
                    case ~/"[\\s\\t]":
                        println("ignore whitespace")
                    case "\n":
                        ++lineNum
                        linePos = 0
                    case quote:
                        lexState = LexState.String
                        tokenStream.append(Token(str:s, type:TokenType.t_quote))
                    case ~/"[a-z]":
                        lexState = LexState.Searching
                        forward = i+1
                    case ~/"[0-9]":
                        tokenStream.append(Token(str:s, type:TokenType.t_digit))
                    case "+":
                        tokenStream.append(Token(str:s, type:TokenType.t_intop))
                    case "(":
                        tokenStream.append(Token(str: s, type: TokenType.t_parenL))
                    case ")":
                        tokenStream.append(Token(str:s, type: TokenType.t_parenR))
                    case "{":
                        tokenStream.append(Token(str:s, type:TokenType.t_braceL))
                    case "}":
                        tokenStream.append(Token(str:s, type:TokenType.t_braceR))
                    case "=":
                        if i+1 < count(arr) && arr[i+1] == "=" {
                            tokenStream.append(Token(str:s+[arr[i+1]], type:TokenType.t_boolop))
                            ++i
                        } else {
                            tokenStream.append(Token(str:s, type:TokenType.t_assign))
                        }
                    case "!":
                        if i+1 >= count(arr) && arr[i+1] == "=" {
                            tokenStream.append(Token(str:s+[arr[i+1]], type:TokenType.t_boolop))
                            ++i
                        } else {
                            log("Lex error at position " + String(forward))
                            return tokenStream
                        }
                    default:
                        return tokenStream
                }
            case LexState.String:
                switch s {
                case quote:
                    tokenStream.append(Token(str:s, type:TokenType.t_quote))
                    lexState = LexState.Default
                case ~/"[a-z ]":
                    tokenStream.append(Token(str:s, type:TokenType.t_string))
                default:
                    log("Lex error at position " + String(forward))
                    return tokenStream
                }
            }
            if lexState != LexState.Searching {
                ++i
            }
        }
    }
    
}

