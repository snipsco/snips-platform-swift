//
//  SnipsPlatformTests.swift
//  SnipsPlatformTests
//
//  Copyright © 2019 Snips. All rights reserved.
//

import XCTest
import AVFoundation
@testable import SnipsPlatform

let kHotwordAudioFile = "hey_snips"
let kWeatherAudioFile = "what_will_be_the_weather_in_Madagascar_in_two_days"
let kWonderlandAudioFile = "what_will_be_the_weather_in_Wonderland"
let kPlayMJAudioFile = "hey_snips_can_you_play_me_some_Michael_Jackson"
let kFrameCapacity: AVAudioFrameCount = 256

class SnipsPlatformTests: XCTestCase {
    var snips: SnipsPlatform?
    
    var onIntentDetected: ((IntentMessage) -> ())?
    var onHotwordDetected: (() -> ())?
    var speechHandler: ((SayMessage) -> ())?
    var onSessionStartedHandler: ((SessionStartedMessage) -> ())?
    var onSessionQueuedHandler: ((SessionQueuedMessage) -> ())?
    var onSessionEndedHandler: ((SessionEndedMessage) -> ())?
    var onListeningStateChanged: ((Bool) -> ())?
    var onIntentNotRecognizedHandler: ((IntentNotRecognizedMessage) -> ())?
    
    let soundQueue = DispatchQueue(label: "ai.snips.SnipsPlatformTests.sound", qos: .userInteractive)
    var firstTimePlayedAudio: Bool = true
    
    // MARK: - XCTestCase lifecycle
    
    override func setUp() {
        super.setUp()
        try! setupSnipsPlatform()
    }

    // MARK: - Tests
    
    func test_hotword() {
        let hotwordDetectedExpectation = expectation(description: "Hotword detected")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onHotwordDetected = hotwordDetectedExpectation.fulfill
        onSessionStartedHandler = { [weak self] sessionStarted in
            try! self?.snips?.endSession(sessionId: sessionStarted.sessionId)
        }
        onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }
        
        playAudio(forResource: kHotwordAudioFile)
        
