//
//  Ontology.swift
//  SnipsPlatform
//
//  Copyright © 2017 Snips. All rights reserved.
//

import Foundation
import Clibsnips_megazord

public struct IntentMessage {
    public let sessionId: String
    public var customData: String?
    public var siteId: String
    public var input: String
    public var intent: IntentClassifierResult?
    public var slots: [Slot]

    init(cResult: CIntentMessage) throws {
        self.sessionId = String(cString: cResult.session_id)
        self.customData = String.fromCStringPtr(cString: cResult.custom_data)
        self.siteId = String(cString: cResult.site_id)
        self.input = String(cString: cResult.input)
        if let cClassifierResult = cResult.intent?.pointee {
            self.intent = IntentClassifierResult(cResult: cClassifierResult)
        } else {
            self.intent = nil
        }
        if let cSlotList = cResult.slots?.pointee {
            self.slots = try UnsafeBufferPointer(start: cSlotList.slots, count: Int(cSlotList.size)).map(Slot.init)
        } else {
            self.slots = []
        }
    }
}

public struct IntentClassifierResult {
    public let intentName: String
    public let probability: Float

    init(cResult: CIntentClassifierResult) {
        self.intentName = String(cString: cResult.intent_name)
        self.probability = cResult.probability
    }
}

public enum SlotValue {
    case custom(String)
    case number(NumberValue)
    case ordinal(OrdinalValue)
    case instantTime(InstantTimeValue)
    case timeInterval(TimeIntervalValue)
    case amountOfMoney(AmountOfMoneyValue)
    case temperature(TemperatureValue)
    case duration(DurationValue)

    init(cSlotValue: CSlotValue) throws {
        switch cSlotValue.value_type {
        case CUSTOM:
            let x = cSlotValue.value.assumingMemoryBound(to: CChar.self)
            self = .custom(String(cString: x))

        case NUMBER:
            let x = cSlotValue.value.assumingMemoryBound(to: CDouble.self)
            self = .number(x.pointee)

        case ORDINAL:
            let x = cSlotValue.value.assumingMemoryBound(to: CInt.self)
            self = .ordinal(OrdinalValue(x.pointee))

        case INSTANTTIME:
            let x = cSlotValue.value.assumingMemoryBound(to: CInstantTimeValue.self)
            self = .instantTime(try InstantTimeValue(cValue: x.pointee))

        case TIMEINTERVAL:
            let x = cSlotValue.value.assumingMemoryBound(to: CTimeIntervalValue.self)
            self = .timeInterval(TimeIntervalValue(cValue: x.pointee))

        case AMOUNTOFMONEY:
            let x = cSlotValue.value.assumingMemoryBound(to: CAmountOfMoneyValue.self)
            self = .amountOfMoney(try AmountOfMoneyValue(cValue: x.pointee))

        case TEMPERATURE:
            let x = cSlotValue.value.assumingMemoryBound(to: CTemperatureValue.self)
            self = .temperature(TemperatureValue(cValue: x.pointee))

        case DURATION:
            let x = cSlotValue.value.assumingMemoryBound(to: CDurationValue.self)
            self = .duration(try DurationValue(cValue: x.pointee))

        default: throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
    }
}

public typealias NumberValue = Double

public typealias OrdinalValue = Int

public struct InstantTimeValue {
    public let value: String
    public let grain: Grain
    public let precision: Precision

    init(cValue: CInstantTimeValue) throws {
        self.value = String(cString: cValue.value)
        self.grain = try Grain(cValue: cValue.grain)
        self.precision = try Precision(cValue: cValue.precision)
    }
}

public struct TimeIntervalValue {
    public let from: String?
    public let to: String?

    init(cValue: CTimeIntervalValue) {
        self.from = String.fromCStringPtr(cString: cValue.from)
        self.to = String.fromCStringPtr(cString: cValue.to)
    }
}

public struct AmountOfMoneyValue {
    public let value: Float
    public let precision: Precision
    public let unit: String?

    init(cValue: CAmountOfMoneyValue) throws {
        self.value = cValue.value
        self.precision = try Precision(cValue: cValue.precision)
        self.unit = String.fromCStringPtr(cString: cValue.unit)
    }
}

public struct TemperatureValue {
    public let value: Float
    public let unit: String?

    init(cValue: CTemperatureValue) {
        self.value = cValue.value
        self.unit = String.fromCStringPtr(cString: cValue.unit)
    }
}

public struct DurationValue {
    public let years: Int
    public let quarters: Int
    public let months: Int
    public let weeks: Int
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int
    public let precision: Precision

