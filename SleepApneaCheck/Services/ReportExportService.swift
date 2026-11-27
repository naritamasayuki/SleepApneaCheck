import Foundation
import os
import UIKit

/// 睡眠外来・呼吸器内科への受診時に持参できる A4 PDF レポートを生成するサービス
enum ReportExportService {
    private static let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "ReportExportService")

    /// 問診履歴および睡眠録音履歴から PDF ファイルを生成し、一時ファイルの URL を返す
    static func generateDoctorReportPDF(
        screenings: [ScreeningResult],
        audioSessions: [SleepAudioSession],
        generatedAt: Date = Date()
    ) -> URL? {
        // A4 サイズ (72 DPI: 595 x 842 pt)
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2

        // デモ（シミュレーション）結果は医師提出用レポートから除外する
        let realSessions = audioSessions.filter { !$0.isSimulated }

        // ダークモード端末でも白い紙の上で確実に読める固定ライト配色を使用
        let primaryTextColor = UIColor.black
        let secondaryTextColor = UIColor.darkGray
        let accentColor = UIColor(red: 0.0, green: 0.45, blue: 0.85, alpha: 1.0)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let headingFont = UIFont.boldSystemFont(ofSize: 14)
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let captionFont = UIFont.systemFont(ofSize: 9.5)

            // タイトルヘッダー
            let title = String(localized: "pdf.report.title")
            y = drawText(title, font: titleFont, color: primaryTextColor, x: margin, y: y, width: contentWidth)
            y += 4

            let dateStr = generatedAt.formatted(date: .long, time: .shortened)
            y = drawText(
                String(localized: "pdf.report.generated_at \(dateStr)"),
                font: captionFont,
                color: secondaryTextColor,
                x: margin,
                y: y,
                width: contentWidth
            )
            y += 14

            drawDivider(at: y, margin: margin, width: contentWidth, in: context.cgContext)
            y += 14

            // 1. 問診スクリーニング結果（直近5件）
            y = drawText(
                String(localized: "pdf.report.section.screening"),
                font: headingFont,
                color: accentColor,
                x: margin,
                y: y,
                width: contentWidth
            )
            y += 8

            if screenings.isEmpty {
                y = drawText(
                    String(localized: "pdf.report.no_data"),
                    font: bodyFont,
                    color: secondaryTextColor,
                    x: margin,
                    y: y,
                    width: contentWidth
                )
            } else {
                for item in screenings.prefix(5) {
                    let itemDate = item.date.formatted(date: .abbreviated, time: .shortened)
                    let line = "• \(itemDate)  |  \(item.riskLevel.localizedTitle)  |  STOP-Bang: \(item.stopBangScore)/8  |  ESS: \(item.essScore)/24 (\(item.sleepinessLevel.localizedTitle))"
                    y = drawText(line, font: bodyFont, color: primaryTextColor, x: margin, y: y, width: contentWidth)
                    y += 5
                }
            }

            y += 14
            drawDivider(at: y, margin: margin, width: contentWidth, in: context.cgContext)
            y += 14

            // 2. 睡眠録音解析結果（直近5件・実録音のみ）
            y = drawText(
                String(localized: "pdf.report.section.audio"),
                font: headingFont,
                color: accentColor,
                x: margin,
                y: y,
                width: contentWidth
            )
            y += 8

            if realSessions.isEmpty {
                y = drawText(
                    String(localized: "pdf.report.no_data"),
                    font: bodyFont,
                    color: secondaryTextColor,
                    x: margin,
                    y: y,
                    width: contentWidth
                )
            } else {
                for session in realSessions.prefix(5) {
                    let itemDate = session.recordedAt.formatted(date: .abbreviated, time: .shortened)
                    let mins = max(1, Int(session.durationSeconds / 60))
                    let tagNames = session.tags.map(\.localizedTitle).joined(separator: ", ")
                    let perHour = String(format: "%.1f", session.estimatedEventsPerHour)
                    var line = String(
                        localized: "pdf.report.audio_line \(itemDate) \(mins) \(perHour) \(session.apneaPauseCount) \(Int(session.longestPauseSeconds)) \(Int(session.snoringPercentage))"
                    )
                    if !tagNames.isEmpty {
                        line += "  [\(tagNames)]"
                    }
                    y = drawText(line, font: bodyFont, color: primaryTextColor, x: margin, y: y, width: contentWidth)
                    y += 5
                }
            }

            // フッター免責事項
            let disclaimerY = pageRect.height - margin - 52
            drawDivider(at: disclaimerY - 8, margin: margin, width: contentWidth, in: context.cgContext)
            _ = drawText(
                String(localized: "disclaimer.banner"),
                font: captionFont,
                color: secondaryTextColor,
                x: margin,
                y: disclaimerY,
                width: contentWidth
            )
        }

        // 一時ディレクトリにファイルが増殖しないよう固定ファイル名で上書きする
        let fileName = "SleepApneaCheck_Doctor_Report.pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            logger.error("PDF レポート保存失敗: \(error.localizedDescription)")
            return nil
        }
    }

    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: ceil(bounding.height)), withAttributes: attributes)
        return y + ceil(bounding.height)
    }

    private static func drawDivider(at y: CGFloat, margin: CGFloat, width: CGFloat, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor(white: 0.78, alpha: 1.0).cgColor)
        ctx.setLineWidth(0.75)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }
}
