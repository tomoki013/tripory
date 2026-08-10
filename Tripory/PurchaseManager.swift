import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseManager {
    static let removeAdsProductID = "io.tmkch.tripory.removeads"

    private(set) var product: Product?
    private(set) var hasRemovedAds = false
    private(set) var entitlementCheckCompleted = false
    private(set) var isLoading = false
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.removeAdsProductID]).first
            if product == nil {
                errorMessage = String(localized: "商品の情報を取得できませんでした。時間をおいてお試しください。")
            }
        } catch {
            errorMessage = String(localized: "商品の情報を取得できませんでした。時間をおいてお試しください。")
        }
    }

    func purchase() async {
        if product == nil { await loadProduct() }
        guard let product else { return }
        isLoading = true
        statusMessage = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                await transaction.finish()
                await refreshEntitlements()
                statusMessage = String(localized: "広告を削除しました。")
            case .pending:
                statusMessage = String(localized: "購入は保留中です。承認後に自動で反映されます。")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = String(localized: "購入を完了できませんでした。もう一度お試しください。")
        }
    }

    func restore() async {
        isLoading = true
        statusMessage = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasRemovedAds
                ? String(localized: "購入を復元しました。")
                : String(localized: "復元できる購入はありませんでした。")
        } catch StoreKitError.userCancelled {
            statusMessage = String(localized: "購入の復元をキャンセルしました。")
        } catch {
            errorMessage = String(localized: "購入を復元できませんでした。通信状況を確認してください。")
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  transaction.productID == Self.removeAdsProductID,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > .now }) ?? true
            else { continue }
            entitled = true
        }
        hasRemovedAds = entitled
        entitlementCheckCompleted = true
    }

    func clearMessages() {
        statusMessage = nil
        errorMessage = nil
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, let transaction = try? self.verified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw PurchaseError.unverified
        }
    }
}

private enum PurchaseError: Error { case unverified }
