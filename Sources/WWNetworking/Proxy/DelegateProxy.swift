//
//  DelegateProxy.swift
//  WWNetworking
//
//  Created by iOS on 2025/12/29.
//

import Foundation

// MARK: - 轉接URLSessionDelegate
class DelegateProxy: NSObject {
    
    weak var owner: WWNetworking?
    
    deinit { owner = nil }
}

// MARK: - URLSessionDataDelegate
extension DelegateProxy: URLSessionDelegate {

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Task { await sslPinningAction(with: session, didReceive: challenge, completionHandler: completionHandler) }
    }
}

// MARK: - SSL Pinning
private extension DelegateProxy {
    
    /// [處理 URLSession 的身份驗證挑戰](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411595-urlsession)
    /// - Parameters:
    ///   - session: URLSession
    ///   - challenge: URLAuthenticationChallenge
    ///   - completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?)
    func sslPinningAction(with session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) async {
        
        guard let sslPinning = await owner?.sslPinning,
              !sslPinning.values.isEmpty
        else {
            return completionHandler(.performDefaultHandling, nil)
        }
        
        let host = challenge.protectionSpace.host.lowercased()
        let pinning = sslPinning
        let pinningHosts = pinning.values.map { $0.host }
        
        print("⚠️ [Challenge Host - DataDelegateProxy] => \(host)")
        
        guard pinningHosts.contains(host),
              let value = pinning.values.first(where: {$0.host.lowercased() == host.lowercased()})
        else {
            return completionHandler(.performDefaultHandling, nil)
        }
        
        switch challenge._checkAuthenticationSSLPinning(bundle: pinning.bundle, filename: value.cer) {
        case .success(let trust): completionHandler(.useCredential, URLCredential(trust: trust))
        case .failure: completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
