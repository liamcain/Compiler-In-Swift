//
//  AppDelegate.swift
//  SwiftCompiler
//
//  Created by Liam Cain on 1/29/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var inputScrollView: ScrollView!
    @IBOutlet weak var outputScrollView: NSScrollView!
    var textView: NSTextView { return inputScrollView!.contentView.documentView as! NSTextView }
    @IBOutlet var console: NSTextView?
    var rulerView: RulerView?
    
    @IBOutlet weak var compileButton: NSButton!
    
    var lexer: Lexer?
    var parser: Parser?

    @IBAction func compilePressed(sender: NSButton) {
        var tokenStream = lexer?.lex(textView.string!)
        parser!.parse(tokenStream!)
    }

    func printStream(tokenStream: Array<Token>){
        var output: String = ""
        for token in tokenStream {
            println(token.str + "   " + token.type.rawValue)
        }
        var str: NSAttributedString = NSAttributedString(string: (output))
        var textView = outputScrollView!.contentView.documentView as! NSTextView
        textView.textStorage?.appendAttributedString(str)
    }
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        let textView = self.textView
        lexer = Lexer(outputView: console)
        parser = Parser(outputView: console)
        
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.textContainerInset = NSMakeSize(0,1)
//        textView.font = NSFont.userFixedPitchFontOfSize(NSFont.smallSystemFontSize())
        textView.font = NSFont.userFixedPitchFontOfSize(12.0)
        textView.automaticQuoteSubstitutionEnabled = false
        
        rulerView = RulerView(scrollView: inputScrollView, orientation: NSRulerOrientation.VerticalRuler)
        inputScrollView!.verticalRulerView = rulerView
        inputScrollView!.hasHorizontalRuler = false
        inputScrollView!.hasVerticalRuler = true
        inputScrollView!.rulersVisible = true
        
        console!.drawsBackground = true
        console!.editable = false
        console!.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}

