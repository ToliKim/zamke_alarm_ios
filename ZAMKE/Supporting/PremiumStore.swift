//
//  PremiumStore.swift
//  ZAMKE
//
//  StoreKit 2 기반 인앱 구매 매니저
//  화들짝 프리미엄 모드 — 비소모성(Non-consumable) 상품
//

import StoreKit
import SwiftUI

@MainActor
@Observable
final class PremiumStore {

    // ── 싱글턴 ──
    static let shared = PremiumStore()

    // ── 상품 ID (App Store Connect에 등록할 ID) ──
    nonisolated static let productID = "com.kodamm.zamke.premium"

    // ── 상태 ──
    var isPremiumUnlocked: Bool = false
    var product: Product? = nil
    var purchaseInProgress: Bool = false
    var errorMessage: String? = nil

    // ── 가격 표시용 ──
    var displayPrice: String {
        product?.displayPrice ?? "$2.99"
    }

    // ── 트랜잭션 리스너 ──
    nonisolated(unsafe) private var updateListenerTask: Task<Void, Never>? = nil

    // MARK: - Init

    private init() {
        // UserDefaults 캐시 복원 (오프라인 대비)
        isPremiumUnlocked = UserDefaults.standard.bool(forKey: "premium_unlocked")

        // 트랜잭션 업데이트 리스너 시작
        updateListenerTask = listenForTransactions()

        // 상품 로드 + 구매 검증
        Task {
            await loadProduct()
            await checkExistingPurchase()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 상품 로드

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [PremiumStore.productID])
            if let p = products.first {
                product = p
                #if DEBUG
                print("💰 상품 로드: \(p.displayName) — \(p.displayPrice)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ 상품 로드 실패: \(error)")
            #endif
        }
    }

    // MARK: - 구매

    func purchase() async {
        guard let product = product else {
            errorMessage = "상품 정보를 불러올 수 없습니다"
            return
        }
        guard !purchaseInProgress else { return }

        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                unlock()
                #if DEBUG
                print("✅ 구매 성공!")
                #endif

            case .userCancelled:
                #if DEBUG
                print("🚫 구매 취소")
                #endif

            case .pending:
                #if DEBUG
                print("⏳ 구매 대기 중 (보호자 승인 등)")
                #endif

            @unknown default:
                break
            }
        } catch {
            errorMessage = "구매 처리 중 오류가 발생했습니다"
            #if DEBUG
            print("❌ 구매 실패: \(error)")
            #endif
        }

        purchaseInProgress = false
    }

    // MARK: - 구매 복원

    func restore() async {
        purchaseInProgress = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkExistingPurchase()

            if !isPremiumUnlocked {
                errorMessage = "복원할 구매 내역이 없습니다"
            }
        } catch {
            errorMessage = "복원 중 오류가 발생했습니다"
            #if DEBUG
            print("❌ 복원 실패: \(error)")
            #endif
        }

        purchaseInProgress = false
    }

    // MARK: - 기존 구매 확인

    func checkExistingPurchase() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == PremiumStore.productID {
                    unlock()
                    return
                }
            }
        }
    }

    // MARK: - 트랜잭션 리스너

    private func listenForTransactions() -> Task<Void, Never> {
        let pid = PremiumStore.productID
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == pid {
                        await transaction.finish()
                        await PremiumStore.shared.unlock()
                    }
                }
            }
        }
    }

    // MARK: - 검증

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - 잠금 해제

    fileprivate func unlock() {
        isPremiumUnlocked = true
        UserDefaults.standard.set(true, forKey: "premium_unlocked")
    }
}
