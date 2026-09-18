import Foundation
import Speech
import AVFoundation

enum SpeechAuthorizationStatus: Sendable {
    case authorized, denied, notDetermined, restricted
}

@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript: String = ""
    @Published var authorization: SpeechAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "hi-IN")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
        updateAuth()
    }

    func updateAuth() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: authorization = .authorized
        case .denied: authorization = .denied
        case .notDetermined: authorization = .notDetermined
        case .restricted: authorization = .restricted
        @unknown default: authorization = .denied
        }
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.updateAuth()
                    cont.resume(returning: status == .authorized)
                }
            }
        }
    }

    func startRecording() async -> Bool {
        if authorization != .authorized {
            let ok = await requestAuthorization()
            if !ok { return false }
        }
        // Audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return false }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return false }
        request.shouldReportPartialResults = true
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "hi-IN")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
        let inputNode = audioEngine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { return false }
        isRecording = true
        transcript = ""
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let r = result {
                Task { @MainActor in self.transcript = r.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in self.stopRecording() }
            }
        }
        return true
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
