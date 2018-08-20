//
//  SnipsPlatform.swift
//  SnipsPlatform
//
//  Copyright © 2017 Snips. All rights reserved.
//

import Foundation
import AVFoundation
import Clibsnips_megazord

private typealias CIntentHandler = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias CSnipsTtsHandler = @convention(c) (UnsafePointer<CSayMessage>?) -> Void
private typealias CSnipsWatchHandler = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias CHotwordHandler = @convention(c) () -> Void
private typealias CListeningHandler = @convention(c) (Bool) -> Void
private typealias CSessionEndedHandler = @convention(c) (UnsafePointer<CSessionEndedMessage>) -> Void
private typealias CSessionQueuedHandler = @convention(c) (UnsafePointer<CSessionQueuedMessage>) -> Void
private typealias CSessionStartedHandler = @convention(c) (UnsafePointer<CSessionStartedMessage>) -> Void

public typealias IntentHandler = (IntentMessage) -> ()
public typealias SpeechHandler = (SayMessage) -> ()
public typealias SnipsWatchHandler = (String) -> ()
public typealias HotwordHandler = () -> ()
public typealias ListeningStateChangedHandler = (Bool) -> ()
public typealias SessionStartedHandler = (SessionStartedMessage) -> ()
public typealias SessionQueuedHandler = (SessionQueuedMessage) -> ()
public typealias SessionEndedHandler = (SessionEndedMessage) -> ()

/// `SnipsPlatformError` is the error type returned by SnipsPlatform.
public struct SnipsPlatformError: Error {
    /// Message of the error
    public let message: String

    static var getLast: SnipsPlatformError {
        let buffer = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: 1)
        megazord_get_last_error(buffer)
        let message = String(cString: buffer.pointee!)
        megazord_destroy_string(UnsafeMutablePointer(mutating: buffer.pointee!))
        return SnipsPlatformError(message: message)
    }

    public var localizedDescription: String { return self.message }
}

private var _onIntentDetected: IntentHandler? = nil
private var _speechHandler: SpeechHandler? = nil
private var _snipsWatchHandler: SnipsWatchHandler? = nil
private var _onHotwordDetected: HotwordHandler? = nil
private var _onListeningStateChanged: ListeningStateChangedHandler? = nil
private var _onSessionStarted: SessionStartedHandler? = nil
private var _onSessionQueued: SessionQueuedHandler? = nil
private var _onSessionEnded: SessionEndedHandler? = nil

/// SnipsPlatform is an assistant
public class SnipsPlatform {
    private var ptr: UnsafeMutablePointer<MegazordClient>? = nil

    /// Creates an instance of an assistant.
    ///
    /// - Parameters:
    ///   - assistantURL: The URL of an assistant directory.
    ///   - hotwordSensitivity: Sensitivity of the hotword. Should be between 0.0 and 1.0. `0.5` by default.
    ///   - enableHtml: This will add html tags to `snipsWatchHandler`. `false` by default.
    ///   - enableLogs: Print Snips internal logs. This should be used only in Debug configuration. `false` by default.
    /// - Throws: A `SnipsPlatformError` if something went wrong while parsing the given the assistant.
    public init(assistantURL: URL,
                hotwordSensitivity: Float = 0.5,
                enableHtml: Bool = false,
                enableLogs: Bool = false,
                enableInjection: Bool = false,
                userURL: URL? = nil,
                injectionDataURL: URL? = nil) throws {
        var client: UnsafePointer<MegazordClient>? = nil
        guard megazord_create(assistantURL.path, &client) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        ptr = UnsafeMutablePointer(mutating: client)
        guard megazord_enable_streaming(ptr, 1) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_set_hotword_sensitivity(ptr, hotwordSensitivity) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_snips_watch_html(ptr, enableHtml ? 1 : 0) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_logs(ptr, enableLogs ? 1 : 0) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        self.hotwordSensitivity = hotwordSensitivity
        try megazordEnableInjection(enable: enableInjection, userURL: userURL, g2pURL: injectionDataURL)
    }

    deinit {
        if ptr != nil {
            megazord_destroy(ptr)
            ptr = nil
        }
    }

    /// Setter/Getter of the hotword sensitivity. Should be between 0.0 and 1.0.
    public var hotwordSensitivity: Float {
        didSet {
            megazord_update_hotword_sensitivity(ptr, hotwordSensitivity)
        }
    }

    /// A closure executed to log what happend on the platform. This is only intended for debug purpose.
    /// - Note: if `SnipsPlatform` was initialized with `enableHtml: true`. Then output will contains html tags.
    public var snipsWatchHandler: SnipsWatchHandler? {
        get {
            return _snipsWatchHandler
        }
        set {
            if newValue != nil {
                _snipsWatchHandler = newValue
                megazord_set_snips_watch_handler(ptr) { buffer in
                    defer {
                        megazord_destroy_string(UnsafeMutablePointer(mutating: buffer))
                    }
                    guard let buffer = buffer else { return }
                    _snipsWatchHandler?(String(cString: buffer))
                }
            } else {
                megazord_set_snips_watch_handler(ptr, nil)
            }
        }
    }

