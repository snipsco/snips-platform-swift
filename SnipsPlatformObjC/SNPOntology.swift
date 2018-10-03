//
//  SNPOntology.swift
//  SnipsPlatform
//
//  Copyright © 2018 Snips. All rights reserved.
//

import Foundation

/// A detected intent.
@objc public class SNPIntent: NSObject {
    /// ID of the session.
    @objc public let sessionId: String
    /// Custom data provided by the developer at the beginning of the session.
    @objc public var customData: String?
    /// Site ID where the intent was detected.
    @objc public var siteId: String
    /// The user input.
    @objc public var input: String
    /// The intent classification result. If `nil`, the `input` wasn't recognized.
    @objc public var intent: SNPIntentClassifierResult?
    /// Lists of parsed slots.
    @objc public var slots: [SNPSlot]
    
    init(_ intentMessage: IntentMessage) {
        sessionId = intentMessage.sessionId
        customData = intentMessage.customData
        siteId = intentMessage.siteId
        input = intentMessage.input
        intent = SNPIntentClassifierResult(intentMessage.intent)
        slots = intentMessage.slots.map { SNPSlot($0) }
    }
}

/// An intent description.
@objc public class SNPIntentClassifierResult: NSObject {
    /// The name of the intent.
    @objc public let intentName: String
    /// The probability between 0.0 and 1.0 of the intent.
    @objc public let probability: Float
    
    init?(_ intentClassifierResult: IntentClassifierResult?) {
        guard let intentClassifierResult = intentClassifierResult else { return nil }
        intentName = intentClassifierResult.intentName
        probability = intentClassifierResult.probability
    }
}

@objc public class SNPSlot: NSObject {
    @objc public let rawValue: String
    /// The value of the slot.
    @objc public let value: SNPSlotValue
    /// The range of the matching string in the given sentence.
    @objc public let range: [Int]
    /// The entity name.
    @objc public let entity: String
    /// The name of the slot.
    @objc public let slotName: String
    
    init(_ slot: Slot) {
        rawValue = slot.rawValue
        value = SNPSlotValue(slot.value)
        range = Array(slot.range.lowerBound...slot.range.upperBound)
        entity = slot.entity
        slotName = slot.slotName
    }
}

@objc public class SNPSlotValue: NSObject {
    @objc public let slotCase: SNPSlotCase
    @objc public let slotValue: Any
    
    init(_ slotValue: SlotValue) {
        switch slotValue {
        case .custom(let string):
            slotCase = .custom
            self.slotValue = string
        case .number( let numberValue):
            slotCase = .number
            self.slotValue = numberValue
        case .ordinal(let ordinalValue):
            slotCase = .ordinal
            self.slotValue = ordinalValue
        case .instantTime(let instantTimeValue):
            slotCase = .instantTime
            self.slotValue = SNPInstantTimeValue(instantTimeValue)
        case .timeInterval(let timeIntervalValue):
            slotCase = .timeInterval
            self.slotValue = SNPTimeIntervalValue(timeIntervalValue)
        case .amountOfMoney(let amountOfMoneyValue):
            slotCase = .amountOfMoney
            self.slotValue = SNPAmountOfMoneyValue(amountOfMoneyValue)
        case .temperature(let temperatureValue):
            slotCase = .temperature
            self.slotValue = SNPTemperatureValue(temperatureValue)
        case .duration(let durationValue):
            slotCase = .duration
            self.slotValue = SNPDurationValue(durationValue)
        case .percentage(let double):
            slotCase = .percentage
            self.slotValue = double
        }
    }
}

@objc public enum SNPSlotCase: Int {
    case custom
    case number
    case ordinal
    case instantTime
    case timeInterval
    case amountOfMoney
    case temperature
    case duration
    case percentage
}

/// A date
@objc final class SNPInstantTimeValue: NSObject {
    /// The date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    @objc public let value: String
    /// Granularity of the date e.g. for "tomorrow" the granularity would be `Grain.day`.
    @objc public let grain: SNPGrain
    /// Precision of the date.
    @objc public let precision: SNPPrecision
    
    init(_ instantTimeValue: InstantTimeValue) {
        value = instantTimeValue.value
        grain = SNPGrain(instantTimeValue.grain)
        precision = SNPPrecision(instantTimeValue.precision)
    }
}

/// A date range.
@objc public class SNPTimeIntervalValue: NSObject {
    /// Start date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    @objc public let from: String?
    /// End date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    @objc public let to: String?
    
    init(_ timeIntervalValue: TimeIntervalValue) {
        from = timeIntervalValue.from
        to = timeIntervalValue.to
    }
}

