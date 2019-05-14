//
//  SnipsPlatformInstance.swift
//  AllTests-iOS
//
//  Copyright © 2019 Snips. All rights reserved.
//

import AVFoundation
import SnipsPlatform

let kHotwordAudioFile = "hey_snips"
let kWeatherAudioFile = "what_will_be_the_weather_in_Madagascar_in_two_days"
let kWonderlandAudioFile = "what_will_be_the_weather_in_Wonderland"
let kPlayMJAudioFile = "hey_snips_can_you_play_me_some_Michael_Jackson"
let kFrameCapacity: AVAudioFrameCount = 256

class SnipsEngine {
    static let shared = SnipsEngine()
    
    var snips: SnipsPlatform?
    
    var activeSessionId: String?
    
    var onIntentDetected: ((IntentMessage) -> ())?
    var onHotwordDetected: (() -> ())?
    var speechHandler: ((SayMessage) -> ())?
    var onSessionStartedHandler: ((SessionStartedMessage) -> ())?
    var onSessionQueuedHandler: ((SessionQueuedMessage) -> ())?
    var onSessionEndedHandler: ((SessionEndedMessage) -> ())?
    var onListeningStateChanged: ((Bool) -> ())?
    var onIntentNotRecognizedHandler: ((IntentNotRecognizedMessage) -> ())?
    var onTextCapturedHandler: ((TextCapturedMessage) -> ())?
    var onPartialTextCapturedHandler: ((TextCapturedMessage) -> ())?
    
    let soundQueue = DispatchQueue(label: "ai.snips.SnipsPlatformTests.sound", qos: .userInteractive)
    
    init() {}
    
    func start(enableInjection: Bool = false, enableASRPartial: Bool = false, asrPartialTextPeriodMs: Float = 1000) throws {
        let url = Bundle(for: type(of: self)).url(forResource: "assistant", withExtension: nil)!
        
        snips = try SnipsPlatform(assistantURL: url,
                                  enableHtml: false,
                                  enableLogs: false,
                                  enableInjection: enableInjection,
                                  enableAsrPartialText: enableASRPartial,
                                  g2pResources: enableInjection ? Bundle(for: type(of: self)).url(forResource: "snips-g2p-resources", withExtension: nil)! : nil,
                                  asrPartialTextPeriodMs: asrPartialTextPeriodMs)
        setupCallbacks()
        try snips?.start()
    }
    
    func stop() throws {
        snips = nil
        tearDown()
        try removeSnipsUserDataIfNecessary()
    }
    
    func tearDown() {
        if let activeSessionId = activeSessionId {
            // Try closing any leftover active session
            try! snips?.endSession(sessionId: activeSessionId)
            self.activeSessionId = nil
        }
        onIntentDetected = nil
        onHotwordDetected = nil
        speechHandler = nil
        onSessionStartedHandler = nil
        onSessionQueuedHandler = nil
        onSessionEndedHandler = nil
        onListeningStateChanged = nil
        onIntentNotRecognizedHandler = nil
        onTextCapturedHandler = nil
        onPartialTextCapturedHandler = nil
    }
    
    func setupCallbacks() {
        snips?.onIntentDetected = { [weak self] intent in
            self?.onIntentDetected?(intent)
        }
        snips?.onHotwordDetected = { [weak self] in
            self?.onHotwordDetected?()
        }
        snips?.onSessionStartedHandler = { [weak self] sessionStartedMessage in
            // Wait a bit to prevent timeout on slow machines. Probably due to race conditions in megazord.
            Thread.sleep(forTimeInterval: 2)
            self?.activeSessionId = sessionStartedMessage.sessionId
            self?.onSessionStartedHandler?(sessionStartedMessage)
        }
        snips?.onSessionQueuedHandler = { [weak self] sessionQueuedMessage in
            self?.onSessionQueuedHandler?(sessionQueuedMessage)
        }
        snips?.onSessionEndedHandler = { [weak self] sessionEndedMessage in
            if self?.activeSessionId == sessionEndedMessage.sessionId {
                self?.activeSessionId = nil
            }
            self?.onSessionEndedHandler?(sessionEndedMessage)
        }
        snips?.onListeningStateChanged = { [weak self] state in
            self?.onListeningStateChanged?(state)
        }
        snips?.speechHandler = { [weak self] sayMessage in
            self?.speechHandler?(sayMessage)
        }
        snips?.onIntentNotRecognizedHandler = { [weak self] message in
            self?.onIntentNotRecognizedHandler?(message)
        }
        snips?.onTextCapturedHandler = { [weak self] text in
            self?.onTextCapturedHandler?(text)
        }
        snips?.onPartialTextCapturedHandler = { [weak self] text in
            self?.onPartialTextCapturedHandler?(text)
        }
    }
    
    func playAudio(forResource resource: String?, withExtension ext: String? = "wav", completionHandler: (() -> ())? = nil) {
        let audioURL = Bundle(for: type(of: self)).url(forResource: resource, withExtension: ext)!
        
        let closure = { [weak self] in
            let audioFile = try! AVAudioFile(forReading: audioURL, commonFormat: .pcmFormatInt16, interleaved: true)
            let soundBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: kFrameCapacity)!
            let silenceBuffer = [Int16](repeating: 0, count: Int(kFrameCapacity))
            
            for _ in 0..<100 {
                try! self?.snips?.appendBuffer(silenceBuffer)
            }
            while let _ = try? audioFile.read(into: soundBuffer, frameCount: kFrameCapacity) {
                try! self?.snips?.appendBuffer(soundBuffer)
            }
            for _ in 0..<100 {
                try! self?.snips?.appendBuffer(silenceBuffer)
            }
        }
        
        // TODO: Hack to send audio after few seconds to wait for the ASR to really listen.
        soundQueue.asyncAfter(deadline: .now() + 1, execute: closure)
    }
    
    func removeSnipsUserDataIfNecessary() throws {
        let manager = FileManager.default
        let snipsUserDocumentURL = try manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("snips")
        var isDirectory = ObjCBool(true)
        let exists = manager.fileExists(atPath: snipsUserDocumentURL.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            try manager.removeItem(at: snipsUserDocumentURL)
        }
    }
}
