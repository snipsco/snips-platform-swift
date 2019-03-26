//
//  Ontology.swift
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
    /// The intent classification result.
    public var intent: IntentClassifierResult
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
            throw SnipsPlatformError(message: "Internal error: Bad type conversion")
        }
        if let cSlotList = cResult.slots?.pointee {
            self.slots = try UnsafeBufferPointer(start: cSlotList.entries, count: Int(cSlotList.count))
                .map({ try Slot(cSlot: $0!.pointee) })
        } else {
            self.slots = []
        }
    }
}

public struct IntentNotRecognizedMessage {
    /// Site ID where the intent was detected.
    public var siteId: String
    /// ID of the session.
    public let sessionId: String
    /// The user input.
    public var input: String?
    /// Custom data provided by the developer at the beginning of the session.
    public var customData: String?

    init(cResult: CIntentNotRecognizedMessage) {
        self.siteId = String(cString: cResult.site_id)
        self.sessionId = String(cString: cResult.session_id)
        self.input = String.fromCStringPtr(cString: cResult.input)
        self.customData = String.fromCStringPtr(cString: cResult.custom_data)
    }
}

/// An intent description.
public struct IntentClassifierResult {
    /// The name of the intent.
    public let intentName: String
    /// The probability between 0.0 and 1.0 of the intent.
    public let confidenceScore: Float

