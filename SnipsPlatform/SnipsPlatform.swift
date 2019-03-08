//
//  SnipsPlatform.swift
//  SnipsPlatform
//
//  Copyright © 2019 Snips. All rights reserved.
//

import Foundation
import AVFoundation
#if os(OSX)
import Clibsnips_megazord_macos
#elseif os(iOS)
import Clibsnips_megazord_ios
#endif

private typealias CIntentHandler = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias CSnipsTtsHandler = @convention(c) (UnsafePointer<CSayMessage>?) -> Void
private typealias CSnipsWatchHandler = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias CHotwordHandler = @convention(c) () -> Void
private typealias CListeningHandler = @convention(c) (Bool) -> Void
private typealias CSessionEndedHandler = @convention(c) (UnsafePointer<CSessionEndedMessage>) -> Void
private typealias CSessionQueuedHandler = @convention(c) (UnsafePointer<CSessionQueuedMessage>) -> Void
private typealias CSessionStartedHandler = @convention(c) (UnsafePointer<CSessionStartedMessage>) -> Void
private typealias CIntentNotRecognizedHandler = @convention(c) (UnsafePointer<CIntentNotRecognizedMessage>) -> Void
private typealias CTextCapturedHandler = @convention(c) (UnsafePointer<CTextCapturedMessage>) -> Void
private typealias CInjectionCompleteHandler = @convention(c) (UnsafePointer<CInjectionCompleteMessage>) -> Void

public typealias IntentHandler = (IntentMessage) -> Void
public typealias SpeechHandler = (SayMessage) -> Void
public typealias SnipsWatchHandler = (String) -> Void
public typealias HotwordHandler = () -> Void
public typealias ListeningStateChangedHandler = (Bool) -> Void
public typealias SessionStartedHandler = (SessionStartedMessage) -> Void
public typealias SessionQueuedHandler = (SessionQueuedMessage) -> Void
public typealias SessionEndedHandler = (SessionEndedMessage) -> Void
public typealias IntentNotRecognizedHandler = (IntentNotRecognizedMessage) -> Void
public typealias TextCapturedHandler = (TextCapturedMessage) -> Void
public typealias InjectionCompleteHandler = (InjectionComplete) -> Void

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

private var _onIntentDetected: IntentHandler?
private var _speechHandler: SpeechHandler?
private var _snipsWatchHandler: SnipsWatchHandler?
private var _onHotwordDetected: HotwordHandler?
private var _onListeningStateChanged: ListeningStateChangedHandler?
private var _onSessionStarted: SessionStartedHandler?
private var _onSessionQueued: SessionQueuedHandler?
private var _onSessionEnded: SessionEndedHandler?
private var _onIntentNotRecognizedHandler: IntentNotRecognizedHandler?
private var _onTextCapturedHandler: TextCapturedHandler?
private var _onPartialTextCapturedHandler: TextCapturedHandler?
private var _onInjectionComplete: InjectionCompleteHandler?

/// SnipsPlatform is an assistant
public class SnipsPlatform {
    private var ptr: UnsafeMutablePointer<MegazordClient>?

    /// Creates an instance of an assistant.
    ///
    /// - Parameters:
    ///   - assistantURL: The URL of an assistant directory.
    ///   - hotwordSensitivity: Sensitivity of the hotword. Should be between 0.0 and 1.0. `0.5` by default.
    ///   - enableHtml: This will add html tags to `snipsWatchHandler`. `false` by default.
    ///   - enableLogs: Print Snips internal logs. This should be used only in Debug configuration. `false` by default.
    ///   - enableInjection: Enable ASR injection feature. You can add new entities using the `requestInjection` method. `false` by default.
    ///   - enableAsrPartialText: Enable ASR partial text capture feature. This is quite resource intensive and will affect the capacity of the platform to run in real time. `false` by default
    ///   - userURL: The platform will use this path to store data. For instance when using the ASR injection, new models will be stored in this path. By default it creates a `snips` folder in the user's document folder.
    ///   - g2pResources: When enabling injection, g2p resources are used to generated new word pronunciation. You either need g2p data or a lexicon when injecting new entities.
    ///   - asrModelParameters: Override default ASR model parameters
    ///   - asrPartialTextPeriodMs: ASR partial text capture period in ms. `250ms` by default. You need to have ASR partial text capture enabled.
    /// - Throws: A `SnipsPlatformError` if something went wrong while parsing the given the assistant.
    public init(assistantURL: URL,
                hotwordSensitivity: Float = 0.5,
                enableHtml: Bool = false,
                enableLogs: Bool = false,
                enableInjection: Bool = false,
                enableAsrPartialText: Bool = false,
                userURL: URL? = nil,
                g2pResources: URL? = nil,
                asrModelParameters: AsrModelParameters? = nil,
                asrPartialTextPeriodMs: Float = 250) throws {
        var client: UnsafePointer<MegazordClient>?
        guard megazord_create(assistantURL.path, &client, nil) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        ptr = UnsafeMutablePointer(mutating: client)
        guard megazord_enable_streaming(ptr, 1) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_set_hotword_sensitivity(ptr, hotwordSensitivity) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_snips_watch_html(ptr, enableHtml ? 1 : 0) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_logs(ptr, enableLogs ? 1 : 0) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_asr_partial(ptr, enableAsrPartialText ? 1 : 0) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
        guard megazord_set_asr_partial_period_ms(ptr, UInt(asrPartialTextPeriodMs)) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }

