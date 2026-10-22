import SwiftUI
import WebKit

struct ContentView: View {
    @AppStorage("pc_gateway_url") private var serverUrl: String = "http://172.20.10.2:8899/mobile"
    @State private var showSettings: Bool = false
    @State private var inputUrl: String = ""

    var body: some View {
        ZStack {
            Color(red: 5/255, green: 7/255, blue: 10/255)
                .ignoresSafeArea()

            WebViewContainer(urlString: serverUrl)
                .ignoresSafeArea()

            // Quick gear button in corner to change PC IP if network changes
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        inputUrl = serverUrl
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(.top, 48)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section(header: Text("Địa Chỉ Máy Chủ AirPulse PC")) {
                        TextField("http://192.168.x.x:8899/mobile", text: $inputUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    Section(footer: Text("Nhập địa chỉ IP hiển thị trên màn hình máy tính của bạn.")) {
                        Button("Lưu & Kết Nối Lại") {
                            serverUrl = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                            showSettings = false
                        }
                    }
                }
                .navigationTitle("Cấu Hình Kết Nối")
                .navigationBarItems(trailing: Button("Đóng") { showSettings = false })
            }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 5/255, green: 7/255, blue: 10/255, alpha: 1)
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if let url = URL(string: urlString) {
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            webView.load(req)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let currentUrl = uiView.url?.absoluteString, currentUrl != urlString, let newUrl = URL(string: urlString) {
            uiView.load(URLRequest(url: newUrl))
        }
    }
}
