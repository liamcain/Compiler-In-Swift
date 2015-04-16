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
        var symbol: Symbol
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
    weak var outputView: NSScrollView?
    var console: TextView?
    
    //models
    var symbolTable: Scope?
    var ast: GrammarTree?
    weak var currentScope: Scope?
    var hasError: Bool
    
    init(outputView: TextView?){
        console = outputView
        hasError = false
    }
    
    func log(string:String, color: NSColor) {
        dispatch_async(dispatch_get_main_queue()) {
            self.console!.font = NSFont(name: "Menlo", size: 12.0)
            let attributedString = NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName: color])
            self.console!.textStorage?.appendAttributedString(attributedString)
            self.console!.needsDisplay = true
        }
    }
    
    func log(string: String){
        log(string+"\n", color:mutedColor())
    }
    
    func log(output: String, type: LogType, position:(Int, Int)){
        var finalOutput = output
        let row = position.0
        let col = position.1
        
        var attributes: [NSObject : AnyObject]
        switch type {
        case .Error:
            log("[Type Error at position \(row):\(col)] ", color: errorColor())
            log(output+"\n", color: mutedColor())
            hasError = true
        case .Warning:
            log("[Type Warning at position \(row):\(col)] ", color: warningColor())
            log(output+"\n", color: mutedColor())
        case .Match:
            log(output, color:mutedColor())
            log("Found\n", color: matchColor())
        default:
            log(output + "\n", color: mutedColor())
        }
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
        
        if hasError {
            return nil
        } else {
            showWarnings()
            ast?.showTree()
            
            log("")
            log("Symbol Table")
            log("------------ ")
            showScope(symbolTable!)
            return ast
        }
    }
    
    func showScope(scope: Scope) {
        for (name, symbol) in scope.symbols {
            log("\(name) -> \(symbol.type.rawValue) ")
        }
        if scope.children != nil {
            for c in scope.children! {
                showScope(c)
            }
            log("")
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
            
            if type == nil {
                type = childType
            } else {
                if type != childType {
                    log("Type mismatch between \(type!.rawValue) and \(childType!.rawValue)", type: LogType.Error, position:c.value.token!.position)
                    return nil
                }
            }
        }
        if node.value.type == GrammarType.boolop {
            return VarType.Boolean
        }
        return type
    }
    
    func returnToParentNode(){
        ast!.cur = ast?.cur?.parent
    }
    
    func getOperator(node: Node<Grammar>) -> Grammar? {
        for c in node.children {
            if c.value.type == GrammarType.boolop || c.value.type == GrammarType.intop {
                c.children[0].value.type = c.value.type
                return c.children[0].value
            }
        }
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
            
        case .IntExpr, .BoolExpr:
            if count(node!.children) > 1 {
                ast?.addBranch(getOperator(node!)!)
                for c in node!.children {
                    convertNode(c)
                }
                if checkType(ast!.cur!) == nil {
                    return
                }
                returnToParentNode()
                
            } else {
                for c in node!.children {
                    convertNode(c)
                }
            }
            
        case .AssignmentStatement, .PrintStatement:
            ast?.addBranch(node!.value)
            for c in node!.children {
                convertNode(c)
            }
            if checkType(ast!.cur!) == nil {
                return
            }
            returnToParentNode()
            
        case .VarDecl:
            ast?.addBranch(node!.value)
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
            currentScope?.addSymbol(type.token!.str, name: name.token!.str, token:name.token!)
            returnToParentNode()
            
        case .Id, .digit, .char, .type, .boolval:
            let newNode = ast?.addGrammar(node!.children[0].value)
            newNode?.value.type = node!.value.type
            
        case .IfStatement, .WhileStatement:
            ast?.addBranch(node!.value)
            for c in node!.children {
                convertNode(c)
            }
            returnToParentNode()
            
        case .Block:
            let newScope = Scope()
            currentScope?.adopt(newScope)
            currentScope = newScope
            
            ast?.addBranch(node!.value)
            for c in node!.children {
                convertNode(c)
            }
            returnToParentNode()
            currentScope = currentScope?.parentScope
        default:
            for c in node!.children {
                convertNode(c)
            }
        }
    }
/*
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

            case .IntExpr:
                if count(node!.children) > 1 {
                    ast?.addBranch(node!.children[1].children[0].value)
                    for c in node!.children {
                        convertNode(c)
                    }
                    if checkType(ast!.cur!) == nil {
                        return
                    }
                    returnToParentNode()
                } else {
                    for c in node!.children {
                        convertNode(c)
                    }
                }
            
            case .BoolExpr:
                if count(node!.children) > 1 {
                    ast?.addBranch(node!.children[2].children[0].value)
                    for c in node!.children {
                        convertNode(c)
                    }
                    returnToParentNode()
                    if checkType(ast!.cur!) == nil {
                        return
                    }
                } else {
                    for c in node!.children {
                        convertNode(c)
                    }
                }
            
            case .VarDecl:
                ast?.addBranch(node!.value)
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
                currentScope?.addSymbol(type.token!.str, name: name.token!.str, token:name.token!)
                returnToParentNode()
            
            case .Id, .digit, .char, .type, .boolval:
                let newNode = ast?.addGrammar(node!.children[0].value)
                newNode?.value.type = node!.value.type
            
            case .IfStatement, .WhileStatement, .AssignmentStatement, .PrintStatement:
                ast?.addBranch(node!.value)
                for c in node!.children {
                    convertNode(c)
                }
                
                //TODO: IF and While shouldn't be typechecked. ONly expressions. whoops
                if checkType(ast!.cur!) == nil {
                    return
                }
                returnToParentNode()
            
            case .Block:
                let newScope = Scope()
                currentScope?.adopt(newScope)
                currentScope = newScope
                
                ast?.addBranch(node!.value)
                for c in node!.children {
                    convertNode(c)
                }
                returnToParentNode()
            default:
                for c in node!.children {
                    convertNode(c)
                }
        }
    }*/
    
    func createAST(cst: GrammarTree) {
            convertNode(cst.root)
    }
    
}