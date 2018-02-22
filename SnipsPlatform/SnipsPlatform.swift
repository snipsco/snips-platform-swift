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

public typealias IntentHandler = (IntentMessage) -> ()
public typealias SpeechHandler = (SayMessage) -> ()
public typealias SnipsWatchHandler = (String) -> ()
public typealias HotwordHandler = () -> ()

public struct SnipsPlatformError: Error {
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

public class SnipsPlatform {
    private var ptr: UnsafeMutablePointer<MegazordClient>? = nil

    public init(assistantURL: URL,
                hotwordSensitivity: Float = 0.5,
                enableHtml: Bool = false,
                enableLogs: Bool = false) throws {
        var client: UnsafePointer<MegazordClient>? = nil
        guard megazord_create(assistantURL.path, &client) == OK else { throw SnipsPlatformError.getLast }
        ptr = UnsafeMutablePointer(mutating: client)
        guard megazord_enable_streaming(ptr, 1) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_set_hotword_sensitivity(ptr, hotwordSensitivity) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_snips_watch_html(ptr, enableHtml ? 1 : 0) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_logs(ptr, enableLogs ? 1 : 0) == OK else { throw SnipsPlatformError.getLast }

        self.hotwordSensitivity = hotwordSensitivity
    }

    deinit {
        if ptr != nil {
            megazord_destroy(ptr)
            ptr = nil
        }
    }

    public var hotwordSensitivity: Float {
        didSet {
            megazord_update_hotword_sensitivity(ptr, hotwordSensitivity)
        }
    }

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

    public func start() throws {
        guard megazord_start(ptr) == OK else { throw SnipsPlatformError.getLast }
    }

    public func pause() throws {
        guard megazord_pause(ptr) == OK else { throw SnipsPlatformError.getLast }
    }

    public func unpause() throws {
        guard megazord_unpause(ptr) == OK else { throw SnipsPlatformError.getLast }
    }

    public func startSession(text: String?, intentFilter: [String], canBeEnqueued: Bool, customData: String?) throws {
        try startSession(
            message: StartSessionMessage(
                initType: .action(text: text, intentFilter: intentFilter, canBeEnqueued: canBeEnqueued),
                customData: customData,
                siteId: nil))
    }

    public func startNotification(text: String?, customData: String?) throws {
        try startSession(
            message: StartSessionMessage(
                initType: .notification(text: text),
                customData: customData,
                siteId: nil))
    }

    public func startSession(message: StartSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_start_session(ptr, $0) == OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    public func continueSession(sessionId: String, text: String, intentFilter: [String]) throws {
        try continueSession(
            message: ContinueSessionMessage(
                sessionId: sessionId,
                text: text,
                intentFilter: intentFilter))
    }

    public func continueSession(message: ContinueSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_continue_session(ptr, $0) == OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    public func endSession(sessionId: String, text: String?) throws {
        try endSession(message: EndSessionMessage(sessionId: sessionId, text: text))
    }

    public func endSession(message: EndSessionMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_dialogue_end_session(ptr, $0) == OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    public func notifySpeechEnded(messageId: String?, sessionId: String?) throws {
        try notifySpeechEnded(message: SayFinishedMessage(messageId: messageId, sessionId: sessionId))
    }

    public func notifySpeechEnded(message: SayFinishedMessage) throws {
        try message.toUnsafeCMessage {
            guard megazord_notify_tts_finished(ptr, $0) == OK else {
                throw SnipsPlatformError.getLast
            }
        }
    }

    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let frame = buffer.int16ChannelData?.pointee else { fatalError("Can't retrieve channel") }
        megazord_send_audio_buffer(ptr, frame, UInt32(buffer.frameLength))
    }
}