        self.hotwordSensitivity = hotwordSensitivity
        
        if let asrModelParameters = asrModelParameters {
            try asrModelParameters.toUnsafeCModelParameters { cParams in
                guard megazord_set_asr_model_parameters(ptr, cParams) == SNIPS_RESULT_OK else { throw SnipsPlatformError.getLast }
            }
        }

        try megazordEnableInjection(enable: enableInjection, userURL: userURL, g2pResources: g2pResources)
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
                megazord_set_snips_watch_handler(ptr) { buffer, _ in
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
                megazord_set_intent_detected_handler(ptr) { cIntent, _ in
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
    
    /// A closure exectued when the intent was not recognized. For this closure to be run, you need to start a session with the `sendIntentNotRecognized` parameter set to `true`
    public var onIntentNotRecognizedHandler: IntentNotRecognizedHandler? {
        get {
            return _onIntentNotRecognizedHandler
        }
        set {
            if newValue != nil {
                _onIntentNotRecognizedHandler = newValue
                megazord_set_intent_not_recognized_handler(ptr) { cIntent, _ in
                    guard let cIntent = cIntent?.pointee else { return }
                    _onIntentNotRecognizedHandler?(IntentNotRecognizedMessage(cResult: cIntent))
                }
            } else {
                megazord_set_intent_not_recognized_handler(ptr, nil)
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
                megazord_set_hotword_detected_handler(ptr) { _ in
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
                megazord_set_listening_state_changed_handler(ptr) { cListeningStateChanged, _ in
                    _onListeningStateChanged?(cListeningStateChanged != 0)
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
                megazord_set_session_started_handler(ptr) { cSessionStartedMessage, _ in
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
                megazord_set_session_queued_handler(ptr) { cSessionQueuedMessage, _ in
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
                megazord_set_session_ended_handler(ptr) { cSessionEndedMessage, _ in
                    defer {
                        megazord_destroy_session_ended_message(UnsafeMutablePointer(mutating: cSessionEndedMessage))
                    }
                    guard let cSessionEndedMessage = cSessionEndedMessage?.pointee else { return }
                    _onSessionEnded?(try! SessionEndedMessage(cSessionEndedMessage: cSessionEndedMessage))
                }
            }
        }
    }
    
    /// A closure executed when an injection completed
    public var onInjectionComplete: InjectionCompleteHandler? {
        get {
            return _onInjectionComplete
        }
        set {
            if newValue != nil {
                _onInjectionComplete = newValue
                megazord_set_injection_complete_handler(ptr) { cMessage, _ in
//                    defer {
//                        megazord_destry_injection(UnsafeMutablePointer(mutating: cSessionEndedMessage))
//                    }
                    guard let cMessage = cMessage?.pointee else { return }
                    _onInjectionComplete?(InjectionComplete(cMessage: cMessage))
                }
            }
        }
    }
    
    public var onComponentLoaded: ComponentLoadedHandler? {
        get {
            return _componentLoaded
        }
        set {
            if newValue != nil {
                _componentLoaded = newValue
                megazord_set_component_loaded_handler(ptr) { cComponent, _ in
                    _componentLoaded?(try! Component(cValue: cComponent))
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
                megazord_set_tts_handler(ptr) { message, _ in
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
    
    /// A closure to get the text captured by the platform.
    public var onTextCapturedHandler: TextCapturedHandler? {
        get {
            return _onTextCapturedHandler
        }
        set {
            if newValue != nil {
                _onTextCapturedHandler = newValue
                megazord_set_asr_text_captured_handler(ptr) { message, _ in
                    defer {
                        megazord_destroy_text_captured_message(UnsafeMutablePointer(mutating: message))
                    }
                    guard let message = message?.pointee else { return }
                    _onTextCapturedHandler?(TextCapturedMessage(cTextCapturedMessage: message))
                }
            } else {
                megazord_set_asr_text_captured_handler(ptr, nil)
            }
        }
    }
    
    /// A closure to get the text captured by the platform in real time.
    public var onPartialTextCapturedHandler: TextCapturedHandler? {
        get {
            return _onPartialTextCapturedHandler
        }
        set {
            if newValue != nil {
                _onPartialTextCapturedHandler = newValue
                megazord_set_asr_partial_text_captured_handler(ptr) { message, _ in
                    defer {
                        megazord_destroy_text_captured_message(UnsafeMutablePointer(mutating: message))
                    }
                    guard let message = message?.pointee else { return }
                    _onPartialTextCapturedHandler?(TextCapturedMessage(cTextCapturedMessage: message))
                }
            } else {
                megazord_set_asr_partial_text_captured_handler(ptr, nil)
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
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let frame = buffer.int16ChannelData?.pointee else { fatalError("Can't retrieve channel") }
        guard megazord_send_audio_buffer(ptr, frame, UInt32(buffer.frameLength)) == SNIPS_RESULT_OK else {
            throw SnipsPlatformError.getLast
        }
    }
    
    /// Append an audio buffer to be processed. This should be continously executed
    /// otherwise the platform could crash.
    ///
    /// - Parameter buffer: The audio buffer
    /// - Throws: A `SnipsPlatformError` if something went wrong.
    public func appendBuffer(_ buffer: [Int16]) throws {
        try buffer.withUnsafeBufferPointer { buf in
            guard megazord_send_audio_buffer(ptr, buf.baseAddress, UInt32(buf.count)) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
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
    public func requestInjection(with message: InjectionRequestMessage) throws {
        try message.toUnsafeCInjectionRequestMessage { cMessage in
            guard megazord_request_injection(ptr, cMessage) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }
    
    /// Enable and disable intents in the dialogue on the fly.
    ///
    /// - Parameters:
    ///   - configuration: DialogueConfigureMessage containing the intents you wish to filter.
    public func dialogueConfiguration(with configuration: DialogueConfigureMessage) throws {
        try configuration.toUnsafeCDialogueConfigureMessage { cMessage in
            guard megazord_dialogue_configure(ptr, cMessage) == SNIPS_RESULT_OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    /// Used internaly to create Snips user folder
    private func megazordEnableInjection(enable: Bool, userURL: URL?, g2pResources: URL? = nil) throws {
        guard enable else { return }

        let userDocumentURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let snipsUserDataURL: URL
        let snipsInjectionURLPath: String?

        if let userURL = userURL {
            snipsUserDataURL = userURL
        } else {
            snipsUserDataURL = userDocumentURL.appendingPathComponent("snips")
            var isDirectory = ObjCBool(true)
            let exists = FileManager.default.fileExists(atPath: snipsUserDataURL.path, isDirectory: &isDirectory)
            if (exists && isDirectory.boolValue) == false {
                try FileManager.default.createDirectory(atPath: snipsUserDataURL.path, withIntermediateDirectories: true, attributes: nil)
            }
        }

        if let g2pResources = g2pResources {
            var isDirectory = ObjCBool(true)
            let exists = FileManager.default.fileExists(atPath: g2pResources.path, isDirectory: &isDirectory)
            guard (exists && isDirectory.boolValue) else {
                throw SnipsPlatformError(message: "Folder doesn't exists at path: \(g2pResources.path)")
            }
            snipsInjectionURLPath = g2pResources.path
        } else {
            snipsInjectionURLPath = nil
        }
        guard megazord_enable_injection(ptr, snipsUserDataURL.path, snipsInjectionURLPath) == SNIPS_RESULT_OK else {
            throw SnipsPlatformError.getLast
        }
    }
}
