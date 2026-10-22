import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 5/255, green: 7/255, blue: 10/255)
                .ignoresSafeArea()

            OfflineWebView()
                .ignoresSafeArea()
        }
    }
}

struct OfflineWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable local file access and script execution
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 5/255, green: 7/255, blue: 10/255, alpha: 1)
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // 1. Try to find index.html in "www" subdirectory
        if let wwwDir = Bundle.main.url(forResource: "www", withExtension: nil) {
            let indexUrl = wwwDir.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: indexUrl.path) {
                webView.loadFileURL(indexUrl, allowingReadAccessTo: wwwDir)
                return webView
            }
        }
        
        // 2. Try to find index.html in bundle root
        if let indexUrl = Bundle.main.url(forResource: "index", withExtension: "html") {
            let accessDir = indexUrl.deletingLastPathComponent()
            webView.loadFileURL(indexUrl, allowingReadAccessTo: accessDir)
            return webView
        }
        
        // 3. Fallback search via resourceURL
        if let resourceUrl = Bundle.main.resourceURL {
            let candidate1 = resourceUrl.appendingPathComponent("www").appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: candidate1.path) {
                webView.loadFileURL(candidate1, allowingReadAccessTo: resourceUrl)
                return webView
            }
            let candidate2 = resourceUrl.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: candidate2.path) {
                webView.loadFileURL(candidate2, allowingReadAccessTo: resourceUrl)
                return webView
            }
        }

        // 4. Fallback: Network URL if bundled files are somehow unavailable
        if let fallbackUrl = URL(string: "http://172.20.10.2:8899/mobile") {
            webView.load(URLRequest(url: fallbackUrl))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Self-contained app; state is maintained in WebView
    }
}
