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
    /// 無呼吸候補とみなす最大静寂時間（秒）— 2分を超える長い無音は静かな睡眠区間とみなし誤検出を防ぐ
    static let maximumApneaPauseSeconds: TimeInterval = 120.0

    /// 音声ファイルURLをチャンク単位でストリーミング読み込みし、低メモリで解析を実行する
    static func analyzeFile(
        at url: URL,
        sensitivity: AudioSensitivity = .standard,
        recordedAt: Date = Date(),
        ignoreInitialSeconds: TimeInterval = 0,
        interruptionCount: Int = 0
    ) throws -> SleepAudioSession {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            logger.error("音声ファイルオープン失敗: \(error.localizedDescription)")
            throw AudioAnalyzerError.fileOpenFailed(error)
        }

        let format = audioFile.processingFormat
        let totalFrames = audioFile.length
        guard totalFrames > 0, format.sampleRate > 0 else {
            throw AudioAnalyzerError.emptyAudioData
        }

        // 入眠待ちディレイ分を先頭からスキップ（総フレーム数を超えない範囲にクランプ）
        let skipFrames = AVAudioFramePosition(max(0, ignoreInitialSeconds) * format.sampleRate)
        let effectiveStartFrame = min(skipFrames, totalFrames)
        if effectiveStartFrame > 0 {
            audioFile.framePosition = effectiveStartFrame
        }

        let remainingFrames = totalFrames - effectiveStartFrame
        guard remainingFrames > 0 else {
            throw AudioAnalyzerError.emptyAudioData
        }

        // 1秒単位のチャンクバッファを再利用してストリーミング読み込み（8時間でも数MB以下）
        let windowFrameCount = AVAudioFrameCount(max(1, Int(format.sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: windowFrameCount) else {
            throw AudioAnalyzerError.invalidAudioFormat
        }

        var windowDecibels: [Double] = []
        let estimatedSeconds = Int(Double(remainingFrames) / format.sampleRate) + 1
        windowDecibels.reserveCapacity(estimatedSeconds)
        var processedFrames: AVAudioFramePosition = 0

        while audioFile.framePosition < totalFrames {
            let framesLeft = AVAudioFrameCount(min(AVAudioFramePosition(windowFrameCount), totalFrames - audioFile.framePosition))
            guard framesLeft > 0 else { break }

            do {
                try audioFile.read(into: buffer, frameCount: framesLeft)
            } catch {
                logger.error("音声チャンク読み込み失敗: \(error.localizedDescription)")
                throw AudioAnalyzerError.fileOpenFailed(error)
            }

            let readCount = Int(buffer.frameLength)
            guard readCount > 0, let channelData = buffer.floatChannelData?[0] else {
                break
            }

            var sumSquares: Double = 0
            for i in 0..<readCount {
                let value = Double(channelData[i])
                sumSquares += value * value
            }
            let rms = sqrt(sumSquares / Double(readCount))
            let db = rms > 1e-5 ? max(-100.0, 20.0 * log10(rms)) : -100.0
            windowDecibels.append(db)
            processedFrames += AVAudioFramePosition(readCount)
        }

        let totalDuration = Double(processedFrames) / format.sampleRate
        let effectiveRecordedAt = recordedAt.addingTimeInterval(max(0, ignoreInitialSeconds))
        return analyzeWindowDecibels(
            windowDecibels,
            totalDuration: totalDuration,
            sensitivity: sensitivity,
            audioFileName: url.lastPathComponent,
            recordedAt: effectiveRecordedAt,
            isSimulated: false,
            interruptionCount: interruptionCount
        )
    }

    /// Float PCMサンプル配列を解析する（単体テスト・シミュレーション共通コアロジック）
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
            let db = rms > 1e-5 ? max(-100.0, 20.0 * log10(rms)) : -100.0
            windowDecibels.append(db)
            index = end
        }

        return analyzeWindowDecibels(
            windowDecibels,
            totalDuration: totalDuration,
            sensitivity: sensitivity,
            audioFileName: audioFileName,
            recordedAt: recordedAt,
            isSimulated: isSimulated
        )
    }

    /// 1秒単位のdBFS配列からいびき・無呼吸候補区間を解析する（低メモリ共通エンジン）
    static func analyzeWindowDecibels(
        _ windowDecibels: [Double],
        totalDuration: TimeInterval,
        sensitivity: AudioSensitivity = .standard,
        audioFileName: String? = nil,
        recordedAt: Date = Date(),
        isSimulated: Bool = false,
        interruptionCount: Int = 0
    ) -> SleepAudioSession {
        guard !windowDecibels.isEmpty, totalDuration > 0 else {
            return SleepAudioSession(
                recordedAt: recordedAt,
                durationSeconds: 0,
                audioFileName: audioFileName,
                events: [],
                normalizedLevels: [],
                snoringDurationSeconds: 0,
                apneaPauseCount: 0,
                longestPauseSeconds: 0,
                isSimulated: isSimulated,
                interruptionCount: interruptionCount
            )
        }

        // 下位20%パーセンタイルを環境ノイズフロアとして推定
        let sortedDb = windowDecibels.sorted()
        let noiseFloorIndex = max(0, min(sortedDb.count - 1, Int(Double(sortedDb.count) * 0.2)))
        let noiseFloorDb = sortedDb[noiseFloorIndex]

        let snoringThresholdDb = max(-55.0, noiseFloorDb + sensitivity.snoringThresholdOffsetDb)
        let silenceUpperBoundDb = noiseFloorDb + 4.0

        var snoreEvents: [SleepAudioEvent] = []
        var apneaEvents: [SleepAudioEvent] = []
        var snoringSeconds: TimeInterval = 0
        var longestPause: TimeInterval = 0
        var apneaPauseCount = 0

        // 1. いびき候補区間の検出（連続した高音圧ウィンドウを抽出し、2秒以内の近接イベントは統合）
        var currentSnoreStart: Int?
        var currentSnorePeak: Double = -100.0

        func commitSnore(start: Int, end: Int, peak: Double) {
            let duration = TimeInterval(end - start)
            snoringSeconds += duration
            if let last = snoreEvents.last,
               TimeInterval(start) - (last.startOffsetSeconds + last.durationSeconds) <= 2.0 {
                // 近接するいびきイベントを統合してイベント数爆発を防ぐ
                let mergedDuration = TimeInterval(end) - last.startOffsetSeconds
                snoreEvents[snoreEvents.count - 1] = SleepAudioEvent(
                    id: last.id,
                    type: .snoring,
                    startOffsetSeconds: last.startOffsetSeconds,
                    durationSeconds: mergedDuration,
                    peakDecibels: max(last.peakDecibels, peak)
                )
            } else {
                snoreEvents.append(
                    SleepAudioEvent(
                        type: .snoring,
                        startOffsetSeconds: TimeInterval(start),
                        durationSeconds: duration,
                        peakDecibels: peak
                    )
                )
            }
        }

        for (sec, db) in windowDecibels.enumerated() {
            if db >= snoringThresholdDb {
                if currentSnoreStart == nil {
                    currentSnoreStart = sec
                    currentSnorePeak = db
                } else {
                    currentSnorePeak = max(currentSnorePeak, db)
                }
            } else if let start = currentSnoreStart {
                commitSnore(start: start, end: sec, peak: currentSnorePeak)
                currentSnoreStart = nil
            }
        }
        if let start = currentSnoreStart {
            commitSnore(start: start, end: windowDecibels.count, peak: currentSnorePeak)
        }

        // 2. 無呼吸候補区間の検出
        // 誤検出削減: 毎回の静寂について「直前が2秒以上のいびき（連続高音圧）」だった場合のみ
        // 10〜120秒の静寂→呼吸再開音（しきい値以上）のパターンを無呼吸候補として検出
        var consecutiveLoudSeconds = 0
        var silenceStart: Int?

        for (sec, db) in windowDecibels.enumerated() {
            if db >= snoringThresholdDb {
                if let sStart = silenceStart {
                    let pauseDuration = TimeInterval(sec - sStart)
                    if pauseDuration >= minimumApneaPauseSeconds
                        && pauseDuration <= maximumApneaPauseSeconds {
                        apneaPauseCount += 1
                        longestPause = max(longestPause, pauseDuration)
                        apneaEvents.append(
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
                consecutiveLoudSeconds += 1
            } else if db <= silenceUpperBoundDb {
                // 静寂の「直前」が2秒以上のいびきだった場合のみ候補区間を開始（毎回判定）
                if silenceStart == nil && consecutiveLoudSeconds >= 2 {
                    silenceStart = sec
                }
                consecutiveLoudSeconds = 0
            } else {
                // 中間音量（通常呼吸）の場合は無呼吸ポーズをリセット
                consecutiveLoudSeconds = 0
                silenceStart = nil
            }
        }

        // タイムライン描画用に最大60ポイントへ正規化ダウンサンプリング (0.0〜1.0)
        let normalizedLevels = downsampleLevels(windowDecibels, targetCount: 60)

        let sortedEvents = (snoreEvents + apneaEvents).sorted { $0.startOffsetSeconds < $1.startOffsetSeconds }

        return SleepAudioSession(
            recordedAt: recordedAt,
            durationSeconds: totalDuration,
            audioFileName: audioFileName,
            events: sortedEvents,
            normalizedLevels: normalizedLevels,
            snoringDurationSeconds: snoringSeconds,
            apneaPauseCount: apneaPauseCount,
            longestPauseSeconds: longestPause,
            isSimulated: isSimulated,
            interruptionCount: interruptionCount
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
