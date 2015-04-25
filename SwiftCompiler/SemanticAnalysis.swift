//
//  SemanticAnalysis.swift
//  SwiftCompiler
//
//  Created by Liam Cain on 4/8/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

class Symbol {
    var type: VarType
    var token: Token
    var initialized: Bool
    var used: Bool
    
    init(type: VarType, token:Token) {
        self.type = type
        self.token = token
        initialized = false
        used = false
    }
}

class Scope {
    weak var parentScope: Scope?
    var children: [Scope]?
    var symbols: Dictionary<String, Symbol>
    
    init(){
        parentScope = nil
        children = []
        symbols = Dictionary<String, Symbol>()
    }
    
    func adopt(scope: Scope){
        children?.append(scope)
        scope.parentScope = self
    }
    
    func addSymbol(type: VarType, name: String, token: Token){
        symbols[name] = Symbol(type: type, token:token)
    }
    
    func addSymbol(strType: String, name: String, token: Token){
        switch(strType){
        case "string":  symbols[name] = Symbol(type: VarType.String,  token: token)
        case "boolean": symbols[name] = Symbol(type: VarType.Boolean, token: token)
        case "int":     symbols[name] = Symbol(type: VarType.Int,     token: token)
        default:        symbols[name] = Symbol(type: VarType.None,    token: token)
        }
    }
    
    func getSymbol(symName: String, recurse:Bool=true) -> Symbol? {
        if recurse {
            return getSymbol(self, name:symName)
        } else {
            return symbols[symName]
        }
    }
    
    func getSymbol(scope: Scope, name: String) -> Symbol? {
        if let symbol = scope.symbols[name] {
            return symbol
        }
        if scope.parentScope != nil {
            return getSymbol(scope.parentScope!, name: name)
        }
        return nil
    }
}

class SemanticAnalysis {
    
    //views
    var appdelegate: AppDelegate?
    
    //models
    var symbolTable: Scope?
    var ast: GrammarTree?
    weak var currentScope: Scope?
    var hasError: Bool
    
    init(){
        appdelegate = (NSApplication.sharedApplication().delegate as! AppDelegate)
        hasError = false
    }

    func log(output: String, type: LogType = .Message, position:(Int, Int)?=nil, profile: OutputProfile = .EndUser){
        if type == LogType.Error {
            hasError = true
        }
        
        let log: Log = Log(output: output, phase: "Semantic Analysis")
        log.position = position
        log.type = type
        appdelegate!.log(log)
    }
    
    func analyze(cst: GrammarTree) -> GrammarTree? {

        ast?.root = nil
        ast?.cur = nil
        currentScope = nil
        hasError = false
        
        ast = GrammarTree()
        symbolTable = Scope()
        currentScope = symbolTable
        
        createAST(cst)
        
        appdelegate!.log("\n------------")
        appdelegate!.log("Symbol Table")
        appdelegate!.log("------------")
        
        if hasError {
            return nil
        } else {
            showScope(symbolTable!)
            showWarnings()
            appdelegate!.log("\n---\nAST\n---")
            appdelegate!.log(ast!.showTree())
            
            return ast
        }
    }
    
    func showScope(scope: Scope) {
        for (name, symbol) in scope.symbols {
            appdelegate!.log("\(name) -> \(symbol.type.rawValue) ")
        }
        if scope.children != nil {
            for c in scope.children! {
                showScope(c)
            }
            appdelegate!.log("")
        }
    }
    
    private func warningsAtScope(scope:Scope?){
        if scope == nil {
            return
        }
        for (name, symbol) in scope!.symbols {
            if !symbol.initialized {
                log("Variable '\(symbol.token.str)' was used but not initialized.", type:LogType.Warning, position: symbol.token.position)
            } else if !symbol.used {
                log("Unused variable '\(symbol.token.str)'", type:LogType.Warning, position: symbol.token.position)
            }
        }
        for c in scope!.children! {
            warningsAtScope(c)
        }
    }
    
    private func showWarnings() {
        warningsAtScope(symbolTable)
    }
    
    private func addBranchNode(branch: Grammar){
        if branch.token != nil {
            log("Creating branch node in AST with value '\(branch.token!.str)'.", type:.Match, profile:.Verbose)
        } else {
            log("Creating branch node in AST with value '\(branch.type!.rawValue)'.", type:.Match, profile:.Verbose)
        }
        
        ast?.addBranch(branch)
    }
    
    private func getSymbol(token: Token, recurse:Bool=true) -> Symbol? {
        let symbol = currentScope?.getSymbol(token.str, recurse: recurse)
        if symbol != nil {
            return symbol
        }
        log("Use of unresolved identifier '\(token.str)'", type: LogType.Error, position:token.position)
        return nil
    }
    
    private func getTypeFromNode(node: Node<Grammar>) -> VarType? {
        switch node.value.type! {
            case GrammarType.string:  return VarType.String
            case GrammarType.digit:   return VarType.Int
            case GrammarType.boolval: return VarType.Boolean
            case GrammarType.Id:
                if let symbol = getSymbol(node.value.token!) {
                    if node.parent?.value.type == GrammarType.AssignmentStatement {
                        symbol.initialized = true
                    } else {
                        symbol.used = true
                    }
                    return symbol.type
                }
                return nil
            default: return VarType.None
        }
    }
    
