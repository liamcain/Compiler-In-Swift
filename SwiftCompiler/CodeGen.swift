//
//  CodeGen.swift
//  SwiftCompiler
//
//  Created by William Cain on 5/10/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa


class Jump {
    
}

class Address {
    var str: String?
    var tmp: Temp?
    init(str: String){
        self.str = str
    }
    init(temp: Temp){
        self.tmp = temp
    }
}

class Temp {
    var symbol: Symbol
    var register: Int
    var address: String?
    init(symbol: Symbol, register: Int){
        self.symbol = symbol
        self.register = register
    }
}

class CodeGen {
    
    var appdelegate: AppDelegate?
    var hasError: Bool
    
    var ast: GrammarTree?
    var symbolTable: Scope?
    var executionEnvironment: [Address?]
    
    var jumpTable: [Jump]?
    var tempTable: [Temp]?
    
    var index: Int
    var currNode: Node<Grammar>?
    
    
    init(){
        appdelegate = (NSApplication.sharedApplication().delegate as! AppDelegate)
        hasError = false
        
        executionEnvironment = [Address?](count: 256, repeatedValue: nil)
        index = 0
    }
    
    func log(output: String, type: LogType = .Message, profile: OutputProfile = .EndUser){
        if type == LogType.Error {
            hasError = true
        }
        
        let log: Log = Log(output: output, phase: "Code Generation")
        log.type = type
        log.profile = profile;
        appdelegate!.log(log)
    }
    
    func next(str:String){
        executionEnvironment[index] = Address(str: str)
        index++
    }
    
    func next(address:Address){
        executionEnvironment[index] = address
        index++
    }
    
    func next(temp: Temp){
        next("T\(temp.register)")
        if(temp.address != nil){
            next(temp.address!)
        } else {
            next(Address(temp:temp))
        }
    }
    
    func generateCode(ast: GrammarTree, symbolTable: Scope) -> String {
        self.ast = ast
        
        executionEnvironment = [Address?](count: 256, repeatedValue: nil)
        jumpTable = Array<Jump>()
        tempTable = Array<Temp>()
        
        index = 0
        
        generateCode(ast.root)
        
        
        return ""//nil
    }
    
    func generateCode(node: Node<Grammar>?) {
        if node == nil {
            return
        }
        log("Generating code for branch: \(node!.value.description).", type:.Useless,  profile:.Verbose)
    
        switch node!.value.type! {
        case .AssignmentStatement:
            assignmentStatement(node!)
        case .VarDecl:
            varDecl(node!)
        case .IfStatement:
            next("A9")
            generateCode(node!.children[0])
            generateCode(node!.children[1])
        case .Block:
            for n in node!.children {
                generateCode(n)
            }
        default: ()
        }
    }
    
    func loadAccumulator(constant: Int? = nil, fromMemory: Int? = nil){
        assert(constant == nil || fromMemory == nil, "Both Constant and fromMemory cannot be assigned")
        
        
        if constant != nil {
            // With a constant
            log("Loading accumulator with constant \(constant!)", type:.Message,  profile:.Verbose)
            next("A9")
            next("0\(constant!)")
        } else {
            // From Memory
            log("Loading accumulator with  \(constant)", type:.Message,  profile:.Verbose)
            next("AD")
            next("\(String(fromMemory!, radix:16, uppercase:true))")
            next("00")
        }
    }
    
    func storeAccumulator(address: Address){
        log("Storing accumulator at address \(address)", type:.Message,  profile:.Verbose)
        next("8D")
        if(address.tmp != nil){
            next(address.tmp!)
        } else {
            next(address.str!)
        }
        
    }
    
    func print(variable: String? = nil, constant: Int?){
        
    }
    
    func assignmentStatement(node: Node<Grammar>){
        log("Found assignment statement.", type:.Message,  profile:.Everything)
        var address: Address?
        if count(node.children) == 2{
            let variable = node.children[0].value
            let constant = node.children[1].value.token!.str.toInt()
            loadAccumulator(constant: constant!)
            let symbol: Symbol = node.value.scope!.getSymbol(variable.token!.str, recurse: true)!
            for tmp in tempTable! {
                if tmp.symbol === symbol {
                    address = Address(str:"T\(tmp.register)")
                    break
                }
            }
        } else {
            address = Address(str: "")
        }
        storeAccumulator(address!)
    }
    
    func varDecl(node: Node<Grammar>){
        let scope = node.value.scope!
        let s = node.children[1].value
        let sym = scope.getSymbol(s.token!.str, recurse: true)!
        let t = Temp(symbol: sym, register: 0)
        
        loadAccumulator(constant: 0)
        tempTable?.append(t)
        storeAccumulator(Address(temp: t))
    }
    
}
