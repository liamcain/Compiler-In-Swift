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

class Node<T> {
    weak var parent: Node<T>?
    var children: [Node]
    var value: T
    
    init(t:T){
        children = Array<Node>()
        value = t
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
    }
}

class GrammarTree {
    
    var root: Node<Grammar>?
    weak var cur:  Node<Grammar>?
    private var traversalResult: String
    
    init(){
        root = nil
        cur  = nil
        traversalResult = ""
    }
    
    init(rootValue: Grammar) {
        root = Node<Grammar>(t:rootValue)
        cur = root
        traversalResult = ""
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
        
        if(root == nil){
            root = node
        } else {
            node.parent = cur;
            cur?.addChild(node)
        }
        return node
    }
    
    func expand(node: Node<Grammar>, depth: Int){
        traversalResult += "\n"
        for (var i = 0; i < depth; i++){
            traversalResult += "-"
        }
        
        if (count(node.children) == 0){
            traversalResult += "["
            traversalResult += node.value.description
            traversalResult += "]"
        } else {
            traversalResult += "<"
            traversalResult += (node.value.description)
            traversalResult += ">"
            for (var i = 0; i < node.children.count; i++) {
                expand(node.children[i], depth: depth + 1)
            }
        }
    }
    
    func showTree() -> String {
        traversalResult = ""
        if root != nil {
            expand(root!, depth: 0)
        }
        return traversalResult
    }
}
