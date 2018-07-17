//
//  COntology.swift
//  SnipsPlatform
//
//  Copyright © 2018 Snips. All rights reserved.
//

import Foundation
import Clibsnips_megazord

extension CStringArray {
    init(array: [String]) {
        let data = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: array.count)
        array.enumerated().forEach {
            data.advanced(by: $0).pointee = UnsafePointer(strdup($1))
        }

        self.init()
        self.data = UnsafePointer(data)
        self.size = Int32(array.count)
    }

    func destroy() {
        let mutating = UnsafeMutablePointer(mutating: data)
        for idx in 0..<size {
            free(UnsafeMutableRawPointer(mutating: data.advanced(by: Int(idx)).pointee))
        }
        mutating?.deallocate()
    }

    func toSwiftArray() -> [String] {
        return UnsafeBufferPointer(start: data, count: Int(size))
            .compactMap { $0 }
            .map { String(cString: $0) }
    }
}

extension String {
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
