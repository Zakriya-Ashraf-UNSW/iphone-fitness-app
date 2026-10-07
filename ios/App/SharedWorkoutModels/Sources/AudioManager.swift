import Foundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

public final class AudioManager: @unchecked Sendable {
    public static let shared = AudioManager()

    public var isMuted: Bool = false

    private init() {
        #if canImport(AVFoundation)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Ambient audio session setup failure is non-fatal
        }
        #endif
    }

    /// Plays a resonant chime when a rest interval finishes
    public func playTimerComplete() {
        guard !isMuted else { return }
        #if canImport(AudioToolbox)
        // System Sound 1005: alert beep / chime
        AudioServicesPlaySystemSound(1005)
        #endif
    }

    /// Plays a celebratory fanfare when an overload PR is logged or workout completes
    public func playFanfare() {
        guard !isMuted else { return }
        #if canImport(AudioToolbox)
        // System Sound 1025: fanfare / achievement chime
        AudioServicesPlaySystemSound(1025)
        #endif
    }

    /// Subtle tick tone during final 3 seconds of countdown
    public func playCountdownTick() {
        guard !isMuted else { return }
        #if canImport(AudioToolbox)
        // System Sound 1057: subtle keyboard / UI tap sound
        AudioServicesPlaySystemSound(1057)
        #endif
    }
}
