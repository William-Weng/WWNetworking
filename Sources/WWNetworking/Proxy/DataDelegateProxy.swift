//
//  DataDelegateProxy.swift
//  WWNetworking
//
//  Created by William.Weng on 2025/12/26.
//

import Foundation

// MARK: - 轉接URLSessionDataDelegate
final class DataDelegateProxy: DelegateProxy {}

// MARK: - URLSessionDataDelegate
extension DataDelegateProxy: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Task { [weak owner] in await owner?.fragmentDownloadAction(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { [weak owner] in await owner?.fragmentDownloadedAction(session, dataTask: dataTask, didReceive: data) }
    }
}
