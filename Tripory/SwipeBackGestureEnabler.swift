import SwiftUI
import UIKit

extension View {
    /// ナビゲーションバーを隠す。旧navigationBarHidden(true)と違い、
    /// interactivePopGestureRecognizerを巻き込んで無効化してしまう問題が起きにくい。
    func hidesNavigationBar() -> some View {
        toolbarVisibility(.hidden, for: .navigationBar)
    }

    /// ナビゲーションバーを隠している画面で、画面左端からのスワイプで戻れるようにする。
    /// UINavigationController はバーを隠すと interactivePopGestureRecognizer を止めることがあるため、
    /// 明示的に有効化し直す。NavigationLink(value:)+navigationDestination(for:) の
    /// 標準プッシュで使う限り安全(スタックとジェスチャーが食い違わない)。
    func swipeToGoBack() -> some View {
        background(InteractivePopGestureEnabler())
    }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { PassthroughController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    /// backgroundに挿すだけの透明なコントローラ。祖先のUINavigationControllerを見つけて
    /// エッジスワイプを有効化する。
    private final class PassthroughController: UIViewController {
        // delegateはweakなので、代入したdelegateを生かし続けるための強参照。
        private let edgeDelegate = EdgeOnlyPopGestureDelegate()

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enablePopGesture()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enablePopGesture()
        }

        private func enablePopGesture() {
            guard let nav = navigationController, nav.viewControllers.count > 1 else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = true
            // 標準delegateはカスタム戻るボタン使用時にジェスチャーを止めてしまうことがあるため、
            // 「画面左端から始まった時だけ許可する」という同等の挙動を自前のdelegateで肩代わりする。
            // ただし丸ごと置き換える(以前の実装)と、SwiftUIのNavigationStackがpop完了を
            // 検知するために元のdelegateへ依存している可能性のある呼び出しまで失われ、
            // 「スワイプでは画面上は戻ったように見えるのにpathの中身が古いままで、
            // 何かの拍子(シート表示など)に元のpushへ戻ってしまう」という深刻な不具合を生んでいた。
            // 初回だけ元のdelegateを保持し、以降は自前のdelegateへ差し替える
            // (自前のdelegateが未知のセレクタを元のdelegateへ転送する)。
            if edgeDelegate.originalDelegate == nil {
                edgeDelegate.originalDelegate = nav.interactivePopGestureRecognizer?.delegate
            }
            nav.interactivePopGestureRecognizer?.delegate = edgeDelegate
        }
    }
}

/// システム標準のエッジスワイプ挙動(画面左端 ~24pt から始まった時だけ戻るジェスチャーを許可)を
/// 再現しつつ、それ以外の呼び出しは元のdelegate(SwiftUIが内部で使っているもの)へそのまま
/// 転送する。丸ごと置き換えるとSwiftUI側のpop完了の検知が壊れることがあるため。
private final class EdgeOnlyPopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var originalDelegate: UIGestureRecognizerDelegate?

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = gestureRecognizer.view else { return true }
        let location = pan.location(in: view)
        return location.x < 24
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return originalDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        let ownSelectors: [Selector] = [
            #selector(UIGestureRecognizerDelegate.gestureRecognizerShouldBegin(_:)),
            #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)),
        ]
        if ownSelectors.contains(aSelector) { return nil }
        return originalDelegate
    }
}
