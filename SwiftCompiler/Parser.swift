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
    var appdelegate: AppDelegate?
    
    // Model
    var tokenStream: [Token]?
    var index: Int = 0
    var cst: GrammarTree?
    var nextToken: Token?
    var hasError: Bool
    
    init(){
        appdelegate = (NSApplication.sharedApplication().delegate as! AppDelegate)
        hasError = false
    }
    
    func log(output: String, type: LogType?=LogType.Message, position:(Int, Int)?=nil, profile:OutputProfile = .EndUser){        
        if type == LogType.Error {
            hasError = true
        }
        
        let log: Log = Log(output: output, phase: "Parse")
        log.position = position
        log.type = type!
        log.profile = profile
        appdelegate!.log(log)
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
//            log(cst!.showTree(), type: LogType.Message, position:(0,0))
            cst!.convertToGV("cst.gv")
            return cst
        } else {
            return nil
        }
    }
    
    func program(){
        log("Began parsing program.", profile:.Verbose)
        addBranchNode(GrammarType.Program)
        block()
        returnToParentNode()
        matchToken(TokenType.t_eof)
    }
    
    func block(){
        if nextToken != nil {
            log("Began parsing block.", profile:.Verbose)
            matchToken(TokenType.t_braceL)
            addBranchNode(GrammarType.Block)
            statementList()
            returnToParentNode()
            matchToken(TokenType.t_braceR)
        }
    }
    
    func statementList(){
        if hasError {
            return
        }
        log("Began parsing statement list.", profile:.Verbose)
        addBranchNode(GrammarType.StatementList)
        if nextToken != nil && nextToken?.type != TokenType.t_braceR {
            if statement() {
                statementList()
            }
        }
        returnToParentNode()
    }
    
    func statement() -> Bool {
        log("Began parsing statement.", profile:.Verbose)
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
            log("Expected the start of a new statement. Instead found '\(nextToken!.str)'.", type:LogType.Error, position:nextToken!.position)
            return false
        }
        returnToParentNode()
        return true
    }
    
    func printStatement(){
        if nextToken != nil {
            log("Parsing print statement.", profile:.Verbose)
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
            log("Parsing assignment statement.", profile:.Verbose)
            addBranchNode(GrammarType.AssignmentStatement)
            id()
            matchToken(TokenType.t_assign)
            expr()
            returnToParentNode()
        }
    }
    
    func varDecl(){
        log("Parsing variable declaration.", profile:.Verbose)
        addBranchNode(GrammarType.VarDecl)
        type()
        id()
        returnToParentNode()
    }
    
    func whileStatement(){
        log("Parsing while statement.", profile:.Verbose)
        addBranchNode(GrammarType.WhileStatement)
        matchToken(TokenType.t_while)
        booleanExpr()
        block()
        returnToParentNode()
    }
    
    func ifStatement(){
        log("Parsing if statement.", profile:.Verbose)
        addBranchNode(GrammarType.IfStatement)
        matchToken(TokenType.t_if)
        booleanExpr()
        block()
        returnToParentNode()
    }
    
    func expr(){
        if hasError {
            return
        }
        log("Parsing expression.", profile:.Verbose)
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
            log("Expecting expression. Instead found '\(nextToken!.str)'.", type:LogType.Error, position: nextToken!.position)
        }
        returnToParentNode()
    }
    
    func intExpr(){
        if hasError {
            return
        }
        log("Parsing int statement.", profile:.Verbose)
        addBranchNode(GrammarType.IntExpr)
        digit()
        if nextToken?.type == TokenType.t_intop {
            intop()
            expr()
        }
        returnToParentNode()
    }
    
    func stringExpr(){
        if hasError {
            return
        }
        log("Parsing string statement.", profile:.Verbose)
        addBranchNode(GrammarType.StringExpr)
        matchToken(TokenType.t_quote)
        charList()
        matchToken(TokenType.t_quote)
        returnToParentNode()
    }
    
    func booleanExpr(){
        if hasError {
            return
        }
        log("Parsing boolean statement.", profile:.Verbose)
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
        if hasError {
            return
        }
        log("Parsing identifier.", profile:.Verbose)
        addBranchNode(GrammarType.Id)
        matchToken(TokenType.t_identifier)
        returnToParentNode()
    }
    
    func charList(){
        if hasError {
            return
        }
        log("Parsing character list.", profile:.Verbose)
        if nextToken?.type == TokenType.t_string {
            matchToken(TokenType.t_string)
            charList()
        }
    }
    
    func type(){
        log("Parsing type.", profile:.Verbose)
        addBranchNode(GrammarType.type)
        matchToken(TokenType.t_type)
        returnToParentNode()
    }
    
    func string(){
        log("Parsing string.", profile:.Verbose)
        addBranchNode(GrammarType.string)
        matchToken(TokenType.t_string)
        returnToParentNode()
    }
    
    func digit(){
        log("Parsing digit.", profile:.Verbose)
        addBranchNode(GrammarType.digit)
        matchToken(TokenType.t_digit)
        returnToParentNode()
    }
    
    func boolop(){
        if hasError {
            return
        }
        log("Parsing boolean operation.", profile:.Verbose)
        addBranchNode(GrammarType.boolop)
        matchToken(TokenType.t_boolop)
        returnToParentNode()
    }
    
    func boolval(){
        log("Parsing boolean value.", profile:.Verbose)
        addBranchNode(GrammarType.boolval)
        matchToken(TokenType.t_boolval)
        returnToParentNode()
    }
    
    func intop(){
        log("Parsing int operation.", profile:.Verbose)
        addBranchNode(GrammarType.intop)
        matchToken(TokenType.t_intop)
        returnToParentNode()
    }
    
    func addBranchNode(type: GrammarType){
        log("Added branch node '\(type.rawValue)' to CST.", profile:.Everything)
        cst!.addBranch(Grammar(type: type))
    }
    
    func addLeafNode(token: Token){
        log("Added leaf node '\(token.str)' to CST.", profile:.Everything)
        cst!.addGrammar(Grammar(token: token))
    }
    
    func returnToParentNode(){
        if hasError {
            return
        }
        log("Climbing up a branch in CST.", type:.Useless, profile:.Everything)
        cst!.cur = cst?.cur?.parent
    }
    
    func stringOutput(str: String) -> String {
        var spaces = ""
        for i in 1...(10 - count(str)) {
            spaces = "\(spaces) "
        }
        return str + spaces
    }
    
    func matchToken(type: TokenType){
        if hasError {
            nextToken = nil
            return
        }
        log("Looking for token of type: \"\(type.rawValue)\".", profile:.Verbose)
        
        if nextToken?.type == type {
            log("Matching token: \(nextToken!.str)", type:LogType.Match, position:nextToken!.position)
            addLeafNode(nextToken!)
            ++index
            if index < count(tokenStream!) {
                nextToken = tokenStream![index]
            } else {
                nextToken = nil
            }
        } else {
            if let nextType = nextToken?.type.rawValue {
                log("Expected \(type.rawValue). Instead found '\(nextToken!.str)'", type:LogType.Error, position:nextToken!.position)
            }
            nextToken = nil
        }
    }
    

}

