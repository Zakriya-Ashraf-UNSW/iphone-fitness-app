import UIKit
import Capacitor
import WebKit

class ViewController: CAPBridgeViewController, WKScriptMessageHandler {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        // Register LiveActivityPlugin directly on the Capacitor bridge
        bridge?.registerPluginInstance(LiveActivityPlugin())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Native WebKit message handler bridge fallback
        webView?.configuration.userContentController.add(self, name: "liveActivity")
        // Edge-to-edge safe area handling with viewport-fit=cover
        webView?.scrollView.contentInsetAdjustmentBehavior = .never
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "liveActivity", let dict = message.body as? [String: Any] {
            LiveActivityPlugin.sharedInstance.handleDirectMessage(dict)
        }
    }
}
