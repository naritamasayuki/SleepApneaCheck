import Foundation
import os

/// 履歴保存・読み込みのエラー
enum HistoryRepositoryError: LocalizedError {
    case directoryCreationFailed(Error)
    case loadFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return String(localized: "error.history.directory_failed")
        case .loadFailed:
            return String(localized: "error.history.load_failed")
        case .saveFailed:
            return String(localized: "error.history.save_failed")
        }
    }
}

/// 問診結果および睡眠録音セッションをJSONファイルへ永続化するリポジトリ
final class HistoryRepository: Sendable {
    private let fileURL: URL
    private let audioDirectoryURL: URL
    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "HistoryRepository")

    init(baseDirectoryURL: URL? = nil) {
        let baseDir: URL
        if let customDir = baseDirectoryURL {
            baseDir = customDir
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            baseDir = docs.appendingPathComponent("SleepApneaCheckData", isDirectory: true)
        }
        self.fileURL = baseDir.appendingPathComponent("history.json")
        self.audioDirectoryURL = baseDir.appendingPathComponent("Recordings", isDirectory: true)
    }

    /// 録音ファイル保存用のディレクトリURLを取得（必要に応じて作成・iCloudバックアップ除外）
    func ensureAudioDirectoryURL() throws -> URL {
        do {
            if !FileManager.default.fileExists(atPath: audioDirectoryURL.path) {
                try FileManager.default.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
            }
            // 一晩数十〜100MBの録音を iCloud バックアップ対象から外す
            var dirURL = audioDirectoryURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dirURL.setResourceValues(values)
            return audioDirectoryURL
        } catch {
            logger.error("録音ディレクトリ作成失敗: \(error.localizedDescription)")
            throw HistoryRepositoryError.directoryCreationFailed(error)
        }
    }

    /// 履歴に紐づかない孤立録音ファイルを列挙する
    func orphanedAudioFileURLs(referencedFileNames: Set<String>) -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: audioDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return urls.filter { $0.pathExtension == "m4a" && !referencedFileNames.contains($0.lastPathComponent) }
    }

    /// 録音ファイル名からフルURLを解決する
    func audioFileURL(for fileName: String) -> URL {
        audioDirectoryURL.appendingPathComponent(fileName)
    }

    /// 履歴データを読み込む（ファイルが存在しない場合は空データを返し、全体破損時はバックアップへ退避する）
    func load() throws -> HistoryStoreData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return HistoryStoreData()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(HistoryStoreData.self, from: data)
        } catch {
            logger.error("履歴データ読み込み失敗（バックアップへ退避）: \(error.localizedDescription)")
            backupCorruptedFileIfNeeded()
            throw HistoryRepositoryError.loadFailed(error)
        }
    }

    /// 破損した履歴ファイルを別名へ退避し、次回保存でのデータ消失を防ぐ
    private func backupCorruptedFileIfNeeded() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("history.corrupt-\(timestamp).json")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.moveItem(at: fileURL, to: backupURL)
                logger.info("破損した履歴ファイルを退避しました: \(backupURL.lastPathComponent)")
            }
        } catch {
            logger.error("破損履歴ファイルの退避に失敗: \(error.localizedDescription)")
        }
    }

    /// 履歴データを保存する
    func save(_ storeData: HistoryStoreData) throws {
        do {
            let parentDir = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(storeData)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            logger.error("履歴データ保存失敗: \(error.localizedDescription)")
            throw HistoryRepositoryError.saveFailed(error)
        }
    }

    /// 紐づく録音音声ファイルを安全に削除する
    func deleteAudioFile(named fileName: String?) {
        guard let fileName else { return }
        let url = audioFileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("録音ファイル削除失敗 (\(fileName)): \(error.localizedDescription)")
        }
    }

    /// 全履歴と録音ファイルを削除する
    func clearAll() throws {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            if FileManager.default.fileExists(atPath: audioDirectoryURL.path) {
                try FileManager.default.removeItem(at: audioDirectoryURL)
            }
        } catch {
            logger.error("履歴全削除失敗: \(error.localizedDescription)")
            throw HistoryRepositoryError.saveFailed(error)
        }
    }
}
