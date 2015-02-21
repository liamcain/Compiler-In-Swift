//
//  Lexer.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/18/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation

enum TokenType {
    case t_identifier
    case t_type
    case t_if
    case t_while
    case t_print
    case t_string
    case t_digit
    case t_parenL
    case t_parenR
    case t_operator
    case t_boolop
    case t_boolval
    case t_intop
    case t_quoteL
    case t_quoteR
    case t_braceL
    case t_braceR
}

enum LexState {
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

func lexChar(input: String) -> [(String, TokenType)] {
    let reservedWords: Dictionary<String, TokenType> = ["if":TokenType.t_if,
                                                     "while":TokenType.t_while,
                                                     "print":TokenType.t_print,
                                                       "int":TokenType.t_type,
                                                      "char":TokenType.t_type,
                                                     "false":TokenType.t_boolval,
                                                      "true":TokenType.t_boolval]
    var tokenStream: [(String, TokenType)] = []
    var tokenSoFar: String = ""
    var lexState: LexState = LexState.Default
    let arr = Array(input)
    let quote = "\""
    var begin:   Int = 0;
    var forward: Int = 0;
    while true {
        begin = count(tokenStream)
        var s = String(arr[begin])
        var s2 = String(arr[forward])
        
        switch lexState {
            case LexState.Searching:
                switch s2 {
                    case ~/"[a-z]":
                        var tokenSoFar = String(arr[begin...forward]);
                        if let token = reservedWords[tokenSoFar] {
                            tokenStream += [(tokenSoFar, token)]
                            lexState = LexState.Default
                        } else {
                            ++forward
                        }
                    case " ":
                        tokenStream += [(s, TokenType.t_identifier)]
                        if forward - begin == 1 {
                            lexState = LexState.Default
                        }
                    default:
                        if forward - begin == 1 {
                            lexState = LexState.String
                            tokenStream += [(s, TokenType.t_identifier)]
                        } else {
                            var error = "Lex error at position " + String(forward);
                        }
                        break;
                }
            case LexState.Default:
                switch s {
                    case "$":
                        break
                    case " ":
                        print("ignore whitespace")
                    case quote:
                        lexState = LexState.String
                        tokenStream += [(s, TokenType.t_quoteL)]
                    case ~/"[a-z]":
                        lexState = LexState.Searching
                        forward = begin+1
                    case ~/"[0-9]":
                        tokenStream += [(s, TokenType.t_digit)]
                    case "+":
                        tokenStream += [(s, TokenType.t_intop)]
                    case "=":
                        println()
                default:
                    println("Lex error. Unknown character at position 0:0")
                    break
                
                }
            case LexState.String:
                switch s {
                    case quote:
                        tokenStream += [(s, TokenType.t_quoteR)]
                    case ~/"[a-z ]":
                        tokenStream += [(tokenSoFar, TokenType.t_string)]
                    default:
                        var error = "Lex error at position 0:0"
                }
        }
    }
    return tokenStream
}