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
        
        guard let owner = owner else { return }
        
        let sslPinning = await owner.sslPinning
        
        var host: String?
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        
        defer { Task { await owner.delegate?.authChalleng(owner, host: host, disposition: disposition, credential: credential) }}
        
        if (sslPinning.values.isEmpty) { return completionHandler(.performDefaultHandling, nil) }
        
        let pinning = sslPinning
        let pinningHosts = pinning.values.map { $0.host }
        host = challenge.protectionSpace.host.lowercased()
        
        guard let host = host,
              pinningHosts.contains(host),
              let value = pinning.values.first(where: {$0.host.lowercased() == host.lowercased()})
        else {
            return completionHandler(.performDefaultHandling, nil)
        }
        
        switch challenge._checkAuthenticationSSLPinning(bundle: pinning.bundle, filename: value.cer) {
        case .success(let trust): disposition = .useCredential; credential = URLCredential(trust: trust)
        case .failure: disposition = .cancelAuthenticationChallenge
        }
        
        completionHandler(disposition, credential)
    }
}
