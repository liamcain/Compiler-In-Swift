//
//  Helper.swift
//  SwiftCompiler
//
//  Created by William Cain on 3/2/15.
//  Copyright (c) 2015 Liam Cain. All rights reserved.
//

import Foundation
import Cocoa

func errorColor() -> NSColor {
    return NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.4, alpha: 1.0)
}

func warningColor() -> NSColor {
    return NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
}

func matchColor() -> NSColor {
    return NSColor(red:0.34, green:0.76, blue:0.43, alpha:1)
}

func mutedColor() -> NSColor {
    return NSColor(calibratedRed: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
}

func uselessColor() -> NSColor {
    return NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.45, alpha: 1.0)
}