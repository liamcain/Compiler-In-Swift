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
    var console: NSTextView?
    
    init(outputView: NSTextView?){
//        var rootNode = Node(Grammar(curentNode, type: GrammarType.Block))
        cst = Tree()
        currentNode = nil
        nextToken = nil
        console = outputView
    }
    
    func log(string:String, color: NSColor) {
        let attributedString = NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName: color])
        console!.textStorage?.appendAttributedString(attributedString)
    }
    
    func log(output: String, type: LogType, token:Token?=nil){
        var finalOutput = output
        let row = token?.position.0
        let col = token?.position.1
        
        var attributes: [NSObject : AnyObject]
        switch type {
        case .Error:
            log("[Parse Error at position \(row):\(col)] ", color: errorColor())
            log(output+"\n", color: mutedColor())
        case .Warning:
            log("[Parse Warning at position \(row):\(col)] ", color: warningColor())
            log(output+"\n", color: mutedColor())
        case .Match:
            log(output, color:mutedColor())
            log("Found\n", color: matchColor())
        default:
            log(output, color: mutedColor())
        }
    }
    
    func parse(tokenStream: [Token]) -> Tree<Grammar>? {
        self.tokenStream = tokenStream
        index = 0
        if self.tokenStream != nil && count(self.tokenStream!) > 0 {
            nextToken = self.tokenStream![0]
            program()
        }
        return cst
    }
    
    func program(){
        block()
        matchToken(TokenType.t_eof)
    }
    
    func block(){
        if nextToken != nil {
            matchToken(TokenType.t_braceL)
            statementList()
            matchToken(TokenType.t_braceR)
        }
    }
    
    func statementList(){
        if nextToken != nil && nextToken?.type != TokenType.t_braceR {
            statement()
            statementList()
        }
    }
    
    func statement(){
        if nextToken == nil {
            return
        } else if nextToken?.type == TokenType.t_print {
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
            log("Expected the start of a new statement. Instead found \(nextToken!.str)", type:LogType.Error)
        }
    }
    
    func printStatement(){
        if nextToken != nil {
            matchToken(TokenType.t_print)
            matchToken(TokenType.t_parenL)
            expr()
            matchToken(TokenType.t_parenR)
        }
    }
    
    func assignmentStatement(){
        if nextToken != nil {
            id()
            matchToken(TokenType.t_assign)
            expr()
        }
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
        if nextToken == nil {
            return
        } else if nextToken?.type == TokenType.t_digit {
            intExpr()
        } else if nextToken?.type == TokenType.t_quote {
            stringExpr()
        } else if nextToken?.type == TokenType.t_parenL || nextToken?.type == TokenType.t_boolval {
            booleanExpr()
        } else if nextToken?.type == TokenType.t_identifier {
            id()
        } else {
            log("Expecting expression. Instead found \(nextToken!.str)", type:LogType.Error)
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
            expr()
            boolop()
            expr()
            matchToken(TokenType.t_parenR)
        }
        
    }
    
    func id(){
        matchToken(TokenType.t_identifier)
    }
    
    func charList(){
        if nextToken?.type == TokenType.t_string {
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
    
    func nonterminal(type:GrammarType){
//        currentNode?.addChild(value:Grammar(token: nil, type: GrammarCategory.Nonterminal)))
    }
    
    func matchToken(type: TokenType){
        if nextToken?.type == type {
            log("Parsing: \(nextToken!.str)\t\t ... ", type:LogType.Match)
            //add token to cs
            ++index
            if index < count(tokenStream!) {
                nextToken = tokenStream![index]
            } else {
                nextToken = nil
            }
        } else {
            if let nextType = nextToken?.type.rawValue {
                log("Expected \(type.rawValue). Found '\(nextToken!.str)'", type:LogType.Error)
            }
            nextToken = nil
        }
    }
    

}

