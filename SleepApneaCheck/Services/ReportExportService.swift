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
            y = drawText(title, font: titleFont, color: .label, x: margin, y: y, width: contentWidth)
            y += 4

            let dateStr = generatedAt.formatted(date: .long, time: .shortened)
            y = drawText(
                String(localized: "pdf.report.generated_at \(dateStr)"),
                font: captionFont,
                color: .secondaryLabel,
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
                color: .systemBlue,
                x: margin,
                y: y,
                width: contentWidth
            )
            y += 8

            if screenings.isEmpty {
                y = drawText(
                    String(localized: "pdf.report.no_data"),
                    font: bodyFont,
                    color: .secondaryLabel,
                    x: margin,
                    y: y,
                    width: contentWidth
                )
            } else {
                for item in screenings.prefix(5) {
                    let itemDate = item.date.formatted(date: .abbreviated, time: .shortened)
                    let line = "• \(itemDate)  |  \(item.riskLevel.localizedTitle)  |  STOP-Bang: \(item.stopBangScore)/8  |  ESS: \(item.essScore)/24 (\(item.sleepinessLevel.localizedTitle))"
                    y = drawText(line, font: bodyFont, color: .label, x: margin, y: y, width: contentWidth)
                    y += 5
                }
            }

            y += 14
            drawDivider(at: y, margin: margin, width: contentWidth, in: context.cgContext)
            y += 14

            // 2. 睡眠録音解析結果（直近5件）
            y = drawText(
                String(localized: "pdf.report.section.audio"),
                font: headingFont,
                color: .systemBlue,
                x: margin,
                y: y,
                width: contentWidth
            )
            y += 8

            if audioSessions.isEmpty {
                y = drawText(
                    String(localized: "pdf.report.no_data"),
                    font: bodyFont,
                    color: .secondaryLabel,
                    x: margin,
                    y: y,
                    width: contentWidth
                )
            } else {
                for session in audioSessions.prefix(5) {
                    let itemDate = session.recordedAt.formatted(date: .abbreviated, time: .shortened)
                    let mins = max(1, Int(session.durationSeconds / 60))
                    let tagNames = session.tags.map(\.localizedTitle).joined(separator: ", ")
                    var line = String(
                        format: "• %@  |  %d min  |  %.1f/h  |  Pauses: %d (Max %.0fs)  |  Snoring: %.0f%%",
                        itemDate,
                        mins,
                        session.estimatedEventsPerHour,
                        session.apneaPauseCount,
                        session.longestPauseSeconds,
                        session.snoringPercentage
                    )
                    if !tagNames.isEmpty {
                        line += "  [\(tagNames)]"
                    }
                    y = drawText(line, font: bodyFont, color: .label, x: margin, y: y, width: contentWidth)
                    y += 5
                }
            }

            // フッター免責事項
            let disclaimerY = pageRect.height - margin - 52
            drawDivider(at: disclaimerY - 8, margin: margin, width: contentWidth, in: context.cgContext)
            _ = drawText(
                String(localized: "disclaimer.banner"),
                font: captionFont,
                color: .secondaryLabel,
                x: margin,
                y: disclaimerY,
                width: contentWidth
            )
        }

        let fileName = "SleepApneaCheck_Report_\(Int(generatedAt.timeIntervalSince1970)).pdf"
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
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(0.75)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }
}
