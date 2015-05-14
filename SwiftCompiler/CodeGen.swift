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
    var name: String
    var distance: Int?
    init(name: String){
        self.name = name
    }
}

class JumpTable {
    var jumps: [Jump]
    var index: Int
    
    init(){
        index = 0
        jumps = Array<Jump>()
    }
    
    func getJump(str: String) -> Jump? {
        for j in jumps {
            if j.name == str {
                return j
            }
        }
        return nil
    }
    
    func addJump() -> String {
        let n = "J\(index)"
        jumps.append(Jump(name: n))
        index++
        return n
    }
}

class TempTable {
    var tempVars: [Temp]
    var index: Int
    
    init(){
        tempVars = Array<Temp>()
        index = 0
    }
    
    func getTemp(symbol: Symbol) -> Temp? {
        for t in tempVars {
            if t.symbol === symbol {
                return t
            }
        }
        return nil
    }
    
    func addTemp(symbol: Symbol) -> Temp {
        let t = Temp(symbol:symbol, register:index)
        tempVars.append(t)
        index++
//        return "T\(t.register)"
        return t
    }
}

class Address {
    var str: String?
    var tmp: Temp?
    var jump: Jump?
    
    init(str: String){
        self.str = str
    }
    init(temp: Temp){
        self.tmp = temp
    }
    
    init(jump: Jump){
        self.jump = jump
    }
    var description: String {
        if str != nil {
            return str!
        } else if tmp != nil {
            if tmp!.finalAddress != nil {
                return tmp!.finalAddress!
            } else {
                return "--"
            }
        } else if jump != nil {
            let s = String(jump!.distance!, radix: 16, uppercase: true)
            if count(s) == 1 {
                return "0\(s)"
            }
            return s
        } else {
            return "00"
        }
    }
}

class Temp {
    var symbol: Symbol
    var register: Int
    var offset: Int
    var finalAddress: String?
    init(symbol: Symbol, register: Int){
        self.symbol = symbol
        self.register = register
        if symbol.type == .String {
            offset = count(symbol.token.str)
        } else {
            offset = 1
        }
    }
}

class CodeGen {
    
    var appdelegate: AppDelegate?
    var hasError: Bool
    
    var ast: GrammarTree?
    var symbolTable: Scope?
    var executionEnvironment: [Address?]
    
    var jumpTable: JumpTable?
    var tempTable: TempTable?
    
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
        if(temp.finalAddress != nil){
            next(temp.finalAddress!)
        } else {
            next(Address(temp:temp))
        }
    }
    
    func generateCode(ast: GrammarTree) -> String {
        self.ast = ast
        
        executionEnvironment = [Address?](count: 256, repeatedValue: nil)
        jumpTable = JumpTable()
        tempTable = TempTable()
        
        index = 0
        
        generateCode(ast.root)
        
        backPatch()
        
        var i = 0
        for s in executionEnvironment {
            if s != nil {
                print("\(s!.description) ")
            } else {
                print("00 ")
            }
            i++
            if i % 8 == 0 {
                println()
            }
        }
        
        return ""//nil
    }
    
    func backPatch(){
        for t in tempTable!.tempVars {
            t.finalAddress = hex(index)
            index += t.offset
        }
        for j in jumpTable!.jumps {
            
        }
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
            boolExpr(node!.children[0])
            let jumpStart = index
            let jumpName = jumpTable!.addJump()
            branchNotEquals()
            next(jumpName)
            generateCode(node!.children[1])
            jumpTable!.getJump(jumpName)!.distance = index - jumpStart
        case .PrintStatement:
            printSysCall(node!.children[0])
        case .Block:
            for n in node!.children {
                generateCode(n)
            }
        default: ()
        }
    }
    
    func hex(i: Int) -> String {
        let s = String(i, radix: 16, uppercase: true)
        if count(s) == 1 {
            return "0\(s)"
        }
        return s
    }
    
    func loadX(fromMemory: Temp) {
        next("AE")
        next(fromMemory)
    }
    
    func loadX(constant: Int) {
        next("A2")
        next(hex(constant))
    }
    
    func loadY(fromMemory: Temp) {
        next("AE")
        next(fromMemory)
    }
    
    func loadY(constant: Int) {
        next("A2")
        next(hex(constant))
    }
    
    func loadY(constant: String) {
        next("A2")
        next(constant)
    }
    
    func addWithCarry(){
        next("6D")
    }
    
    func printSysCall(node: Node<Grammar>){
        let address = addressForNode(node)
        if address.str != nil {
            loadY(address.str!)
        } else {
            loadY(address.tmp!)
        }
        loadX(1)
        next("FF")
    }
    
    func breakSysCall(){
        next("00")
    }
    
    func compareToX(fromMemory: Temp){
        next("EC")
        next(fromMemory)
    }
    
    func branchNotEquals(){
        next("D0")
    }
    
    func increment(){
        next("D0")
    }
    
    
    func loadAccumulator(constant: String){
        // With a constant
        log("Loading accumulator with constant \(constant)", type:.Message,  profile:.Verbose)
        next("A9")
        next(constant)
    }
    
    func loadAccumulator(constant: Int){
        // With a constant
        log("Loading accumulator with constant \(constant)", type:.Message,  profile:.Verbose)
        next("A9")
        next(hex(constant))
    }
    
    func loadAccumuluator(fromMemory: Temp){
        log("Loading accumulator from memory \(fromMemory)", type:.Message,  profile:.Verbose)
        next("AD")
        next(fromMemory)
    }
    
    func storeAccumulator(toRegister: Temp){
        log("Storing accumulator at Temp \(toRegister.symbol)'s register.", type:.Message,  profile:.Verbose)
        next("8D")
        if(toRegister.finalAddress != nil){
            next(toRegister.finalAddress!)
        } else {
            next(toRegister)
        }
        
    }
    
    func boolExpr(node: Node<Grammar>){
        let addressA = registerForSymbol(node.children[0])
        let addressB = registerForSymbol(node.children[0])
        loadX(addressA!)
        compareToX(addressB!)
    }
    
    func registerForSymbol(node: Node<Grammar>) -> Temp? {
        let str = node.value.token!.str
        let symbol: Symbol = node.parent!.value.scope!.getSymbol(str, recurse: true)!
        return tempTable?.getTemp(symbol)
    }
    
    func addressForNode(node: Node<Grammar>) -> Address {
        let type = node.value.token!.type
        
        
        if type == TokenType.t_digit {
            let value = node.value.token!.str.toInt()
            return Address(str:hex(value!))
        } else {
            return Address(temp: registerForSymbol(node)!)
        }
    }
    
    func assignmentStatement(node: Node<Grammar>){
        log("Found assignment statement.", type:.Message,  profile:.Everything)
        var address: Address?
        if count(node.children) == 2 {
            let variable = node.children[0].value
            let address = addressForNode(node.children[1])
            if address.str != nil {
                loadAccumulator(address.str!)
            } else {
                loadAccumuluator(address.tmp!)
            }
            if let t = registerForSymbol(node.children[0]) {
                storeAccumulator(t)
            } else {
                //Error
            }
        }
    }
    
    func varDecl(node: Node<Grammar>){
        let scope = node.value.scope!
        let s = node.children[1].value
        let sym = scope.getSymbol(s.token!.str, recurse: true)!
        
        let t = tempTable!.addTemp(sym)
        
        loadAccumulator(0)
        storeAccumulator(t)
    }
    
}
