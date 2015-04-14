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
}

enum VarType: String {
    case None = "None"
    case Int = "Int"
    case Boolean = "Boolean"
    case String = "String"
}

enum GrammarType: String {
    case Program = "Program"
    case Block = "Block"
    case StatementList = "StatementList"
    case Statement = "Statement"
    case PrintStatement = "PrintStatement"
    case AssignmentStatement = "AssignmentStatement"
    case VarDecl = "VarDecl"
    case WhileStatement = "WhileStatement"
    case IfStatement = "IfStatement"
    case Expr = "Expr"
    case BoolExpr = "BoolExpr"
    case IntExpr = "IntExpr"
    case StringExpr = "StringExpr"
    case Id = "Id"
    case CharList = "CharList"
    case type = "type"
    case string = "string"
    case char = "char"
    case space = "space"
    case digit = "digit"
    case boolop = "boolop"
    case boolval = "boolval"
    case intop = "intop"
}

class Grammar {
    
    var token: Token?      // For leaf nodes
    var type :GrammarType? // For branch nodes
    
    var description: String {
        if token != nil {
            return token!.str
        } else if (type != nil) {
            return type!.rawValue
        } else {
            return "nil"
        }
        
    }
    
    init(type: GrammarType) {
        self.type  = type
    }
    
    init(token: Token) {
        self.token = token
    }
}

class Parser {
    
    // Views
    weak var outputView: NSScrollView?
    var console: NSTextView?
    
    // Model
    var tokenStream: [Token]?
    var index: Int = 0
    var cst: GrammarTree?
    var nextToken: Token?
    var hasError: Bool
    
    init(outputView: NSTextView?){
//        cst = GrammarTree()
//        nextToken = nil
        console = outputView
        hasError = false
    }
    
    func log(string:String, color: NSColor) {
        console!.font = NSFont(name: "Menlo", size: 12.0)
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
            hasError = true
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
    
    func parse(tokenStream: [Token]) -> GrammarTree? {
        cst = GrammarTree()
        hasError = false
        nextToken = nil
        self.tokenStream = tokenStream
        index = 0
        if self.tokenStream != nil && count(self.tokenStream!) > 0 {
            nextToken = self.tokenStream![0]
            program()
        }
        
        if !hasError {
            cst?.showTree()
            return cst
        } else {
            return nil
        }
    }
    
    func program(){
        addBranchNode(GrammarType.Program)
        block()
        returnToParentNode()
        matchToken(TokenType.t_eof)
    }
    
    func block(){
        if nextToken != nil {
            matchToken(TokenType.t_braceL)
            addBranchNode(GrammarType.Block)
            statementList()
            returnToParentNode()
            matchToken(TokenType.t_braceR)
        }
    }
    
    func statementList(){
        addBranchNode(GrammarType.StatementList)
        if nextToken != nil && nextToken?.type != TokenType.t_braceR {
            if statement() {
                statementList()
            }
        }
        returnToParentNode()
    }
    
    func statement() -> Bool {
        addBranchNode(GrammarType.Statement)
        if nextToken == nil {
            return true
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
            return false
        }
        returnToParentNode()
        return true
    }
    
    func printStatement(){
        if nextToken != nil {
            addBranchNode(GrammarType.PrintStatement)
            matchToken(TokenType.t_print)
            matchToken(TokenType.t_parenL)
            expr()
            matchToken(TokenType.t_parenR)
            returnToParentNode()
        }
    }
    
    func assignmentStatement(){
        if nextToken != nil {
            addBranchNode(GrammarType.AssignmentStatement)
            id()
            matchToken(TokenType.t_assign)
            expr()
            returnToParentNode()
        }
    }
    
    func varDecl(){
        addBranchNode(GrammarType.VarDecl)
        type()
        id()
        returnToParentNode()
    }
    
    func whileStatement(){
        addBranchNode(GrammarType.WhileStatement)
        matchToken(TokenType.t_while)
        booleanExpr()
        block()
        returnToParentNode()
    }
    
    func ifStatement(){
        addBranchNode(GrammarType.IfStatement)
        matchToken(TokenType.t_if)
        booleanExpr()
        block()
        returnToParentNode()
    }
    
    func expr(){
        addBranchNode(GrammarType.Expr)
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
        returnToParentNode()
    }
    
    func intExpr(){
        addBranchNode(GrammarType.IntExpr)
        digit()
        if nextToken?.type == TokenType.t_intop {
            intop()
            expr()
        }
        returnToParentNode()
    }
    
    func stringExpr(){
        addBranchNode(GrammarType.StringExpr)
        matchToken(TokenType.t_quote)
        charList()
        matchToken(TokenType.t_quote)
        returnToParentNode()
    }
    
    func booleanExpr(){
        addBranchNode(GrammarType.BoolExpr)
        if nextToken?.type == TokenType.t_boolval {
            boolval()
        } else {
            matchToken(TokenType.t_parenL)
            expr()
            boolop()
            expr()
            matchToken(TokenType.t_parenR)
        }
        returnToParentNode()
    }
    
    func id(){
        addBranchNode(GrammarType.Id)
        matchToken(TokenType.t_identifier)
        returnToParentNode()
    }
    
    func charList(){
        if nextToken?.type == TokenType.t_string {
            matchToken(TokenType.t_string)
            charList()
        }
    }
    
    func type(){
        addBranchNode(GrammarType.type)
        matchToken(TokenType.t_type)
        returnToParentNode()
    }
    
    func string(){
        addBranchNode(GrammarType.string)
        matchToken(TokenType.t_string)
        returnToParentNode()
    }
    
    func digit(){
        addBranchNode(GrammarType.digit)
        matchToken(TokenType.t_digit)
        returnToParentNode()
    }
    
    func boolop(){
        addBranchNode(GrammarType.boolop)
        matchToken(TokenType.t_boolop)
        returnToParentNode()
    }
    
    func boolval(){
        addBranchNode(GrammarType.boolval)
        matchToken(TokenType.t_boolval)
        returnToParentNode()
    }
    
    func intop(){
        addBranchNode(GrammarType.intop)
        matchToken(TokenType.t_intop)
        returnToParentNode()
    }
    
    func addBranchNode(type: GrammarType){
        cst!.addBranch(Grammar(type: type))
    }
    
    func addLeafNode(token: Token){
        cst!.addGrammar(Grammar(token: token))
    }
    
    func returnToParentNode(){
        cst!.cur = cst?.cur?.parent
    }
    
    func matchToken(type: TokenType){
        if nextToken?.type == type {
            log("Parsing: \(nextToken!.str)\t\t ... ", type:LogType.Match)
            addLeafNode(nextToken!)
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

