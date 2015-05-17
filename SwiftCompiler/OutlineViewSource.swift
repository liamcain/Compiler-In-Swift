//
//  OutlineViewSource.swift
//  SwiftCompiler
//
//  Created by William Cain on 5/17/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Cocoa

class OutlineViewSource: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    var outlineSections: [OutlineSection] = Array<OutlineSection>()
    
    var root: OutlineSection = OutlineSection(name: "Output", isHeader: true)
    var tokens: OutlineSection = OutlineSection(name: "TOKENS", isHeader: true)
    var ast: OutlineSection = OutlineSection(name: "AST", isHeader: true)
    var cst: OutlineSection = OutlineSection(name: "CST", isHeader: true)
    
    func setup(){
        root.children?.append(tokens)
        root.children?.append(cst)
        root.children?.append(ast)
        outlineSections.append(root)
    }
    
    func setTokenStream(tokenStream: [Token]){
        for t in tokenStream {
            tokens.children?.append(OutlineSection(name: t.str))
        }
    }
    
    func setCST(cstTree: GrammarTree) {
        nodeToOutline(cstTree.root, parentSection: cst)
    }
    
    func setAST(astTree: GrammarTree) {
        nodeToOutline(astTree.root, parentSection: ast)
    }
    
    private func nodeToOutline(node: Node<Grammar>?, parentSection: OutlineSection){
        if node == nil {
            return
        }
        
        let newSection = OutlineSection(name: node!.value.description)
        parentSection.children?.append(newSection)
        
        for n in node!.children {
            nodeToOutline(n, parentSection: newSection)
        }
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if let it = item as? OutlineSection {
            return it.childAtIndex(index)!
        } else {
            return root
        }
    }
    
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if let it = item as? OutlineSection {
            if it.numberOfChildren() > 0 {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    func outlineView(outlineView: NSOutlineView, didClickTableColumn tableColumn: NSTableColumn) {
        
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if let it = item as? OutlineSection {
            return it.numberOfChildren()
        }
        return 1
    }
    
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let section = item as! OutlineSection
        if section.name == "Output" {
            return nil
        }
        if section.isHeader {
            var v = outlineView.makeViewWithIdentifier("HeaderCell", owner: self) as! NSTableCellView
            if let tf = v.textField {
                tf.stringValue = section.name
            }
            return v
        } else {
            var v = outlineView.makeViewWithIdentifier("OutlineCell", owner: self) as! NSTableCellView
            if let tf = v.textField {
                tf.stringValue = section.name
            }
            return v
        }
    }
    
    func outlineView(outlineView: NSOutlineView, shouldShowOutlineCellForItem item: AnyObject) -> Bool {
        let section = item as! OutlineSection
        return !section.isHeader

    }
    
    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn: NSTableColumn?, byItem:AnyObject?) -> AnyObject? {
        if let item = byItem as? OutlineSection {
            return item.name
        }
        return nil
    }
    
    
}
