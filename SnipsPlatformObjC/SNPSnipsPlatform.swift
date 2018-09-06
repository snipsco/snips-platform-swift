//
//  SNPSnipsPlatform.swift
//  SNPSnipsPlatform
//
//  Copyright © 2018 Snips. All rights reserved.
//

import Foundation
import AVFoundation
import SnipsPlatform

/// `SNPSnipsPlatformError` is the error type returned by SNPSnipsPlatform.
@objc public class SNPSnipsPlatformError: NSError {
    public let message: String
    public override var localizedDescription: String { return message }

    init(_ snipsPlatformError: SnipsPlatformError) {
        message = snipsPlatformError.message
        super.init(domain: "Snips", code: 1, userInfo: nil)
    }
    
    init(_ message: String) {
        self.message = message
        super.init(domain: "Snips", code: 1, userInfo: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.message = ""
        super.init(coder: aDecoder)
    }
}

@objc public protocol SNPSnipsPlatformDelegate {
    @objc optional func onIntentDetected(_ intent: SNPIntent)
    @objc optional func speechHandler(_ sayMessage: SNPSayMessage)
    @objc optional func snipsWatchHandler(_ log: String)
    @objc optional func onHotwordDetected()
    @objc optional func onListeningStateChanged(_ state: Bool)
    @objc optional func onSessionStarted(_ message: SNPSessionStartedMessage)
    @objc optional func onSessionQueued(_ message: SNPSessionQueuedMessage)
    @objc optional func onSessionEnded(_ message: SNPSessionEndedMessage)
}

/// SnipsPlatform is an assistant
@objc public class SNPSnipsPlatform: NSObject {
    private var snipsPlatform: SnipsPlatform
    public var delegate: SNPSnipsPlatformDelegate? = nil

