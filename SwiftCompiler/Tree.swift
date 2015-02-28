//
//  Tree.swift
//  SwiftCompiler
//
//  Created by William Cain on 2/22/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation

class Node<T> {
    var children: [Node]
    
    init(T){
        children = Array<Node>()
    }
    
    func addChild(value: T){
        children.append(Node(value))
    }
    
    func hasChildren() -> Bool {
        return false
    }
}

class Tree<T> {
    var root: Node<T>?
    
    init(){
        self.root = nil
    }
    
    init(root: T) {
        self.root = Node(root)
    }
    
}
