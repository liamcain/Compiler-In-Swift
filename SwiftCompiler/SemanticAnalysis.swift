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
    var parentScope: Scope?
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
    
    func getSymbol(symName: String) -> Symbol? {
        return getSymbol(self, name:symName)
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
    var currentScope: Scope?
    
    init(outputView: NSTextView?){
        console = outputView
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
        ast = GrammarTree()
        symbolTable = Scope()
        currentScope = symbolTable
        createAST(cst)
        ast?.showTree()
        
        log("Symbol Table", type:LogType.Message)
        log("------------------", type:LogType.Message)
        showScope(symbolTable!)
        return ast
    }
    
    func showScope(scope: Scope) {
        for (name, symbol) in scope.symbols {
            log("\(name) -> \(symbol), ", type: LogType.Match)
        }
        if scope.children != nil {
            log("", type:LogType.Message)
            for c in scope.children! {
                showScope(c)
            }
        }
    }
    
    private func getType(name: String) -> VarType? {
        let symbol = currentScope?.getSymbol(name)
        if symbol != nil {
            return symbol!.type
        }
        return nil
    }
    
    private func getTypeFromGrammar(grammar: Grammar) -> VarType? {
//        println(grammar.token!.str)
        if let type = grammar.type {
            switch grammar.type! {
                case .IntExpr:  return VarType.Int
                case .BoolExpr: return VarType.Boolean
                case .string:   return VarType.String
                case .digit:    return VarType.Int
                default:        return VarType.None
            }
        } else {
            let str = grammar.token!.str
            switch str {
                case "string":  return VarType.String
                case "int":     return VarType.Int
                case "boolean": return VarType.Boolean
                case "true":    return VarType.Boolean
                case "false":   return VarType.Boolean
                default:
                    let str = grammar.token!.str
                    if str.toInt() != nil {
                        return VarType.Int
                    } else if count(str) == 1 {
                        return getType(str)
                    } else {
                        return VarType.String
                    }
            }
        }
    }
    
    private func checkType(node: Node<Grammar>) -> VarType? {
        var type: VarType? = VarType.None
        
        for c in node.children {
            var grammar: Grammar
            var childType: VarType?
            
            if c.hasChildren() {
                childType = checkType(c)
                if childType == nil {
                    return nil
                }
            } else {
                grammar = c.value
                childType = getTypeFromGrammar(grammar)
            }
//            println(childType)
            
            if type == VarType.None {
                type = childType
            } else {
                if type != childType {
                    log("Type mismatch: \(type) and \(childType)", type: LogType.Error)
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
        if node == nil || node!.value.type == nil {
            return
        }
                
        switch node!.value.type! {
            case .StringExpr:
                var str = ""
                for c in node!.children {
                    str += c.value.token!.str
                }
                let n = node?.children[0]
                n?.value.token?.str = str
                ast?.addBranch(n!.value)

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
                
                if currentScope?.symbols[name.token!.str] != nil {
                    log("Scope Error. Variable with the name '\(name) has already been declared at #:#.", type: LogType.Error)
                }
                currentScope?.addSymbol(type.token!.str, name: name.token!.str)
                returnToParentNode()
            
            case .Id, .digit, .char, .type, .boolval:
                ast?.addGrammar(node!.children[0].value)

            case .IfStatement, .WhileStatement, .AssignmentStatement, .PrintStatement:
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
            default:
                for c in node!.children {
                    convertNode(c)
                }
        }
    }
    
    func createAST(cst: GrammarTree) {
            convertNode(cst.root)
    }
    
//    func typeCheck(){
//        typeCheck(ast?.root)
//    }
//    
//    func typeCheck(node: Node<Grammar>?){
//        if node == nil {
//            return
//        }
//        
//        switch node!.value.type! {
//        case: .VarDecl:
//            
//        default:
//            for c in node!.children {
//            typeCheck(c)
//            }
//        }
//    }
    
    
    
    
}