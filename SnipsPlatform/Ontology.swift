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
/// - percentage: A percentage e.g. 90%
public enum SlotValue {
    case custom(String)
    case number(NumberValue)
    case ordinal(OrdinalValue)
    case instantTime(InstantTimeValue)
    case timeInterval(TimeIntervalValue)
    case amountOfMoney(AmountOfMoneyValue)
    case temperature(TemperatureValue)
    case duration(DurationValue)
    case percentage(PercentageValue)

    init(cSlotValue: CSlotValue) throws {
        switch cSlotValue.value_type {
        case SNIPS_SLOT_VALUE_TYPE_CUSTOM:
            let x = cSlotValue.value.assumingMemoryBound(to: CChar.self)
            self = .custom(String(cString: x))

        case SNIPS_SLOT_VALUE_TYPE_NUMBER:
            let x = cSlotValue.value.assumingMemoryBound(to: CDouble.self)
            self = .number(x.pointee)

        case SNIPS_SLOT_VALUE_TYPE_ORDINAL:
            let x = cSlotValue.value.assumingMemoryBound(to: CInt.self)
            self = .ordinal(OrdinalValue(x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_INSTANTTIME:
            let x = cSlotValue.value.assumingMemoryBound(to: CInstantTimeValue.self)
            self = .instantTime(try InstantTimeValue(cValue: x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_TIMEINTERVAL:
            let x = cSlotValue.value.assumingMemoryBound(to: CTimeIntervalValue.self)
            self = .timeInterval(TimeIntervalValue(cValue: x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_AMOUNTOFMONEY:
            let x = cSlotValue.value.assumingMemoryBound(to: CAmountOfMoneyValue.self)
            self = .amountOfMoney(try AmountOfMoneyValue(cValue: x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_TEMPERATURE:
            let x = cSlotValue.value.assumingMemoryBound(to: CTemperatureValue.self)
            self = .temperature(TemperatureValue(cValue: x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_DURATION:
            let x = cSlotValue.value.assumingMemoryBound(to: CDurationValue.self)
            self = .duration(try DurationValue(cValue: x.pointee))

        case SNIPS_SLOT_VALUE_TYPE_PERCENTAGE:
            let x = cSlotValue.value.assumingMemoryBound(to: CDouble.self)
            self = .percentage(x.pointee)

        default: throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
    }
}

public typealias NumberValue = Double

public typealias OrdinalValue = Int

public typealias PercentageValue = Double

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
        self.years = Int(cValue.years)
        self.quarters = Int(cValue.quarters)
        self.months = Int(cValue.months)
        self.weeks = Int(cValue.weeks)
        self.days = Int(cValue.days)
        self.hours = Int(cValue.hours)
        self.minutes = Int(cValue.minutes)
        self.seconds = Int(cValue.seconds)
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

    init(cValue: SNIPS_GRAIN) throws {
        switch cValue {
        case SNIPS_GRAIN_YEAR: self = .year
        case SNIPS_GRAIN_QUARTER: self = .quarter
        case SNIPS_GRAIN_MONTH: self = .month
        case SNIPS_GRAIN_WEEK: self = .week
        case SNIPS_GRAIN_DAY: self = .day
        case SNIPS_GRAIN_HOUR: self = .hour
        case SNIPS_GRAIN_MINUTE: self = .minute
        case SNIPS_GRAIN_SECOND: self = .second
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

    init(cValue: SNIPS_PRECISION) throws {
        switch cValue {
        case SNIPS_PRECISION_APPROXIMATE: self = .approximate
        case SNIPS_PRECISION_EXACT: self = .exact
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
    case action(text: String?, intentFilter: [String]?, canBeEnqueued: Bool, sendIntentNotRecognized: Bool)
    case notification(text: String)

    func toUnsafeCMessage(body: (UnsafePointer<CSessionInit>) throws -> Void) rethrows {
        switch self {
        case .action(let text, let intentFilter, let canBeEnqueued, let sendIntentNotRecognized):
            var arrayString: CStringArray?
            let unsafeArrayString: UnsafePointer<CStringArray>?
            if let intentFilter = intentFilter {
                arrayString = CStringArray(array: intentFilter)
                unsafeArrayString = withUnsafePointer(to: &arrayString!) { $0 }
            } else {
                arrayString = nil
                unsafeArrayString = nil
            }
            var actionInit = CActionSessionInit(
                text: text?.unsafeMutablePointerRetained(),
                intent_filter: unsafeArrayString,
                can_be_enqueued: canBeEnqueued ? 1 : 0,
                send_intent_not_recognized: sendIntentNotRecognized ? 1 : 0)
            let unsafeActionInit = withUnsafePointer(to: &actionInit) { $0 }
            var sessionInit = CSessionInit(init_type: SNIPS_SESSION_INIT_TYPE_ACTION, value: unsafeActionInit)
            try body(withUnsafePointer(to: &sessionInit) { $0 })
            actionInit.text?.freeUnsafeMemory()
            arrayString?.destroy()
        case .notification(let text):
            var sessionInit = CSessionInit(init_type: SNIPS_SESSION_INIT_TYPE_NOTIFICATION, value: text.unsafeMutablePointerRetained())
            try body(withUnsafePointer(to: &sessionInit) { $0 })
            free(UnsafeMutableRawPointer(mutating: sessionInit.value))
        }
    }
}

/// A message to start a session.
public struct StartSessionMessage {
    /// The type of the session.
    public let initType: SessionInitType
    /// An optional piece of data that will be given back in `IntentMessage`, `IntentNotRecognizedMessage`, `SessionQueuedMessage`, `SessionStartedMessage` and `SessionEndedMessage` that are related to this session
    public let customData: String?
    /// Site where the user started the interaction.
    public let siteId: String?

    public init(initType: SessionInitType, customData: String? = nil, siteId: String? = nil) {
        self.initType = initType
        self.customData = customData
        self.siteId = siteId
    }

    func toUnsafeCMessage(body: (UnsafePointer<CStartSessionMessage>) throws -> Void) rethrows {
        try self.initType.toUnsafeCMessage {
            var cMessage = CStartSessionMessage(
                init: $0.pointee,
                custom_data: customData?.unsafeMutablePointerRetained(),
                site_id: siteId?.unsafeMutablePointerRetained())
            try body(withUnsafePointer(to: &cMessage) { $0 })
            cMessage.custom_data?.freeUnsafeMemory()
            cMessage.site_id?.freeUnsafeMemory()
        }
    }
}

/// Message to send to continue a session.
public struct ContinueSessionMessage {
    /// Session identifier to continue.
    public let sessionId: String
    /// The text the TTS should say to start this additional request of the session.
    public let text: String
    /// A list of intents names to restrict the NLU resolution on the answer of this query. Filter is inclusive.
    /// Passing nil will not filter. Passing an empty array will filter everything. Passing the name of the intent will let only this intent pass.
    public let intentFilter: [String]?
    /// An optional piece of data that will be given back in `IntentMessage` and `IntentNotRecognizedMessage` and `SessionEndedMessage` that are related to this session. If set it will replace any existing custom data previously set on this session
    public let customData: String?
    /// An optional boolean to indicate whether the dialogue manager should handle non recognized intents by itself or sent them as an `IntentNotRecognizedMessage` for the client to handle. This setting applies only to the next conversation turn. The default value is false (and the dialogue manager will handle non recognized intents by itself)
    public let sendIntentNotRecognized: Bool

    public init(sessionId: String, text: String, intentFilter: [String]? = nil, customData: String? = nil, sendIntentNotRecognized: Bool = false) {
        self.sessionId = sessionId
        self.text = text
        self.intentFilter = intentFilter
        self.customData = customData
        self.sendIntentNotRecognized = sendIntentNotRecognized
    }

    func toUnsafeCMessage(body: (UnsafePointer<CContinueSessionMessage>) throws -> Void) rethrows {
        var arrayString: CStringArray?
        let unsafeMutableArrayString: UnsafeMutablePointer<CStringArray>?
        if let intentFilter = intentFilter {
            arrayString = CStringArray(array: intentFilter)
            let unsafeArrayString = withUnsafePointer(to: &arrayString!) { $0 }
            unsafeMutableArrayString = UnsafeMutablePointer(mutating: unsafeArrayString)
        } else {
            arrayString = nil
            unsafeMutableArrayString = nil
        }
        var cMessage = CContinueSessionMessage(session_id: sessionId.unsafeMutablePointerRetained(),
                                               text: text.unsafeMutablePointerRetained(),
                                               intent_filter: unsafeMutableArrayString,
                                               custom_data: customData?.unsafeMutablePointerRetained(),
                                               send_intent_not_recognized: sendIntentNotRecognized ? 1 : 0)
        try body(withUnsafePointer(to: &cMessage) { $0 })
        cMessage.session_id.freeUnsafeMemory()
        cMessage.text.freeUnsafeMemory()
        cMessage.custom_data?.freeUnsafeMemory()
        arrayString?.destroy()
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

    func toUnsafeCMessage(body: (UnsafePointer<CEndSessionMessage>) throws -> Void) rethrows {
        var cMessage = CEndSessionMessage(session_id: sessionId.unsafeMutablePointerRetained(), text: text?.unsafeMutablePointerRetained())
        try body(withUnsafePointer(to: &cMessage) { $0 })
        cMessage.session_id.freeUnsafeMemory()
        cMessage.text?.freeUnsafeMemory()
    }
}

/// Message sent when a session starts.
public struct SessionStartedMessage {
    /// The id of the session that was started.
    public let sessionId: String
    /// The custom data that was given at the session creation.
    public let customData: String?
    /// The site on which this session was started.
    public let siteId: String
    /// This optional field indicates this session is a reactivation of a previously ended session.
    /// This is for example provided when the user continues talking to the platform without saying
    /// the hotword again after a session was ended.
    public let reactivatedFromSessionId: String?

    init(cSessionStartedMessage: CSessionStartedMessage) {
        self.sessionId = String(cString: cSessionStartedMessage.session_id)
        self.customData = String.fromCStringPtr(cString: cSessionStartedMessage.custom_data)
        self.siteId = String(cString: cSessionStartedMessage.site_id)
        self.reactivatedFromSessionId = String.fromCStringPtr(cString: cSessionStartedMessage.reactivated_from_session_id)
    }
}

/// Message sent when a session continues.
public struct SessionQueuedMessage {
    /// The id of the session that was started.
    public let sessionId: String
    /// The custom data that was given at the session creation.
    public let customData: String?
    /// The site on which this session was started.
    public let siteId: String

    init(cSessionsQueuedMessage: CSessionQueuedMessage) {
        self.sessionId = String(cString: cSessionsQueuedMessage.session_id)
        self.customData = String.fromCStringPtr(cString: cSessionsQueuedMessage.custom_data)
        self.siteId = String(cString: cSessionsQueuedMessage.site_id)
    }
}

/// Message sent when a session has ended.
public struct SessionEndedMessage {
    /// The id of the session that was started.
    public let sessionId: String
    /// The custom data that was given at the session creation.
    public let customData: String?
    /// The site on which this session was started.
    public let siteId: String
    /// How the session was ended.
    public let sessionTermination: SessionTermination

    init(cSessionEndedMessage: CSessionEndedMessage) throws {
        self.sessionId = String(cString: cSessionEndedMessage.session_id)
        self.customData = String.fromCStringPtr(cString: cSessionEndedMessage.custom_data)
        self.siteId = String(cString: cSessionEndedMessage.site_id)
        self.sessionTermination = try SessionTermination(cSessionTermination: cSessionEndedMessage.termination)
    }
}

/// Session termination sent when a session has ended containing the type of termination.
public struct SessionTermination {
    /// The type of termination.
    public let terminationType: SessionTerminationType
    /// In case of an error, there can be data provided for more details.
    public let data: String?

    init(cSessionTermination: CSessionTermination) throws {
        self.data = String.fromCStringPtr(cString: cSessionTermination.data)
        self.terminationType = try SessionTerminationType(cValue: cSessionTermination.termination_type)
    }
}

/// Session termination type
///
/// - nominal: The session ended as expected
/// - siteUnavailable: Dialogue was deactivated on the site the session requested
/// - abortedByUser: The user aborted the session
/// - intentNotRecognized: The platform didn't understand what the user said.
/// - timeout: No response was received from one of the components in a timely manner.
/// - error: Generic error occured, there could be associated data with it.
public enum SessionTerminationType {
    case nominal
    case siteUnavailable
    case abortedByUser
    case intentNotRecognized
    case timeout
    case error

    init(cValue: SNIPS_SESSION_TERMINATION_TYPE) throws {
        switch cValue {
        case SNIPS_SESSION_TERMINATION_TYPE_NOMINAL: self = .nominal
        case SNIPS_SESSION_TERMINATION_TYPE_SITE_UNAVAILABLE: self = .siteUnavailable
        case SNIPS_SESSION_TERMINATION_TYPE_ABORTED_BY_USER: self = .abortedByUser
        case SNIPS_SESSION_TERMINATION_TYPE_INTENT_NOT_RECOGNIZED: self = .intentNotRecognized
        case SNIPS_SESSION_TERMINATION_TYPE_TIMEOUT: self = .timeout
        case SNIPS_SESSION_TERMINATION_TYPE_ERROR: self = .error
        default: throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
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
    /// The site id where the message to say comes from.
    public let siteId: String
    /// The id of the session.
    public let sessionId: String?

    public init(cMessage: CSayMessage) {
        self.text = String(cString: cMessage.text)
        self.lang = String.fromCStringPtr(cString: cMessage.lang)
        self.messageId = String.fromCStringPtr(cString: cMessage.id)
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

    func toUnsafeCMessage(body: (UnsafePointer<CSayFinishedMessage>) throws -> Void) rethrows {
        var cMessage = CSayFinishedMessage(id: messageId?.unsafeMutablePointerRetained(), session_id: sessionId?.unsafeMutablePointerRetained())
        try body(withUnsafePointer(to: &cMessage) { $0 })
        cMessage.id?.freeUnsafeMemory()
        cMessage.session_id?.freeUnsafeMemory()
    }
}

/// The kind of ASR injection
///
/// - add: Add new entities
public enum SnipsInjectionKind {
    case add

    init(cValue: SNIPS_INJECTION_KIND) throws {
        switch cValue {
        case SNIPS_INJECTION_KIND_ADD: self = .add
        default: throw SnipsPlatformError(message: "Internal error: SnipsInjectionKind")
        }
    }

    func toCSnipsInjectionKind() -> SNIPS_INJECTION_KIND {
        switch self {
        case .add: return SNIPS_INJECTION_KIND_ADD
        }
    }
}

/// The injection request operation
///
/// - entities: String dictionary containing the new entities. The key of the dictionary must correspond with the slots in your app or else the injection will fail. For instance, the Snips' weather app has a locality slot. Usage:
///     ```
///     var newEntities: [String: [String]] = [:]
///     newEntites["locality"] = ["wonderland"]
///     let injectionRequestOperation = InjectionRequestOperation(entities: newEntities, kind: .add)
///     ```
///
/// - kind: Injection kind case
public struct InjectionRequestOperation {
    public let entities: [String: [String]]
    public let kind: SnipsInjectionKind

    public init(entities: [String: [String]], kind: SnipsInjectionKind) {
        self.entities = entities
        self.kind = kind
    }
}

/// Injection request message
///
/// - operations: Array of `InjectionRequestOperation`.
/// - lexicon: String dictionary containing the pronunciation of each new entity. It will replace the g2p resources provided by Snips. This lexicon is generated by Snips.
public struct InjectionRequestMessage {
    public let operations: [InjectionRequestOperation]
    public let lexicon: [String: [String]]

    public init(operations: [InjectionRequestOperation], lexicon: [String: [String]] = [:]) {
        self.operations = operations
        self.lexicon = lexicon
    }

    func toUnsafeCInjectionRequestMessage(body: (UnsafePointer<CInjectionRequestMessage>) throws -> Void) throws {
        var cMapLexicon = try CMapStringToStringArray(array: lexicon)
        let cUnsafeLexicon = withUnsafePointer(to: &cMapLexicon) { $0 }
        var cOperations = try CInjectionRequestOperations(operations: operations)
        let cUnsafeOperations = withUnsafePointer(to: &cOperations) { $0 }
        var cInjectionRequestMessage = CInjectionRequestMessage(operations: cUnsafeOperations, lexicon: cUnsafeLexicon)
        try body(withUnsafePointer(to: &cInjectionRequestMessage) { $0 })
        cMapLexicon.destroy()
        cUnsafeOperations.pointee.destroy()
    }
}
