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
private typealias CSnipsWatchHandler = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias CHotwordHandler = @convention(c) () -> Void

public typealias IntentHandler = (IntentMessage) -> ()
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

private var _snipsWatchHandler: SnipsWatchHandler? = nil
private var _onIntentDetected: IntentHandler? = nil
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
        guard megazord_enable_streaming(1, ptr) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_set_hotword_sensitivity(hotwordSensitivity, ptr) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_snips_watch_html(enableHtml ? 1 : 0, ptr) == OK else { throw SnipsPlatformError.getLast }
        guard megazord_enable_logs(enableLogs ? 1 : 0, ptr) == OK else { throw SnipsPlatformError.getLast }
        
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
            megazord_update_hotword_sensitivity(hotwordSensitivity, ptr)
        }
    }
    
    public var snipsWatchHandler: SnipsWatchHandler? {
        get {
            return _snipsWatchHandler
        }
        set {
            if newValue != nil {
                _snipsWatchHandler = newValue
                megazord_set_snips_watch_handler({ buffer in
                    defer {
                        megazord_destroy_string(UnsafeMutablePointer(mutating: buffer))
                    }
                    guard let buffer = buffer else { return }
                    _snipsWatchHandler?(String(cString: buffer))
                }, ptr)
            } else {
                megazord_set_snips_watch_handler(nil, ptr)
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
                megazord_set_intent_detected_handler({ cIntent in
                    defer {
                        megazord_destroy_intent_message(UnsafeMutablePointer(mutating: cIntent))
                    }
                    guard let cIntent = cIntent?.pointee else { return }
                    _onIntentDetected?(try! IntentMessage(cResult: cIntent))
                }, ptr)
            } else {
                megazord_set_intent_detected_handler(nil, ptr)
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
                megazord_set_hotword_detected_handler({
                    _onHotwordDetected?()
                }, ptr)
            } else {
                megazord_set_intent_detected_handler(nil, ptr)
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
        try withArrayOfCStrings(intentFilter) { cIntentFilter in
            try cIntentFilter.withUnsafeBufferPointer { cIntentFilter2 in
                let result = megazord_dialogue_start_session(
                    ptr,
                    text,
                    cIntentFilter2.baseAddress,
                    UInt32(intentFilter.count),
                    canBeEnqueued ? 1 : 0,
                    customData
                )
                guard result == OK else { throw SnipsPlatformError.getLast }
            }
        }
    }
    
    public func startNotification(text: String?, customData: String?) throws {
        guard megazord_dialogue_start_notification(ptr, text, customData) == OK else {
            throw SnipsPlatformError.getLast
        }
    }
    
    public func continueSession(sessionId: String, text: String, intentFilter: [String]) throws {
        try withArrayOfCStrings(intentFilter) { cIntentFilter in
            try cIntentFilter.withUnsafeBufferPointer { cIntentFilter2 in
                let result = megazord_dialogue_continue_session(
                    ptr,
                    sessionId,
                    text,
                    cIntentFilter2.baseAddress,
                    UInt32(intentFilter.count)
                )
                guard result == OK else { throw SnipsPlatformError.getLast }
            }
        }
    }

    public func endSession(sessionId: String, text: String?) throws {
        guard megazord_dialogue_end_session(ptr, sessionId, text) == OK else {
            throw SnipsPlatformError.getLast
        }
    }
    
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let frame = buffer.int16ChannelData?.pointee else { fatalError("Can't retrieve channel") }
        megazord_send_audio_buffer(frame, UInt32(buffer.frameLength), ptr)
    }
}

func withArrayOfCStrings<R>(_ args: [String], _ body: ([UnsafePointer<CChar>?]) throws -> R) rethrows -> R {
    var cStrings = args.map { UnsafePointer(strdup($0)) }
    cStrings.append(nil)
    defer {
        cStrings.forEach { free(UnsafeMutablePointer(mutating: $0)) }
    }
    return try body(cStrings)
}
