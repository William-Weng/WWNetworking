//
//  File.swift
//  WWNetworking
//
//  Created by iOS on 2025/12/26.
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
        owner?.fragmentDownloadCompleteAction(session, task: task, didCompleteWithError: error)
        owner?.fragmentUploadCompleteAction(session, task: task, didCompleteWithError: error)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        owner?.fragmentUploadProgressAction(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }
}
