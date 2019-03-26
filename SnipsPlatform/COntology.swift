//
//  COntology.swift
//  SnipsPlatform
//
//  Copyright © 2019 Snips. All rights reserved.
//

import Foundation
#if os(OSX)
import Clibsnips_megazord_macos
#elseif os(iOS)
import Clibsnips_megazord_ios
#endif

extension CStringArray {
    init(array: [String]) {
        let data = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: array.count)
        array.enumerated().forEach {
            data.advanced(by: $0).pointee = UnsafePointer($1.unsafeMutablePointerRetained())
        }
        self.init(data: data, size: Int32(array.count))
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
        self.init(key: key.unsafeMutablePointerRetained(), value: retainedArray)
    }

    func destroy() {
        key?.freeUnsafeMemory()
        value?.pointee.destroy()
        UnsafeMutablePointer(mutating: value)?.deinitialize(count: 1)
        value?.deallocate()
    }
}

extension CMapStringToStringArray {
    init(dict: [String: [String]]) throws {
        let entries = UnsafeMutablePointer<UnsafePointer<CMapStringToStringArrayEntry>?>.allocate(capacity: dict.count)
        try dict.enumerated().forEach { (offset, element) in
            let retainedArray = UnsafeMutablePointer<CMapStringToStringArrayEntry>.allocate(capacity: 1)
            retainedArray.initialize(to: try CMapStringToStringArrayEntry(key: element.key, value: element.value))
            entries.advanced(by: offset).pointee = UnsafePointer(retainedArray)
        }
        self.init(entries: entries, count: Int32(dict.count))
    }

    func destroy() {
        for idx in 0..<count {
            if let cMapStrToStrEntry = entries.advanced(by: Int(idx)).pointee {
                cMapStrToStrEntry.pointee.destroy()
                UnsafeMutablePointer(mutating: cMapStrToStrEntry)?.deinitialize(count: 1)
                cMapStrToStrEntry.deallocate()
            }
        }
        entries?.deallocate()
    }
}

extension CInjectionRequestOperation {
    init(dict: [String: [String]], kind: InjectionKind) throws {
        let retainedArray = UnsafeMutablePointer<CMapStringToStringArray>.allocate(capacity: 1)
        retainedArray.initialize(to: try CMapStringToStringArray(dict: dict))
        self.init(values: retainedArray, kind: kind.toCInjectionKind())
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
            let retainedArray = UnsafeMutablePointer<CInjectionRequestOperation>.allocate(capacity: 1)
            retainedArray.initialize(to: try CInjectionRequestOperation(dict: $0.element.entities, kind: $0.element.kind))
            entries.advanced(by: $0.offset).pointee = UnsafePointer(retainedArray)
        }
        self.init(operations: UnsafePointer(entries), count: Int32(operations.count))
    }

    func destroy() {
        for idx in 0..<count {
            if let cInjectionRequestOperation = operations.advanced(by: Int(idx)).pointee {
                cInjectionRequestOperation.pointee.destroy()
                UnsafeMutablePointer(mutating: cInjectionRequestOperation).deinitialize(count: 1)
                cInjectionRequestOperation.deallocate()
            }
        }
        operations?.deallocate()
    }
}
