//
//  DownloadDelegateProxy.swift
//  WWNetworking
//
//  Created by William.Weng on 2025/12/26.
//

import Foundation

// MARK: - 轉接URLSessionDownloadDelegate
final class DownloadDelegateProxy: NSObject {
    
    weak var owner: WWNetworking?
    
    deinit { owner = nil }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadDelegateProxy: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let result = downloadProgressAction(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        Task { [weak owner] in await owner?.downloadProgressAction(result: result) }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let result = downloadFinishedAction(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        Task { [weak owner] in await owner?.downloadFinishedAction(result: result) }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Task { [weak owner] in await owner?.sslPinning(with: session, didReceive: challenge, completionHandler: completionHandler) }
    }
}

// MARK: - 小工具
private extension DownloadDelegateProxy {
    
    /// 下載完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - downloadTask: URLSessionDownloadTask
    ///   - location: URL
    /// - Returns: Result<WWNetworking.DownloadResultInformation, Error>
    func downloadFinishedAction(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) -> Result<WWNetworking.DownloadResultInformation, Error> {
        
        guard let response = downloadTask.response as? HTTPURLResponse,
              let urlString = downloadTask.currentRequest?.url?.absoluteString
        else {
            return .failure(WWNetworking.CustomError.notUrlDownload)
        }
        
        do {
            let fileUrl = try moveLocationFile(at: location).get()
            let data = try Data(contentsOf: fileUrl)
            let info: WWNetworking.DownloadResultInformation = (urlString: urlString, location: fileUrl, data: data)
            return .success(info)
        } catch {
            return .failure(error)
        }
    }
    
    /// 下載進度處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - downloadTask: URLSessionDownloadTask
    ///   - bytesWritten: Int64
    ///   - totalBytesWritten: Int64
    ///   - totalBytesExpectedToWrite: Int64
    func downloadProgressAction(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Result<WWNetworking.DownloadProgressInformation, Error> {
        
        guard let response = downloadTask.response as? HTTPURLResponse,
              let urlString = downloadTask.originalRequest?.url?.absoluteString
        else {
            return .failure(WWNetworking.CustomError.notUrlDownload)
        }
        
        let httpResponse = WWNetworking.HttpResponse.builder(response: response)
        if (httpResponse.hasError()) { downloadTask.cancel(); return .failure(httpResponse) }
        
        let progress: WWNetworking.DownloadProgressInformation = (urlString: urlString, totalSize: totalBytesExpectedToWrite, totalWritten: totalBytesWritten, writting: bytesWritten)
        return .success(progress)
    }
    
    /// 移動本地下載完成的檔案 (因為在tmp的檔案會不見)
    /// - Parameter location: tmp檔位置
    /// - Returns: Result<URL, any Error>
    func moveLocationFile(at location: URL) -> Result<URL, any Error> {
        
        guard let cachesDirectory = FileManager.default._cachesDirectory() else { return .failure(WWNetworking.CustomError.isCachesDirectoryEmpty) }
        
        let fileURL = cachesDirectory.appending(component: location.lastPathComponent)
                
        switch FileManager.default._moveFile(at: location, to: fileURL) {
        case .success(_): return .success(fileURL)
        case .failure(let error): return .failure(error)
        }
    }
}
