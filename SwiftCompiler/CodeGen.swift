//
//  CodeGen.swift
//  SwiftCompiler
//
//  Created by William Cain on 5/10/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

extension String {

    // Faster version
    // benchmarked with a 1000 characters and 100 repeats the fast version is approx 500 000 times faster :-)
    func repeat(n:Int) -> String {
        var result = self
        for _ in 1 ..< n {
            result.extend(self)   // Note that String.extend is up to 10 times faster than "result += self"
        }
        return result
    }
}

extension Int {
    func hex() -> String {
        let s = String(self, radix: 16, uppercase: true)
        if count(s) == 1 {
            return "0\(s)"
        }
        return s
    }
}

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
        for t in tempVars {
            if t.description == reg {
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
    enum AddressType {
        case Constant
        case Reference
        case Command
        case Temp
        case Jump
    }
    var type: AddressType
    var str: String?
    var tmp: Temp?
    var addressRef: String?
    var jump: Jump?
    
    init(str: String){
        self.str = str
        type = AddressType.Command
    }
    init(ref: String){
        self.str = ref
        type = AddressType.Reference
    }
    init(const: Int){
        self.str = const.hex()
        type = AddressType.Constant
    }
    init(temp: Temp){
        self.tmp = temp
        type = AddressType.Temp
    }
    
    init(jump: Jump){
        self.jump = jump
        type = AddressType.Jump
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
    var description: String {
        return "T\(register)"
    }
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
        heapIndex = 255
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
//        for c in str {
            executionEnvironment[index] = str//String(c)
            index++
//        }
    }
    
    func next(address:Address){
        next("XX")
    }
    
    func next(temp: Temp){
        next(temp.description)
        next("XX")
    }
    
    func generateCode(ast: GrammarTree) -> String {
        self.ast = ast
        
        executionEnvironment = [String](count: 256, repeatedValue: "00")
        jumpTable = JumpTable()
        tempTable = TempTable()
        
        index = 0
        heapIndex = 255
        
        generateCode(ast.root)
        next("00")
        
        backPatch()
        
        var i = 0
        print("\(hex(i/2))| ")
        for s in executionEnvironment {
            print(s + " ")
            i++
            if i % 8 == 0 {
                println()
                print("\(hex(i))| ")
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
            t.finalAddress = hex(index)
            index += t.offset
        }
        
        for var i = 0; i < count(executionEnvironment); i++ {
            let byte = executionEnvironment[i]

            if byte.hasPrefix("T") {
                let temp = tempTable!.get(byte)!
                executionEnvironment[i] = temp.finalAddress!
                executionEnvironment[i+1] = "00"
            } else if byte.hasPrefix("J") {
                let distance = jumpTable?.getJump(byte)!.distance
                executionEnvironment[i] = hex(distance!)
                executionEnvironment[i+1] = "00"
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
            jumpTable!.getJump(jumpName)!.distance = index - jumpStart - 1
        case .WhileStatement:
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
        log("Loading X Register from memory address of temp \(fromMemory.register)", type:.Message,  profile:.Verbose)
        next("AE")
        next(fromMemory)
    }
    
    func loadX(constant: Int) {
        log("Loading X Register with constant \(constant)", type:.Message,  profile:.Verbose)
        next("A2")
        next(hex(constant))
    }
    
    func loadY(fromMemory: Temp) {
        log("Loading Y Register from memory address of temp \(fromMemory.register)", type:.Message,  profile:.Verbose)
        next("AC")
        next(fromMemory)
    }
    
    func loadY(constant: String) {
        log("Loading Y with string \(constant)", type:.Message,  profile:.Verbose)
        next("A0")
        next(constant)
    }
    
    func addWithCarry(fromMemory: Temp){
        log("Adding with carry bit.", type:.Message,  profile:.Verbose)
        next("6D")
        next(fromMemory)
    }
    
    func printSysCall(node: Node<Grammar>){
        log("Printing branch.)", type:.Message,  profile:.Verbose)
        let address = addressForNode(node)
        
        switch address.type {
        case .Reference:
            loadY(address.str!)
            loadX(2)
        case .Constant:
            loadY(address.str!)
            loadX(1)
        default:
            loadY(address.tmp!)
            if address.tmp?.symbol.type == VarType.String {
                loadX(2)
            } else {
                loadX(1)
            }
        }
        next("FF")
    }
    
    func breakSysCall(){
        log("Break.", type:.Message,  profile:.Verbose)
        next("00")
    }
    
    func compareToX(fromMemory: Temp){
        log("Comparing X register to memory address for register\(fromMemory).", type:.Message,  profile:.Verbose)
        next("EC")
        next(fromMemory)
    }
    
    func branchNotEquals(){
        log("Branch not equals.", type:.Message,  profile:.Verbose)
        next("D0")
    }
    
    func increment(){
        log("Incrementing byte.", type:.Message,  profile:.Verbose)
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
        log("Storing accumulator to Register\(toRegister.register).", type:.Message,  profile:.Verbose)
        next("8D")

        next(toRegister)
    }
    
    func boolExpr(node: Node<Grammar>){
        let addressA = registerForSymbol(node.children[0])
        let addressB = registerForSymbol(node.children[1])
        loadX(addressA!)
        compareToX(addressB!)
        if node.value.token!.str == "!=" {
            
        }
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
    
    func addressForNode(node: Node<Grammar>) -> Address {
        let type = node.value.token!.type
        
        if type == TokenType.t_digit {
            let value = node.value.token!.str.toInt()
            return Address(const: value!)
        } else if type == TokenType.t_boolval {
            let value = node.value.token!.str == "true" ?1 :0
            return Address(const: value)
        } else if type == TokenType.t_quote {
            var string = stripQuotes(node.value.token!.str)
            heapIndex -= count(string) + 1
            var tempIndex = heapIndex + 1
            for s in string.utf8 {
                let h: Int = String(s).toInt()!
                executionEnvironment[tempIndex] = hex(h)
                tempIndex++
            }
            return Address(ref: hex((heapIndex+1)))
        } else {
            return Address(temp: registerForSymbol(node)!)
        }
    }
    
    func recursiveAddTo(temp: Temp, node: Node<Grammar>){
            let constant = node.children[0].value.token!.str.toInt()
            storeAccumulator(temp)
            loadAccumulator(hex(constant!))
            addWithCarry(temp)
            if node.children[1].value.type! == GrammarType.intop {
                recursiveAddTo(temp, node: node.children[1])
            } else {
                let constant = node.children[1].value.token!.str.toInt()
                loadAccumulator(hex(constant!))
                addWithCarry(temp)
            
        }
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
            if(recurseAdd) {
                recursiveAddTo(t, node: node.children[1])
            }
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