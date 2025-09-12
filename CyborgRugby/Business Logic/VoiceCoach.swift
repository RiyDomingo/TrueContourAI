//
//  VoiceCoach.swift
//  CyborgRugby
//
//  Voice coaching system for rugby scrum cap scanning
//

import AVFoundation

@MainActor
protocol VoiceCoachDelegate: AnyObject {
    func voiceCoachDidStartSpeaking(_ coach: VoiceCoach, message: VoiceCoach.CoachingMessage)
    func voiceCoachDidFinishSpeaking(_ coach: VoiceCoach, message: VoiceCoach.CoachingMessage)
    func voiceCoachEncounteredError(_ coach: VoiceCoach, error: Error)
}

@MainActor
class VoiceCoach: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    weak var delegate: VoiceCoachDelegate?
    private var currentMessage: CoachingMessage?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    enum CoachingMessage {
        case startScanning
        case holdSteady
        case goodPosition
        case adjustPosition(String)
        case poseComplete
        case scanningComplete
        case lightingIssue
        case achievementUnlocked(String)
        
        var text: String {
            switch self {
            case .startScanning:
                return "Start scanning now. Hold your head steady and follow the on-screen instructions."
            case .holdSteady:
                return "Hold steady... capturing your head shape."
            case .goodPosition:
                return "Perfect position! Keep holding steady."
            case .adjustPosition(let advice):
                return "Adjust your position: \(advice)"
            case .poseComplete:
                return "Great job! Pose complete."
            case .scanningComplete:
                return "Scanning complete! Your custom scrum cap measurements are ready."
            case .lightingIssue:
                return "Lighting looks low. Move to a brighter area or face a light source."
            case .achievementUnlocked(let achievement):
                return "Achievement unlocked: \(achievement)"
            }
        }
    }
    
    func speak(_ message: CoachingMessage, language: String = "en-US") {
        currentMessage = message
        
        let utterance = AVSpeechUtterance(string: message.text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        delegate?.voiceCoachDidStartSpeaking(self, message: message)
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentMessage = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceCoach: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if let message = currentMessage {
                delegate?.voiceCoachDidFinishSpeaking(self, message: message)
            }
            currentMessage = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentMessage = nil
        }
    }
}