        wait(for: [hotwordDetectedExpectation, sessionEndedExpectation], timeout: 20)
    }
    
    func test_intent() {
        let countrySlotExpectation = expectation(description: "City slot")
        let timeSlotExpectation = expectation(description: "Time slot")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        onListeningStateChanged = { [weak self] isListening in
            if isListening {
                self?.playAudio(forResource: kWeatherAudioFile)
            }
        }
        onIntentDetected = { [weak self] intent in
            XCTAssertEqual(intent.input, "what will be the weather in madagascar in two days")
            XCTAssertEqual(intent.intent.intentName, "searchWeatherForecast")
            XCTAssertEqual(intent.slots.count, 2)

            intent.slots.forEach { slot in
                if slot.slotName.contains("forecast_country") {
                    if case .custom(let country) = slot.value {
                        XCTAssertEqual(country, "Madagascar")
                        countrySlotExpectation.fulfill()
                    }
                } else if slot.slotName.contains("forecast_start_datetime") {
                    if case .instantTime(let instantTime) = slot.value {
                        XCTAssertEqual(instantTime.precision, .exact)
                        XCTAssertEqual(instantTime.grain, .day)
                        let dateInTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withDashSeparatorInDate, .withSpaceBetweenDateAndTime]
                        let instantTimeDate = formatter.date(from: instantTime.value)
                        XCTAssertEqual(Calendar.current.compare(dateInTwoDays!, to: instantTimeDate!, toGranularity: .day), .orderedSame)
                        timeSlotExpectation.fulfill()
                    }
                }
            }
            try! self?.snips?.endSession(sessionId: intent.sessionId)
        }
        onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }

        try! self.snips?.startSession(intentFilter: nil, canBeEnqueued: true)
        
        wait(for: [countrySlotExpectation, timeSlotExpectation, sessionEndedExpectation], timeout: 30)
    }
    
    func test_intent_not_recognized() {
        let onIntentNotRecognizedExpectation = expectation(description: "Intent was not recognized")
        
        onListeningStateChanged = { [weak self] isListening in
            if isListening {
                self?.playAudio(forResource: kPlayMJAudioFile)
            }
        }
        onIntentNotRecognizedHandler = { [weak self] message in
            onIntentNotRecognizedExpectation.fulfill()
            try! self?.snips?.endSession(sessionId: message.sessionId)
        }
        
        try! self.snips?.startSession(canBeEnqueued: false, sendIntentNotRecognized: true)
        wait(for: [onIntentNotRecognizedExpectation], timeout: 20)
    }
    
    func test_empty_intent_filter_intent_not_recognized() {
        let intentNotRecognizedExpectation = expectation(description: "Intent not recognized")
        
        onListeningStateChanged = { [weak self] isListening in
            if isListening {
                self?.playAudio(forResource: kWeatherAudioFile)
            }
        }
        onSessionEndedHandler = { sessionEndedMessage in
            XCTAssertEqual(sessionEndedMessage.sessionTermination.terminationType, .intentNotRecognized)
            intentNotRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(intentFilter: ["nonExistentIntent"], canBeEnqueued: false)
        waitForExpectations(timeout: 20)
    }
    
    func test_intent_filter() {
        let intentRecognizedExpectation = expectation(description: "Intent recognized")
        
        onListeningStateChanged = { [weak self] isListening in
            if isListening {
                self?.playAudio(forResource: kWeatherAudioFile)
            }
        }
        onIntentDetected = { [weak self] intent in
            try! self?.snips?.endSession(sessionId: intent.sessionId)
            intentRecognizedExpectation.fulfill()
        }
        
        try! snips?.startSession(intentFilter: ["searchWeatherForecast"], canBeEnqueued: false)
        waitForExpectations(timeout: 20)
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
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        
        try! snips?.startSession(intentFilter: nil, canBeEnqueued: false)
        wait(for: [listeningStateChangedOn, listeningStateChangedOff], timeout: 5)
    }
    
    func test_session_notification() {
        let notificationSentExpectation = expectation(description: "Notification sent")
        let notificationStartMessage = StartSessionMessage(initType: .notification(text: "Notification text"), customData: "Notification custom data", siteId: "iOS notification")
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.siteId, notificationStartMessage.siteId)
            XCTAssertEqual(sessionStartedMessage.customData, notificationStartMessage.customData)
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        onSessionEndedHandler = { _ in
            notificationSentExpectation.fulfill()
        }
        
        try! snips?.startSession(message: notificationStartMessage)
        waitForExpectations(timeout: 20)
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
        waitForExpectations(timeout: 20)
    }
    
    func test_session_action() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: "Action!", intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: false), customData: "Action Custom data", siteId: "iOS action")
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.customData, actionStartSessionMessage.customData)
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        onSessionEndedHandler = { _ in
            actionSentExpectation.fulfill()
        }
        
        try! snips?.startSession(message: actionStartSessionMessage)
        waitForExpectations(timeout: 20)
    }
    
    func test_session_action_nil() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: nil, intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: false), customData: nil, siteId: nil)
        
        onSessionStartedHandler = { [weak self] sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.customData, actionStartSessionMessage.customData)
            try! self?.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        onSessionEndedHandler = { _ in
            actionSentExpectation.fulfill()
        }
        try! snips?.startSession(message: actionStartSessionMessage)
        waitForExpectations(timeout: 20)
    }
    
    func test_speech_handler() {
        let speechExpectation = expectation(description: "Testing speech")
        let messageToSpeak = "Testing speech"
        
        speechHandler = { [weak self] sayMessage in
            XCTAssertEqual(sayMessage.text, messageToSpeak)
            guard let sessionId = sayMessage.sessionId else {
                XCTFail("Message should have a session Id since it was sent from a notification")
                return
            }
            try! self?.snips?.notifySpeechEnded(messageId: sayMessage.messageId, sessionId: sessionId)
            try! self?.snips?.endSession(sessionId: sessionId)
            speechExpectation.fulfill()
        }
        
        try! snips?.startNotification(text: messageToSpeak)
        waitForExpectations(timeout: 15)
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
            XCTAssertEqual(sessionEndedMessage.sessionTermination.terminationType, .nominal)
            
            if !hasSentContinueSessionMessage {
                hasSentContinueSessionMessage = true
                continueSessionMessage = ContinueSessionMessage(sessionId: sessionEndedMessage.sessionId, text: "Continue session", intentFilter: nil)
                try! self?.snips?.continueSession(message: continueSessionMessage!)
                self?.playAudio(forResource: kHotwordAudioFile)
            }
            else {
                sessionEndedExpectation.fulfill()
            }
        }
        
        try! snips?.startSession(message: startSessionMessage)
        waitForExpectations(timeout: 20)
    }
    
    func test_injection() {
        enum TestPhaseKind {
            case entityNotInjectedShouldNotBeDetected
            case injectingEntities
            case entityInjectedShouldBeDetected
        }
        
        let entityNotInjectedShouldNotBeDetectedExpectation = expectation(description: "Entity not injected was not detected")
        let injectingEntitiesExpectation = expectation(description: "Injecting entities done")
        let entityInjectedShouldBeDetectedExpectation = expectation(description: "Entity injected was detected")
        
        var testPhase: TestPhaseKind = .entityNotInjectedShouldNotBeDetected
        
        let injectionBlock = { [weak self] in
            let operation = InjectionRequestOperation(entities: ["locality": ["wonderland"], "region": ["wonderland"]], kind: .add)
            do {
                try self?.snips?.requestInjection(with: InjectionRequestMessage(operations: [operation]))
            } catch let error {
                XCTFail("Injection failed, reason: \(error)")
            }
        }
        
        onListeningStateChanged = { [weak self] isListening in
            if isListening {
                switch testPhase {
                case .entityNotInjectedShouldNotBeDetected, .entityInjectedShouldBeDetected:
                    self?.playAudio(forResource: kWonderlandAudioFile)
                    break
                case .injectingEntities: XCTFail("For test purposes, shouldn't start listening in this state")
                }
            }
        }
        
        onIntentDetected = { [weak self] intentMessage in
            let slotLocalityWonderland = intentMessage.slots.filter { $0.entity == "locality" && $0.rawValue == "wonderland" }
            
            switch testPhase {
            case .entityNotInjectedShouldNotBeDetected:
                XCTAssertEqual(slotLocalityWonderland.count, 0, "should not have found any slot")
                entityNotInjectedShouldNotBeDetectedExpectation.fulfill()
                try! self?.snips?.endSession(sessionId: intentMessage.sessionId)
                testPhase = .injectingEntities
                injectionBlock()
                
                // TODO: Hack to wait for the injection to be finished + models fully reloaded.
                // Remove this when the platform will have a callback to notify for injection status.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) {
                    injectingEntitiesExpectation.fulfill()
                    testPhase = .entityInjectedShouldBeDetected
                    try! self?.snips?.startSession()
                }
                
            case .entityInjectedShouldBeDetected:
                XCTAssertEqual(slotLocalityWonderland.count, 1, "should have found the slot wonderland")
                entityInjectedShouldBeDetectedExpectation.fulfill()
                try! self?.snips?.endSession(sessionId: intentMessage.sessionId)
                
            case .injectingEntities: XCTFail("For test purposes, intents shouldn't be detected while injecting")
            }
        }
        
        try! self.snips?.startSession()
        
        wait(
            for: [
                entityNotInjectedShouldNotBeDetectedExpectation,
                injectingEntitiesExpectation,
                entityInjectedShouldBeDetectedExpectation,
            ],
            timeout: 100,
            enforceOrder: true
        )
    }
}

