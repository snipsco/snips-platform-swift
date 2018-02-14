//
//  String+Utils.swift
//  SnipsPlatform
//
//  Copyright © 2018 Snips. All rights reserved.
//

import Foundation

extension String {
    static func fromCStringPtr(cString: UnsafePointer<Int8>!) -> String? {
        if let cStringUnwrapped = cString {
            return String(cString: cStringUnwrapped)
        } else {
            return nil
        }
    }
}
