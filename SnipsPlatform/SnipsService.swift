//
//  SnipsService.swift
//  SnipsPlatform
//
//  Copyright © 2017 Snips. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation
import AVFoundation
import SnipsPlatform

enum SnipsPlatformStatus {
    case stopped, started, paused
}

protocol SnipsServiceDelegate: class {
    func recordPremissionsDidUpdate(_ permission: AVAudioSession.RecordPermission)
    func onErrorLoadingAssistant()
    func onHotwordDetected()
    func onIntent(_ message: IntentMessage)
    func onIntentNotRecognizedHandler(_ message: IntentNotRecognizedMessage)
    func onListeningStateChanged(_ state: Bool)
    func onSnipsWatchHandler(_ log: String)
    func onServiceStatusChanged(_ status: SnipsPlatformStatus)
    
    func onSessionEnded(_ message: SessionEndedMessage)
    func onSessionStarted(_ message: SessionStartedMessage)
}

extension SnipsServiceDelegate {
    func recordPremissionsDidUpdate(_ permission: AVAudioSession.RecordPermission) {}
    func onErrorLoadingAssistant() {}
    func onHotwordDetected() {}
    func onIntent(_ intent: IntentMessage) {}
    func onIntentNotRecognizedHandler(_ message: IntentNotRecognizedMessage) {}
    func onListeningStateChanged(_ state: Bool) {}
    func onSnipsWatchHandler(_ log: String) {}
    func onServiceStatusChanged(_ status: SnipsPlatformStatus) {}
    
    func onSessionEnded(_ message: SessionEndedMessage) {}
    func onSessionStarted(_ message: SessionStartedMessage) {}
}

class SnipsService {
    
    static let shared: SnipsService = SnipsService()

    fileprivate(set) var snips: SnipsPlatform?
    fileprivate(set) var audioEngine: AVAudioEngine?
    fileprivate var audioSession: AVAudioSession?
    fileprivate var audioAlreadyPrepared = false
    
    var delegate: SnipsServiceDelegate? = nil
    var status = SnipsPlatformStatus.stopped
    
    init() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.pause()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.resume()
        }
        #endif
    }
    
    func start(with assistant: URL,
               audioEngine: AVAudioEngine? = nil,
               audioSession: AVAudioSession? = nil,
               hotwordSensitivity: Float = 0.5,
               enableHtml: Bool = false,
               enableLogs: Bool = false,
               enableInjection: Bool = false,
               userURL: URL? = nil,
               g2pResources: URL? = nil,
               asrModelParameters: AsrModelParameters? = nil) {
        self.audioEngine = audioEngine
        self.audioSession = audioSession
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            status = .stopped
            delegate?.onServiceStatusChanged(.stopped)
            print("Recording permission denied by the user")
            return
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { permission in
                DispatchQueue.main.sync { [weak self] in
                    self?.delegate?.recordPremissionsDidUpdate(AVAudioSession.sharedInstance().recordPermission)
                    self?.start(with: assistant, audioEngine: audioEngine, audioSession: audioSession)
                }
            }
            return
        case .granted: break
        }
        do {
            try startRecording()
        } catch let error {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                self?.snips = try SnipsPlatform(assistantURL: assistant, hotwordSensitivity: hotwordSensitivity, enableHtml: enableHtml, enableLogs: enableLogs, enableInjection: enableInjection, userURL: userURL, g2pResources: g2pResources, asrModelParameters: asrModelParameters)
            } catch {
                print("Failed to start SDK: \(error.localizedDescription)")
                return
            }
            
            self?.snips?.onIntentDetected = { intent in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onIntent(intent) }
            }
            self?.snips?.onHotwordDetected = {
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onHotwordDetected() }
            }
            self?.snips?.onSessionEndedHandler = { sessionEndedMessage in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onSessionEnded(sessionEndedMessage) }
            }
            self?.snips?.onListeningStateChanged = { state in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onListeningStateChanged(state) }
            }
            self?.snips?.snipsWatchHandler = { log in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onSnipsWatchHandler(log) }
            }
            self?.snips?.onSessionEndedHandler = { message in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onSessionEnded(message) }
            }
            self?.snips?.onIntentNotRecognizedHandler = { message in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onIntentNotRecognizedHandler(message) }
            }
            self?.snips?.onSessionStartedHandler = { message in
                DispatchQueue.main.sync { [weak self] in self?.delegate?.onSessionStarted(message) }
            }
            
            do {
                try self?.snips?.start()
                DispatchQueue.main.sync {
                    self?.status = .started
                    self?.delegate?.onServiceStatusChanged(.started)
                }
            } catch {
                DispatchQueue.main.sync {
                    self?.status = .stopped
                    self?.delegate?.onErrorLoadingAssistant()
                    self?.delegate?.onServiceStatusChanged(.stopped)
                }
            }
        }
    }
    
    func resume() {
        switch status {
        case .paused:
            do {
                try audioEngine?.start()
                try snips?.unpause()
                status = .started
                delegate?.onServiceStatusChanged(.started)
            } catch {
                print("Failed to resume platform, error:\n\(error)")
            }
        case .started, .stopped: break
        }
    }
    
    func pause() {
        switch status {
        case .started:
            do {
                audioEngine?.pause()
                try snips?.pause()
                status = .paused
                delegate?.onServiceStatusChanged(.paused)
            } catch {
                print("Failed to pause platform, error:\n\(error)")
            }
        case .stopped, .paused: break
        }
    }
    
    private func startRecording() throws {
        try prepareAudio()
        try audioEngine?.start()
    }
    
    private func prepareAudio() throws {
        guard !audioAlreadyPrepared else { return }
        if audioSession == nil { try setupAudioSession() }
        if audioEngine == nil { setupAudioEngine() }
        audioAlreadyPrepared = true
    }
    
    private func setupAudioSession() throws {
        audioSession = AVAudioSession.sharedInstance()
        try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP, .allowBluetooth])
        try audioSession?.setPreferredSampleRate(16_000)
        try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupAudioEngine() {
        let audioEngine = AVAudioEngine()
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                            sampleRate: 16_000,
                                            channels: 1,
                                            interleaved: true)
        
        let input = audioEngine.inputNode
        let downMixer = AVAudioMixerNode()
        audioEngine.attach(downMixer)
        audioEngine.connect(input, to: downMixer, format: nil)
        downMixer.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, time) in
            self?.snips?.appendBuffer(buffer)
        }
        self.audioEngine = audioEngine
    }
    
    
}
