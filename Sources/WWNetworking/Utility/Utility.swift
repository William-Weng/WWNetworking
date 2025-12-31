//
//  Utility.swift
//  WWNetworking
//
//  Created by Willam.Weng on 2025/12/29.
//

import Foundation

extension WWNetworking {
    final class Utility {}
}

// MARK: - 小工具
extension WWNetworking.Utility {
        
    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - contentType: [要回傳的格式 => application/json](https://notfalse.net/39/http-message-format)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - queryItems: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - delegate: URLSessionDataDelegate
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionTask?
    func request(httpMethod: WWNetworking.HttpMethod = .GET, urlString: String, contentType: WWNetworking.ContentType = .json, timeout: TimeInterval, queryItems: [URLQueryItem]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil, delegate: URLSessionDataDelegate, delegateQueue: OperationQueue?, result: @escaping (Result<WWNetworking.ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        
        guard let urlComponents = URLComponents._build(urlString: urlString, queryItems: queryItems),
              let queryedURL = urlComponents.url
        else {
            result(.failure(WWNetworking.CustomError.notUrlFormat)); return nil
        }
        
        var request = URLRequest._build(url: queryedURL, httpMethod: httpMethod, timeout: timeout)
        
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        request.httpBody = httpBody
        request._setValue(contentType, forHTTPHeaderField: .contentType)
        
        let task = fetchData(from: request, delegate: delegate, delegateQueue: delegateQueue, result: result)
        return task
    }
    
    /// [抓取資料 - dataTask() => URLSessionDataDelegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate)
    /// - Parameters:
    ///   - request: [URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    ///   - configuration: URLSessionConfiguration
    ///   - delegate: URLSessionDataDelegate
    ///   - delegateQueue: 執行緒
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask
    func fetchData(from request: URLRequest, configuration: URLSessionConfiguration = .default, delegate: URLSessionDataDelegate, delegateQueue: OperationQueue?, result: @escaping (Result<WWNetworking.ResponseInformation, Error>) -> Void) -> URLSessionDataTask {
        
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            Task { @MainActor in
                if let error = error { result(.failure(error)); return }
                let info: WWNetworking.ResponseInformation = (data: data, response: response as? HTTPURLResponse)
                result(.success(info))
            }
        }
        
        dataTask.resume()
        return dataTask
    }
}

// MARK: - 小工具
extension WWNetworking.Utility {
    
    /// 計算下載的檔案總和 (將分段的Data組合起來)
    /// - Parameters:
    ///   - datas: [<Task String>: Data]
    ///   - keys: [<Task String>]
    /// - Returns: Data
    func downloadTotalDatas(_ datas: [String: Data], for keys: [String]) -> Data {

        var downloadData = Data()
        for key in keys { if let _data = datas[key] { downloadData += _data }}

        return downloadData
    }
    
    /// 產生上傳檔案的Body (多個檔案) - Content-Type: multipart/form-data
    /// - Parameters:
    ///   - boundary: 分隔字串
    ///   - formDatas: 上傳檔案的相關資料
    ///   - parameters: [String: String]?
    /// - Returns: Data
    func multipleUploadBodyMaker(boundary: String, formDatas: [WWNetworking.FormDataInformation], parameters: [String: String]?) -> Data {
        
        var body = Data()
        
        for formData in formDatas {
            
            /* 上傳Data的部分 */
            _ = body._append(string: "--\(boundary)\r\n")
            _ = body._append(string: "Content-Disposition: form-data; name=\"\(formData.name)\"; filename=\"\(formData.filename)\"\r\n")
            _ = body._append(string: "Content-Type: \(formData.contentType)\r\n")
            _ = body._append(string: "\r\n")
            _ = body._append(data: formData.data)
            _ = body._append(string: "\r\n")
        }
        
        /* 額外參數的部分 */
        parameters?.forEach { (key, value) in
            _ = body._append(string: "--\(boundary)\r\n")
            _ = body._append(string: "Content-Disposition: form-data; name=\"\(key)\"\r\n")
            _ = body._append(string: "\r\n")
            _ = body._append(string: "\(value)")
            _ = body._append(string: "\r\n")
        }
        
        /* 結尾部分 */
        _ = body._append(string: "--\(boundary)--\r\n")
        
        return body
    }
    
    /// [產生下載用的HttpTask - downloadTask() => URLSessionDownloadDelegate](https://developer.apple.com/documentation/foundation/urlsessiondownloaddelegate)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: URLSessionConfiguration
    ///   - delegate: URLSessionDownloadDelegate
    ///   - delegateQueue: 執行緒
    /// - Returns: URLSessionDownloadTask
    func downloadTaskMaker(with httpMethod: WWNetworking.HttpMethod?, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegate: URLSessionDownloadDelegate, delegateQueue: OperationQueue? = .current) -> URLSessionDownloadTask? {
        
        guard let request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { return nil }
        
        let urlSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        let downloadTask = urlSession.downloadTask(with: request)

        downloadTask.delegate = delegate
        urlSession.finishTasksAndInvalidate()
        
        return downloadTask
    }
    
    /// Range: bytes=0-1024
    /// - Parameter offset: WWNetworking.HttpDownloadOffset
    /// - Returns: String?
    func downloadOffsetMaker(offset: WWNetworking.HttpDownloadOffset) -> String? {

        guard let startOffset = offset.start else { return nil }
        guard let endOffset = offset.end else { return String(format: "bytes=%lld-", startOffset) }

        return String(format: "bytes=%lld-%lld", startOffset, endOffset)
    }
    
    /// [斷點續傳下載檔案 - URLSessionTaskDelegate (Data) => HTTPHeaderField = Range / ∵ 是一段一段下載 ∴ 自己要一段一段存](https://www.jianshu.com/p/534ec0d9d758)
    /// - urlSession(_:dataTask:didReceive:) => completionHandler(.allow)
    /// - Parameters:
    ///   - urlString: [String](https://stackoverflow.com/questions/58023230/memory-leak-occurring-in-iphone-x-after-updating-to-ios-13)
    ///   - delegate: URLSessionDataDelegate
    ///   - delegateQueue: OperationQueue?
    ///   - offset: HttpDownloadOffset
    ///   - timeout: TimeInterval
    ///   - configiguration: URLSessionConfiguratio
    /// - Returns: URLSessionDataTask?
    func fragmentDownloadDataTaskMaker(with urlString: String, delegate: URLSessionDataDelegate, delegateQueue: OperationQueue?, offset: WWNetworking.HttpDownloadOffset = (0, nil), timeout: TimeInterval, configiguration: URLSessionConfiguration) -> URLSessionDataTask? {

        guard let url = URL(string: urlString),
              let headerValue = downloadOffsetMaker(offset: offset)
        else {
            return nil
        }
        
        let urlSession = URLSession(configuration: configiguration, delegate: delegate, delegateQueue: delegateQueue)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        
        defer { urlSession.finishTasksAndInvalidate() }
        
        request._setValue(headerValue, forHTTPHeaderField: .range)
        
        let dataTask = urlSession.dataTask(with: request)
        dataTask.delegate = delegate
        
        return dataTask
    }
}