/// A quantity of money.
@objc public class SNPAmountOfMoneyValue: NSObject {
    /// The amount.
    @objc public let value: Float
    /// The precision of this amount.
    @objc public let precision: SNPPrecision
    /// Currency of this amount e.g. "EUR", "USD", "$".
    @objc public let unit: String?
    
    init(_ amountOfMoneyValue: AmountOfMoneyValue) {
        value = amountOfMoneyValue.value
        precision = SNPPrecision(amountOfMoneyValue.precision)
        unit = amountOfMoneyValue.unit
    }
}

/// A temperature.
@objc public class SNPTemperatureValue: NSObject {
    /// The value of the temperature.
    @objc public let value: Float
    /// The unit of this temperature e.g. "degree", "celcius", "fahrenheit".
    @objc public let unit: String?
    
    init(_ temperatureValue: TemperatureValue) {
        self.value = temperatureValue.value
        self.unit = temperatureValue.unit
    }
}

/// A duration.
@objc public class SNPDurationValue: NSObject {
    /// Numbers of years.
    @objc public let years: Int
    /// Numbers of quarters.
    @objc public let quarters: Int
    /// Numbers of months.
    @objc public let months: Int
    /// Numbers of weeks.
    @objc public let weeks: Int
    /// Numbers of days.
    @objc public let days: Int
    /// Numbers of hours.
    @objc public let hours: Int
    /// Numbers of minutes.
    @objc public let minutes: Int
    /// Numbers of seconds.
    @objc public let seconds: Int
    /// Precision of the duration.
    @objc public let precision: SNPPrecision
    
