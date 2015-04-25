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
public enum OutputProfile: Int {
    case EndUser = 1
    case Verbose = 2
    case Everything = 3
}

public enum LogType {
    case Message
    case Match
    case Error
    case Warning
    case Useless
}

public class Log {
    var phase: String
    var output: String
    var type: LogType         = LogType.Message
    var color: NSColor?       = nil
    var position: (Int, Int)? = nil
    var profile: OutputProfile = OutputProfile.EndUser
    
    init(output:String, phase: String){
        self.output = output
        self.phase = phase
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var inputScrollView: ScrollView!
    @IBOutlet weak var outputScrollView: NSScrollView!
    @IBOutlet weak var overlayPanel: NSPanel!
    @IBOutlet weak var overlayText: NSTextField!
    @IBOutlet weak var runButton: NSToolbarItem!

    @IBOutlet weak var defaultSnippetsMenu: NSMenu!
    @IBOutlet weak var customSnippetsMenu: NSMenu!
    
    @IBOutlet weak var cursorPosLabel: NSTextField!
    
    var textView: NSTextView { return inputScrollView!.contentView.documentView as! NSTextView }
    var console:  OutputTextView { return outputScrollView!.contentView.documentView as! OutputTextView }
    
    var rulerView: RulerView?
    var lexer: Lexer?
    var parser: Parser?
    var analyzer: SemanticAnalysis?
    var tokenStream: [Token]?
    var defaultSnippets: Dictionary<String, String> = Dictionary()
    var customSnippets: Dictionary<String, String>  = Dictionary()
    var selectedProfile: OutputProfile = OutputProfile.EndUser
    
    @IBAction func createSnippetPressed(sender: AnyObject) {
        let name = "Test Case \(customSnippets.count)"
        customSnippetsMenu.addItem(NSMenuItem(title: name, action: Selector("insertSnippet:"), keyEquivalent: ""))
        customSnippets[name] = textView.string!
        Defaults["snippets"] = customSnippets
        Defaults.synchronize()
    }
    
    @IBAction func setOutputProfile(sender: NSMenuItem) {
        switch sender.title {
            case "End User":
                selectedProfile = OutputProfile.EndUser
            case "Verbose":
                selectedProfile = OutputProfile.Verbose
            case "Tell me everything":
                selectedProfile = OutputProfile.Everything
            default: ()
        }
        for c in sender.parentItem!.submenu!.itemArray {
            let m = c as! NSMenuItem
            m.state = NSOffState
        }
        sender.state = NSOnState
    }
    
    
    @IBAction func compileMenuItemPressed(sender: AnyObject) {
        self.compile()
    }

    @IBAction func compileButtonPressed(sender: AnyObject) {
        self.compile()
    }
    
    func compile(){
        console.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        // -- LEX --------------------------------------
        log("-----------------------------")
        log("Starting Lex Phase...")
        log("-----------------------------")
        tokenStream = lexer?.lex(textView.string!)
        if tokenStream == nil {
            showOverlay("Lexer Failed")
            log("*Lex failed. Exiting.*")
            return
        }
        log("*Lex successful.*\n")
        
        
        // -- PARSE ------------------------------------
        log("-----------------------------")
        log("Starting Parse Phase...")
        log("-----------------------------")
        
        let cst = parser!.parse(tokenStream!)
        if cst == nil {
            showOverlay("Parser Failed")
            log("*Parse failed. Exiting.*")
            return
        }
        log("*Parse successful.*\n")
        
        
        // -- SEMANTIC ANALYSIS ------------------------
        log("-----------------------------")
        log("Starting Semantic Analysis...")
        log("-----------------------------")
        let ast = analyzer!.analyze(cst!)
        if ast == nil {
            showOverlay("Semantic Analysis Failed")
            log("*Semantic Analysis failed. Exiting.*")
            return
        }
        showOverlay("Compiler Succeeded")
    }
    

    
    func log(string:String) {
        logString(string+"\n", color:mutedColor())
    }
    
    func logString(string:String, color: NSColor) {
        dispatch_async(dispatch_get_main_queue()) {
            let font = NSFont(name: "Menlo", size: 12)
            let attributedString = NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName: color, NSFontAttributeName: font!])
            self.console.textStorage?.appendAttributedString(attributedString)
        }
    }
    
    func log(log: Log){
        var str: String
        
        if selectedProfile.rawValue >= log.profile.rawValue {
            switch log.type {
            case .Warning:
                str = "[\(log.phase) Warning at position \(log.position!.0):\(log.position!.1)] \(log.output)\n"
                logString(str, color:warningColor())
            case .Error:
                str = "[\(log.phase) Error at position \(log.position!.0):\(log.position!.1)] \(log.output)\n"
                logString(str, color:errorColor())
            case .Match:
                str = "\(log.output)\n"
                logString(str, color:matchColor())
            case .Useless:
                str = "\(log.output)\n"
                logString(str, color:uselessColor())
            case .Message:
                str = "\(log.output)\n"
                logString(str, color:mutedColor())
            }
        }
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
    
    func showOverlay(str:String) {
        overlayText.stringValue = str
        
        self.window.addChildWindow(overlayPanel, ordered: NSWindowOrderingMode.Above)
        let xPos = window.frame.origin.x + window.frame.size.width/2 - NSWidth(overlayPanel.frame)/2
        let yPos = window.frame.origin.y + window.frame.size.height/2 - NSHeight(overlayPanel.frame)/2
        overlayPanel.center()
        overlayPanel.setFrameOrigin(NSPoint(x:xPos, y:yPos))
        overlayPanel.makeKeyAndOrderFront(self.window)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.overlayPanel.orderOut(self.overlayPanel)
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
        let console  = self.console
        
        lexer    = Lexer()
        parser   = Parser()
        analyzer = SemanticAnalysis()
        
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.textContainerInset = NSMakeSize(0,1)
        textView.font = NSFont(name: "Menlo", size: 12.0)
        textView.automaticQuoteSubstitutionEnabled = false
        
        console.translatesAutoresizingMaskIntoConstraints = true
        console.font = NSFont(name: "Menlo", size: 12.0)
        
        rulerView = RulerView(scrollView: inputScrollView, orientation: NSRulerOrientation.VerticalRuler)
        inputScrollView!.verticalRulerView = rulerView
        inputScrollView!.hasHorizontalRuler = false
        inputScrollView!.hasVerticalRuler = true
        inputScrollView!.rulersVisible = true
        console.drawsBackground = true
        console.editable = false
        console.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        
        // Allow text to align properly in console
        let style = NSMutableParagraphStyle()
        style.defaultTabInterval = 36.0
        console.defaultParagraphStyle = style
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

