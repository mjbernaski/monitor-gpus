import Foundation
import AVFoundation

#if os(watchOS)
import WatchKit
#endif

@MainActor
class SoundService {
    static let shared = SoundService()

    @Published var soundEnabled = true

    private let volume: Float = 0.15
    private let toneDuration: Double = 0.1

    #if !os(watchOS)
    private var audioPlayer: AVAudioPlayer?

    func playUpSound() {
        guard soundEnabled else { return }
        playTone(frequency: 880)
    }

    func playDownSound() {
        guard soundEnabled else { return }
        playTone(frequency: 440)
    }

    func playVengeanceTone(wattage: Double) {
        guard soundEnabled else { return }

        // Ascend from E3 to E5 as power rises from 100 W to 500 W.
        // Interpolate geometrically so equal wattage steps sound like equal pitch steps.
        let normalizedWattage = min(max((wattage - 100) / 400, 0), 1)
        let lowFrequency = 164.81
        let highFrequency = 659.25
        let frequency = lowFrequency * pow(highFrequency / lowFrequency, normalizedWattage)
        playTone(frequency: frequency)
    }

    private func playTone(frequency: Double) {
        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * toneDuration)

        // WAV header + 16-bit PCM data
        let dataSize = sampleCount * 2
        let fileSize = 44 + dataSize

        var wav = Data(capacity: fileSize)

        // RIFF header
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        wav.append(littleEndian: UInt32(fileSize - 8))
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wav.append(littleEndian: UInt32(16))       // chunk size
        wav.append(littleEndian: UInt16(1))        // PCM format
        wav.append(littleEndian: UInt16(1))        // mono
        wav.append(littleEndian: UInt32(44100))    // sample rate
        wav.append(littleEndian: UInt32(88200))    // byte rate
        wav.append(littleEndian: UInt16(2))        // block align
        wav.append(littleEndian: UInt16(16))       // bits per sample

        // data chunk
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wav.append(littleEndian: UInt32(dataSize))

        // Generate sine wave with fade-in/fade-out envelope
        let fadeLength = sampleCount / 4
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            var sample = sin(2.0 * .pi * frequency * t)

            // Envelope to avoid clicks
            if i < fadeLength {
                sample *= Double(i) / Double(fadeLength)
            } else if i > sampleCount - fadeLength {
                sample *= Double(sampleCount - i) / Double(fadeLength)
            }

            let int16Sample = Int16(clamping: Int(sample * 32767.0))
            wav.append(littleEndian: int16Sample)
        }

        audioPlayer = try? AVAudioPlayer(data: wav)
        audioPlayer?.volume = volume
        audioPlayer?.play()
    }
    #else
    func playUpSound() {
        guard soundEnabled else { return }
        WKInterfaceDevice.current().play(.start)
    }

    func playDownSound() {
        guard soundEnabled else { return }
        WKInterfaceDevice.current().play(.stop)
    }

    func playVengeanceTone(wattage: Double) {
        guard soundEnabled else { return }
        WKInterfaceDevice.current().play(.notification)
    }
    #endif
}

// MARK: - Data helper for little-endian encoding

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
