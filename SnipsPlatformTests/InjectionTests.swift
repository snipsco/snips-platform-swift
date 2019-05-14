//
//  BaseTests.swift
//  AllTests-iOS
//
//  Copyright © 2019 Snips. All rights reserved.
//

import XCTest
@testable import SnipsPlatform

class InjectionTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        try! SnipsEngine.shared.start(enableInjection: true)
    }

    override class func tearDown() {
        super.tearDown()
        try! SnipsEngine.shared.stop()
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
        
        let injectionBlock = {
            let operation = InjectionRequestOperation(entities: ["locality": ["wonderland"], "region": ["wonderland"]], kind: .add)
            do {
                try SnipsEngine.shared.snips?.requestInjection(with: InjectionRequestMessage(operations: [operation]))
            } catch let error {
                XCTFail("Injection failed, reason: \(error)")
            }
        }
        
        SnipsEngine.shared.onListeningStateChanged = { isListening in
            if isListening {
                switch testPhase {
                case .entityNotInjectedShouldNotBeDetected, .entityInjectedShouldBeDetected:
                    SnipsEngine.shared.playAudio(forResource: kWonderlandAudioFile)
                    break
                case .injectingEntities: XCTFail("For test purposes, shouldn't start listening in this state")
                }
            }
        }
        
        SnipsEngine.shared.onIntentDetected = { intentMessage in
            let slotLocalityWonderland = intentMessage.slots.filter { $0.entity == "locality" && $0.rawValue == "wonderland" }
            
            switch testPhase {
            case .entityNotInjectedShouldNotBeDetected:
                XCTAssertEqual(slotLocalityWonderland.count, 0, "should not have found any slot")
                entityNotInjectedShouldNotBeDetectedExpectation.fulfill()
                try! SnipsEngine.shared.snips?.endSession(sessionId: intentMessage.sessionId)
                testPhase = .injectingEntities
                injectionBlock()
                
                // TODO: Hack to wait for the injection to be finished + models fully reloaded.
                // Remove this when the platform will have a callback to notify for injection status.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) {
                    injectingEntitiesExpectation.fulfill()
                    testPhase = .entityInjectedShouldBeDetected
                    try! SnipsEngine.shared.snips?.startSession()
                }
                
            case .entityInjectedShouldBeDetected:
                XCTAssertEqual(slotLocalityWonderland.count, 1, "should have found the slot wonderland")
                entityInjectedShouldBeDetectedExpectation.fulfill()
                try! SnipsEngine.shared.snips?.endSession(sessionId: intentMessage.sessionId)
                
            case .injectingEntities: XCTFail("For test purposes, intents shouldn't be detected while injecting")
            }
        }
        
        try! SnipsEngine.shared.snips?.startSession()
        
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
