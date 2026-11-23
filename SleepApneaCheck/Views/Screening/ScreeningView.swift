import StoreKit
import SwiftUI

/// 問診スクリーニング画面（簡易判定 / 詳細問診 STOP-Bang + ESS 切り替え）
struct ScreeningView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.requestReview) private var requestReview

    private enum FocusField {
        case height
        case weight
    }

    @State private var mode = 0
    @State private var stopBang = StopBangInput()
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var essAnswers = Array(repeating: 0, count: EssQuestion.allCases.count)
    @State private var latestResult: ScreeningResult?
    @State private var showFeedbackForm = false
    @FocusState private var focusedField: FocusField?

    private var currentStopBangScore: Int {
        ScreeningCalculator.stopBangScore(from: stopBang)
    }

    private var currentEssScore: Int {
        ScreeningCalculator.essScore(from: essAnswers)
    }

    private var computedBMI: Double? {
        guard let h = Double(heightText), let w = Double(weightText) else { return nil }
        return ScreeningCalculator.calculateBMI(heightCm: h, weightKg: w)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    Text(String(localized: "screening.mode.quick")).tag(0)
                    Text(String(localized: "screening.mode.detailed")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if mode == 0 {
                    QuickCheckView {
                        withAnimation {
                            mode = 1
                        }
                    }
                } else {
                    detailedForm
                }
            }
            .navigationTitle(String(localized: "screening.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFeedbackForm = true
                    } label: {
                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                    }
                    .accessibilityLabel(String(localized: "feedback.title"))
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .sheet(item: $latestResult) { result in
                ScreeningResultView(result: result)
            }
            .sheet(isPresented: $showFeedbackForm) {
                FeedbackView()
            }
        }
    }

    private var detailedForm: some View {
        Form {
                Section {
                    DisclaimerBanner()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Toggle(String(localized: "stopbang.snoring"), isOn: $stopBang.snoring)
                    Toggle(String(localized: "stopbang.tired"), isOn: $stopBang.tired)
                    Toggle(String(localized: "stopbang.observed"), isOn: $stopBang.observed)
                    Toggle(String(localized: "stopbang.pressure"), isOn: $stopBang.highBloodPressure)
                } header: {
                    Text(String(localized: "screening.section.stop"))
                } footer: {
                    Text(String(localized: "screening.section.stop.footer"))
                }

                Section {
                    HStack {
                        Label(
                            "STOP-Bang: \(currentStopBangScore)/8",
                            systemImage: "waveform.path.ecg"
                        )
                        .font(.caption.bold())
                        Spacer()
                        Label(
                            "ESS: \(currentEssScore)/24",
                            systemImage: "bed.double.fill"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(currentEssScore >= 11 ? .orange : .secondary)
                    }
                }

                Section {
                    HStack {
                        TextField(String(localized: "screening.bmi.height"), text: $heightText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .height)
                        TextField(String(localized: "screening.bmi.weight"), text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .weight)
                    }
                    .onChange(of: heightText) { _, _ in syncBmiToggle() }
                    .onChange(of: weightText) { _, _ in syncBmiToggle() }

                    if let bmi = computedBMI {
                        HStack {
                            Text(String(localized: "screening.bmi.calculated"))
                            Spacer()
                            Text(String(format: "%.1f kg/m²", bmi))
                                .foregroundStyle(bmi > 35 ? .red : .secondary)
                                .monospacedDigit()
                        }
                    }

                    Toggle(String(localized: "stopbang.bmi"), isOn: $stopBang.bmiOver35)
                    Toggle(String(localized: "stopbang.age"), isOn: $stopBang.ageOver50)
                    Toggle(String(localized: "stopbang.neck"), isOn: $stopBang.neckOver40)
                    Toggle(String(localized: "stopbang.male"), isOn: $stopBang.isMale)
                } header: {
                    Text(String(localized: "screening.section.bang"))
                }

                Section {
                    ForEach(EssQuestion.allCases) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.localizedPrompt)
                                .font(.subheadline)
                            Picker("", selection: $essAnswers[question.rawValue]) {
                                ForEach(EssScoreOption.allCases) { option in
                                    Text(option.localizedTitle).tag(option.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "screening.section.ess"))
                } footer: {
                    Text(String(localized: "screening.section.ess.footer"))
                }

                Section {
                    Button {
                        runEvaluation()
                    } label: {
                        HStack {
                            Spacer()
                            Label(String(localized: "screening.button.evaluate"), systemImage: "stethoscope")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Button(role: .destructive) {
                        resetForm()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "screening.button.reset"))
                            Spacer()
                        }
                    }
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "common.done")) {
                    focusedField = nil
                }
            }
        }
    }

    private func syncBmiToggle() {
        if let bmi = computedBMI {
            stopBang.bmiOver35 = bmi > 35.0
            stopBang.heightCm = Double(heightText)
            stopBang.weightKg = Double(weightText)
        }
    }

    private func runEvaluation() {
        let result = ScreeningCalculator.evaluate(
            stopBangInput: stopBang,
            essAnswers: essAnswers
        )
        appState.addScreeningResult(result)
        latestResult = result
        if ReviewPromptService.recordActionAndShouldPrompt() {
            requestReview()
        }
    }

    private func resetForm() {
        stopBang = StopBangInput()
        heightText = ""
        weightText = ""
        essAnswers = Array(repeating: 0, count: EssQuestion.allCases.count)
    }
}
