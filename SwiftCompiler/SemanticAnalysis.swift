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
    var token: Token?
    
    init(type: VarType) {
        self.type = type
        token = nil
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
    
    func addSymbol(type: VarType, name: String){
        symbols[name] = Symbol(type: type)
    }
    
    func addSymbol(strType: String, name: String){
        var symbol: Symbol
        switch(strType){
        case "string":  symbols[name] = Symbol(type: VarType.String)
        case "boolean": symbols[name] = Symbol(type: VarType.Boolean)
        case "int":     symbols[name] = Symbol(type: VarType.Int)
        default:        symbols[name] = Symbol(type: VarType.None)
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
    var console: NSTextView?
    
    //models
    var symbolTable: Scope?
    var ast: GrammarTree?
    weak var currentScope: Scope?
    var hasError: Bool
    
    init(outputView: NSTextView?){
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
            ast?.showTree()
            
            log("Symbol Table",       type:LogType.Message)
            log("------------", type:LogType.Message)
            showScope(symbolTable!)
            return ast
        }
    }
    
    func showScope(scope: Scope) {
        for (name, symbol) in scope.symbols {
            log("\(name) -> \(symbol.type.rawValue), ", type: LogType.Match)
        }
        if scope.children != nil {
            log("", type:LogType.Message)
            for c in scope.children! {
                showScope(c)
            }
        }
    }
    
    private func getType(name: String, recurse:Bool=true) -> VarType? {
        let symbol = currentScope?.getSymbol(name, recurse: recurse)
        if symbol != nil {
            return symbol!.type
        }
        log("Use of unresolved identifier '\(name)'", type: LogType.Error)
        return nil
    }
    
    private func getTypeFromNode(node: Node<Grammar>) -> VarType? {
        switch node.value.type! {
            case GrammarType.string:  return VarType.String
            case GrammarType.digit:   return VarType.Int
            case GrammarType.boolval: return VarType.Boolean
            case GrammarType.Id:      return getType(node.value.token!.str)
            default:                  return VarType.None
        }
    }
    
//    private func getTypeFromGrammar(grammar: Grammar) -> VarType? {
//        if let type = grammar.type {
//            switch grammar.type! {
//                case .IntExpr:  return VarType.Int
//                case .BoolExpr: return VarType.Boolean
//                case .string:   return VarType.String
//                case .digit:    return VarType.Int
//                default:        return VarType.None
//            }
//        } else {
//            let str = grammar.token!.str
//            switch str {
//                case "string":  return VarType.String
//                case "int":     return VarType.Int
//                case "boolean": return VarType.Boolean
//                case "true":    return VarType.Boolean
//                case "false":   return VarType.Boolean
//                default:
//                    let str = grammar.token!.str
//                    if str.toInt() != nil {
//                        return VarType.Int
//                    } else if count(str) == 1 {
//                        return getType(str)
//                    } else {
//                        return VarType.String
//                    }
//            }
//        }
//    }
    
    private func checkType(node: Node<Grammar>) -> VarType? {
        var type: VarType? = nil
        println()
        println(node.value.description)
        
        for c in node.children {
            var childType: VarType? = getTypeFromNode(c)
            if childType == nil {
                return nil
            }
            
            println(childType!.rawValue)
            
            if type == nil {
                type = childType
            } else {
                if type != childType {
                    log("Type mismatch between \(type!.rawValue) and \(childType!.rawValue)", type: LogType.Error)
                    return nil
                }
            }
        }
        return type
    }
    
    private func checkScope(node: Node<Grammar>) -> Bool{
        return true
    }
    
    func returnToParentNode(){
        ast!.cur = ast?.cur?.parent
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
                
                if currentScope?.getSymbol(name.token!.str, recurse: false) != nil {
                    log("Variable with the name '\(name.token!.str)' has already been declared at #:#.", type: LogType.Error)
                    return
                }
                currentScope?.addSymbol(type.token!.str, name: name.token!.str)
                returnToParentNode()
            
            case .Id, .digit, .char, .type, .boolval:
                let newNode = ast?.addGrammar(node!.children[0].value)
                newNode?.value.type = node!.value.type

            case .IfStatement, .WhileStatement, .AssignmentStatement, .PrintStatement:
                ast?.addBranch(node!.value)
                for c in node!.children {
                    convertNode(c)
                }
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
    }
    
    func createAST(cst: GrammarTree) {
            convertNode(cst.root)
    }
    
}