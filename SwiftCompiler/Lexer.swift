//
//  Lexer.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/18/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation

public enum TokenType {
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
    case t_assign
    case t_boolval
    case t_intop
    case t_quoteL
    case t_quoteR
    case t_braceL
    case t_braceR
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

public func lex(input: String) -> [(String, TokenType)] {
    let reservedWords: Dictionary<String, TokenType> = ["if":TokenType.t_if,
                                                     "while":TokenType.t_while,
                                                     "print":TokenType.t_print,
                                                       "int":TokenType.t_type,
                                                      "char":TokenType.t_type,
                                                    "string":TokenType.t_string,
                                                     "false":TokenType.t_boolval,
                                                      "true":TokenType.t_boolval]
    var tokenStream: [(String, TokenType)] = []
//    var tokenSoFar: String = ""
    var lexState: LexState = LexState.Default
    let arr = Array(input)
    let quote = "\""
    var i:   Int = 0;
    var forward: Int = 0;
    var s :String, s2: String
    while true {
        if i >= count(arr) || forward >= count(arr) {
            println("Lex error. Reached EOL without finding $.")
            return tokenStream
        }
        s = String(arr[i])
        s2 = String(arr[forward])
        
        switch lexState {
            case LexState.Searching:
                switch s2 {
                    case ~/"[a-z]":
                        var tokenSoFar = String(arr[i...forward]);
                        print(tokenSoFar)
                        if let token = reservedWords[tokenSoFar] {
                            tokenStream += [(tokenSoFar, token)]
                            lexState = LexState.Default
                            i = forward
                        } else {
                            ++forward
                        }
                    case " ":
                        tokenStream += [(s, TokenType.t_identifier)]
                        if forward - i == 1 {
                            lexState = LexState.Default
                        }
                    default:
                        if forward - i == 1 {
                            lexState = LexState.Default
                            tokenStream += [(s, TokenType.t_identifier)]
                        } else {
                            var error = "Lex error at position " + String(forward);
                            return tokenStream
                        }
                }
            case LexState.Default:
                switch s {
                    case "$":
                        return tokenStream
                    case " ":
                        print("ignore whitespace")
                    case quote:
                        lexState = LexState.String
                        tokenStream += [(s, TokenType.t_quoteL)]
                    case ~/"[a-z]":
                        lexState = LexState.Searching
                        forward = i+1
                    case ~/"[0-9]":
                        tokenStream += [(s, TokenType.t_digit)]
                    case "+":
                        tokenStream += [(s, TokenType.t_intop)]
                    case "=":
                        if arr[i+1] == "=" {
                            tokenStream += [(s+[arr[i+1]], TokenType.t_assign)]
                            ++i
                        } else {
                            tokenStream += [(s+[arr[i+1]], TokenType.t_boolop)]
                        }
                default:
                    println("Lex error. Unknown character at position 0:0")
                    return tokenStream
                
                }
            case LexState.String:
                switch s {
                    case quote:
                        tokenStream += [(s, TokenType.t_quoteR)]
                        lexState = LexState.Default
                    case ~/"[a-z ]":
                        tokenStream += [(s, TokenType.t_string)]
                    default:
                        var error = "Lex error at position 0:0"
                }
        }
        if lexState != LexState.Searching {
            ++i
        }
    }
//    return tokenStream
}