    private func checkType(node: Node<Grammar>) -> VarType? {
        if hasError {
            return nil
        }
        log("Checking type of '\(node.value.type!.rawValue)' node's children:", profile:.Verbose)
        
        var type: VarType? = nil
        
        for c in node.children {
            
            var childType: VarType?
            if c.hasChildren() {
                childType = checkType(c)
            } else {
                childType = getTypeFromNode(c)
            }
            if childType == nil {
                return nil
            }
            log("Child has type: \(childType!.rawValue).", profile:.Everything)
            
            if type == nil {
                type = childType
            } else {
                if type != childType {
                    log("Type mismatch between \(type!.rawValue) and \(childType!.rawValue)", type: LogType.Error, position:c.value.token!.position)
                    return nil
                }
            }
        }
        if type != nil {
            log("Type checks out. Each child is of type '\(type!.rawValue)'", type:.Match, profile:.Verbose)
        } else {
            log("Type checks out. Children do not have a type.", type:.Match, profile:.Verbose)
        }
        
        if node.value.type == GrammarType.boolop {
            log("Returning type 'Boolean'.", profile:.Everything)
            return VarType.Boolean
        }
        return type
    }
    
    func returnToParentNode(){
        if hasError {
            return
        }
        log("Climbing up a branch in AST.", type:.Useless, profile:.Everything)
        ast!.cur = ast?.cur?.parent
    }
    
    func getOperator(node: Node<Grammar>) -> Grammar? {
        for c in node.children {
            if c.value.type == GrammarType.boolop || c.value.type == GrammarType.intop {
                c.children[0].value.type = c.value.type
                let op = c.children[0].value
                log("Found operator '\(op)'. Will add as a branch to the AST.", profile:.Verbose)
                return op
            }
        }
        log("Could not find operator within node '\(node.value.token?.str)'.", profile:.Verbose)
        return nil
    }
    
    private func convertNode(node: Node<Grammar>?){
        if hasError || node == nil || node!.value.type == nil {
            return
        }
        
        switch node!.value.type! {
        case .StringExpr:
            var str = ""
            for c in node!.children {
                str += c.value.token!.str
            }
            let n = node?.children[0]
            let newNode = ast?.addGrammar(n!.value)
            newNode?.value.token?.str = str
            newNode?.value.type = GrammarType.string
            log("Found [Char]. Collapsing to form string '\(str)'.", profile:.Verbose)
        case .IntExpr, .BoolExpr:
            if count(node!.children) > 1 {
                log("Expression has multiple operands.", profile:.Verbose)
                addBranchNode(getOperator(node!)!)
                log("Recursing...", type:.Useless, profile:.Verbose)
                for c in node!.children {
                    convertNode(c)
                }
                if checkType(ast!.cur!) == nil {
                    return
                }
                returnToParentNode()
            } else {
                log("Recursing...", type:.Useless, profile:.Verbose)
                for c in node!.children {
                    convertNode(c)
                }
            }
            
        case .AssignmentStatement, .PrintStatement:
            addBranchNode(node!.value)
            log("Recursing...", type:.Useless, profile:.Verbose)
            for c in node!.children {
                convertNode(c)
            }
            if checkType(ast!.cur!) == nil {
                return
            }
            returnToParentNode()
            
        case .VarDecl:
            addBranchNode(node!.value)
            for c in node!.children {
                convertNode(c)
            }
            let type = ast!.cur!.children[0].value
            let name = ast!.cur!.children[1].value
            
            if let symbol = currentScope?.getSymbol(name.token!.str, recurse: false) {
                let lineNum = symbol.token.position.0
                log("Variable with the name '\(name.token!.str)' has already been declared on line \(lineNum).", type: LogType.Error, position:name.token!.position)
                return
            }
            log("Adding symbol '\(type.token!.str) \(name.token!.str)' to the symbol table.", profile:.Verbose)
            currentScope?.addSymbol(type.token!.str, name: name.token!.str, token:name.token!)
            returnToParentNode()
            
        case .Id, .digit, .char, .type, .boolval:
            let newNode = ast?.addGrammar(node!.children[0].value)
            newNode?.value.type = node!.value.type
            
        case .IfStatement, .WhileStatement:
            addBranchNode(node!.value)
            log("Recursing...", type:.Useless, profile:.Verbose)
            for c in node!.children {
                convertNode(c)
            }
            returnToParentNode()
            
        case .Block:
            let newScope = Scope()
            currentScope?.adopt(newScope)
            currentScope = newScope
            
            addBranchNode(node!.value)
            log("Recursing...", type:.Useless, profile:.Verbose)
            for c in node!.children {
                convertNode(c)
            }
            returnToParentNode()
            currentScope = currentScope?.parentScope
        default:
            log("Nothing important on the level '\(node!.value.type!.rawValue)'. We must go deeper.\nRecursing...", type:.Useless, profile:.Verbose)
            for c in node!.children {
                convertNode(c)
            }
        }
    }
    
    func createAST(cst: GrammarTree) {
            log("Began creating AST from CST.", profile:.Verbose)
            convertNode(cst.root)
    }
    
}