    public init(assistantURL: URL,
                hotwordSensitivity: Float = 0.5,
                enableHtml: Bool = false,
                enableLogs: Bool = false,
                enableInjection: Bool = false,
                userURL: URL? = nil,
                g2pResources: URL? = nil) throws {
        
        do {
            snipsPlatform = try SnipsPlatform(assistantURL: assistantURL, hotwordSensitivity: hotwordSensitivity, enableHtml: enableHtml, enableLogs: enableLogs, enableInjection: enableInjection, userURL: userURL, g2pResources: g2pResources)
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
        
        super.init()
        
        snipsPlatform.snipsWatchHandler = { [weak self] log in
            self?.delegate?.snipsWatchHandler?(log)
        }
        snipsPlatform.onIntentDetected = { [weak self] intent in
            self?.delegate?.onIntentDetected?(SNPIntent(intent))
        }
        snipsPlatform.speechHandler = { [weak self] sayMessage in
            self?.delegate?.speechHandler?(SNPSayMessage(sayMessage))
        }
        snipsPlatform.onHotwordDetected = { [weak self] in
            self?.delegate?.onHotwordDetected?()
        }
        snipsPlatform.onListeningStateChanged = { [weak self] state in
            self?.delegate?.onListeningStateChanged?(state)
        }
        snipsPlatform.onSessionStartedHandler = { [weak self] message in
            self?.delegate?.onSessionStarted?(SNPSessionStartedMessage(message))
        }
        snipsPlatform.onSessionQueuedHandler = { [weak self] message in
            self?.delegate?.onSessionQueued?(SNPSessionQueuedMessage(message))
        }
        snipsPlatform.onSessionEndedHandler = { [weak self] message in
            self?.delegate?.onSessionEnded?(SNPSessionEndedMessage(message))
        }
    }

    /// Setter/Getter of the hotword sensitivity. Should be between 0.0 and 1.0.
    @objc public var hotwordSensitivity: Float {
        get {
            return snipsPlatform.hotwordSensitivity
        }
        set {
            snipsPlatform.hotwordSensitivity = newValue
        }
    }

    /// Start the platform. This operation could be heavy as this start all sub-services.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    @objc public func start() throws {
        do {
            try snipsPlatform.start()
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Pause the platform.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    @objc public func pause() throws {
        do {
            try snipsPlatform.pause()
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Restore the paused platform.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    @objc public func unpause() throws {
        do {
            try snipsPlatform.unpause()
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Start manually a dialogue session.
    ///
    /// - Parameters:
    ///   - text: Text that the TTS should say at the beginning of the session.
    ///   - intentFilter: A list of intents names to restrict the NLU resolution on the first query. Passing nil will not filter. Passing an empty array will filter everything. Passing the name of the intent will let only this intent pass.
    ///   - canBeEnqueued: if true, the session will start when there is no pending one on this siteId, if false, the session is just dropped if there is running one. Default to true
    ///   - sendIntentNotRecognized: An optional boolean to indicate whether the dialogue manager should handle non recognized intents by itself or sent them as an `IntentNotRecognizedMessage` for the client to handle. This setting applies only to the next conversation turn. The default value is false (and the dialogue manager will handle non recognized intents by itself)
    ///   - customData: Additional information that can be provided by the handler. Each message related to the new session - sent by the Dialogue Manager - will contain this data.
    ///   - siteId: The id where the session will take place
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    @objc public func startSession(text: String? = nil, intentFilter: [String]? = nil, canBeEnqueued: Bool = true, sendIntentNotRecognized: Bool = false, customData: String? = nil, siteId: String? = nil) throws {
        do {
            try snipsPlatform.startSession(
                message: StartSessionMessage(
                    initType: .action(text: text, intentFilter: intentFilter, canBeEnqueued: canBeEnqueued, sendIntentNotRecognized: sendIntentNotRecognized),
                    customData: customData,
                    siteId: siteId))
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Start a notification.
    ///
    /// - Parameters:
    ///   - text: Text the TTS should say.
    ///   - customData: Additional information that can be provided by the handler. Each message related to the new session - sent by the Dialogue Manager - will contain this data.
    ///   - siteId: The id where the session will take place
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    @objc public func startNotification(text: String, customData: String? = nil, siteId: String? = nil) throws {
        do {
            try snipsPlatform.startSession(
                message: StartSessionMessage(
                    initType: .notification(text: text),
                    customData: customData,
                    siteId: siteId))
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Continue a session after an intent was detected.
    ///
    /// - Parameters:
    ///   - sessionId: Session identifier to continue.
    ///   - text: The text the TTS should say to start this additional request of the session.
    ///   - intentFilter: A list of intents names to restrict the NLU resolution on the answer of this query. Passing nil will not filter. Passing an empty array will filter everything. Passing the name of the intent will let only this intent pass.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    @objc public func continueSession(sessionId: String, text: String, intentFilter: [String]?) throws {
        do {
            try snipsPlatform.continueSession(
                message: ContinueSessionMessage(
                    sessionId: sessionId,
                    text: text,
                    intentFilter: intentFilter))
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// End a session.
    ///
    /// - Parameters:
    ///   - sessionId: Session identifier to end.
    ///   - text: The text the TTS should say to end the session.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    @objc public func endSession(sessionId: String, text: String? = nil) throws {
        do {
            try snipsPlatform.endSession(message: EndSessionMessage(sessionId: sessionId, text: text))
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Should be called after a text-to-speech operation was successfully performed.
    /// Should only be used if `speechHandler` was set and triggered.
    ///
    /// - Parameters:
    ///   - messageId: The id of the said message.
    ///   - sessionId: The session identifier of the message.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    @objc public func notifySpeechEnded(messageId: String? = nil, sessionId: String? = nil) throws {
        do {
            try snipsPlatform.notifySpeechEnded(message: SayFinishedMessage(messageId: messageId, sessionId: sessionId))
        } catch let error as SnipsPlatformError {
            throw SNPSnipsPlatformError(error)
        } catch let error {
            throw error
        }
    }

    /// Append an audio buffer to be processed. This should be continously executed
    /// otherwise the platform could crash.
    ///
    /// - Parameter buffer: The audio buffer
    @objc public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        snipsPlatform.appendBuffer(buffer)
    }
    
    /// Request an injection of new entities values in the ASR model.
    ///
    /// - Parameters:
    ///   - message: InjectionRequestMessage containing the new entities values. Usage:
    ///     ```
    ///     var newEntities: [String: [String]] = [:]
    ///     newEntities["locality"] = ["wonderland"]
    ///
    ///     let operation = InjectionRequestOperation(entities: newEntities, kind: .add)
    ///     do {
    ///         try snips?.requestInjection(with: InjectionRequestMessage(operations: [operation]))
    ///     } catch let error {
    ///         print(error)
    ///     }
    ///     ```
    ///
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    ///
//    @objc public func requestInjection(with message: InjectionRequestMessage) throws {
//        try message.toUnsafeCInjectionRequestMessage { cMessage in
//            guard megazord_request_injection(ptr, cMessage) == SNIPS_RESULT_OK else {
//                throw SnipsPlatformError.getLast
//            }
//        }
//    }
}