    init(cResult: CNluIntentClassifierResult) {
        self.intentName = String(cString: cResult.intent_name)
        self.confidenceScore = cResult.confidence_score
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
    case musicAlbum(String)
    case musicArtist(String)
    case musicTrack(String)

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

        case SNIPS_SLOT_VALUE_TYPE_MUSICALBUM:
            let x = cSlotValue.value.assumingMemoryBound(to: CChar.self)
            self = .musicAlbum(String(cString: x))

        case SNIPS_SLOT_VALUE_TYPE_MUSICARTIST:
            let x = cSlotValue.value.assumingMemoryBound(to: CChar.self)
            self = .musicArtist(String(cString: x))

        case SNIPS_SLOT_VALUE_TYPE_MUSICTRACK:
            let x = cSlotValue.value.assumingMemoryBound(to: CChar.self)
            self = .musicTrack(String(cString: x))

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
    /// The confidence of the slot.
    public let confidenceScore: Float?

    init(cSlot: CNluSlot) throws {
        self.rawValue = String(cString: cSlot.nlu_slot.pointee.raw_value)
        self.value = try SlotValue(cSlotValue: cSlot.nlu_slot.pointee.value)
        self.range = Range(uncheckedBounds: (Int(cSlot.nlu_slot.pointee.range_start), Int(cSlot.nlu_slot.pointee.range_end)))
        self.entity = String(cString: cSlot.nlu_slot.pointee.entity)
        self.slotName = String(cString: cSlot.nlu_slot.pointee.slot_name)
        self.confidenceScore = (cSlot.nlu_slot.pointee.confidence_score < 0) ? cSlot.nlu_slot.pointee.confidence_score : nil
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
    /// An optional string, requires `intent_filter` to contain a single value. If set, the dialogue engine will not run the the intent classification on the user response and go straight to slot filling, assuming the intent is the one passed in the `intent_filter`, and searching the value of the given slot
    public let slot: String?
    /// An optional boolean to indicate whether the dialogue manager should handle non recognized intents by itself or sent them as an `IntentNotRecognizedMessage` for the client to handle. This setting applies only to the next conversation turn. The default value is false (and the dialogue manager will handle non recognized intents by itself)
    public let sendIntentNotRecognized: Bool

    public init(sessionId: String, text: String, intentFilter: [String]? = nil, customData: String? = nil, slot: String? = nil, sendIntentNotRecognized: Bool = false) {
        self.sessionId = sessionId
        self.text = text
        self.intentFilter = intentFilter
        self.customData = customData
        self.slot = slot
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
                                               slot: slot?.unsafeMutablePointerRetained(),
                                               send_intent_not_recognized: sendIntentNotRecognized ? 1 : 0)
        try body(withUnsafePointer(to: &cMessage) { $0 })
        cMessage.session_id.freeUnsafeMemory()
        cMessage.text.freeUnsafeMemory()
        cMessage.custom_data?.freeUnsafeMemory()
        cMessage.slot?.freeUnsafeMemory()
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

    init(cMessage: CSayMessage) {
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
/// - add: Add new entities on top of the latest injected assistant.
/// - addFromVanilla: Add new entities on top of the vanilla assistant (the assistant without any injection).
public enum InjectionKind {
    case add
    case addFromVanilla

    init(cValue: SNIPS_INJECTION_KIND) throws {
        switch cValue {
        case SNIPS_INJECTION_KIND_ADD: self = .add
        case SNIPS_INJECTION_KIND_ADD_FROM_VANILLA: self = .addFromVanilla
        default: throw SnipsPlatformError(message: "Internal error: SnipsInjectionKind")
        }
    }

    func toCInjectionKind() -> SNIPS_INJECTION_KIND {
        switch self {
        case .add: return SNIPS_INJECTION_KIND_ADD
        case .addFromVanilla: return SNIPS_INJECTION_KIND_ADD_FROM_VANILLA
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
    public let kind: InjectionKind

    public init(entities: [String: [String]], kind: InjectionKind) {
        self.entities = entities
        self.kind = kind
    }
}

/// Injection request message
///
/// - operations: Array of `InjectionRequestOperation`.
/// - lexicon: String dictionary containing the pronunciation of each new entity. It will replace the g2p resources provided by Snips. This lexicon is generated by Snips.
/// - crossLanguage: If set, this will be generate pronunciations into the given language in addition of the assistant language e.g. french words into the english phonology.
/// - requestId: The id of the injection request.
public struct InjectionRequestMessage {
    public let operations: [InjectionRequestOperation]
    public let lexicon: [String: [String]]
    public let crossLanguage: String?
    public let requestId: String?

    public init(operations: [InjectionRequestOperation], lexicon: [String: [String]] = [:], crossLanguage: String? = nil, requestId: String? = nil) {
        self.operations = operations
        self.lexicon = lexicon
        self.crossLanguage = crossLanguage
        self.requestId = requestId
    }

    func toUnsafeCInjectionRequestMessage(body: (UnsafePointer<CInjectionRequestMessage>) throws -> Void) throws {
        var cMapLexicon = try CMapStringToStringArray(dict: lexicon)
        let cUnsafeLexicon = withUnsafePointer(to: &cMapLexicon) { $0 }
        var cOperations = try CInjectionRequestOperations(operations: operations)
        let cUnsafeOperations = withUnsafePointer(to: &cOperations) { $0 }
        
        var cMessage = CInjectionRequestMessage(
            operations: cUnsafeOperations,
            lexicon: cUnsafeLexicon,
            cross_language: crossLanguage?.unsafeMutablePointerRetained(),
            id: requestId?.unsafeMutablePointerRetained()
        )
        
        try body(withUnsafePointer(to: &cMessage) { $0 })
        cUnsafeLexicon.pointee.destroy()
        cUnsafeOperations.pointee.destroy()
        cMessage.cross_language?.freeUnsafeMemory()
        cMessage.id?.freeUnsafeMemory()
    }
}

/// ASR model parameters
public struct AsrModelParameters {
    public let beamSize: Float?
    public let latticeBeamSize: Float?
    public let acousticScale: Float?
    public let maxActive: UInt?
    public let minActive: UInt?
    public let endpointing: String?
    public let useFinalProbs: Bool?

    init(cParameters: CModelParameters) throws {
        self.beamSize = cParameters.beam_size >= 0 ? cParameters.beam_size : nil
        self.latticeBeamSize = cParameters.lattice_beam_size >= 0 ? cParameters.lattice_beam_size : nil
        self.acousticScale = cParameters.acoustic_scale >= 0 ? cParameters.acoustic_scale : nil
        self.maxActive = cParameters.max_active >= 0 ? UInt(cParameters.max_active) : nil
        self.minActive = cParameters.min_active >= 0 ? UInt(cParameters.min_active) : nil
        self.endpointing = String.fromCStringPtr(cString: cParameters.endpointing)
        self.useFinalProbs = cParameters.use_final_probs < UINT8_MAX ? (cParameters.use_final_probs != 0) : nil
    }
    
    func toUnsafeCModelParameters(body: (UnsafePointer<CModelParameters>) throws -> Void) throws {
        var cParameters = CModelParameters(
            beam_size: beamSize ?? -1.0,
            lattice_beam_size: latticeBeamSize ?? -1.0,
            acoustic_scale: acousticScale ?? -1.0,
            max_active: maxActive.map(Int32.init) ?? -1,
            min_active: minActive.map(Int32.init) ?? -1,
            endpointing: endpointing?.unsafeMutablePointerRetained(),
            use_final_probs: useFinalProbs.map({ $0 ? 1 : 0 }) ?? UInt8(UINT8_MAX)
        )
        
        try body(withUnsafePointer(to: &cParameters) { $0 })
        cParameters.endpointing?.freeUnsafeMemory()
    }
}
