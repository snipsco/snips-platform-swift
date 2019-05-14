//
//  BaseTests.swift
//  AllTests-iOS
//
//  Copyright © 2019 Snips. All rights reserved.
//

import XCTest
@testable import SnipsPlatform

class ASRPartialTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        try! SnipsEngine.shared.start(enableASRPartial: true)
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
    
    func test_asr_text_captured_handler() {
        let onTextCaptured = expectation(description: "ASR Text was captured")
        
        SnipsEngine.shared.onSessionStartedHandler = { _ in
            SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
        }
        
        SnipsEngine.shared.onTextCapturedHandler = { message in
            if message.text == "what will be the weather in madagascar in two days" {
                onTextCaptured.fulfill()
            } else {
                XCTFail("Text captured wasn't equal to the text sent")
            }
        }
        
        try! SnipsEngine.shared.snips?.startSession(text: nil, intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: true, customData: nil, siteId: nil)
        
        wait(for: [onTextCaptured], timeout: 40)
    }
    
    func test_asr_partial_text_captured_handler() {
        let onTextCaptured = expectation(description: "Partial ASR Text was captured")
        
        SnipsEngine.shared.onSessionStartedHandler = { _ in
            SnipsEngine.shared.playAudio(forResource: kWeatherAudioFile)
        }
        
        SnipsEngine.shared.onPartialTextCapturedHandler = { message in
            if message.text == "what will be the weather in madagascar in two days" {
                onTextCaptured.fulfill()
            }
        }
        
        try! SnipsEngine.shared.snips?.startSession(text: nil, intentFilter: nil, canBeEnqueued: false, sendIntentNotRecognized: false, customData: nil, siteId: nil)
        
        wait(for: [onTextCaptured], timeout: 40)
    }

}
