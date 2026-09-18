import AVFoundation

final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioURLPlayer: AVPlayer?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "en-US") {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: language)
        utter.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utter)
    }

    func speakHindi(_ text: String) { speak(text, language: "hi-IN") }

    func playAudioURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { speak(urlString); return }
        // Try to play remote audio if available
        audioURLPlayer = AVPlayer(url: url)
        audioURLPlayer?.play()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioURLPlayer?.pause()
    }
}
