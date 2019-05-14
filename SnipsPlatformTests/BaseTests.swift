//
//  BaseTests.swift
//  AllTests-iOS
//
//  Copyright © 2019 Snips. All rights reserved.
//

import XCTest
@testable import SnipsPlatform

class BaseTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        try! SnipsEngine.shared.start()
    }

    override class func tearDown() {
        super.tearDown()
        try! SnipsEngine.shared.stop()
    }
    
    override func tearDown() {
        super.tearDown()
        SnipsEngine.shared.tearDown()
        // TODO workaround to wait for the asr thread to stop, cf snips-megazord/src/lib.rs#L538
        Thread.sleep(forTimeInterval: 5)
    }

    func test_hotword() {
        let hotwordDetectedExpectation = expectation(description: "Hotword detected")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        SnipsEngine.shared.onHotwordDetected = hotwordDetectedExpectation.fulfill
        SnipsEngine.shared.onSessionStartedHandler = { sessionStarted in
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStarted.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }
        
        SnipsEngine.shared.playAudio(forResource: kHotwordAudioFile)
        
        wait(for: [hotwordDetectedExpectation, sessionEndedExpectation], timeout: 40)
    }
    
    func test_intent() {
        let countrySlotExpectation = expectation(description: "City slot")
        let timeSlotExpectation = expectation(description: "Time slot")
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        SnipsEngine.shared.onListeningStateChanged = { isListening in
            if isListening {
                SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
            }
        }
        SnipsEngine.shared.onIntentDetected = { intent in
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
            try! SnipsEngine.shared.snips?.endSession(sessionId: intent.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            sessionEndedExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(intentFilter: nil, canBeEnqueued: true)
        
        wait(for: [countrySlotExpectation, timeSlotExpectation, sessionEndedExpectation], timeout: 40)
    }
    
    func test_intent_not_recognized() {
        let onIntentNotRecognizedExpectation = expectation(description: "Intent was not recognized")
        
        SnipsEngine.shared.onListeningStateChanged = { isListening in
            if isListening {
                SnipsEngine.shared.playAudio(forResource: kPlayMJAudioFile)
            }
        }
        SnipsEngine.shared.onIntentNotRecognizedHandler = { message in
            onIntentNotRecognizedExpectation.fulfill()
            try! SnipsEngine.shared.snips?.endSession(sessionId: message.sessionId)
        }
        
        try! SnipsEngine.shared.snips?.startSession(canBeEnqueued: false, sendIntentNotRecognized: true)
        wait(for: [onIntentNotRecognizedExpectation], timeout: 40)
    }
    
    func test_empty_intent_filter_intent_not_recognized() {
        let intentNotRecognizedExpectation = expectation(description: "Intent not recognized")

        SnipsEngine.shared.onSessionStartedHandler = { _ in
            SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
        }
        SnipsEngine.shared.onSessionEndedHandler = { sessionEndedMessage in
            XCTAssertEqual(sessionEndedMessage.sessionTermination.terminationType, .intentNotRecognized)
            intentNotRecognizedExpectation.fulfill()
        }

        try! SnipsEngine.shared.snips?.startSession(intentFilter: [], canBeEnqueued: false)
        waitForExpectations(timeout: 40)
    }
    
    func test_unknown_intent_filter_error() {
        let intentNotRecognizedExpectation = expectation(description: "Error")
        
        SnipsEngine.shared.onListeningStateChanged = { isListening in
            if isListening {
                SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
            }
        }
        SnipsEngine.shared.onSessionEndedHandler = { sessionEndedMessage in
            XCTAssertEqual(sessionEndedMessage.sessionTermination.terminationType, .error)
            intentNotRecognizedExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(intentFilter: ["nonExistentIntent"], canBeEnqueued: false)
        waitForExpectations(timeout: 40)
    }
    
    func test_intent_filter() {
        let intentRecognizedExpectation = expectation(description: "Intent recognized")
        
        SnipsEngine.shared.onListeningStateChanged = { isListening in
            if isListening {
                SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
            }
        }
        SnipsEngine.shared.onIntentDetected = { intent in
            try! SnipsEngine.shared.snips?.endSession(sessionId: intent.sessionId)
            intentRecognizedExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(intentFilter: ["searchWeatherForecast"], canBeEnqueued: false)
        waitForExpectations(timeout: 40)
    }
    
    func test_listening_state_changed_on() {
        let listeningStateChangedOn = expectation(description: "Listening state turned on")
        
        SnipsEngine.shared.onListeningStateChanged = { state in
            if state {
                listeningStateChangedOn.fulfill()
            }
        }
        
        try! SnipsEngine.shared.snips?.startSession(intentFilter: nil, canBeEnqueued: true)
        wait(for: [listeningStateChangedOn], timeout: 30)
    }
    
    func test_listening_state_changed_off() {
        let listeningStateChangedOff = expectation(description: "Listening state turned off")
        var fullfilled = false
        SnipsEngine.shared.onListeningStateChanged = { state in
            // we can receive multiple Listening state turned off, only fullfill once
            if !state && !fullfilled {
                listeningStateChangedOff.fulfill()
                fullfilled = true
            }
        }
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        
        try! SnipsEngine.shared.snips?.startSession(intentFilter: nil, canBeEnqueued: false)
        wait(for: [listeningStateChangedOff], timeout: 15)
    }
    
    func test_session_notification() {
        let notificationSentExpectation = expectation(description: "Notification sent")
        let notificationStartMessage = StartSessionMessage(initType: .notification(text: "Notification text"), customData: "Notification custom data", siteId: "iOS notification")
        
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.siteId, notificationStartMessage.siteId)
            XCTAssertEqual(sessionStartedMessage.customData, notificationStartMessage.customData)
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            notificationSentExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(message: notificationStartMessage)
        waitForExpectations(timeout: 40)
    }
    
    func test_session_notification_nil() {
        let notificationSentExpectation = expectation(description: "Notification sent")
        let notificationStartMessage = StartSessionMessage(initType: .notification(text: "Notification text"), customData: nil, siteId: nil)
        
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            notificationSentExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(message: notificationStartMessage)
        waitForExpectations(timeout: 40)
    }
    
    func test_session_action() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: "Action!", intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: false), customData: "Action Custom data", siteId: "iOS action")
        
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.customData, actionStartSessionMessage.customData)
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            actionSentExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startSession(message: actionStartSessionMessage)
        waitForExpectations(timeout: 40)
    }
    
    func test_session_action_nil() {
        let actionSentExpectation = expectation(description: "Action sent")
        let actionStartSessionMessage = StartSessionMessage(initType: .action(text: nil, intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: false), customData: nil, siteId: nil)
        
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            XCTAssertEqual(sessionStartedMessage.customData, actionStartSessionMessage.customData)
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { _ in
            actionSentExpectation.fulfill()
        }
        try! SnipsEngine.shared.snips?.startSession(message: actionStartSessionMessage)
        waitForExpectations(timeout: 40)
    }
    
    func test_speech_handler() {
        let speechExpectation = expectation(description: "Testing speech")
        let messageToSpeak = "Testing speech"
        
        SnipsEngine.shared.speechHandler = { sayMessage in
            XCTAssertEqual(sayMessage.text, messageToSpeak)
            guard let sessionId = sayMessage.sessionId else {
                XCTFail("Message should have a session Id since it was sent from a notification")
                return
            }
            try! SnipsEngine.shared.snips?.notifySpeechEnded(messageId: sayMessage.messageId, sessionId: sessionId)
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionId)
            speechExpectation.fulfill()
        }
        
        try! SnipsEngine.shared.snips?.startNotification(text: messageToSpeak)
        waitForExpectations(timeout: 15)
    }
    
    func test_dialog_scenario() {
        let startSessionMessage = StartSessionMessage(initType: .notification(text: "Notification"), customData: "foobar", siteId: "iOS")
        var continueSessionMessage: ContinueSessionMessage?
        var hasSentContinueSessionMessage = false
        let sessionEndedExpectation = expectation(description: "Session ended")
        
        SnipsEngine.shared.onSessionStartedHandler = { sessionStartedMessage in
            try! SnipsEngine.shared.snips?.endSession(sessionId: sessionStartedMessage.sessionId)
        }
        SnipsEngine.shared.onSessionEndedHandler = { sessionEndedMessage in
            XCTAssertEqual(sessionEndedMessage.sessionTermination.terminationType, .nominal)
            
            if !hasSentContinueSessionMessage {
                hasSentContinueSessionMessage = true
                continueSessionMessage = ContinueSessionMessage(sessionId: sessionEndedMessage.sessionId, text: "Continue session", intentFilter: nil)
                try! SnipsEngine.shared.snips?.continueSession(message: continueSessionMessage!)
                SnipsEngine.shared.playAudio(forResource: kHotwordAudioFile)
            }
            else {
                sessionEndedExpectation.fulfill()
            }
        }
        
        try! SnipsEngine.shared.snips?.startSession(message: startSessionMessage)
        waitForExpectations(timeout: 40)
    }
    
    func test_dialoge_configuration() {
        let intentName = "searchWeatherForecast"
        let onIntentReceived = expectation(description: "Intent recognized after reenabling it in the dialogue configuration")
        let onIntentNotRecognized = expectation(description: "Intent not recognized because it has been disabled")
        let enableIntent = DialogueConfigureMessage(intents: [DialogueConfigureIntent(intentName: intentName, enable: true)])
        let disableIntent = DialogueConfigureMessage(intents: [DialogueConfigureIntent(intentName: intentName, enable: false)])
        
        SnipsEngine.shared.onSessionStartedHandler = { message in
            SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
        }
        
        SnipsEngine.shared.onIntentDetected = { intent in
            if intent.intent.intentName == intentName {
                onIntentReceived.fulfill()
            }
        }
        
        SnipsEngine.shared.onSessionEndedHandler = { message in
            if message.sessionTermination.terminationType == .timeout {
                onIntentNotRecognized.fulfill()
                try! SnipsEngine.shared.snips?.dialogueConfiguration(with: enableIntent)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    try! SnipsEngine.shared.snips?.startSession()
                }
            }
        }
        
        try! SnipsEngine.shared.snips?.dialogueConfiguration(with: disableIntent)
        try! SnipsEngine.shared.snips?.startSession()
        
        wait(for: [onIntentNotRecognized, onIntentReceived], timeout: 40, enforceOrder: true)
    }

}
