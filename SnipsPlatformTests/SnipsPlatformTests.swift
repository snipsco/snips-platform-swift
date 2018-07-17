//
//  SnipsPlatformTests.swift
//  SnipsPlatformTests
//
//  Copyright © 2017 Snips. All rights reserved.
//

import XCTest
import AVFoundation
@testable import SnipsPlatform

// To add your own audio, simply record with QuicktimeTime Player > File > New Audio Recording.
// Once recorded goto File > Export as > Audio only, it will save a .m4a file.
// Drag & drop into the project, enjoy!

class SnipsPlatformTests: XCTestCase {
    var snips: SnipsPlatform?
    
    let audioEngine = AVAudioEngine()
    let snipsAudioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 16_000,
                                         channels: 1,
                                         interleaved: true)
    let downMixer = AVAudioMixerNode()
    var currentAudioPlayer: AVAudioPlayerNode?
    
    var onIntentDetected: ((IntentMessage) -> ())?
    var onHotwordDetected: (() -> ())?
    var onSessionStartedHandler: ((SessionStartedMessage) -> ())?
    var onSessionQueuedHandler: ((SessionQueuedMessage) -> ())?
    var onSessionEndedHandler: ((SessionEndedMessage) -> ())?
    var onListeningStateChanged: ((Bool) -> ())?
    
    override func setUp() {
        super.setUp()
        try! setupSnipsPlatform()
        try! setupAudioEngine()
    }
    
    func test_hotword() {
        let hotwordDetectedExpectation = expectation(description: "Hotword detected")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onHotwordDetected = {
            hotwordDetectedExpectation.fulfill()
        }
        onSessionStartedHandler = { [weak self] sessionStarted in
            try! self?.snips?.endSession(sessionId: sessionStarted.sessionId)
        }
        onSessionEndedHandler = { sessionEnded in
            sessionEndedExpectation.fulfill()
        }
        try! playAudio(forResource: "hey snips", withExtension: "m4a")
        wait(for: [hotwordDetectedExpectation, sessionEndedExpectation], timeout: 10)
    }
    
    func test_intent() {
        let ovenModeSlotExpectation = expectation(description: "Cook mode slot")
        let dishSlotExpectation = expectation(description: "Dish name slot")
        let durationSlotExpectation = expectation(description: "Duration slot")
        let sessionEndedExpectation = expectation(description: "Session ended")
               
        onListeningStateChanged = { [weak self] state in
            if state {
                try! self?.playAudio(forResource: "Cook this chicken for 20min", withExtension: "m4a")
            }
        }
        
        onIntentDetected = { [weak self] intent in
            guard let intentClassifierResult = intent.intent else {
                XCTFail("Intent doesn't contain an intent classifier result")
                return
            }
            
            XCTAssert(intent.input == "cook this chicken for twenty minutes")
            XCTAssert(intentClassifierResult.intentName.contains("cook"))
            XCTAssert(intent.slots.count == 3)
            
            intent.slots.forEach { slot in
                if slot.entity.contains("oven_mode") {
                    if case .custom(let slotValue) = slot.value {
                        XCTAssert(slotValue == "Cook")
                        ovenModeSlotExpectation.fulfill()
                    }
                }
                else if slot.entity.contains("dish") {
                    if case .custom(let slotValue) = slot.value {
                        XCTAssert(slotValue == "chicken")
                        dishSlotExpectation.fulfill()
                    }
                }
                else if slot.entity.contains("snips/duration") {
                    if case .duration(let slotValue) = slot.value {
                        XCTAssert(slotValue.minutes == 20)
                        durationSlotExpectation.fulfill()
                    }
                }
            }
            try! self?.snips?.endSession(sessionId: intent.sessionId)
        }
        
        onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }
        
        try! snips?.startSession(intentFilter: [], canBeEnqueued: true)
        wait(for: [ovenModeSlotExpectation, dishSlotExpectation, durationSlotExpectation, sessionEndedExpectation], timeout: 30)
    }
    
    func test_emtpy_intent_filter_intent_not_recognized() {
        let intentNotRecognizedExpectation = expectation(description: "Intent not recognized")
        
        onSessionStartedHandler = { [weak self] _ in
            try! self?.playAudio(forResource: "Cook this chicken for 20min", withExtension: "m4a")
        }
        
        onSessionEndedHandler = { sessionEndedMessage in
            XCTAssert(sessionEndedMessage.sessionTermination.terminationType == .intentNotRecognized)
            intentNotRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(message: StartSessionMessage(initType: .action(text: nil, intentFilter: ["nonExistentIntent"], canBeEnqueued: false)))
        waitForExpectations(timeout: 10)
    }
    
    func test_itent_filter() {
        let intentRecognizedExpectation = expectation(description: "Intent recognized")
        
        onSessionStartedHandler = { [weak self] _ in
            try! self?.playAudio(forResource: "Cook this chicken for 20min", withExtension: "m4a")
        }
        
        onIntentDetected = { [weak self] intent in
            try! self?.snips?.endSession(sessionId: intent.sessionId)
            intentRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(message: StartSessionMessage(initType: .action(text: nil, intentFilter: ["cook_EN_v1-1"], canBeEnqueued: false)))
        waitForExpectations(timeout: 10)
    }
    
    func test_session_notification() {
        let notificationSentExpectation = expectation(description: "Notification sent")
        let notificationStartMessage = StartSessionMessage(initType: .notification(text: "Notification text"), customData: "Notification custom data", siteId: "iOS notification")
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssert(sessionStartedMessage.siteId == notificationStartMessage.siteId)
            XCTAssert(sessionStartedMessage.customData == notificationStartMessage.customData)
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        onSessionEndedHandler = { _ in
            notificationSentExpectation.fulfill()
        }
        
        try! snips?.startSession(message: notificationStartMessage)
        waitForExpectations(timeout: 10)
    }
    
    func test_session_action() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: "Action!", intentFilter: [], canBeEnqueued: false), customData: "Action Custom data", siteId: "iOS action")
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssert(sessionStartedMessage.customData == actionStartSessionMessage.customData)
            XCTAssert(sessionStartedMessage.customData == actionStartSessionMessage.customData)
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        onSessionEndedHandler = { _ in
            actionSentExpectation.fulfill()
        }
        try! snips?.startSession(message: actionStartSessionMessage)
        waitForExpectations(timeout: 10)
    }
    
    func test_dialog_scenario() {
        let startSessionMessage = StartSessionMessage(initType: .notification(text: "Notification"), customData: "foobar", siteId: "iOS")
        var continueSessionMessage: ContinueSessionMessage?
        var endSessionMessage: EndSessionMessage?
        var hasSentContinueSessionMessage = false
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssert(sessionStartedMessage.siteId == startSessionMessage.siteId!)
            XCTAssert(sessionStartedMessage.customData! == startSessionMessage.customData!)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continueSessionMessage = ContinueSessionMessage(sessionId: sessionStartedMessage.sessionId, text: "Continue session", intentFilter: [])
                hasSentContinueSessionMessage = true
                try! self?.snips?.continueSession(message: continueSessionMessage!)
            }
        }
        
        onSessionQueuedHandler = { [weak self] sessionQueuedMessage in
            if hasSentContinueSessionMessage {
                XCTAssert(sessionQueuedMessage.customData == continueSessionMessage?.text)
            }
            endSessionMessage = EndSessionMessage(sessionId: sessionQueuedMessage.sessionId, text: "End session")
            try! self?.snips?.endSession(message: endSessionMessage!)
        }
        
        onSessionEndedHandler = { sessionEndedMessage in
            XCTAssert(sessionEndedMessage.customData == startSessionMessage.customData!)
            XCTAssert(sessionEndedMessage.sessionTermination.terminationType == .nominal)
            sessionEndedExpectation.fulfill()
        }
        
        try! snips?.startSession(message: startSessionMessage)
        wait(for: [sessionEndedExpectation], timeout: 10)
    }
    
    
    override func tearDown() {
        currentAudioPlayer?.stop()
        audioEngine.stop()
        try! snips?.pause()
        super.tearDown()
    }
}

