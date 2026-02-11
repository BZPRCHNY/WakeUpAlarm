import AVFoundation

final class AlarmSoundPlayer {

    static let shared = AlarmSoundPlayer()

    private var audioEngine: AVAudioEngine?
    private var toneNode: AVAudioSourceNode?
    private var isPlaying = false

    // Параметры звука
    private var frequency: Double = 880.0 // Гц — высокий раздражающий тон
    private var sampleRate: Double = 44100.0
    private var phase: Double = 0.0
    private var beepOn = true
    private var beepCounter: Int = 0

    private init() {}

    /// Запускает громкий будильник (пищащий тон)
    func startAlarm() {
        guard !isPlaying else { return }
        isPlaying = true
        phase = 0

        // Максимальная громкость
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate

        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = 2.0 * Double.pi * self.frequency / self.sampleRate

            for frame in 0..<Int(frameCount) {
                // Переключение beep on/off каждые 4000 сэмплов (~0.09 сек) — быстрый пик-пик
                self.beepCounter += 1
                if self.beepCounter >= 4000 {
                    self.beepCounter = 0
                    self.beepOn.toggle()
                }

                let value: Float
                if self.beepOn {
                    value = Float(sin(self.phase)) * 0.9
                    self.phase += phaseIncrement
                    if self.phase > 2.0 * Double.pi {
                        self.phase -= 2.0 * Double.pi
                    }
                } else {
                    value = 0
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value
                }
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mainMixer, format: outputFormat)

        do {
            try engine.start()
        } catch {
            print("Ошибка запуска звука: \(error)")
        }

        self.audioEngine = engine
        self.toneNode = sourceNode
    }

    /// Останавливает будильник
    func stopAlarm() {
        audioEngine?.stop()
        audioEngine = nil
        toneNode = nil
        isPlaying = false
    }

    /// Тихий звук для поддержания работы в фоне
    func startSilentBackground() {
        guard !isPlaying else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        let silentNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = 0.0 // Тишина
                }
            }
            return noErr
        }

        engine.attach(silentNode)
        engine.connect(silentNode, to: mainMixer, format: outputFormat)

        do {
            try engine.start()
        } catch {
            print("Ошибка фонового звука: \(error)")
        }

        self.audioEngine = engine
        self.toneNode = silentNode
    }

    func stopSilentBackground() {
        stopAlarm()
    }
}
