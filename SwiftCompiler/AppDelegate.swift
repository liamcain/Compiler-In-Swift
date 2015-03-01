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
    @IBOutlet weak var snippetsMenu: NSMenu!
    var textView: NSTextView { return inputScrollView!.contentView.documentView as! NSTextView }
    @IBOutlet var console: NSTextView?
    var rulerView: RulerView?
    var lexer: Lexer?
    var parser: Parser?
    var snippets: Dictionary<String, String> = Dictionary()

    @IBAction func createSnippetPressed(sender: AnyObject) {
        let name = "Test Case \(snippets.count)"
        snippetsMenu.addItem(NSMenuItem(title: name, action: Selector("insertSnippet:"), keyEquivalent: ""))
        snippets[name] = textView.string!
        Defaults["snippets"] = snippets
        Defaults.synchronize()
//        Defaults["Snippets"].dictionary!["Test"] = textView.string!
    }
    @IBAction func compileMenuItemPressed(sender: AnyObject) {
        compile()
    }
    @IBAction func compilePressed(sender: NSButton) {
        compile()
    }
    
    func compile(){
        console!.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        // -- LEX --------------------------------------
        log("Starting Lex Phase...")
        let tokenStream = lexer?.lex(textView.string!)
        if tokenStream == nil {
            log("Lex failed. Exiting.")
            return
        }
        log("Lex successful.\n")
        
        
        // -- PARSE ------------------------------------
        log("Starting Parse Phase...")
        let cst = parser!.parse(tokenStream!)
        if cst == nil {
            log("Parse failed. Exiting.")
        }
        log("Parse successful. That's all for now.")
    }
    
    func log(output: String){
        let attributes = [NSForegroundColorAttributeName: NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)]
        var str: NSAttributedString = NSAttributedString(string: (output + "\n"), attributes: attributes)
        console!.textStorage?.appendAttributedString(str)
    }
    
    func insertSnippet(sender: AnyObject){
        let str = (sender as! NSMenuItem).title
        
        textView.insertText(snippets[str]!)
    }
    
    func populateSnippetsMenu() {
        for (key, value) in snippets {
            snippetsMenu.addItem(NSMenuItem(title: key, action: Selector("insertSnippet:"), keyEquivalent: ""))
        }
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        let textView = self.textView
        lexer = Lexer(outputView: console)
        parser = Parser(outputView: console)
        
        if Defaults["snippets"].dictionary != nil {
            snippets = Defaults["snippets"].dictionary as! Dictionary<String, String>
            populateSnippetsMenu()
        }
        
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

