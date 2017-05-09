//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public protocol NorthstarWebViewControllerDelegate: class {
    func didFailLoad(withError error: Error)
}

extension NorthstarWebViewController: NorthstarLoadable {}

public final class NorthstarWebViewController: UIViewController {

    public var request: URLRequest?
    public weak var delegate: NorthstarWebViewControllerDelegate?

    @IBOutlet weak var webView: UIWebView!

    public override func viewDidLoad() {
        super.viewDidLoad()
        if let request = request {
            webView.loadRequest(request)
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
    }
}

extension NorthstarWebViewController: UIWebViewDelegate {
    public func webView(_: UIWebView, shouldStartLoadWith request: URLRequest, navigationType _: UIWebViewNavigationType) -> Bool {
        if let URL = request.url {
            if URL.scheme == "mailto" || URL.scheme == "tel" {
                UIApplication.shared.openURL(URL)
                return false
            }
            if URL.scheme == "http" {
                UIApplication.shared.openURL(URL)
                return false
            }
        }
        return true
    }

    public func webViewDidFinishLoad(_ webView: UIWebView) {
        let documentTitle = webView.stringByEvaluatingJavaScript(from: "document.title")
        guard let vcTitle = documentTitle, !vcTitle.isEmpty else { return }
        title = vcTitle
    }

    public func webView(_: UIWebView, didFailLoadWithError error: Error) {
        delegate?.didFailLoad(withError: error)
    }
}
