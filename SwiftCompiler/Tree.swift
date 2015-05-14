//
//  Tree.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/22/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation

public enum NodeType {
    case Leaf
    case Branch
}

extension String {
    func createFolderAt(location: NSSearchPathDirectory) -> String? {
        if let directoryUrl = NSFileManager.defaultManager().URLsForDirectory(location, inDomains: .UserDomainMask).first as? NSURL {
            let folderUrl = directoryUrl.URLByAppendingPathComponent(self)
            var err: NSErrorPointer = nil
            if NSFileManager.defaultManager().createDirectoryAtPath(folderUrl.path!, withIntermediateDirectories: true, attributes: nil, error: err) {
                return folderUrl.path!
            }
            return nil
        }
        return nil
    }
}

class Node<T> {
    weak var parent: Node<T>?
    var children: [Node]
    var value: T
    var id: Int
    
    init(t:T){
        children = Array<Node>()
        value = t
        id = 0
    }
    
    func addChild(childValue: T){
        children.append(Node(t: childValue))
    }
    
    func addChild(c: Node<T>){
        children.append(c)
    }
    
    func hasChildren() -> Bool {
        return children.count > 0
    }
    
}

class Tree<T> {
    var root: Node<T>?
    
    init(){
        self.root = nil
    }
    
    init(root: T) {
        self.root = Node(t: root)
        self.root?.id = 0
    }
}

class GrammarTree {
    
    var root: Node<Grammar>?
    weak var cur:  Node<Grammar>?
    private var traversalResult: String
    private var latestId: Int
    var graphvizFile: NSURL?
    
    init(){
        root = nil
        cur  = nil
        traversalResult = ""
        latestId = 1
    }
    
    init(rootValue: Grammar) {
        root = Node<Grammar>(t:rootValue)
        root?.id = 0
        cur = root
        traversalResult = ""
        latestId = 0
    }
    
    func addBranch(value: Grammar){
        var node = addGrammar(value)
        cur = node
    }
    
    func addChild(node: Node<Grammar>){
        addGrammar(node.value)
    }
    
    func addGrammar(value: Grammar) -> Node<Grammar> {
        var node: Node<Grammar> = Node(t: value)
        node.id = latestId
        
        if(root == nil){
            root = node
        } else {
            node.parent = cur;
            cur?.addChild(node)
        }
        latestId++
        return node
    }
    
//    func expand(node: Node<Grammar>, depth: Int){
//        traversalResult += "\n"
//        for (var i = 0; i < depth; i++){
//            traversalResult += "-"
//        }
//        
//        if (count(node.children) == 0){
//            traversalResult += "["
//            traversalResult += node.value.description
//            traversalResult += "]"
//        } else {
//            traversalResult += "<"
//            traversalResult += (node.value.description)
//            traversalResult += ">"
//            for (var i = 0; i < node.children.count; i++) {
//                expand(node.children[i], depth: depth + 1)
//            }
//        }
//    }
    
    func expand(node: Node<Grammar>) -> String {
        var str = "\"\(node.id)\" [label = \"\(node.value.description)\"]\n"
        if node.hasChildren() {
            for n in node.children {
                str += "\"\(node.id)\" -> \"\(n.id)\"\n"
                str += expand(n)
            }
        }
        return str
    }
    
    func shell(args: String...) -> Int32 {
        let task = NSTask()
        task.launchPath = "/usr/local/bin/dot"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
    
    
    
    func convertToGV(filename: String) {
        if(root == nil){
            return
        }
        var fileContents: String = "digraph canonical {\n"
        fileContents += expand(root!)
        fileContents += "\n}"
        
        let fileManager = NSFileManager.defaultManager()
        
        
//        let appDir = "~/Library/Application Support/"
        let appDir = "com.liamcain.compiler-in-swift".createFolderAt(.ApplicationSupportDirectory)
        let fullPath = appDir!.stringByAppendingPathComponent(filename)
        
        let gvLocation = fullPath.stringByAppendingPathExtension("gv")!
        let pdfLocation = fullPath.stringByAppendingPathExtension("pdf")!
        graphvizFile = NSURL(fileURLWithPath:pdfLocation)
        
        if fileContents.writeToFile(gvLocation, atomically: false, encoding: NSUTF8StringEncoding, error: nil) {
            shell("-Tpdf", gvLocation, "-o", pdfLocation)
        }
    }
    
//    func showTree() -> String {
//        traversalResult = ""
//        if root != nil {
//            expand(root!, depth: 0)
//        }
//        return traversalResult
//    }
}
