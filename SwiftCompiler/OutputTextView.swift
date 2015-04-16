//
//  OutputTextView.swift
//  SwiftCompiler
//
//  Created by Liam Cain on 4/16/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Cocoa

class OutputTextView: NSTextView {
    var guidePosition : CGFloat = 0
    var currentColumn : Int = 0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    required override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }
    
    func setup() {

    }

//    override func viewDidMoveToSuperview() {
//        
//    }
}