    init(cValue: CDurationValue) throws {
        self.years = cValue.years
        self.quarters = cValue.quarters
        self.months = cValue.months
        self.weeks = cValue.weeks
        self.days = cValue.days
        self.hours = cValue.hours
        self.minutes = cValue.minutes
        self.seconds = cValue.seconds
        self.precision = try Precision(cValue: cValue.precision)
    }
}

public enum Grain {
    case year
    case quarter
    case month
    case week
    case day
    case hour
    case minute
    case second

    init(cValue: CGrain) throws {
        switch cValue {
        case YEAR: self = .year
        case QUARTER: self = .quarter
        case MONTH: self = .month
        case WEEK: self = .week
        case DAY: self = .day
        case HOUR: self = .hour
        case MINUTE: self = .minute
        case SECOND: self = .second
        default: throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
    }
}

public enum Precision {
    case approximate
    case exact

    init(cValue: CPrecision) throws {
        switch cValue {
        case APPROXIMATE: self = .approximate
        case EXACT: self = .exact
        default: throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
    }
}

public struct Slot {
    public let rawValue: String
    public let value: SlotValue
    public let range: Range<Int>
    public let entity: String
    public let slotName: String

    init(cSlot: CSlot) throws {
        self.rawValue = String(cString: cSlot.raw_value)
        self.value = try SlotValue(cSlotValue: cSlot.value)
        self.range = Range(uncheckedBounds: (Int(cSlot.range_start), Int(cSlot.range_end)))
        self.entity = String(cString: cSlot.entity)
        self.slotName = String(cString: cSlot.slot_name)
    }
}

public enum SessionInitType {
    case action(text: String?, intentFilter: [String], canBeEnqueued: Bool)
    case notification(text: String?)

    func toUnsafeCMessage(body: (UnsafePointer<CSessionInit>) throws -> ()) rethrows {
        switch self {
        case .action(let text, let intentFilter, let canBeEnqueued):
            var arrayString = CArrayString(array: intentFilter)
            try withUnsafePointer(to: &arrayString) {
                var actionInit = CActionSessionInit(text: text, intent_filter: $0, can_be_enqueued: canBeEnqueued ? 1 : 0)
                try withUnsafePointer(to: &actionInit) {
                    var sessionInit = CSessionInit(init_type: ACTION, value: $0)
                    try withUnsafePointer(to: &sessionInit) {
                        try body($0)
                    }
                }
            }
            arrayString.destroy()

        case .notification(let text):
            var sessionInit = CSessionInit(init_type: NOTIFICATION, value: text)
            try withUnsafePointer(to: &sessionInit) { try body($0) }
        }
    }
}

public struct StartSessionMessage {
    public let initType: SessionInitType
    public let customData: String?
    public let siteId: String?

    public init(initType: SessionInitType, customData: String? = nil, siteId: String? = nil) {
        self.initType = initType
        self.customData = customData
        self.siteId = siteId
    }

    func toUnsafeCMessage(body: (UnsafePointer<CStartSessionMessage>) throws -> ()) rethrows {
        try self.initType.toUnsafeCMessage {
            var cMessage = CStartSessionMessage(
                session_init: $0.pointee,
                custom_data: self.customData,
                site_id: self.siteId)
            try withUnsafePointer(to: &cMessage) { try body($0) }
        }
    }
}

public struct ContinueSessionMessage {
    public let sessionId: String
    public let text: String
    public let intentFilter: [String]

    public init(sessionId: String, text: String, intentFilter: [String] = []) {
        self.sessionId = sessionId
        self.text = text
        self.intentFilter = intentFilter
    }

    func toUnsafeCMessage(body: (UnsafePointer<CContinueSessionMessage>) throws -> ()) rethrows {
        var arrayString = CArrayString(array: intentFilter)
        try withUnsafePointer(to: &arrayString) {
            var cMessage = CContinueSessionMessage(session_id: self.sessionId, text: self.text, intent_filter: UnsafeMutablePointer(mutating: $0))
            try withUnsafePointer(to: &cMessage) { try body($0) }
        }
        arrayString.destroy()
    }
}

public struct EndSessionMessage {
    public let sessionId: String
    public let text: String?

    public init(sessionId: String, text: String? = nil) {
        self.sessionId = sessionId
        self.text = text
    }

    func toUnsafeCMessage(body: (UnsafePointer<CEndSessionMessage>) throws -> ()) rethrows {
        var cMessage = CEndSessionMessage(session_id: self.sessionId, text: self.text)
        try withUnsafePointer(to: &cMessage) { try body($0) }
    }
}