extension SnipsPlatformTests {
    
    func setupSnipsPlatform() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "kitchen_assistant_en", withExtension: nil)!
        snips = try! SnipsPlatform(assistantURL: url, enableLogs: true)
        
        snips?.onIntentDetected = { [weak self] intent in
            self?.onIntentDetected?(intent)
        }
        snips?.onHotwordDetected = { [weak self] in
            self?.onHotwordDetected?()
        }
        snips?.snipsWatchHandler = { log in
//            NSLog(log)
        }
        snips?.onSessionStartedHandler = { [weak self] sessionStartedMessage in
            self?.onSessionStartedHandler?(sessionStartedMessage)
        }
        snips?.onSessionQueuedHandler = { [weak self] sessionQueuedMessage in
            self?.onSessionQueuedHandler?(sessionQueuedMessage)
        }
        snips?.onSessionEndedHandler = { [weak self] sessionEndedMessage in
            self?.onSessionEndedHandler?(sessionEndedMessage)
        }
        snips?.onListeningStateChanged = { [weak self] state in
            self?.onListeningStateChanged?(state)
        }
        
        try! snips?.start()
    }
    
    func setupAudioEngine() throws {
        audioEngine.attach(downMixer)
        audioEngine.connect(downMixer, to: audioEngine.mainMixerNode, format: snipsAudioFormat)
        downMixer.installTap(onBus: 0, bufferSize: 1024, format: snipsAudioFormat) { [weak self] (buffer, time) in
            self?.snips?.appendBuffer(buffer)
        }
        try audioEngine.start()
    }
    
    func playAudio(forResource: String, withExtension: String?, completionHandler: (() -> ())? = nil) throws {
        let audioURL = Bundle(for: type(of: self)).url(forResource: forResource, withExtension: withExtension)!
        let audioFile = try AVAudioFile(forReading: audioURL)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(audioFile.length))!
        let audioFilePlayer = AVAudioPlayerNode()
        audioEngine.attach(audioFilePlayer)
        audioEngine.connect(audioFilePlayer, to: downMixer, format: audioFile.processingFormat)
        
        audioFilePlayer.play()
        audioFilePlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
        audioFilePlayer.scheduleBuffer(audioFileBuffer) { completionHandler?() }
        
        // Cleanup previous AVAudioPlayerNode.
        // It's done after scheduling the next audio player becauses we need the downMixer to keep streaming to the platform.
        if let currentAudioPlayer = currentAudioPlayer {
            DispatchQueue.global().async { [weak self] in
                currentAudioPlayer.stop()
                self?.audioEngine.detach(currentAudioPlayer)
                self?.currentAudioPlayer = audioFilePlayer
            }
        }
    }
}
