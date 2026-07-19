import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case homeCountry
    case homePhoto
    case ready
}

enum OnboardingFlowMode {
    case complete
    case photoOnly
}

struct OnboardingFlowView: View {
    let mode: OnboardingFlowMode
    let profile: UserProfile
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @Query private var records: [CountryRecord]
    @State private var step: OnboardingStep
    @State private var selectedCountry: Country?

    init(mode: OnboardingFlowMode, profile: UserProfile, onComplete: @escaping () -> Void) {
        self.mode = mode
        self.profile = profile
        self.onComplete = onComplete
        var initialStep: OnboardingStep = mode == .complete ? .welcome : .homePhoto
#if DEBUG
        // デザイン確認用: -qaOnboardingStep welcome|homeCountry|homePhoto|ready
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-qaOnboardingStep"),
           arguments.indices.contains(flagIndex + 1) {
            switch arguments[flagIndex + 1] {
            case "welcome": initialStep = .welcome
            case "homeCountry": initialStep = .homeCountry
            case "homePhoto": initialStep = .homePhoto
            case "ready": initialStep = .ready
            default: break
            }
        }
#endif
        _step = State(initialValue: initialStep)
        _selectedCountry = State(initialValue: CountryCatalog.byCode[UserDefaults.standard.string(forKey: "homeCountryCode") ?? ""])
    }

    // Ready画面は「日本から始まる、あなたの世界。」の演出として住んでいる国も含めて数える
    // (新規ユーザーでも 0 ではなく 1 COUNTRY から始まる)。
    private var countryCount: Int {
        records.filter(\.status.countsAsVisited).count
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcomeStep { advance(to: .homeCountry) }
                    .transition(stepTransition)
            case .homeCountry:
                OnboardingHomeCountryStep(selectedCountry: $selectedCountry) {
                    commitHomeCountry()
                    advance(to: .homePhoto)
                }
                .transition(stepTransition)
            case .homePhoto:
                OnboardingHomePhotoStep(profile: profile) {
                    advance(to: .ready)
                }
                .transition(stepTransition)
            case .ready:
                OnboardingReadyStep(
                    profile: profile,
                    homeCountryCode: homeCountryCode,
                    countryCount: countryCount,
                    onOpen: finish
                )
                .transition(stepTransition)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: String(localized: "オンボーディング %lld / 4"), step.rawValue + 1))
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }

    private func advance(to next: OnboardingStep) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
            step = next
        }
    }

    private func commitHomeCountry() {
        guard let selectedCountry else { return }
        homeCountryCode = selectedCountry.code
        modelContext.record(for: selectedCountry.code).status = .visited

        let code = selectedCountry.code
        let predicate = #Predicate<HomeCountryPeriod> { $0.countryCode == code }
        let hasPeriod = ((try? modelContext.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0) > 0
        if !hasPeriod {
            modelContext.insert(HomeCountryPeriod(countryCode: selectedCountry.code))
        }
        try? modelContext.save()
    }

    private func finish() {
        profile.onboardingCompletedAt = .now
        try? modelContext.save()
        onComplete()
    }
}

struct OnboardingProgress: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.triporyCoral : Color.triporyInk.opacity(0.16))
                    .frame(width: 28, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "全4ステップ中%lldステップ目"), step.rawValue + 1))
    }
}
