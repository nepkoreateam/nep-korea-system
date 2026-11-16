import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = NEPViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class NEPViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private let host = "nepkoreateam.github.io"
    private let prefix = "/nep-korea-system/"
    private let home = URL(string: "https://nepkoreateam.github.io/nep-korea-system/")!
    private let blue = UIColor(red: 15/255, green: 63/255, blue: 140/255, alpha: 1)
    private var web: WKWebView!
    private let progress = UIProgressView(progressViewStyle: .default)
    private var progressObservation: NSKeyValueObservation?
    private var downloadLocations: [ObjectIdentifier: URL] = [:]
    private let offline = UIStackView()
    private var isFailed = false

    private func isOrigin(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        return url.scheme?.lowercased() == "https" && url.host?.lowercased() == host
            && (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
    }
    private func isApp(_ url: URL?) -> Bool {
        guard isOrigin(url), let path = url?.path else { return false }
        return (path == "/nep-korea-system" || path.hasPrefix(prefix)) && !path.contains("/../")
    }
    private func trustedFrame(_ frame: WKFrameInfo) -> Bool {
        isOrigin(frame.request.url) && isApp(web.url)
    }
    private func canDownload(_ url: URL?) -> Bool {
        if isApp(url) { return true }
        if let absolute = url?.absoluteString { return absolute.hasPrefix("blob:https://" + host + "/") && isApp(web.url) }
        return false
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 245/255, green: 247/255, blue: 251/255, alpha: 1)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        let title = UILabel()
        title.text = "NEP KOREA"
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 17)
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = .white
        back.accessibilityLabel = "뒤로"
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        let reload = UIButton(type: .system)
        reload.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        reload.tintColor = .white
        reload.accessibilityLabel = "새로고침"
        reload.addTarget(self, action: #selector(reloadApp), for: .touchUpInside)
        let bar = UIStackView(arrangedSubviews: [back, title, reload])
        bar.axis = .horizontal; bar.alignment = .center; bar.spacing = 12
        bar.isLayoutMarginsRelativeArrangement = true
        bar.layoutMargins = UIEdgeInsets(top: 2,left: 12,bottom: 2,right: 12)
        bar.backgroundColor = blue
        bar.heightAnchor.constraint(equalToConstant: 48).isActive = true
        back.widthAnchor.constraint(equalToConstant: 32).isActive = true
        reload.widthAnchor.constraint(equalToConstant: 36).isActive = true
        progress.progressTintColor = blue
        progress.trackTintColor = .systemGray5
        progress.heightAnchor.constraint(equalToConstant: 3).isActive = true
        let frame = UIView()
        frame.addSubview(web); web.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            web.topAnchor.constraint(equalTo: frame.topAnchor),
            web.bottomAnchor.constraint(equalTo: frame.bottomAnchor)
        ])
        let heading = UILabel(); heading.text = "연결을 확인해주세요"
        heading.font = .boldSystemFont(ofSize: 22); heading.textColor = blue; heading.textAlignment = .center
        let body = UILabel()
        body.text = "인터넷 연결을 확인한 후 다시 시도해주세요.\n수거 완료는 서버 저장이 확인된 경우에만 처리됩니다."
        body.font = .systemFont(ofSize: 15); body.textColor = .secondaryLabel; body.textAlignment = .center; body.numberOfLines = 0
        let retry = UIButton(type: .system)
        retry.setTitle("다시 연결", for: .normal)
        retry.addTarget(self, action: #selector(loadHome), for: .touchUpInside)
        offline.axis = .vertical; offline.spacing = 16; offline.alignment = .fill
        offline.addArrangedSubview(heading); offline.addArrangedSubview(body); offline.addArrangedSubview(retry)
        offline.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(offline)
        NSLayoutConstraint.activate([
            offline.centerYAnchor.constraint(equalTo: frame.centerYAnchor),
            offline.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 25),
            offline.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -25)
        ])
        offline.isHidden = true
        let content = UIStackView(arrangedSubviews: [bar, progress, frame])
        content.axis = .vertical
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        progressObservation = web.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async { self?.progress.setProgress(Float(web.estimatedProgress), animated: true) }
        }
        loadHome()
    }
    @objc private func loadHome() {
        isFailed = false; offline.isHidden = true; web.isHidden = false
        web.load(URLRequest(url: home, cachePolicy: .reloadIgnoringLocalCacheData))
    }
    @objc private func reloadApp() {
        if isFailed || !isApp(web.url) { loadHome() } else { web.reloadFromOrigin() }
    }
    @objc private func goBack() { if web.canGoBack { web.goBack() } else { loadHome() } }
    private func showOffline() {
        isFailed = true; web.isHidden = true; offline.isHidden = false; progress.setProgress(0, animated: false)
    }
    private func openExternal(_ url: URL) {
        guard ["https", "tel", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return }
        UIApplication.shared.open(url)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.shouldPerformDownload {
            decisionHandler(canDownload(url) ? .download : .cancel); return
        }
        if navigationAction.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if isApp(url) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel); web.load(navigationAction.request)
            } else { decisionHandler(.allow) }
            return
        }
        decisionHandler(.cancel)
        if navigationAction.navigationType == .linkActivated { openExternal(url) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse, navigationResponse.isForMainFrame, response.statusCode >= 400 {
            decisionHandler(.cancel); showOffline(); return
        }
        if !navigationResponse.canShowMIMEType {
            decisionHandler(canDownload(navigationResponse.response.url) ? .download : .cancel); return
        }
        if navigationResponse.isForMainFrame && !isApp(navigationResponse.response.url) { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { progress.setProgress(0, animated: false) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isApp(web.url) { isFailed = false; web.isHidden = false; offline.isHidden = true }
        progress.setProgress(1, animated: true)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showOffline() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showOffline() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { showOffline() }
    // JS dialogs preserve the existing NEP app's confirm/prompt flows.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard trustedFrame(frame), presentedViewController == nil else { completionHandler(); return }
        let a = UIAlertController(title: "NEP KOREA", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard trustedFrame(frame), presentedViewController == nil else { completionHandler(false); return }
        let a = UIAlertController(title: "NEP KOREA", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard trustedFrame(frame), presentedViewController == nil else { completionHandler(nil); return }
        let a = UIAlertController(title: "NEP KOREA", message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        present(a, animated: true)
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let allowed = origin.protocol == "https" && origin.host == host && trustedFrame(frame) && type == .camera
        decisionHandler(allowed ? .prompt : .deny)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let name = (suggestedFilename as NSString).lastPathComponent
        let clean = name.isEmpty || name == "." || name == ".." ? "NEP-export" : name
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("NEP-" + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let target = dir.appendingPathComponent(clean)
            downloadLocations[ObjectIdentifier(download)] = target; completionHandler(target)
        } catch { completionHandler(nil) }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloadLocations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX,y: view.bounds.midY,width: 1,height: 1)
        share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        if presentedViewController == nil { present(share, animated: true) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let url = downloadLocations.removeValue(forKey: ObjectIdentifier(download)) { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        guard presentedViewController == nil else { return }
        let a = UIAlertController(title: "파일 저장 실패", message: "인터넷 연결을 확인하거나 PC에서 다시 내려받아주세요.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "확인", style: .default)); present(a, animated: true)
    }
}
