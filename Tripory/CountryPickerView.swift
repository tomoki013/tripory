import SwiftUI

/// 旅の記録を追加するときに国を選ぶための検索可能な一覧。
/// onMarkWantToGoを渡すと、各行に「行きたい国として登録」ボタンが出る。
struct CountryPickerView: View {
    let onSelect: (Country) -> Void
    var onMarkWantToGo: ((Country) -> Void)?
    var excludingCode: String?
    /// 一覧には表示するが選択はできない国(例: 現在住んでいる国)
    var disablingCode: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private func matches(_ country: Country) -> Bool {
        guard country.code != excludingCode else { return false }
        guard !searchText.isEmpty else { return true }
        return country.name.localizedStandardContains(searchText)
            || country.code.localizedStandardContains(searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Continent.allCases) { continent in
                    let countries = CountryCatalog.countries(in: continent).filter(matches)
                    if !countries.isEmpty {
                        Section {
                            ForEach(countries) { country in
                                let isDisabled = country.code == disablingCode
                                HStack(spacing: 12) {
                                    Button {
                                        onSelect(country)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(country.flag).font(.title2)
                                            Text(country.name)
                                                .foregroundStyle(isDisabled ? .secondary : .primary)
                                            if isDisabled {
                                                Text("設定中")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.primary.opacity(0.08), in: Capsule())
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isDisabled)

                                    if let onMarkWantToGo {
                                        Spacer()
                                        Button {
                                            onMarkWantToGo(country)
                                            dismiss()
                                        } label: {
                                            Label("行きたい", systemImage: "star")
                                                .font(.caption.bold())
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.orange.opacity(0.12), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        } header: {
                            Label(continent.displayName, systemImage: continent.symbolName)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("国を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "国名で検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}
