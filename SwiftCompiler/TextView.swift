//
//  TextView.swift
//  SwiftEdit
//
//  Created by Scott Horn on 17/06/2014.
//  Copyright (c) 2014 Scott Horn. All rights reserved.
//

import Cocoa

class TextView: NSTextView {
    let myDelegate = TextViewDelegate()
    var guidePosition : CGFloat = 0
    var currentColumn : Int = 0
//    var fixedFont = NSFont.userFixedPitchFontOfSize(NSFont.smallSystemFontSize())
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    required override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }
    
    func setup() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "selectionDidChange:",
            name: NSTextViewDidChangeSelectionNotification,
            object: self)
//        guidePosition = initGuidePosition()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func selectionDidChange(notification: NSNotification) {
        needsDisplay = true
        let delegate: AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
        delegate.textDidChange()
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSColor.whiteColor().set()
        NSRectFill(bounds)
        super.drawRect(dirtyRect)
    }
    
    override func drawViewBackgroundInRect(rect: NSRect) {
        //super.drawViewBackgroundInRect(rect)
//        drawPageGuideBackgroundAt(guidePosition)
        drawHighlightedLine()
//        drawPageGuideLineAt(guidePosition)
    }
    
    func drawHighlightedLine() {
        let text = textStorage!.string as NSString
        if selectedRange.location <= text.length {
            let lineRange = text.lineRangeForRange(NSMakeRange(selectedRange.location, 0))
            NSColor(calibratedRed: 0.992, green: 1.000, blue: 0.800, alpha: 1).setFill()
            NSRectFill(rectForRange(lineRange))
        }
    }
    
    func rectForRange(range: NSRange) -> NSRect {
        var lineRectCount : Int = 0
        let lineRectsForRange = layoutManager!.rectArrayForCharacterRange(range,
            withinSelectedCharacterRange: NSMakeRange(NSNotFound, 0),
            inTextContainer: textContainer!,
            rectCount: &lineRectCount)
        
        if lineRectCount < 1 {
            return NSZeroRect
        }
        let y = lineRectsForRange[0].origin.y
        let h = lineRectsForRange[0].size.height
        let w = bounds.size.width
        return NSOffsetRect(NSMakeRect(0, y, w, h), textContainerOrigin.x, textContainerOrigin.y)
    }
    
    func initGuidePosition() -> CGFloat {
        var lineRectCount: Int = 0
        var stripSpace = false
        if count(string!.utf16) < 1 {
            string = " "
            stripSpace = true
        }
        let lineRectsForRange = layoutManager!.rectArrayForCharacterRange(NSMakeRange(0, 1),
            withinSelectedCharacterRange: NSMakeRange(NSNotFound, 0),
            inTextContainer: textContainer!,
            rectCount: &lineRectCount)
        string = stripSpace ? "" : string
        let margin = lineRectsForRange[0].origin.x
        let maxSizeChar = "8" as NSString
//        let size = maxSizeChar.sizeWithAttributes([NSFontAttributeName: fixedFont]).width
        let size = 3// maxSizeChar.sizeWithAttributes([NSFontAttributeName: fixedFont])
        return 20.0//Double(Int(margin + size * 80)) + 0.5
    }
    
    override func doCommandBySelector(aSelector: Selector) {
        if !myDelegate.textView(self, doCommandBySelector: aSelector) {
            super.doCommandBySelector(aSelector)
        }
    }
    
}
