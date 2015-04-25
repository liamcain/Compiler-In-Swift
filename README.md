![Swift Compiler](compiler-header.png?raw=true)

This is a compiler for CMPT432 written in [Swift](https://developer.apple.com/swift/). It will eventually compile `Alan++` into [6502 opcode](http://www.6502.org/tutorials/6502opcodes.html).

*Note:* I will be out of touch until Monday night. I thought I would have time to finish verbose mode but I refactored my logging instead. I plan on adding verbose mode when I get back.

Features
========
- [x] Lexer - Makes sure you spelled `boolean` right
- [x] Parser - Did I put 5 parentheses or 6?
- [x] Semantic Analysis - Oh, I never declared that variable that does the stuff?
- [ ] Code Generation - *Coming Soon!*

Requirements
============

- [Xcode 6.3 (or higher)](https://developer.apple.com/xcode/)
- [OS X 10.10 (or higher)](https://www.apple.com/osx/)

How to Setup
============
- Clone repo (`$ git clone https://github.com/boundincode/Compiler-In-Swift`)
- Open `SwiftCompiler.xcodeproj` in Xcode
- Press `Build > Run` (<kbd>⌘</kbd> + <kbd>R</kbd>)

Credits
=======
JP Simard - For his project [SwiftEdit](github.com/jpsim/SwiftEdit) which adds line numbers to NSTextViews.

