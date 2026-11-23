import Foundation

/// 睡眠時無呼吸・いびきセルフケア対策グッズの定義
enum SleepCareGood: String, CaseIterable, Identifiable, Sendable {
    case sideSleeperPillow
    case mouthTape
    case nasalStrips
    case antiSnoreMouthpiece
    case pulseOximeter

    var id: String { rawValue }

    /// SF Symbols アイコン名
    var symbolName: String {
        switch self {
        case .sideSleeperPillow: return "bed.double.fill"
        case .mouthTape: return "bandage.fill"
        case .nasalStrips: return "wind"
        case .antiSnoreMouthpiece: return "mouth.fill"
        case .pulseOximeter: return "heart.text.square.fill"
        }
    }

    /// ローカライズされたグッズ名
    var localizedTitle: String {
        switch self {
        case .sideSleeperPillow: return String(localized: "goods.pillow.title")
        case .mouthTape: return String(localized: "goods.mouthtape.title")
        case .nasalStrips: return String(localized: "goods.nasalstrips.title")
        case .antiSnoreMouthpiece: return String(localized: "goods.mouthpiece.title")
        case .pulseOximeter: return String(localized: "goods.oximeter.title")
        }
    }

    /// ローカライズされた説明文
    var localizedDescription: String {
        switch self {
        case .sideSleeperPillow: return String(localized: "goods.pillow.desc")
        case .mouthTape: return String(localized: "goods.mouthtape.desc")
        case .nasalStrips: return String(localized: "goods.nasalstrips.desc")
        case .antiSnoreMouthpiece: return String(localized: "goods.mouthpiece.desc")
        case .pulseOximeter: return String(localized: "goods.oximeter.desc")
        }
    }

    /// ロケールに応じた Amazon 検索キーワード
    func searchKeyword(isJapanLocale: Bool) -> String {
        if isJapanLocale {
            switch self {
            case .sideSleeperPillow: return "いびき防止 枕 横向き寝"
            case .mouthTape: return "いびき防止 口閉じテープ"
            case .nasalStrips: return "鼻腔拡張テープ いびき"
            case .antiSnoreMouthpiece: return "いびき防止 マウスピース"
            case .pulseOximeter: return "パルスオキシメーター 医療機器認証"
            }
        } else {
            switch self {
            case .sideSleeperPillow: return "anti snoring side sleeper pillow"
            case .mouthTape: return "mouth tape for sleeping anti snoring"
            case .nasalStrips: return "nasal strips for snoring"
            case .antiSnoreMouthpiece: return "anti snoring mouthpiece"
            case .pulseOximeter: return "pulse oximeter fingertip"
            }
        }
    }
}

/// Amazon アソシエイト用の安全な商品検索 URL を生成するサービス
enum AmazonAffiliateService {
    /// 共通 Amazon アソシエイト ID（日本・Amazon.co.jp）
    static let japanAssociateTag = "shirokumacamp-22"

    /// 現在のロケールが日本（日本語または日本リージョン）かどうかを判定する
    static func isJapanLocale(_ locale: Locale = .current) -> Bool {
        if locale.region?.identifier.uppercased() == "JP" {
            return true
        }
        if locale.language.languageCode?.identifier.lowercased() == "ja" {
            return true
        }
        return false
    }

    /// 指定されたグッズの Amazon 検索 URL を URLComponents で安全に生成する
    static func searchURL(for good: SleepCareGood, locale: Locale = .current) -> URL? {
        let isJP = isJapanLocale(locale)
        let keyword = good.searchKeyword(isJapanLocale: isJP)
        return searchURL(keyword: keyword, isJapanLocale: isJP)
    }

    /// 任意の検索キーワードから Amazon 検索 URL を生成する
    static func searchURL(keyword: String, isJapanLocale: Bool) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        if isJapanLocale {
            components.host = "www.amazon.co.jp"
            components.path = "/s"
            components.queryItems = [
                URLQueryItem(name: "k", value: keyword),
                URLQueryItem(name: "tag", value: japanAssociateTag)
            ]
        } else {
            components.host = "www.amazon.com"
            components.path = "/s"
            components.queryItems = [
                URLQueryItem(name: "k", value: keyword)
            ]
        }
        return components.url
    }
}
