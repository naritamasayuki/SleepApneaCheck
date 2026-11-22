import AVFoundation
import Foundation
import os

/// 音声解析エラー
enum AudioAnalyzerError: LocalizedError {
    case fileOpenFailed(Error)
    case invalidAudioFormat
    case emptyAudioData

    var errorDescription: String? {
        switch self {
        case .fileOpenFailed:
            return String(localized: "error.audio.open_failed")
        case .invalidAudioFormat:
            return String(localized: "error.audio.invalid_format")
        case .emptyAudioData:
            return String(localized: "error.audio.empty_data")
        }
    }
}

/// 録音音声またはPCMサンプルからいびき・無呼吸候補区間を解析するエンジン
enum AudioAnalyzer {
    private static let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "AudioAnalyzer")

    /// 無呼吸候補とみなす最小静寂時間（秒）— 医学的基準(10秒以上)に準拠
    static let minimumApneaPauseSeconds: TimeInterval = 10.0

    /// 音声ファイルURLを読み込んで解析を実行する
    static func analyzeFile(
        at url: URL,
        sensitivity: AudioSensitivity = .standard,
        recordedAt: Date = Date()
    ) throws -> SleepAudioSession {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            logger.error("音声ファイルオープン失敗: \(error.localizedDescription)")
            throw AudioAnalyzerError.fileOpenFailed(error)
        }

        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0, format.sampleRate > 0 else {
            throw AudioAnalyzerError.emptyAudioData
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioAnalyzerError.invalidAudioFormat
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            logger.error("音声バッファ読み込み失敗: \(error.localizedDescription)")
            throw AudioAnalyzerError.fileOpenFailed(error)
        }

        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioAnalyzerError.invalidAudioFormat
        }

        let sampleCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: sampleCount))

        return analyzeSamples(
            samples,
            sampleRate: format.sampleRate,
            sensitivity: sensitivity,
            audioFileName: url.lastPathComponent,
            recordedAt: recordedAt,
            isSimulated: false
        )
    }

    /// Float PCMサンプル配列を解析する（単体テスト・実データ共通コアロジック）
    static func analyzeSamples(
        _ samples: [Float],
        sampleRate: Double,
        sensitivity: AudioSensitivity = .standard,
        audioFileName: String? = nil,
        recordedAt: Date = Date(),
        isSimulated: Bool = false
    ) -> SleepAudioSession {
        guard !samples.isEmpty, sampleRate > 0 else {
            return SleepAudioSession(
                recordedAt: recordedAt,
                durationSeconds: 0,
                audioFileName: audioFileName,
                events: [],
                normalizedLevels: [],
                snoringDurationSeconds: 0,
                apneaPauseCount: 0,
                longestPauseSeconds: 0,
                isSimulated: isSimulated
            )
        }

        let totalDuration = Double(samples.count) / sampleRate
        // 1秒単位のウィンドウでRMS(dBFS)を算出
        let windowSize = max(1, Int(sampleRate))
        var windowDecibels: [Double] = []
        windowDecibels.reserveCapacity((samples.count / windowSize) + 1)

        var index = 0
        while index < samples.count {
            let end = min(index + windowSize, samples.count)
            let count = end - index
            var sumSquares: Double = 0
            for i in index..<end {
                let value = Double(samples[i])
                sumSquares += value * value
            }
            let rms = sqrt(sumSquares / Double(count))
            // 0除算回避のため -100 dBFS を下限とする
            let db = rms > 1e-5 ? max(-100.0, 20.0 * log10(rms)) : -100.0
            windowDecibels.append(db)
            index = end
        }

        // 下位20%パーセンタイルを環境ノイズフロアとして推定
        let sortedDb = windowDecibels.sorted()
        let noiseFloorIndex = max(0, min(sortedDb.count - 1, Int(Double(sortedDb.count) * 0.2)))
        let noiseFloorDb = sortedDb[noiseFloorIndex]

        let snoringThresholdDb = max(-55.0, noiseFloorDb + sensitivity.snoringThresholdOffsetDb)
        let silenceUpperBoundDb = noiseFloorDb + 4.0

        var events: [SleepAudioEvent] = []
        var snoringSeconds: TimeInterval = 0
        var longestPause: TimeInterval = 0
        var apneaPauseCount = 0

        // 1. いびき候補区間の検出（連続した高音圧ウィンドウを統合）
        var currentSnoreStart: Int?
        var currentSnorePeak: Double = -100.0

        for (sec, db) in windowDecibels.enumerated() {
            if db >= snoringThresholdDb {
                if currentSnoreStart == nil {
                    currentSnoreStart = sec
                    currentSnorePeak = db
                } else {
                    currentSnorePeak = max(currentSnorePeak, db)
                }
            } else if let start = currentSnoreStart {
                let duration = TimeInterval(sec - start)
                snoringSeconds += duration
                events.append(
                    SleepAudioEvent(
                        type: .snoring,
                        startOffsetSeconds: TimeInterval(start),
                        durationSeconds: duration,
                        peakDecibels: currentSnorePeak
                    )
                )
                currentSnoreStart = nil
            }
        }
        if let start = currentSnoreStart {
            let duration = TimeInterval(windowDecibels.count - start)
            snoringSeconds += duration
            events.append(
                SleepAudioEvent(
                    type: .snoring,
                    startOffsetSeconds: TimeInterval(start),
                    durationSeconds: duration,
                    peakDecibels: currentSnorePeak
                )
            )
        }

        // 2. 無呼吸候補区間の検出
        // 条件: 高音圧(いびき/呼吸)の後に10秒以上の静寂が続き、直後に呼吸再開音(しきい値以上)がある
        var hasPriorLoudSound = false
        var silenceStart: Int?

        for (sec, db) in windowDecibels.enumerated() {
            if db >= snoringThresholdDb {
                if let sStart = silenceStart {
                    let pauseDuration = TimeInterval(sec - sStart)
                    if hasPriorLoudSound && pauseDuration >= minimumApneaPauseSeconds {
                        apneaPauseCount += 1
                        longestPause = max(longestPause, pauseDuration)
                        events.append(
                            SleepAudioEvent(
                                type: .apneaPause,
                                startOffsetSeconds: TimeInterval(sStart),
                                durationSeconds: pauseDuration,
                                peakDecibels: db
                            )
                        )
                    }
                    silenceStart = nil
                }
                hasPriorLoudSound = true
            } else if db <= silenceUpperBoundDb {
                if hasPriorLoudSound && silenceStart == nil {
                    silenceStart = sec
                }
            } else {
                // 中間音量（通常呼吸）の場合は無呼吸ポーズをリセット
                silenceStart = nil
            }
        }

        // タイムライン描画用に最大60ポイントへ正規化ダウンサンプリング (0.0〜1.0)
        let normalizedLevels = downsampleLevels(windowDecibels, targetCount: 60)

        let sortedEvents = events.sorted { $0.startOffsetSeconds < $1.startOffsetSeconds }

        return SleepAudioSession(
            recordedAt: recordedAt,
            durationSeconds: totalDuration,
            audioFileName: audioFileName,
            events: sortedEvents,
            normalizedLevels: normalizedLevels,
            snoringDurationSeconds: snoringSeconds,
            apneaPauseCount: apneaPauseCount,
            longestPauseSeconds: longestPause,
            isSimulated: isSimulated
        )
    }

    /// シミュレータやデモ確認用に、いびき＋無呼吸再開パターンを含む仮想サンプル音声を生成して解析する
    static func generateSimulatedSession(sensitivity: AudioSensitivity = .standard) -> SleepAudioSession {
        let sampleRate = 8000.0
        let durationSeconds = 60 // 60秒間の睡眠デモ波形
        let totalSamples = Int(sampleRate) * durationSeconds
        var samples = [Float](repeating: 0.001, count: totalSamples)

        // 0〜10秒: いびき（大きな波形）
        // 10〜24秒: 無呼吸候補（14秒間の極小音）
        // 24〜30秒: 呼吸再開・大きないびき
        // 30〜43秒: 無呼吸候補（13秒間の極小音）
        // 43〜55秒: いびき断続
        // 55〜60秒: 通常呼吸
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let noise = Float.random(in: -0.0015...0.0015)

            if (t >= 2 && t < 10) || (t >= 24 && t < 30) || (t >= 43 && t < 53) {
                // いびき様の低周波パルス
                let envelope = abs(sin(.pi * t * 0.8))
                let tone = sin(2.0 * .pi * 120.0 * t)
                samples[i] = Float(0.25 * envelope * tone) + noise
            } else if (t >= 10 && t < 24) || (t >= 30 && t < 43) {
                // 無呼吸ポーズ（静寂）
                samples[i] = noise * 0.5
            } else {
                // 通常呼吸
                samples[i] = Float(0.015 * sin(2.0 * .pi * 80.0 * t)) + noise
            }
        }

        return analyzeSamples(
            samples,
            sampleRate: sampleRate,
            sensitivity: sensitivity,
            audioFileName: nil,
            recordedAt: Date(),
            isSimulated: true
        )
    }

    private static func downsampleLevels(_ decibels: [Double], targetCount: Int) -> [Double] {
        guard !decibels.isEmpty else { return [] }
        let mapped = decibels.map { db -> Double in
            // -70dB〜-10dB を 0.0〜1.0 にマッピング
            let clamped = max(-70.0, min(-10.0, db))
            return (clamped + 70.0) / 60.0
        }
        if mapped.count <= targetCount {
            return mapped
        }
        let step = Double(mapped.count) / Double(targetCount)
        return (0..<targetCount).map { i in
            let start = Int(Double(i) * step)
            let end = min(mapped.count, Int(Double(i + 1) * step))
            let slice = mapped[start..<max(start + 1, end)]
            return slice.max() ?? 0.0
        }
    }
}