    init(_ durationValue: DurationValue) {
        years = durationValue.years
        quarters = durationValue.quarters
        months = durationValue.months
        weeks = durationValue.weeks
        days = durationValue.days
        hours = durationValue.hours
        minutes = durationValue.minutes
        seconds = durationValue.seconds
        precision = SNPPrecision(durationValue.precision)
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
@objc public enum SNPGrain: Int {
    case year
    case quarter
    case month
    case week
    case day
    case hour
    case minute
    case second
    
    init(_ grain: Grain) {
        switch grain {
        case .year: self = .year
        case .quarter: self = .quarter
        case .month: self = .month
        case .week: self = .week
        case .day: self = .day
        case .hour: self = .hour
        case .minute: self = .minute
        case .second: self = .second
        }
    }
}

/// Precision of a slot.
///
/// - approximate: When a user explicitly gave an approximation quantifier with the slot.
/// - exact: Default case when no information about the precision of the slot is available.
@objc public enum SNPPrecision: Int {
    case approximate
    case exact
    
    init(_ precision: Precision) {
        switch precision {
        case .approximate: self = .approximate
        case .exact: self = .exact
        }
    }
}

@objc public enum SNPSessionInitTypeCase: Int {
    case action
    case notification
}

@objc public class SNPSessionInitTypeAction: NSObject {
    @objc public let text: String?
    @objc public let intentFilter: [String]?
    @objc public let canBeEnqueued: Bool
    @objc public let sendIntentNotRecognized: Bool
    
    init(text: String?, intentFilter: [String]?, canBeEnqueued: Bool, sendIntentNotRecognized: Bool) {
        self.text = text
        self.intentFilter = intentFilter
        self.canBeEnqueued = canBeEnqueued
        self.sendIntentNotRecognized = sendIntentNotRecognized
    }
}

/// A session type of a session
///
/// - action: When an intent is expected to be parsed.
/// - notification: Notify the user about something via the tts.
@objc public class SNPSessionInitType: NSObject {
    @objc public let slotCase: SNPSessionInitTypeCase
    @objc public let slotValue: Any
    
    init(_ sessionInitType: SessionInitType) {
        switch sessionInitType {
        case .action(let text, let intentFilter, let canBeEnqueued, let sendIntentNotRecognized):
            self.slotCase = .action
            self.slotValue = SNPSessionInitTypeAction(text: text, intentFilter: intentFilter, canBeEnqueued: canBeEnqueued, sendIntentNotRecognized: sendIntentNotRecognized)
        case .notification(let text):
            self.slotCase = .notification
            self.slotValue = text
        }
    }
}

/// A message to start a session.
@objc public class SNPStartSessionMessage: NSObject {
    /// The type of the session.
    @objc public let initType: SNPSessionInitType
    /// An optional piece of data that will be given back in `IntentMessage`, `IntentNotRecognizedMessage`, `SessionQueuedMessage`, `SessionStartedMessage` and `SessionEndedMessage` that are related to this session
    @objc public let customData: String?
    /// Site where the user started the interaction.
    @objc public let siteId: String?
    
    @objc public init(initType: SNPSessionInitType, customData: String? = nil, siteId: String? = nil) {
        self.initType = initType
        self.customData = customData
        self.siteId = siteId
    }
}

/// Message to send to continue a session.
@objc public class SNPContinueSessionMessage: NSObject {
    /// Session identifier to continue.
    @objc public let sessionId: String
    /// The text the TTS should say to start this additional request of the session.
    @objc public let text: String
    /// A list of intents names to restrict the NLU resolution on the answer of this query. Filter is inclusive.
    /// Passing nil will not filter. Passing an empty array will filter everything. Passing the name of the intent will let only this intent pass.
    @objc public let intentFilter: [String]?
    /// An optional piece of data that will be given back in `IntentMessage` and `IntentNotRecognizedMessage` and `SessionEndedMessage` that are related to this session. If set it will replace any existing custom data previously set on this session
    @objc public let customData: String?
    /// An optional boolean to indicate whether the dialogue manager should handle non recognized intents by itself or sent them as an `IntentNotRecognizedMessage` for the client to handle. This setting applies only to the next conversation turn. The default value is false (and the dialogue manager will handle non recognized intents by itself)
    @objc public let sendIntentNotRecognized: Bool
    
    @objc public init(sessionId: String, text: String, intentFilter: [String]? = nil, customData: String? = nil, sendIntentNotRecognized: Bool = false) {
        self.sessionId = sessionId
        self.text = text
        self.intentFilter = intentFilter
        self.customData = customData
        self.sendIntentNotRecognized = sendIntentNotRecognized
    }
}

/// Message to send to end a session.
@objc public class SNPEndSessionMessage: NSObject {
    /// Session identifier to end.
    @objc public let sessionId: String
    /// The text the TTS should say to end the session.
    @objc public let text: String?
    
    @objc public init(sessionId: String, text: String? = nil) {
        self.sessionId = sessionId
        self.text = text
    }
}

/// Message sent when a session starts.
@objc public class SNPSessionStartedMessage: NSObject {
    /// The id of the session that was started.
    @objc public let sessionId: String
    /// The custom data that was given at the session creation.
    @objc public let customData: String?
    /// The site on which this session was started.
    @objc public let siteId: String
    /// This optional field indicates this session is a reactivation of a previously ended session.
    /// This is for example provided when the user continues talking to the platform without saying
    /// the hotword again after a session was ended.
    @objc public let reactivatedFromSessionId: String?
    
    init(_ sessionStartedMessage: SessionStartedMessage) {
        self.sessionId = sessionStartedMessage.sessionId
        self.customData = sessionStartedMessage.customData
        self.siteId = sessionStartedMessage.siteId
        self.reactivatedFromSessionId = sessionStartedMessage.reactivatedFromSessionId
    }
}

/// Message sent when a session continues.
@objc public class SNPSessionQueuedMessage: NSObject {
    /// The id of the session that was started.
    @objc public let sessionId: String
    /// The custom data that was given at the session creation.
    @objc public let customData: String?
    /// The site on which this session was started.
    @objc public let siteId: String
    
    init(_ sessionsQueuedMessage: SessionQueuedMessage) {
        self.sessionId = sessionsQueuedMessage.sessionId
        self.customData = sessionsQueuedMessage.customData
        self.siteId = sessionsQueuedMessage.siteId
    }
}

/// Message sent when a session has ended.
@objc public class SNPSessionEndedMessage: NSObject {
    /// The id of the session that was started.
    @objc public let sessionId: String
    /// The custom data that was given at the session creation.
    @objc public let customData: String?
    /// The site on which this session was started.
    @objc public let siteId: String
    /// How the session was ended.
    @objc public let sessionTermination: SNPSessionTermination
    
    init(_ sessionEndedMessage: SessionEndedMessage) {
        self.sessionId = sessionEndedMessage.sessionId
        self.customData = sessionEndedMessage.customData
        self.siteId = sessionEndedMessage.siteId
        self.sessionTermination = SNPSessionTermination(sessionEndedMessage.sessionTermination)
    }
}

/// Session termination sent when a session has ended containing the type of termination.
@objc public class SNPSessionTermination: NSObject {
    /// The type of termination.
    @objc public let terminationType: SNPSessionTerminationType
    /// In case of an error, there can be data provided for more details.
    @objc public let data: String?
    
    init(_ sessionTermination: SessionTermination) {
        self.data = sessionTermination.data
        self.terminationType = SNPSessionTerminationType(sessionTermination.terminationType)
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
@objc public enum SNPSessionTerminationType: Int {
    case nominal
    case siteUnavailable
    case abortedByUser
    case intentNotRecognized
    case timeout
    case error
    
    init(_ sessionTerminationType: SessionTerminationType) {
        switch sessionTerminationType {
        case .nominal: self = .nominal
        case .siteUnavailable: self = .siteUnavailable
        case .abortedByUser: self = .abortedByUser
        case .intentNotRecognized: self = .intentNotRecognized
        case .timeout: self = .timeout
        case .error: self = .error
        }
    }
}

/// A message to say to the user.
@objc public class SNPSayMessage: NSObject {
    /// The text to say.
    @objc public let text: String
    /// The lang of the message to say.
    @objc public let lang: String?
    /// A unique id of the message to say.
    @objc public let messageId: String?
    /// The site id where the message to say comes from.
    @objc public let siteId: String
    /// The id of the session.
    @objc public let sessionId: String?
    
    init(_ message: SayMessage) {
        self.text = message.text
        self.lang = message.lang
        self.messageId = message.messageId
        self.siteId = message.siteId
        self.sessionId = message.sessionId
    }
    
    @objc public init(text: String, lang: String?, messageId: String?, siteId: String, sessionId: String?) {
        self.text = text
        self.lang = lang
        self.messageId = messageId
        self.siteId = siteId
        self.sessionId = sessionId
    }
}

/// A message to send to the platform when a message was said
/// (typically when a text-to-speech finished to say its message)
@objc public class SNPSayFinishedMessage: NSObject {
    /// The unique id of message that what was said.
    @objc public let messageId: String?
    /// The id of the session.
    @objc public let sessionId: String?
    
    init(_ message: SayFinishedMessage) {
        messageId = message.messageId
        sessionId = message.sessionId
    }
    
    @objc public init(messageId: String?, sessionId: String?) {
        self.messageId = messageId
        self.sessionId = sessionId
    }
}

/// The kind of ASR injection
///
/// - add: Add new entities on top of the latest injected assistant.
/// - addFromVanilla: Add new entities on top of the vanilla assistant (the assistant without any injection).
@objc public enum SNPSnipsInjectionKind: Int {
    case add
    case addFromVanilla
    
    init(_ snipsInjectionKind: SnipsInjectionKind) {
        switch snipsInjectionKind {
        case .add: self = .add
        case .addFromVanilla: self = .addFromVanilla
        }
    }
    
    var snipsInjectionKind: SnipsInjectionKind {
        switch self {
        case .add: return .add
        case .addFromVanilla: return .addFromVanilla
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
@objc public class SNPInjectionRequestOperation: NSObject {
    @objc public let entities: [String: [String]]
    @objc public let kind: SNPSnipsInjectionKind
    
    @objc public init(entities: [String: [String]], kind: SNPSnipsInjectionKind) {
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
@objc public class SNPInjectionRequestMessage: NSObject {
    @objc public let operations: [SNPInjectionRequestOperation]
    @objc public let lexicon: [String: [String]]
    @objc public let crossLanguage: String?
    @objc public let requestId: String?
    
    @objc public init(operations: [SNPInjectionRequestOperation], lexicon: [String: [String]] = [:], crossLanguage: String? = nil, requestId: String? = nil) {
        self.operations = operations
        self.lexicon = lexicon
        self.crossLanguage = crossLanguage
        self.requestId = requestId
    }
}

/// ASR model parameters
@objc public class SNPAsrModelParameters: NSObject {
    @objc public var beamSize: Float
    @objc public var latticeBeamSize: Float
    @objc public var acousticScale: Float
    @objc public var maxActive: UInt
    @objc public var minActive: UInt
    @objc public var endpointing: String
    @objc public var useFinalProbs: Bool
    
    @objc public init(beamSize: Float, latticeBeamSize: Float, acousticScale: Float, maxActive: UInt, minActive: UInt, endpointing: String, useFinalProbs: Bool) {
        self.beamSize = beamSize
        self.latticeBeamSize = latticeBeamSize
        self.acousticScale = acousticScale
        self.maxActive = maxActive
        self.minActive = minActive
        self.endpointing = endpointing
        self.useFinalProbs = useFinalProbs
    }
    
    var asrModelParameters: AsrModelParameters {
        return AsrModelParameters(beamSize: beamSize, latticeBeamSize: latticeBeamSize, acousticScale: acousticScale, maxActive: maxActive, minActive: minActive, endpointing: endpointing, useFinalProbs: useFinalProbs)
    }
}
