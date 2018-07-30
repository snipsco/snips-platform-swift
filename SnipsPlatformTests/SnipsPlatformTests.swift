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
    var speechHandler: ((SayMessage) -> ())?
    var onSessionStartedHandler: ((SessionStartedMessage) -> ())?
    var onSessionQueuedHandler: ((SessionQueuedMessage) -> ())?
    var onSessionEndedHandler: ((SessionEndedMessage) -> ())?
    var onListeningStateChanged: ((Bool) -> ())?
    
    let hotwordAudioFile = "hey snips"
    let weatherAudioFile = "What will be the weather in Madagascar in two days"
    
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
        try! playAudio(forResource: hotwordAudioFile, withExtension: "m4a")
        wait(for: [hotwordDetectedExpectation, sessionEndedExpectation], timeout: 10)
    }
    
    func test_intent() {
        let countrySlotExpectation = expectation(description: "City slot")
        let timeSlotExpectation = expectation(description: "Time slot")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onSessionStartedHandler = { [weak self] _ in
            try! self?.playAudio(forResource: self?.weatherAudioFile, withExtension: "m4a")
        }
        
        onIntentDetected = { [weak self] intent in
            guard let intentClassifierResult = intent.intent else {
                XCTFail("Intent doesn't contain an intent classifier result")
                return
            }
            
            XCTAssert(intent.input == "what will be the weather in madagascar in two days")
            XCTAssert(intentClassifierResult.intentName == "searchWeatherForecast")
            XCTAssert(intent.slots.count == 2)
            
            intent.slots.forEach { slot in
                if slot.slotName.contains("forecast_country") {
                    if case .custom(let country) = slot.value {
                        XCTAssert(country == "Madagascar")
                        countrySlotExpectation.fulfill()
                    }
                }
                else if slot.slotName.contains("forecast_start_datetime") {
                    if case .instantTime(let instantTime) = slot.value {
                        XCTAssert(instantTime.precision == .exact)
                        XCTAssert(instantTime.grain == .day)
                        let dateInTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withDashSeparatorInDate, .withSpaceBetweenDateAndTime]
                        let instantTimeDate = formatter.date(from: instantTime.value)
                        XCTAssert(Calendar.current.compare(dateInTwoDays!, to: instantTimeDate!, toGranularity: .day) == .orderedSame)
                        timeSlotExpectation.fulfill()
                    }
                }
            }
            try! self?.snips?.endSession(sessionId: intent.sessionId)
        }
        
        onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }
        
        try! snips?.startSession(intentFilter: nil, canBeEnqueued: true)
        wait(for: [countrySlotExpectation, timeSlotExpectation, sessionEndedExpectation], timeout: 15)
    }
    
    func test_emtpy_intent_filter_intent_not_recognized() {
        let intentNotRecognizedExpectation = expectation(description: "Intent not recognized")
        
        onSessionStartedHandler = { [weak self] _ in
            try! self?.playAudio(forResource: self?.weatherAudioFile, withExtension: "m4a")
        }
        
        onSessionEndedHandler = { sessionEndedMessage in
            XCTAssert(sessionEndedMessage.sessionTermination.terminationType == .intentNotRecognized)
            intentNotRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(message: StartSessionMessage(initType: .action(text: nil, intentFilter: ["nonExistentIntent"], canBeEnqueued: false)))
        waitForExpectations(timeout: 10)
    }
    
    func test_intent_filter() {
        let intentRecognizedExpectation = expectation(description: "Intent recognized")
        
        onSessionStartedHandler = { [weak self] _ in
            try! self?.playAudio(forResource: self?.weatherAudioFile, withExtension: "m4a")
        }
        
        onIntentDetected = { [weak self] intent in
            try! self?.snips?.endSession(sessionId: intent.sessionId)
            intentRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(message: StartSessionMessage(initType: .action(text: nil, intentFilter: ["searchWeatherForecast"], canBeEnqueued: false)))
        waitForExpectations(timeout: 10)
    }
    
    func test_listening_state_changed() {
        let listeningStateChangedOn = expectation(description: "Listening state turned on")
        let listeningStateChangedOff = expectation(description: "Listening state turned off")
        
        onListeningStateChanged = { state in
            if state {
                listeningStateChangedOn.fulfill()
            } else {
                listeningStateChangedOff.fulfill()
            }
        }
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
            }
        }
        
        try! snips?.startSession(intentFilter: nil, canBeEnqueued: false)
        wait(for: [listeningStateChangedOn, listeningStateChangedOff], timeout: 5)
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
    
    func test_session_notification_nil() {
        let notificationSentExpectation = expectation(description: "Notification sent")
        let notificationStartMessage = StartSessionMessage(initType: .notification(text: "Notification text"), customData: nil, siteId: nil)
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
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
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: "Action!", intentFilter: nil, canBeEnqueued: false), customData: "Action Custom data", siteId: "iOS action")
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
    
    func test_session_action_nil() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: nil, intentFilter: nil, canBeEnqueued: false), customData: nil, siteId: nil)
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
    
    func test_speech_handler() {
        let speechExpectation = expectation(description: "Testing speech")
        let messageToSpeak = "Testing speech"
        speechHandler = { [weak self] sayMessage in
            XCTAssert(sayMessage.text == messageToSpeak)
            guard let sessionId = sayMessage.sessionId else {
                XCTFail("Message should have a session Id since it was sent from a notification")
                return
            }
            try! self?.snips?.notifySpeechEnded(messageId: sayMessage.messageId, sessionId: sessionId)
            try! self?.snips?.endSession(sessionId: sessionId)
            speechExpectation.fulfill()
        }
        
        try! snips?.startNotification(text: messageToSpeak)
        waitForExpectations(timeout: 5)
    }
    
    func test_dialog_scenario() {
        let startSessionMessage = StartSessionMessage(initType: .notification(text: "Notification"), customData: "foobar", siteId: "iOS")
        var continueSessionMessage: ContinueSessionMessage?
        var hasSentContinueSessionMessage = false
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        
        onSessionEndedHandler = { [weak self] sessionEndedMessage in
            XCTAssert(sessionEndedMessage.sessionTermination.terminationType == .nominal)
            
            if !hasSentContinueSessionMessage {
                hasSentContinueSessionMessage = true
                continueSessionMessage = ContinueSessionMessage(sessionId: sessionEndedMessage.sessionId, text: "Continue session", intentFilter: nil)
                try! self?.snips?.continueSession(message: continueSessionMessage!)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    try! self?.playAudio(forResource: self?.hotwordAudioFile, withExtension: "m4a")
                }
            }
            else {
                sessionEndedExpectation.fulfill()
            }
        }
        
        try! snips?.startSession(message: startSessionMessage)
        waitForExpectations(timeout: 10)
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
        let url = Bundle(for: type(of: self)).url(forResource: "assistant", withExtension: nil)!
        snips = try! SnipsPlatform(assistantURL: url, enableLogs: true)
        
        snips?.onIntentDetected = { [weak self] intent in
            self?.onIntentDetected?(intent)
        }
        snips?.onHotwordDetected = { [weak self] in
            self?.onHotwordDetected?()
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
        snips?.speechHandler = { [weak self] sayMessage in
            self?.speechHandler?(sayMessage)
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
    
    func playAudio(forResource: String?, withExtension: String?, completionHandler: (() -> ())? = nil) throws {
        guard let forResource = forResource else { throw NSError(domain: "Empty resource", code: 101, userInfo: nil) }
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
