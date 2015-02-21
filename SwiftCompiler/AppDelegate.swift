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
    @IBOutlet weak var inputTextfield: NSTextField!
    @IBOutlet weak var outputTextfield: NSTextField!
    @IBOutlet weak var compileButton: NSButton!
    @IBAction func compilePressed(sender: NSButton) {
        var tokenStream = lex(inputTextfield.stringValue)
        print(tokenStream)
    }


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}

