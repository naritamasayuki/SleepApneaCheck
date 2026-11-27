import Foundation

/// 配列内の破損要素をスキップしつつ残りの有効要素を救済する Lossy デコード用ラッパー
private struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct EmptyDecodable: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else {
                // 壊れた1要素だけ読み飛ばして他の履歴を保護する
                _ = try? container.decode(EmptyDecodable.self)
            }
        }
        self.elements = decoded
    }
}

/// 履歴保存用の統合データコンテナ
struct HistoryStoreData: Codable, Equatable, Sendable {
    var screenings: [ScreeningResult]
    var audioSessions: [SleepAudioSession]

    enum CodingKeys: String, CodingKey {
        case screenings
        case audioSessions
    }

    init(screenings: [ScreeningResult] = [], audioSessions: [SleepAudioSession] = []) {
        self.screenings = screenings
        self.audioSessions = audioSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.screenings = (try? container.decode(LossyDecodableArray<ScreeningResult>.self, forKey: .screenings).elements) ?? []
        self.audioSessions = (try? container.decode(LossyDecodableArray<SleepAudioSession>.self, forKey: .audioSessions).elements) ?? []
    }
}
