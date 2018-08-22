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
            data.advanced(by: $0).pointee = UnsafePointer($1.unsafeMutablePointerRetained())
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
        let retainedArray = UnsafeMutablePointer<CStringArray>.allocate(capacity: 1)
        retainedArray.initialize(to: CStringArray(array: value))
        self.init()
        self.key = UnsafePointer(key.unsafeMutablePointerRetained())
        self.value = UnsafePointer(retainedArray)
    }
    
    func destroy() {
        key?.freeUnsafeMemory()
        value?.pointee.destroy()
        UnsafeMutablePointer(mutating: value)?.deinitialize(count: 1)
        value?.deallocate()
    }
}

extension CMapStringToStringArray {
    init(array: [String: [String]]) throws {
        let entries = UnsafeMutablePointer<UnsafePointer<CMapStringToStringArrayEntry>?>.allocate(capacity: array.count)
        try array.enumerated().forEach { (offset, element) in
            let retainedArray = UnsafeMutablePointer<CMapStringToStringArrayEntry>.allocate(capacity: 1)
            retainedArray.initialize(to: try CMapStringToStringArrayEntry(key: element.key, value: element.value))
            entries.advanced(by: offset).pointee = UnsafePointer(retainedArray)
        }
        self.init()
        self.entries = UnsafePointer(entries)
        self.count = Int32(array.count)
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

extension CInjectionRequestOperation {
    init(array: [String: [String]], kind: SnipsInjectionKind) throws {
        let cMapStringToStringArray = try CMapStringToStringArray(array: array)
        let retainedArray = UnsafeMutablePointer<CMapStringToStringArray>.allocate(capacity: 1)
        retainedArray.initialize(to: cMapStringToStringArray)
        self.init()
        self.values = UnsafePointer(retainedArray)
        self.kind = kind.toUnsafeCSnipsInjectionKind()
    }
    
    func destroy() {
        values?.pointee.destroy()
        UnsafeMutablePointer(mutating: values)?.deinitialize(count: 1)
        values?.deallocate()
    }
}

extension CInjectionRequestOperations {
    init(operations: [InjectionRequestOperation]) throws {
        let entries = UnsafeMutablePointer<UnsafePointer<CInjectionRequestOperation>?>.allocate(capacity: operations.count)
        try operations.enumerated().forEach {
            let cInjectionRequestOperation = try CInjectionRequestOperation(array: $0.element.entities, kind: $0.element.kind)
            let retainedArray = UnsafeMutablePointer<CInjectionRequestOperation>.allocate(capacity: 1)
            retainedArray.initialize(to: cInjectionRequestOperation)
            entries.advanced(by: $0.offset).pointee = UnsafePointer(retainedArray)
        }
        self.init()
        self.operations = UnsafePointer(entries)
        self.count = Int32(operations.count)
    }
    
    func destroy() {
        for idx in 0..<count {
            if let subPointee = operations.pointee?.advanced(by: Int(idx)) {
                subPointee.pointee.destroy()
                UnsafeMutablePointer(mutating: subPointee).deinitialize(count: 1)
                subPointee.deallocate()
            }
        }
        operations?.deallocate()
    }
}
