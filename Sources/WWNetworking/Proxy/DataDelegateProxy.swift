//
//  File.swift
//  WWNetworking
//
//  Created by iOS on 2025/12/26.
//

import Foundation

// MARK: - 轉接URLSessionDataDelegate
final class DataDelegateProxy: NSObject {
    
    weak var owner: WWNetworking?
    
    deinit { owner = nil }
}

// MARK: - URLSessionDataDelegate
extension DataDelegateProxy: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        owner?.fragmentDownloadAction(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        owner?.fragmentDownloadedAction(session, dataTask: dataTask, didReceive: data)
    }
}