    /// A closure executed when an intent is detected.
    public var onIntentDetected: IntentHandler? {
        get {
            return _onIntentDetected
        }
        set {
            if newValue != nil {
                _onIntentDetected = newValue
                megazord_set_intent_detected_handler(ptr) { cIntent in
                    defer {
                        megazord_destroy_intent_message(UnsafeMutablePointer(mutating: cIntent))
                    }
                    guard let cIntent = cIntent?.pointee else { return }
                    _onIntentDetected?(try! IntentMessage(cResult: cIntent))
                }
            } else {
                megazord_set_intent_detected_handler(ptr, nil)
            }
        }
    }

    /// A closure executed when an hotword is detected.
    public var onHotwordDetected: HotwordHandler? {
        get {
            return _onHotwordDetected
        }
        set {
            if newValue != nil {
                _onHotwordDetected = newValue
                megazord_set_hotword_detected_handler(ptr) {
                    _onHotwordDetected?()
                }
            } else {
                megazord_set_intent_detected_handler(ptr, nil)
            }
        }
    }
    
    /// A closure executed when the listening state has changed.
    public var onListeningStateChanged: ListeningStateChangedHandler? {
        get {
            return _onListeningStateChanged
        }
        set {
            if newValue != nil {
                _onListeningStateChanged = newValue
                megazord_set_listening_state_changed_handler(ptr) { cListeningStateChanged in
                    _onListeningStateChanged?(cListeningStateChanged)
                }
            } else {
                megazord_set_listening_state_changed_handler(ptr, nil)
            }
        }
    }
    
    /// A closure executed when the session has started.
    public var onSessionStartedHandler: SessionStartedHandler? {
        get {
            return _onSessionStarted
        }
        set {
            if newValue != nil {
                _onSessionStarted = newValue
                megazord_set_session_started_handler(ptr) { cSessionStartedMessage in
                    defer {
                        megazord_destroy_session_started_message(UnsafeMutablePointer(mutating: cSessionStartedMessage))
                    }
                    guard let cSessionStartedMessage = cSessionStartedMessage?.pointee else { return }
                    _onSessionStarted?(SessionStartedMessage(cSessionStartedMessage: cSessionStartedMessage))
                }
            }
        }
    }
    
    /// A closure executed when the session is queued.
    public var onSessionQueuedHandler: SessionQueuedHandler? {
        get {
            return _onSessionQueued
        }
        set {
            if newValue != nil {
                _onSessionQueued = newValue
                megazord_set_session_queued_handler(ptr) { cSessionQueuedMessage in
                    defer {
                        megazord_destroy_session_queued_message(UnsafeMutablePointer(mutating: cSessionQueuedMessage))
                    }
                    guard let cSessionQueuedMessage = cSessionQueuedMessage?.pointee else { return }
                    _onSessionQueued?(SessionQueuedMessage(cSessionsQueuedMessage: cSessionQueuedMessage))
                }
            }
        }
    }
    
    /// A closure executed when the session has ended
    public var onSessionEndedHandler: SessionEndedHandler? {
        get {
            return _onSessionEnded
        }
        set {
            if newValue != nil {
                _onSessionEnded = newValue
                megazord_set_session_ended_handler(ptr) { cSessionEndedMessage in
                    defer {
                        megazord_destroy_session_ended_message(UnsafeMutablePointer(mutating: cSessionEndedMessage))
                    }
                    guard let cSessionEndedMessage = cSessionEndedMessage?.pointee else { return }
                    _onSessionEnded?(try! SessionEndedMessage(cSessionEndedMessage: cSessionEndedMessage))
                }
            }
        }
    }
    
    /// A closure executed to delegate text-to-speech operations.
    public var speechHandler: SpeechHandler? {
        get {
            return _speechHandler
        }
        set {
            if newValue != nil {
                _speechHandler = newValue
                megazord_set_tts_handler(ptr) { message in
                    defer {
                        megazord_destroy_say_message(UnsafeMutablePointer(mutating: message))
                    }
                    guard let message = message?.pointee else { return }
                    _speechHandler?(SayMessage(cMessage: message))
                }
            } else {
                megazord_set_tts_handler(ptr, nil)
            }
        }
    }