private extension SnipsPlatformTests {
    
    func setupSnipsPlatform(userURL: URL? = nil) throws {
        let url = Bundle(for: type(of: self)).url(forResource: "assistant", withExtension: nil)!
        let g2pResources = Bundle(for: type(of: self)).url(forResource: "snips-g2p-resources", withExtension: nil)!
        
        try removeSnipsUserDataIfNecessary()
        
        snips = try SnipsPlatform(assistantURL: url,
                                  enableHtml: false,
                                  enableLogs: false,
                                  enableInjection: true,
                                  userURL: userURL,
                                  g2pResources: g2pResources)
        
        snips?.onIntentDetected = { [weak self] intent in
            self?.onIntentDetected?(intent)
        }
        snips?.onHotwordDetected = { [weak self] in
            self?.onHotwordDetected?()
        }
        snips?.onSessionStartedHandler = { [weak self] sessionStartedMessage in
            // Wait a bit to prevent timeout on slow machines. Probably due to race conditions in megazord.
            Thread.sleep(forTimeInterval: 2)
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
        snips?.onIntentNotRecognizedHandler = { [weak self] message in
            self?.onIntentNotRecognizedHandler?(message)
        }
        
        try snips?.start()
        
        // TODO: Hack to wait for the platform to be fully loaded.
        // Remove this when SnipsPlatform.start() will be blocking.
        Thread.sleep(forTimeInterval: 5)
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
        let snipsUserDocumentURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("snips")
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: snipsUserDocumentURL.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            try FileManager.default.removeItem(at: snipsUserDocumentURL)
        }
    }
}
