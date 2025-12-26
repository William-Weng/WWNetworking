//
//  TaskDelegateProxy.swift
//  WWNetworking
//
//  Created by William.Weng on 2025/12/26.
//

import Foundation

// MARK: - 轉接URLSessionTaskDelegate
final class TaskDelegateProxy: NSObject {
    
    weak var owner: WWNetworking?
    
    deinit { owner = nil }
}

// MARK: - URLSessionTaskDelegate
extension TaskDelegateProxy: URLSessionTaskDelegate {
        
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        Task { [weak owner] in
            await owner?.fragmentDownloadCompleteAction(session, task: task, didCompleteWithError: error)
            await owner?.fragmentUploadCompleteAction(session, task: task, didCompleteWithError: error)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = fragmentUploadProgressAction(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        Task { [weak owner] in await owner?.fragmentUploadProgressAction(progress) }
    }
}

// MARK: - 小工具
private extension TaskDelegateProxy {
    
    /// 分段上傳進度處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - bytesSent: Int64
    ///   - totalBytesSent: Int64
    ///   - totalBytesExpectedToSend: Int64
    /// - Returns: WWNetworking.UploadProgressInformation
    func fragmentUploadProgressAction(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> WWNetworking.UploadProgressInformation {
        let progress: WWNetworking.UploadProgressInformation = (urlString: task.currentRequest?.url?.absoluteString, bytesSent: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        return progress
    }
}
