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
    return NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.3, alpha: 1.0)
}

func mutedColor() -> NSColor {
    return NSColor(calibratedRed: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
}

func tokenColor() -> NSColor {
    return NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
}