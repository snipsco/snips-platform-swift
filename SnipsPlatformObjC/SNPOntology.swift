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
    public let sessionId: String
    /// Custom data provided by the developer at the beginning of the session.
    public var customData: String?
    /// Site ID where the intent was detected.
    public var siteId: String
    /// The user input.
    public var input: String
    /// The intent classification result. If `nil`, the `input` wasn't recognized.
    public var intent: SNPIntentClassifierResult?
    /// Lists of parsed slots.
    public var slots: [SNPSlot]
    
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
    public let intentName: String
    /// The probability between 0.0 and 1.0 of the intent.
    public let probability: Float
    
    init?(_ intentClassifierResult: IntentClassifierResult?) {
        guard let intentClassifierResult = intentClassifierResult else { return nil }
        intentName = intentClassifierResult.intentName
        probability = intentClassifierResult.probability
    }
}

@objc public class SNPSlot: NSObject {
    public let rawValue: String
    /// The value of the slot.
    public let value: SNPSlotValue
    /// The range of the matching string in the given sentence.
    public let range: Range<Int>
    /// The entity name.
    public let entity: String
    /// The name of the slot.
    public let slotName: String
    
    init(_ slot: Slot) {
        rawValue = slot.rawValue
        value = SNPSlotValue(slot.value)
        range = slot.range
        entity = slot.entity
        slotName = slot.slotName
    }
}

@objc public class SNPSlotValue: NSObject {
    public let slotCase: SNPSlotCase
    public let slotValue: Any
    
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
    public let value: String
    /// Granularity of the date e.g. for "tomorrow" the granularity would be `Grain.day`.
    public let grain: SNPGrain
    /// Precision of the date.
    public let precision: SNPPrecision
    
    init(_ instantTimeValue: InstantTimeValue) {
        value = instantTimeValue.value
        grain = SNPGrain(instantTimeValue.grain)
        precision = SNPPrecision(instantTimeValue.precision)
    }
}

/// A date range.
@objc public class SNPTimeIntervalValue: NSObject {
    /// Start date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    public let from: String?
    /// End date in ISO 8601 format e.g. 2018-03-26T17:27:48+00:00.
    public let to: String?
    
    init(_ timeIntervalValue: TimeIntervalValue) {
        from = timeIntervalValue.from
        to = timeIntervalValue.to
    }
}

/// A quantity of money.
@objc public class SNPAmountOfMoneyValue: NSObject {
    /// The amount.
    public let value: Float
    /// The precision of this amount.
    public let precision: SNPPrecision
    /// Currency of this amount e.g. "EUR", "USD", "$".
    public let unit: String?
    
    init(_ amountOfMoneyValue: AmountOfMoneyValue) {
        value = amountOfMoneyValue.value
        precision = SNPPrecision(amountOfMoneyValue.precision)
        unit = amountOfMoneyValue.unit
    }
}

/// A temperature.
@objc public class SNPTemperatureValue: NSObject {
    /// The value of the temperature.
    public let value: Float
    /// The unit of this temperature e.g. "degree", "celcius", "fahrenheit".
    public let unit: String?
    
    init(_ temperatureValue: TemperatureValue) {
        self.value = temperatureValue.value
        self.unit = temperatureValue.unit
    }
}

/// A duration.
@objc public class SNPDurationValue: NSObject {
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
    public let precision: SNPPrecision
    
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
    public let text: String?
    public let intentFilter: [String]?
    public let canBeEnqueued: Bool
    public let sendIntentNotRecognized: Bool
    
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
    public let slotCase: SNPSessionInitTypeCase
    public let slotValue: Any
    
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
    public let initType: SNPSessionInitType
    /// An optional piece of data that will be given back in `IntentMessage`, `IntentNotRecognizedMessage`, `SessionQueuedMessage`, `SessionStartedMessage` and `SessionEndedMessage` that are related to this session
    public let customData: String?
    /// Site where the user started the interaction.
    public let siteId: String?
    
    @objc public init(initType: SNPSessionInitType, customData: String? = nil, siteId: String? = nil) {
        self.initType = initType
        self.customData = customData
        self.siteId = siteId
    }
}

/// Message to send to continue a session.
@objc public class SNPContinueSessionMessage: NSObject {
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
    public let sessionId: String
    /// The text the TTS should say to end the session.
    public let text: String?
    
    @objc public init(sessionId: String, text: String? = nil) {
        self.sessionId = sessionId
        self.text = text
    }
}

/// Message sent when a session starts.
@objc public class SNPSessionStartedMessage: NSObject {
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
    public let sessionId: String
    /// The custom data that was given at the session creation.
    public let customData: String?
    /// The site on which this session was started.
    public let siteId: String
    
    init(_ sessionsQueuedMessage: SessionQueuedMessage) {
        self.sessionId = sessionsQueuedMessage.sessionId
        self.customData = sessionsQueuedMessage.customData
        self.siteId = sessionsQueuedMessage.siteId
    }
}

/// Message sent when a session has ended.
@objc public class SNPSessionEndedMessage: NSObject {
    /// The id of the session that was started.
    public let sessionId: String
    /// The custom data that was given at the session creation.
    public let customData: String?
    /// The site on which this session was started.
    public let siteId: String
    /// How the session was ended.
    public let sessionTermination: SNPSessionTermination
    
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
    public let terminationType: SNPSessionTerminationType
    /// In case of an error, there can be data provided for more details.
    public let data: String?
    
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
    public let text: String
    /// The lang of the message to say.
    public let lang: String?
    /// A unique id of the message to say.
    public let messageId: String?
    /// The site id where the message to say comes from.
    public let siteId: String
    /// The id of the session.
    public let sessionId: String?
    
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
    public let messageId: String?
    /// The id of the session.
    public let sessionId: String?
    
    init(_ message: SayFinishedMessage) {
        messageId = message.messageId
        sessionId = message.sessionId
    }
    
    @objc public init(messageId: String?, sessionId: String?) {
        self.messageId = messageId
        self.sessionId = sessionId
    }
}
