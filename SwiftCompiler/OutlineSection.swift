//
//  OutlineSection.swift
//  SwiftCompiler
//
//  Created by William Cain on 5/17/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

class OutlineSection: NSObject {
    
    var isHeader: Bool
    var name: String
    var children: [OutlineSection]?
 
    
    init(name: String, isHeader:Bool=false){
        self.isHeader = isHeader
        self.name = name
        children = Array<OutlineSection>()
    }
    
    func numberOfChildren() -> Int {
        if let children = children {
            return children.count
        }
        return 0
    }
    
    func childAtIndex(n: Int) -> OutlineSection? {
        if let children = children {
            return children[n]
        } else {
            return nil
        }
    }
    
}
