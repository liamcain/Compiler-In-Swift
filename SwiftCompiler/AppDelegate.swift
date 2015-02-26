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
    @IBOutlet var inputTextView: NSTextView!
    @IBOutlet weak var outputScrollView: NSScrollView!
    
    @IBOutlet weak var compileButton: NSButton!
    
    var lexer: Lexer?
    var parser: Parser?

    @IBAction func compilePressed(sender: NSButton) {
        lexer = Lexer(_outputView: outputScrollView)
        var tokenStream = lexer?.lex(inputTextView.string!)
        printStream(tokenStream!)
        
        parser = Parser()
        parser!.parse(tokenStream!)
    }

    func printStream(tokenStream: Array<Token>){
        var output: String = ""
        for token in tokenStream {
            println(token.str + "   " + token.type.rawValue)
        }
        return
        var str: NSAttributedString = NSAttributedString(string: (output))
        var textView = outputScrollView!.contentView.documentView as! NSTextView
        textView.textStorage?.appendAttributedString(str)
    }
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        inputTextView.automaticQuoteSubstitutionEnabled = false
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}

