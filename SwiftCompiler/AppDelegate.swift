//
//  AppDelegate.swift
//  SwiftCompiler
//
//  Created by Liam Cain on 1/29/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Cocoa

extension Dictionary {
    mutating func merge<K, V>(dict: [K: V]){
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var inputScrollView: ScrollView!
    @IBOutlet weak var outputScrollView: NSScrollView!

    @IBOutlet weak var defaultSnippetsMenu: NSMenu!
    @IBOutlet weak var customSnippetsMenu: NSMenu!

    
    @IBOutlet weak var cursorPosLabel: NSTextField!
    @IBOutlet var console: NSTextView?
    
    var textView: NSTextView { return inputScrollView!.contentView.documentView as! NSTextView }
    
    var rulerView: RulerView?
    var lexer: Lexer?
    var parser: Parser?
    var tokenStream: [Token]?
    var defaultSnippets: Dictionary<String, String> = Dictionary()
    var customSnippets: Dictionary<String, String>  = Dictionary()

    @IBAction func createSnippetPressed(sender: AnyObject) {
        let name = "Test Case \(customSnippets.count)"
        customSnippetsMenu.addItem(NSMenuItem(title: name, action: Selector("insertSnippet:"), keyEquivalent: ""))
        customSnippets[name] = textView.string!
        Defaults["snippets"] = customSnippets
        Defaults.synchronize()
    }

    @IBAction func compileMenuItemPressed(sender: AnyObject) {
        compile()
    }

    @IBAction func compileButtonPressed(sender: AnyObject) {
        compile()
    }
    
    func compile(){
        console!.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        // -- LEX --------------------------------------
        log("Starting Lex Phase...")
        tokenStream = lexer?.lex(textView.string!)
        if tokenStream == nil {
            log("*Lex failed. Exiting.*")
            return
        }
        log("*Lex successful.*\n")
        
        
        // -- PARSE ------------------------------------
        log("Starting Parse Phase...")
        let cst = parser!.parse(tokenStream!)
        if cst == nil {
            log("*Parse failed. Exiting.*")
        }
        log("*Parse successful. That's all for now.*")
    }
    
    func log(output: String){
        let attributes = [NSForegroundColorAttributeName: matchColor()]
        var str: NSAttributedString = NSAttributedString(string: (output + "\n"), attributes: attributes)
        console!.textStorage?.appendAttributedString(str)
    }
    
    func insertSnippet(sender: AnyObject){
        let menuItem = (sender as! NSMenuItem)
        let str = menuItem.title
        
        if menuItem.menu?.title == "Custom Snippets" {
            textView.insertText(customSnippets[str]!)
        } else {
            textView.insertText(defaultSnippets[str]!)
        }
        
        
    }
    
    func populateSnippetsMenu() {
        var myDict: NSDictionary?
        if let path = NSBundle.mainBundle().pathForResource("test-cases", ofType: "plist") {
            defaultSnippets = NSDictionary(contentsOfFile: path) as! Dictionary<String, String>
        }
        if count(defaultSnippets) > 0 {
            for (key, value) in defaultSnippets {
                defaultSnippetsMenu.addItem(NSMenuItem(title: key, action: Selector("insertSnippet:"), keyEquivalent: ""))
            }
        }
        
        for (key, value) in customSnippets {
            customSnippetsMenu.addItem(NSMenuItem(title: key, action: Selector("insertSnippet:"), keyEquivalent: ""))
        }
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
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
        
        populateSnippetsMenu()
    }
    
    func textDidChange(){
        let pos = textView.selectedRange().location
        var col: Int = 1, line = 1
        var char: Character! = nil
        let chars = Array(textView.string!)
        for var i = 0; i < pos; i++ {
            char = chars[i]
            if char == "\n" {
                line++
                col = 1
            } else {
                col++
            }
        }
        cursorPosLabel.stringValue = "Line \(line), Column \(col)"
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}

