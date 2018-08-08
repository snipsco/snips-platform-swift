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
        for idx in 0..<size {
            free(UnsafeMutableRawPointer(mutating: data.advanced(by: Int(idx)).pointee))
        }
        data?.deallocate()
    }

    func toSwiftArray() -> [String] {
        return UnsafeBufferPointer(start: data, count: Int(size))
            .compactMap { $0 }
            .map { String(cString: $0) }
    }
}

extension CMapStringToStringArrayEntry {
    init(key: String, value: [String]) throws {
        var cStringArray = CStringArray(array: value)
        let unsafeArrayString = withUnsafePointer(to: &cStringArray) { $0 }
        let unsafeMutableArrayString = UnsafeMutablePointer(mutating: unsafeArrayString)
        self.init(key: key.unsafeMutablePointerRetained(), value: unsafeMutableArrayString)
    }
    
    func destroy() {
        key?.freeUnsafeMemory()
        value?.pointee.destroy()
    }
}

extension CMapStringToStringArray {
    init(array: [String: [String]]) throws {
        let entries = UnsafeMutablePointer<UnsafePointer<CMapStringToStringArrayEntry>?>.allocate(capacity: array.count)
        try array.enumerated().forEach { tuple in
            var cMapStoSArrayEntry = try CMapStringToStringArrayEntry(key: tuple.element.key, value: tuple.element.value)
            entries.advanced(by: tuple.offset).pointee = withUnsafePointer(to: &cMapStoSArrayEntry) { $0 }
        }
        self.init(entries: UnsafePointer(entries), count: Int32(array.count))
    }
    
    func destroy() {
        for idx in 0..<count {
            if let subPointee = entries.pointee?.advanced(by: Int(idx)) {
                subPointee.pointee.destroy()
                free(UnsafeMutableRawPointer(mutating: subPointee))
            }
        }
        entries?.deallocate()
    }
}
