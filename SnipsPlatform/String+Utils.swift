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

    /// Helper to create a retained pointer to a C String. We have to free it later on.
    func unsafeMutablePointerRetained() -> UnsafeMutablePointer<Int8>! {
        return strdup(self)
    }
}

extension UnsafePointer where Pointee == Int8 {
    /// Helper to free retained C String from strdup / unsafeMutablePointerRetained()
    func freeUnsafeMemory() {
        free(UnsafeMutableRawPointer(mutating: UnsafeRawPointer(self)))
    }
}
