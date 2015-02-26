//
//  Parser.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/21/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

enum GrammarCategory {
    case Terminal
    case Nonterminal
    case Production
}

enum GrammarType: String {
    case Program = "Program"
    case Block = "Block"
    case Statement = "Statement"
    case PrintStatement = "PrintStatement"
    case AssignmentStatement = "AssignmentStatement"
    case VarDecl = "VarDecl"
    case IfStatement = "IfStatement"
    case Expr = "Expr"
    case IntExpr = "IntExpr"
    case StringExpr = "StringExpr"
    case Id = "Id"
    case CharList = "CharList"
    case type = "type"
    case char = "char"
    case space = "space"
    case digit = "digit"
    case boolop = "boolop"
    case boolval = "boolval"
    case intop = "intop"
}

class Grammar {
    
    var token: Token
    var type :GrammarType
    
    init(token: Token, type: GrammarType) {
        self.token = token
        self.type  = type
    }
}

class Parser {
    
    weak var outputView: NSScrollView?
    var tokenStream: [Token]?
    var index: Int = 0
    var cst: Tree<Grammar>?
    var currentNode: Node<Grammar>?
    var nextToken: Token?
    
    init(){
//        var rootNode = Node(Grammar(curentNode, type: GrammarType.Block))
        cst = Tree()
        currentNode = nil
        nextToken = nil
    }
    
    func parse(tokenStream: [Token]){
        self.tokenStream = tokenStream
        if self.tokenStream != nil {
            nextToken = self.tokenStream![0]
            program()
        }
        
    }
    
//    func production(type: TokenType){
//        
//    }
//    
//    func nonterminal(type: GrammarType){
//        
//    }
    
    func program(){
        block()
        matchToken(TokenType.t_eof)
    }
    
    func block(){
        matchToken(TokenType.t_braceL)
        statementList()
        matchToken(TokenType.t_braceR)
    }
    
    func statementList(){
        if nextToken != nil && nextToken?.type != TokenType.t_braceR {
            statement()
            statementList()
        }
    }
    
    func statement(){
        if nextToken?.type == TokenType.t_print {
            printStatement()
        } else if nextToken?.type == TokenType.t_identifier {
            assignmentStatement()
        } else if nextToken?.type == TokenType.t_type {
            varDecl()
        } else if nextToken?.type == TokenType.t_while {
            whileStatement()
        } else if nextToken?.type == TokenType.t_if {
            ifStatement()
        } else if nextToken?.type == TokenType.t_braceL {
            block()
        } else {
            println("Parse error")
            nextToken = nil
        }
    }
    
    func printStatement(){
        matchToken(TokenType.t_print)
        matchToken(TokenType.t_parenL)
        expr()
        matchToken(TokenType.t_parenR)
    }
    
    func assignmentStatement(){
        id()
        matchToken(TokenType.t_assign)
        expr()
    }
    
    func varDecl(){
        type()
        id()
    }
    
    func whileStatement(){
        matchToken(TokenType.t_while)
        booleanExpr()
        block()
    }
    
    func ifStatement(){
        matchToken(TokenType.t_if)
        booleanExpr()
        block()
    }
    
    func expr(){
        if nextToken?.type == TokenType.t_digit {
            intExpr()
        } else if nextToken?.type == TokenType.t_quote {
            stringExpr()
        } else if nextToken?.type == TokenType.t_parenL {
            booleanExpr()
        } else if nextToken?.type == TokenType.t_identifier {
            id()
        } else {
            println("Parse error. Expecting expression. Instead found ")
        }
    }
    
    func intExpr(){
        digit()
        if nextToken?.type == TokenType.t_intop {
            intop()
            expr()
        }
    }
    
    func stringExpr(){
        matchToken(TokenType.t_quote)
        charList()
        matchToken(TokenType.t_quote)
    }
    
    func booleanExpr(){
        if nextToken?.type == TokenType.t_boolval {
            boolval()
        } else {
            matchToken(TokenType.t_parenL)
            boolop()
            matchToken(TokenType.t_parenR)
        }
        
    }
    
    func id(){
        matchToken(TokenType.t_identifier)
    }
    
    func charList(){
        if nextToken?.type == TokenType.t_string {NSString
            matchToken(TokenType.t_string)
            charList()
        }
    }
    
    func type(){
        matchToken(TokenType.t_type)
    }
    
    func string(){
        matchToken(TokenType.t_string)
    }
    
    func digit(){
        matchToken(TokenType.t_digit)
    }
    
    func boolop(){
        matchToken(TokenType.t_boolop)
    }
    
    func boolval(){
        matchToken(TokenType.t_boolval)
    }
    
    func intop(){
        matchToken(TokenType.t_intop)
    }
    
    func matchToken(type: TokenType){
        if nextToken?.type == type {
            println(type.rawValue)
            //add token to cs
            ++index
            if index < count(tokenStream!) {
                nextToken = tokenStream![index]
            }
        } else {
            if let nextType = nextToken?.type.rawValue {
                println("Parse error: Expected " + type.rawValue + ". Found " + nextType)
            }
            nextToken = nil
        }
    }
    

}

