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
    
    func get(symbol: Symbol) -> Temp? {
        for t in tempVars {
            if t.symbol === symbol {
                return t
            }
        }
        return nil
    }
    
    func get(reg: String) -> Temp? {
        let register = reg.toInt()
        for t in tempVars {
            if t.register == register {
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
    var executionEnvironment: [String]
    
    var jumpTable: JumpTable?
    var tempTable: TempTable?
    
    var index: Int
    var heapIndex: Int
    var currNode: Node<Grammar>?
    
    
    init(){
        appdelegate = (NSApplication.sharedApplication().delegate as! AppDelegate)
        hasError = false
        executionEnvironment = [String](count: 256, repeatedValue: "00")
        index = 0
        heapIndex = 254
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
        for c in str {
            executionEnvironment[index] = String(c)
            index++
        }
    }
    
    func next(address:Address){
        next("XX")
    }
    
    func next(temp: Temp){
        next("T\(temp.register)")
        next("XX")
        /*if(temp.finalAddress != nil){
            next(temp.finalAddress!)
        } else {
            next(Address(temp:temp))
        }*/
    }
    
    func generateCode(ast: GrammarTree) -> String {
        self.ast = ast
        
        executionEnvironment = [String](count: 256, repeatedValue: "0")
        jumpTable = JumpTable()
        tempTable = TempTable()
        
        index = 0
        heapIndex = 254
        
        generateCode(ast.root)
        next("00")
        
        backPatch()
        
        var i = 0
        print("\(hex(i/2)) |")
        for s in executionEnvironment {
            print(s)
            i++
            if i % 2 == 0 {
                print(" ")
            }
            if i % 16 == 0 {
                println()
                print("\(hex(i/2)) |")
            }
        }
        
        var machineCode: String = ""
        for s in executionEnvironment {
            machineCode += s
        }
        return machineCode
    }
    
    func replace(pos: Int, str: String){
        var p = pos
        for s in str {
            executionEnvironment[p] = String(s)
            p++
        }
    }
    
    func backPatch(){
        for t in tempTable!.tempVars {
            t.finalAddress = hex(index/2)
            index += t.offset*2
        }
        
        for var i = 0; i < count(executionEnvironment); i += 2 {
            let char = executionEnvironment[i]
            let num = executionEnvironment[i+1]
            let complete = char + num
            
            if executionEnvironment[i] == "T" {
                let temp = tempTable!.get(num)!
                replace(i, str: temp.finalAddress! + "00")
                i += 2
            } else if executionEnvironment[i] == "J" {
                let distance = jumpTable?.getJump(complete)!.distance
                replace(i, str: hex(distance!))
            }
        }
    }
    
    func generateCode(node: Node<Grammar>?) {
        if node == nil {
            return
        }
        log("Generating code for branch: \(node!.value.description).", type:.Useless,  profile:.Verbose)
    
        switch node!.value.type! {
        case .AssignmentStatement: return
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
            jumpTable!.getJump(jumpName)!.distance = (index - jumpStart) / 2 - 1
        case .WhileStatement:
            boolExpr(node!.children[0])
            let jumpStart = index
            let jumpName = jumpTable!.addJump()
            branchNotEquals()
            next(jumpName)
            generateCode(node!.children[1])
            jumpTable!.getJump(jumpName)!.distance = (index - jumpStart) / 2 - 1
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
        next("AC")
        next(fromMemory)
    }
    
    func loadY(constant: Int) {
        next("A0")
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

        next(toRegister)
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
        return tempTable?.get(symbol)
    }
    
    func stripQuotes(str: String) -> String {
        // Huh Okay swift. No problem!
        return str.substringFromIndex(str.startIndex.successor()).substringToIndex(str.endIndex.predecessor().predecessor())
    }
    
    func insertIntoHeap(index: Int, str: String){
        var i = index
        for s in str {
            executionEnvironment[i] = String(s)
            i++
        }
    }
    
    func addressForNode(node: Node<Grammar>) -> Address {
        let type = node.value.token!.type
        
        if type == TokenType.t_digit {
            let value = node.value.token!.str.toInt()
            return Address(str:hex(value!))
        } else if type == TokenType.t_quote {
            var string = stripQuotes(node.value.token!.str)
            heapIndex -= count(string)*2 + 2
            var tempIndex = heapIndex + 2
            for s in string.utf8 {
                let h: Int = String(s).toInt()!
                insertIntoHeap(tempIndex, str: hex(h))
                tempIndex += 2
            }
            return Address(str: hex((heapIndex+2)))
        } else {
            return Address(temp: registerForSymbol(node)!)
        }
    }
    
    func recursiveAddTo(address: Address, node: Node<Grammar>){
        
    }
    
    func assignmentStatement(node: Node<Grammar>){
        log("Found assignment statement.", type:.Message,  profile:.Everything)
        let variable = node.children[0].value
        var address: Address?
        var recurseAdd: Bool = false
        
        if node.children[1].value.type! == GrammarType.intop {
            address = addressForNode(node.children[1].children[0])
            recurseAdd = true
        } else {
            address = addressForNode(node.children[1])
        }
        
        
        if address!.str != nil {
            loadAccumulator(address!.str!)
        } else {
            loadAccumuluator(address!.tmp!)
        }
        if let t = registerForSymbol(node.children[0]) {
            storeAccumulator(t)
        } else {
            //Error
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