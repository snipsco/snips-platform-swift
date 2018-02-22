//
//  ViewController.swift
//  SnipsPlatformDemo
//
//  Copyright © 2017 Snips. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import SnipsPlatform

class ViewController: UIViewController {
    private var snips: SnipsPlatform? = nil
    private let audioEngine = AVAudioEngine()
    
    var textView: UITextView!
    var startButton: UIButton!
    var recordButton: UIButton!
    
    // MARK: - View lifecycle
    
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white
        
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start dialogue", for: .normal)
        startButton.addTarget(self, action: #selector(startDialogueTapped), for: .touchUpInside)
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        self.startButton = startButton

        let textView = UITextView()
        textView.isEditable = false
        textView.backgroundColor = .lightGray
        textView.font = .systemFont(ofSize: 20)
        self.textView = textView
        
        let recordButton = UIButton(type: .system)
        recordButton.setTitle("Start", for: .normal)
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        recordButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        self.recordButton = recordButton
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(startButton)
        stackView.addArrangedSubview(textView)
        stackView.addArrangedSubview(recordButton)
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            ])
        
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Snips Voice Platform"
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        startButton.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestRecordPermission()
    }

    // MARK: UI actions
    
    @objc
    private func startDialogueTapped() {
        try! snips?.startSession(text: nil, intentFilter: [], canBeEnqueued: true, customData: nil)
    }
    
    @objc
    private func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            
            snips = nil
            
            startButton.isEnabled = false
            recordButton.setTitle("Start", for: .normal)
        } else {
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["ai.snips.assistant.snips"], in: .open)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            navigationController?.present(documentPicker, animated: true)
        }
    }
}

// MARK: API

extension ViewController {
    func startSnips(assistantURL url: URL) {
        // Start microphone
        try! startRecording()
        
        // Start snips
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.snips = try! SnipsPlatform(assistantURL: url, enableHtml: true, enableLogs: true)
            self?.snips?.onIntentDetected = { intent in
                print("intent detected: \(intent)")
                try! self?.snips?.endSession(sessionId: intent.sessionId, text: nil)
            }
            self?.snips?.onHotwordDetected = {
                print("hotword detected")
            }
            self?.snips?.snipsWatchHandler = { log in
                guard let htmlAttributedString = "\(log)<br />".htmlAttributedString else { return }
                
                DispatchQueue.main.async {
                    guard let actualHtmlAttributedString = self?.textView.attributedText else { return }
                    
                    let newAttributedString = NSMutableAttributedString(attributedString: actualHtmlAttributedString)
                    newAttributedString.append(htmlAttributedString)
                    self?.textView.attributedText = newAttributedString
                    
                    self?.textView.scrollRangeToVisible(NSMakeRange(newAttributedString.length, 0)) // scroll to bottom
                }
            }
            try! self?.snips?.start()

            DispatchQueue.main.async {
                self?.recordButton.setTitle("Stop recording", for: [])
                self?.startButton.isEnabled = true
            }
        }
    }
}

// MARK: - Microphone management

private extension ViewController {
    func requestRecordPermission() {
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { _ in
            // The callback may not be called on the main thread. Add an
            // operation to the main queue to update the record button's state.
            let recordPermission = audioSession.recordPermission()
            OperationQueue.main.addOperation {
                switch recordPermission {
                case .undetermined:
                    self.startButton.isEnabled = false
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Record not yet authorized", for: .disabled)
                    
                case .denied:
                    self.startButton.isEnabled = false
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to recording", for: .disabled)
                
                case .granted:
                    self.recordButton.isEnabled = true
                }
            }
        }
    }
    
    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setPreferredSampleRate(16_000)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                            sampleRate: 16_000,
                                            channels: 1,
                                            interleaved: true)
        
        let downMixer = AVAudioMixerNode()
        audioEngine.attach(downMixer)
        audioEngine.connect(inputNode, to: downMixer, format: nil)
        
        downMixer.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.snips?.appendBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { fatalError("Should have at least one url") }
        
        if url.startAccessingSecurityScopedResource() == true {
            startSnips(assistantURL: url)
        } else {
            print("Can't access securely to this URL")
        }
    }
}

private extension String {
    var htmlAttributedString: NSAttributedString? {
        guard let data = self.data(using: .utf16) else { return nil }
        guard let html = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil) else { return nil }
        return html
    }
}