    /// Start the platform. This operation could be heavy as this start all sub-services.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    public func start() throws {
        guard megazord_start(ptr) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
    }

    /// Pause the platform.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    public func pause() throws {
        guard megazord_pause(ptr) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
    }

    /// Restore the paused platform.
    ///
    /// - Throws: A `SnipsPlatformError` is something went wrong.
    public func unpause() throws {
        guard megazord_unpause(ptr) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
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
    public func startSession(text: String? = nil, intentFilter: [String]? = nil, canBeEnqueued: Bool = true, sendIntentNotRecognized: Bool = false, customData: String? = nil, siteId: String? = nil) throws {
        try startSession(
            message: StartSessionMessage(
                initType: .action(text: text, intentFilter: intentFilter, canBeEnqueued: canBeEnqueued, sendIntentNotRecognized: sendIntentNotRecognized),
                customData: customData,
                siteId: siteId))
    }

    /// Start a notification.
    ///
    /// - Parameters:
    ///   - text: Text the TTS should say.
    ///   - customData: Additional information that can be provided by the handler. Each message related to the new session - sent by the Dialogue Manager - will contain this data.
    ///   - siteId: The id where the session will take place
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func startNotification(text: String, customData: String? = nil, siteId: String? = nil) throws {
        try startSession(
            message: StartSessionMessage(
                initType: .notification(text: text),
                customData: customData,
                siteId: siteId))
    }

    /// Start manually a dialogue session.
    ///
    /// - Parameter message: The message describing the session to start.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func startSession(message: StartSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_start_session(ptr, $0) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    /// Continue a session after an intent was detected.
    ///
    /// - Parameters:
    ///   - sessionId: Session identifier to continue.
    ///   - text: The text the TTS should say to start this additional request of the session.
    ///   - intentFilter: A list of intents names to restrict the NLU resolution on the answer of this query. Passing nil will not filter. Passing an empty array will filter everything. Passing the name of the intent will let only this intent pass.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func continueSession(sessionId: String, text: String, intentFilter: [String]?) throws {
        try continueSession(
            message: ContinueSessionMessage(
                sessionId: sessionId,
                text: text,
                intentFilter: intentFilter))
    }

    /// Continue a session after an intent was detected.
    ///
    /// - Parameter message: The message describing the session to continue.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func continueSession(message: ContinueSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_continue_session(ptr, $0) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    /// End a session.
    ///
    /// - Parameters:
    ///   - sessionId: Session identifier to end.
    ///   - text: The text the TTS should say to end the session.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func endSession(sessionId: String, text: String? = nil) throws {
        try endSession(message: EndSessionMessage(sessionId: sessionId, text: text))
    }

    /// End a session.
    ///
    /// - Parameter message: The message describing the session to end.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func endSession(message: EndSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_end_session(ptr, $0) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    /// Should be called after a text-to-speech operation was successfully performed.
    /// Should only be used if `speechHandler` was set and triggered.
    ///
    /// - Parameters:
    ///   - messageId: The id of the said message.
    ///   - sessionId: The session identifier of the message.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func notifySpeechEnded(messageId: String? = nil, sessionId: String? = nil) throws {
        try notifySpeechEnded(message: SayFinishedMessage(messageId: messageId, sessionId: sessionId))
    }

    /// Should be called after a text-to-speech operation was successfully performed.
    /// Should only be used if `speechHandler` was set and triggered.
    ///
    /// - Parameter message: The message describing the speech that ended.
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func notifySpeechEnded(message: SayFinishedMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_notify_tts_finished(ptr, $0) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    /// Append an audio buffer to be processed. This should be continously executed
    /// otherwise the platform could crash.
    ///
    /// - Parameter buffer: The audio buffer
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let frame = buffer.int16ChannelData?.pointee else { fatalError("Can't retrieve channel") }
        megazord_send_audio_buffer(ptr, frame, UInt32(buffer.frameLength))
    }
    
    public func requestInjection(with message: InjectionRequestMessage) throws {
        try message.toUnsafeCInjectionRequestMessage {
            guard megazord_request_injection(ptr, $0) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }
}

fileprivate extension SnipsPlatform {
    func megazordEnableInjection(enable: Bool, userURL: URL?, g2pURL: URL?) throws {
        guard enable else { return }
        let userDocumentURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let snipsUserDataURL: URL
        let snipsInjectionURL: URL
        
        if let userURL = userURL {
            snipsUserDataURL = userURL
        } else {
            snipsUserDataURL = userDocumentURL.appendingPathComponent("snips/user")
            var isDirectory = ObjCBool(true)
            let exists = FileManager.default.fileExists(atPath: snipsUserDataURL.path, isDirectory: &isDirectory)
            if (exists && isDirectory.boolValue) == false {
                try FileManager.default.createDirectory(atPath: snipsUserDataURL.path, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        if let g2pURL = g2pURL {
            snipsInjectionURL = g2pURL
        } else {
            snipsInjectionURL = userDocumentURL.appendingPathComponent("snips/injection")
            var isDirectory = ObjCBool(true)
            let exists = FileManager.default.fileExists(atPath: snipsInjectionURL.path, isDirectory: &isDirectory)
            if (exists && isDirectory.boolValue) == false {
                try FileManager.default.createDirectory(atPath: snipsInjectionURL.path, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        guard megazord_enable_asr_injection(ptr, snipsUserDataURL.path, snipsInjectionURL.path) == SNIPS_RESULT_OK else {
            throw SnipsPlatformError.getLast
        }
    }
}
