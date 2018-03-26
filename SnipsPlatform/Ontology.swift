//
//  Ontology.swift
//  SnipsPlatform
//
//  Copyright © 2017 Snips. All rights reserved.
//

import Foundation
import Clibsnips_megazord

/// A detected intent.
public struct IntentMessage {
    /// ID of the session.
    public let sessionId: String
    /// Custom data provided by the developer at the beginning of the session.
    public var customData: String?
    /// Site ID where the intent was detected.
    public var siteId: String
    /// The user input.
    public var input: String
    /// The intent classification result. If `nil`, the `input` wasn't recognized.
    public var intent: IntentClassifierResult?
    /// Lists of parsed slots.
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

/// An intent description.
public struct IntentClassifierResult {
    /// The name of the intent.
    public let intentName: String
    /// The probability between 0.0 and 1.0 of the intent.
    public let probability: Float

    init(cResult: CIntentClassifierResult) {
        self.intentName = String(cString: cResult.intent_name)
        self.probability = cResult.probability
    }
}

/// A slot value.
///
/// - custom: An entity defined on the console (not builtin entities).
/// - number: A value number e.g. "9", "42.1".
/// - ordinal: An ordinal number e.g. "first".
/// - instantTime: A date e.g. "tomorrow".
/// - timeInterval: A date range e.g. "between 1pm and 2pm".
/// - amountOfMoney: An amount of money e.g. "$400.68", "10€".
/// - temperature: A temperature e.g. "30°C", "86°F".
/// - duration: A duration e.g. "2 hours", "5 minutes".
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

/// A date.
public struct InstantTimeValue {
    /// The date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    public let value: String
    /// Granularity of the date e.g. for "tomorrow" the granularity would be `Grain.day`.
    public let grain: Grain
    /// Precision of the date.
    public let precision: Precision

    init(cValue: CInstantTimeValue) throws {
        self.value = String(cString: cValue.value)
        self.grain = try Grain(cValue: cValue.grain)
        self.precision = try Precision(cValue: cValue.precision)
    }
}

/// A date range.
public struct TimeIntervalValue {
    /// Start date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    public let from: String?
    /// End date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    public let to: String?

    init(cValue: CTimeIntervalValue) {
        self.from = String.fromCStringPtr(cString: cValue.from)
        self.to = String.fromCStringPtr(cString: cValue.to)
    }
}

/// A quantity of money.
public struct AmountOfMoneyValue {
    /// The amount.
    public let value: Float
    /// The precision of this amount.
    public let precision: Precision
    /// Currency of this amount e.g. "EUR", "USD", "$".
    public let unit: String?

    init(cValue: CAmountOfMoneyValue) throws {
        self.value = cValue.value
        self.precision = try Precision(cValue: cValue.precision)
        self.unit = String.fromCStringPtr(cString: cValue.unit)
    }
}

/// A temperature.
public struct TemperatureValue {
    /// The value of the temperature.
    public let value: Float
    /// The unit of this temperature e.g. "degree", "celcius", "fahrenheit".
    public let unit: String?

    init(cValue: CTemperatureValue) {
        self.value = cValue.value
        self.unit = String.fromCStringPtr(cString: cValue.unit)
    }
}

/// A duration.
public struct DurationValue {
    /// Numbers of years.
    public let years: Int
    /// Numbers of quarters.
    public let quarters: Int
    /// Numbers of months.
    public let months: Int
    /// Numbers of weeks.
    public let weeks: Int
    /// Numbers of days.
    public let days: Int
    /// Numbers of hours.
    public let hours: Int
    /// Numbers of minutes.
    public let minutes: Int
    /// Numbers of seconds.
    public let seconds: Int
    /// Precision of the duration.
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

/// Represent the granularity of a date.
///
/// - year: When a date represent a year e.g. "in 2 years".
/// - quarter: When a date represent a quarter e.g. "Q3".
/// - month: When a date represent a month e.g. "in 4 months".
/// - week: When a date represent a week e.g. "the next week".
/// - day: When a date represent a day e.g. "tomorrow".
/// - hour: When a date represent an hour e.g. "1pm".
/// - minute: When a date represent a minute e.g. "1h30".
/// - second: When a date represent seconds e.g. "1:40:02".
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

/// Precision of a slot.
///
/// - approximate: When a user explicitly gave an approximation quantifier with the slot.
/// - exact: Default case when no information about the precision of the slot is available.
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

/// A slot.
public struct Slot {
    /// The matching string.
    public let rawValue: String
    /// The structured representation of the slot.
    public let value: SlotValue
    /// The range of the matching string in the given sentence.
    public let range: Range<Int>
    /// The entity name.
    public let entity: String
    /// The name of the slot.
    public let slotName: String

    init(cSlot: CSlot) throws {
        self.rawValue = String(cString: cSlot.raw_value)
        self.value = try SlotValue(cSlotValue: cSlot.value)
        self.range = Range(uncheckedBounds: (Int(cSlot.range_start), Int(cSlot.range_end)))
        self.entity = String(cString: cSlot.entity)
        self.slotName = String(cString: cSlot.slot_name)
    }
}

/// A session type of a session
///
/// - action: When an intent is expected to be parsed.
/// - notification: Notify the user about something via the tts.
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

/// A message to start a session.
public struct StartSessionMessage {
    /// The type of the session.
    public let initType: SessionInitType
    /// Additional information that can be provided by the handler. Each message related to the new session - sent by the Dialogue Manager - will contain this data
    public let customData: String?
    /// Site where the user started the interaction.
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

/// Message to send to continue a session.
public struct ContinueSessionMessage {
    /// Session identifier to continue.
    public let sessionId: String
    /// The text the TTS should say to start this additional request of the session.
    public let text: String
    /// A list of intents names to restrict the NLU resolution on the answer of this query.
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

/// Message to send to end a session.
public struct EndSessionMessage {
    /// Session identifier to end.
    public let sessionId: String
    /// The text the TTS should say to end the session.
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

/// A message to say to the user.
public struct SayMessage {
    /// The text to say.
    public let text: String
    /// The lang of the message to say.
    public let lang: String?
    /// A unique id of the message to say.
    public let messageId: String?
    /// The site id where come from the message to say.
    public let siteId: String
    /// The id of the session.
    public let sessionId: String?

    public init(cMessage: CSayMessage) {
        self.text = String(cString: cMessage.text)
        self.lang = String.fromCStringPtr(cString: cMessage.lang)
        self.messageId = String.fromCStringPtr(cString: cMessage.message_id)
        self.siteId = String(cString: cMessage.site_id)
        self.sessionId = String.fromCStringPtr(cString: cMessage.session_id)
    }
}

/// A message to send to the platform when a message was said
/// (typically when a text-to-speech finished to say its message)
public struct SayFinishedMessage {
    /// The unique id of message that what was said.
    public let messageId: String?
    /// The id of the session.
    public let sessionId: String?

    public init(messageId: String?, sessionId: String?) {
        self.messageId = messageId
        self.sessionId = sessionId
    }

    func toUnsafeCMessage(body: (UnsafePointer<CSayFinishedMessage>) throws -> ()) rethrows {
        var cMessage = CSayFinishedMessage(message_id: self.messageId, session_id: self.sessionId)
        try withUnsafePointer(to: &cMessage) { try body($0) }
    }
}
