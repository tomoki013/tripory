import SwiftUI

struct OnboardingHomeCountryStep: View {
    @Binding var selectedCountry: Country?
    let onContinue: () -> Void

    @State private var searchText = ""

    private var countries: [Country] {
        guard !searchText.isEmpty else { return CountryCatalog.all }
        return CountryCatalog.all.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.code.localizedStandardContains(searchText)
                || englishName(for: $0).localizedStandardContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.triporyCanvas
            VStack(alignment: .leading, spacing: 0) {
                OnboardingProgress(step: .homeCountry)
                    .padding(.top, 62)

                countryStepPhoto

                Text("住んでいる国は？")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .padding(.top, 34)
                Text("海外旅行の記録から除外し、3D地球の最初の向きを決めます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("国名を検索", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.triporyInk.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.triporyNavy.opacity(0.05), radius: 8, y: 3)
                .padding(.top, 20)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(countries) { country in
                            countryRow(country)
                        }
                    }
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)

                PrimaryCapsuleButton(
                    title: selectedCountry.map { String(format: String(localized: "%@で続ける"), $0.name) } ?? String(localized: "国を選んでください"),
                    isEnabled: selectedCountry != nil,
                    action: onContinue
                )
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
    }

    /// 差し替え用の実写真(Assets.xcassetsの"OnboardingCountryPhoto")があれば、見出しの上に帯として敷く。
    @ViewBuilder
    private var countryStepPhoto: some View {
        if let uiImage = UIImage(named: "OnboardingCountryPhoto") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.top, 24)
                .accessibilityHidden(true)
        }
    }

    /// モックの「日本 / Japan」のように、現地語名の下に英語名を添える。
    private func englishName(for country: Country) -> String {
        Locale(identifier: "en").localizedString(forRegionCode: country.code) ?? country.code
    }

    private func countryRow(_ country: Country) -> some View {
        let selected = country == selectedCountry
        let english = englishName(for: country)
        return Button {
            selectedCountry = country
        } label: {
            HStack(spacing: 13) {
                Text(country.flag)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.triporyNavy.opacity(0.06), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(.headline)
                        .foregroundStyle(Color.triporyInk)
                    if english != country.name {
                        Text(english)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.triporyCoral, in: Circle())
                } else {
                    Text(country.code)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .background(selected ? Color.triporyCoral.opacity(0.08) : Color.triporyCard, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? Color.triporyCoral : Color.triporyInk.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            }
            .shadow(color: Color.triporyNavy.opacity(selected ? 0.1 : 0.03), radius: selected ? 10 : 4, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(country.name)、\(selected ? String(localized: "選択中") : String(localized: "未選択"))")
    }
}
