import StoreKitTest
import XCTest
@testable import Tripory

@MainActor
final class PurchaseManagerStoreKitTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() {
        session.clearTransactions()
        session = nil
    }

    func testCurrentEntitlementReflectsPurchaseAndRefund() async throws {
        let manager = PurchaseManager()
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.hasRemovedAds)

        do {
            try await session.buyProduct(identifier: PurchaseManager.removeAdsProductID)
        } catch {
            throw XCTSkip("StoreKit Test service is unavailable on this simulator: \(error)")
        }
        await manager.refreshEntitlements()
        XCTAssertTrue(manager.hasRemovedAds)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.hasRemovedAds)
    }

    func testPendingPurchaseIsNotAnEntitlementUntilApproved() async throws {
        session.askToBuyEnabled = true
        let manager = PurchaseManager()

        do {
            try await session.buyProduct(identifier: PurchaseManager.removeAdsProductID)
        } catch {
            throw XCTSkip("StoreKit Test service is unavailable on this simulator: \(error)")
        }
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.hasRemovedAds)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await manager.refreshEntitlements()
        XCTAssertTrue(manager.hasRemovedAds)
    }
}
