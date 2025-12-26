//
//  Networking.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import Foundation

// MARK: - 簡易型的AFNetworking (單例)
open class WWNetworking: NSObject {
    
    public static let shared = WWNetworking()
    
    public static var sslPinning: SSLPinningInformation = (bundle: .main, values: [])
    
    private var downloadTaskResultBlock: ((Result<DownloadResultInformation, Error>) -> Void)?      // 下載檔案完成的動作
    private var downloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?               // 下載進行中的進度 - 檔案

    private var fragmentDownloadFinishBlock: ((Result<Data, Error>) -> Void)?                       // 分段下載完成的動作
    private var fragmentDownloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?       // 分段下載進行中的進度 - 檔案大小
    private var fragmentDownloadContentLength = -1                                                  // 分段下載的檔案總大小
    private var fragmentDownloadDatas: [String: Data] = [:]                                         // 記錄分段下載的Data
    private var fragmentDownloadKeys: [String] = []                                                 // 記錄Tasks的順序
    
    private var fragmentUploadFinishBlock: ((Result<Bool, Error>) -> Void)?                         // 分段上傳完成的動作
    private var fragmentUploadProgressResultBlock: ((UploadProgressInformation) -> Void)?           // 分段下載進行中的進度 - 檔案大小
}

extension WWNetworking: URLSessionTaskDelegate {}
extension WWNetworking: URLSessionDataDelegate {}
extension WWNetworking: URLSessionDownloadDelegate {}

// MARK: - URLSessionTaskDelegate
public extension WWNetworking {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.fragmentDownloadCompleteAction(session, task: task, didCompleteWithError: error)
        self.fragmentUploadCompleteAction(session, task: task, didCompleteWithError: error)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        self.fragmentUploadProgressAction(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }
}

// MARK: - URLSessionDataDelegate
public extension WWNetworking {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.fragmentDownloadAction(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.fragmentDownloadedAction(session, dataTask: dataTask, didReceive: data)
    }
}

// MARK: - URLSessionDownloadDelegate
public extension WWNetworking {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadProgressAction(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.downloadFinishedAction(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        sslPinning(with: session, didReceive: challenge, completionHandler: completionHandler)
    }
}

// MARK: - 公開函數 (static)
public extension WWNetworking {
    
    /// 建立一個新的WWNetworking
    /// - Returns: WWNetworking
    static func builder() -> WWNetworking { return WWNetworking() }
}

// MARK: - 公開函數
public extension WWNetworking {
    
    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - contentType: HttpBody的類型
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - paramaters: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBodyType: HttpBobyType?
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionTask?
    func request(httpMethod: HttpMethod = .GET, urlString: String, timeout: TimeInterval = 60, contentType: ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBodyType: HttpBobyType? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        let task = request(httpMethod: httpMethod, urlString: urlString, contentType: contentType, timeout: timeout, queryItems: paramaters?._queryItems(), headers: headers, httpBody: httpBodyType?.data(), delegateQueue: delegateQueue) { result($0) }
        return task
    }
    
    /// [取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)](https://github.com/pro648/tips/blob/master/sources/URLSession详解.md)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation?, Error>
    /// - Returns: URLSessionTask?
    func header(urlString: String, timeout: TimeInterval = 60, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        
        let task = request(httpMethod: .HEAD, urlString: urlString, timeout: timeout, contentType: .plain, paramaters: nil, headers: headers, httpBodyType: nil, delegateQueue: delegateQueue) { _result in

            switch _result {
            case .failure(let error): result(.failure(error))
            case .success(let info): result(.success(info))
            }
        }
        
        return task
    }
    
    /// [上傳檔案 - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - formData: [圖片Data相關參數](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - parameters: [額外參數](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask?
    func upload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, parameters: [String: String]? = nil, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(CustomError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = multipleUploadBodyMaker(boundary: boundary, formDatas: [formData], parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return fetchData(from: request, delegateQueue: delegateQueue, result: result)
    }
    
    /// [上傳檔案 (多個) - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - formDatas: [圖片Data相關參數](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - parameters: [額外參數](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask?
    func multipleUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formDatas: [FormDataInformation], parameters: [String: String]? = nil, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(CustomError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = multipleUploadBodyMaker(boundary: boundary, formDatas: formDatas, parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return fetchData(from: request, delegateQueue: delegateQueue, result: result)
    }
    
    /// [二進制檔案上傳 - 大型檔案](https://www.swiftbysundell.com/articles/http-post-and-file-upload-requests-using-urlsession/)
    /// - Parameters:
    ///   - httpMethod: [HttpMethod?](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
    ///   - urlString: [String](https://cloud.tencent.com/developer/ask/sof/642880)
    ///   - formData: [FormDataInformation](https://ithelp.ithome.com.tw/articles/10185514)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - headers:  [String: String?]?
    ///   - delegateQueue: OperationQueue?
    ///   - progress: UploadProgressInformation
    ///   - completion: Result<Bool, Error>
    /// - Returns: URLSessionUploadTask?
    func binaryUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, progress: @escaping ((UploadProgressInformation) -> Void), completion: @escaping (Result<Bool, Error>) -> Void) -> URLSessionUploadTask? {
        
        cleanAllBlocks()
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { completion(.failure(CustomError.notOpenURL)); return nil }
        
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        var uploadTask: URLSessionUploadTask?
        
        request._setValue("\(formData.contentType)", forHTTPHeaderField: .contentType)
        request.setValue(formData.filename, forHTTPHeaderField: formData.name)
        uploadTask = urlSession.uploadTask(with: request, from: formData.data)
                
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        fragmentUploadProgressResultBlock = progress
        fragmentUploadFinishBlock = completion
        
        uploadTask?.resume()
        urlSession.finishTasksAndInvalidate()

        return uploadTask
    }
    
    /// [下載資料 => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [下載資料網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: [URLSession設定 / timeout](https://draveness.me/ios-yuan-dai-ma-jie-xi-sdwebimage/)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - progress: [下載進度](https://www.appcoda.com.tw/ios-concurrency/)
    ///   - completion: 下載完成後
    /// - Returns: URLSessionDownloadTask?
    func download(httpMethod: HttpMethod? = .GET, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = nil, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> URLSessionDownloadTask? {
        
        guard let downloadTask = downloadTaskMaker(with: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) else { completion(.failure(CustomError.notUrlFormat)); return nil }
        
        downloadTaskResultBlock = completion
        downloadProgressResultBlock = progress
        
        downloadTask.resume()
        
        return downloadTask
    }

    /// [下載資料 (多個) => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlStrings: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: [URLSessionConfiguration](https://cootie8788.medium.com/swift-示範如何客製化元件-2-串上http-get-作法-f9db4524c31c)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - progress: 下載進度
    ///   - completion: 下載完成後
    /// - Returns: [URLSessionDownloadTask]
    func multipleDownload(httpMethod: HttpMethod? = .GET, urlStrings: [String], timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> [URLSessionDownloadTask] {
        
        cleanAllBlocks()
        
        let downloadTasks = urlStrings.compactMap { urlString in
            
            download(httpMethod: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) { info in
                progress(info)
            } completion: { result in
                completion(result)
            }
        }
        
        return downloadTasks
    }
    
    /// [分段下載](https://www.jianshu.com/p/534ec0d9d758)
    /// - Parameters:
    ///   - urlString: 下載資料網址
    ///   - timeout: TimeInterval
    ///   - fragment: 分段數量
    ///   - configiguration: URLSessionConfiguration
    ///   - delegateQueue: OperationQueue
    ///   - progress: 下載進度
    ///   - fragmentTask: URLSessionTask
    ///   - completion: Result<Data, Error>
    func fragmentDownload(urlString: String, timeout: TimeInterval = .infinity, fragment: Int = 2, configiguration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current, progress: @escaping ((DownloadProgressInformation) -> Void), fragmentTask: @escaping (URLSessionTask) -> Void, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard fragment > 0 else { completion(.failure(CustomError.fragmentCountError)); return }
        
        fragmentDownloadProgressResultBlock = progress
        cleanFragmentInformation()
        
        header(urlString: urlString, timeout: timeout) { result in

            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let info):

                guard let contentLengthString = info.response?._headerField(with: .contentLength) as? String,
                      let contentLength = Int(contentLengthString)
                else {
                    completion(.failure(CustomError.notUrlDownload)); return
                }
                
                let fragmentSize = (contentLength / fragment) + 1
                self.fragmentDownloadContentLength = contentLength
                
                for index in 0..<fragment {

                    let offset: HttpDownloadOffset = (index * fragmentSize, (index + 1) * fragmentSize - 1)

                    let _task = self.fragmentDownloadDataTaskMaker(with: urlString, delegateQueue: delegateQueue, offset: offset, timeout: timeout, configiguration: configiguration) { _result in
                        switch _result {
                        case .failure(let error): completion(.failure(error))
                        case .success(let info): completion(.success(info))
                        }
                    }

                    if let _task = _task {
                        self.fragmentDownloadKeys.append("\(_task)")
                        _task.resume()
                        fragmentTask(_task)
                    }
                }
            }
        }
    }
}

// MARK: - 公開函數 (非同步)
public extension WWNetworking {
    
    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - paramaters: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - contentType: ContentType
    ///   - httpBodyType: HttpBobyType?
    ///   - delegateQueue: OperationQueue?
    /// - Returns: Result<ResponseInformation, Error>
    func request(httpMethod: HttpMethod = .GET, urlString: String, timeout: TimeInterval = 60, contentType: ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBodyType: HttpBobyType? = nil, delegateQueue: OperationQueue? = .current) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            request(httpMethod: httpMethod, urlString: urlString, timeout: timeout, contentType: contentType, paramaters: paramaters, headers: headers, httpBodyType: httpBodyType, delegateQueue: delegateQueue) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [順序執行多個Request](https://youtu.be/s2PiL_Vte4E)
    /// - Parameter types: [[RequestInformationType]](https://onevcat.com/2021/07/swift-concurrency/)
    /// - Returns: [Result<ResponseInformation, Error>]
    func multipleRequest(types: [RequestInformationType]) async -> [Result<ResponseInformation, Error>] {
        
        var requests: [Result<ResponseInformation, Error>] = []
        
        for type in types {
            async let request = request(httpMethod: type.httpMethod, urlString: type.urlString, timeout: type.timeout, contentType: type.contentType, paramaters: type.paramaters, headers: type.headers, httpBodyType: type.httpBodyType, delegateQueue: type.delegateQueue)
            requests.append(await request)
        }
        
        return requests
    }
    
    /// 同時執行多個Request
    /// - Parameter types: [RequestInformationType]
    /// - Returns: [Result<ResponseInformation, Error>]
    func multipleRequestWithTaskGroup(types: [RequestInformationType]) async -> [Result<ResponseInformation, Error>] {
        
        await withTaskGroup(of: Result<ResponseInformation, Error>.self) { [self] group in
            
            for type in types {
                group.addTask {
                    await self.request(httpMethod: type.httpMethod, urlString: type.urlString, timeout: type.timeout, contentType: type.contentType, paramaters: type.paramaters, headers: type.headers, httpBodyType: type.httpBodyType, delegateQueue: type.delegateQueue)
                }
            }
            
            var requests: [Result<ResponseInformation, Error>] = []
            for await request in group { requests.append(request) }
            
            return requests
        }
    }
    
    /// 串流執行多個Request
    /// - Parameter types: [RequestInformationType]
    /// - Returns: [Result<ResponseInformation, Error>]
    func multipleRequestWithStream(types: [RequestInformationType]) -> AsyncStream<Result<ResponseInformation, Error>> {
        
        AsyncStream { continuation in
            
            var parentTask: Task<Void, Never>?
            
            parentTask = Task {
                
                await withTaskGroup(of: Result<ResponseInformation, Error>.self) { [self] group in
                    
                    for type in types {
                        group.addTask {
                            await self.request(httpMethod: type.httpMethod, urlString: type.urlString, timeout: type.timeout, contentType: type.contentType, paramaters: type.paramaters, headers: type.headers, httpBodyType: type.httpBodyType, delegateQueue: type.delegateQueue)
                        }
                    }
                    
                    for await result in group { continuation.yield(result) }
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in parentTask?.cancel() }
        }
    }
    
    /// 取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    /// - Returns: Result<ResponseInformation, Error>
    func header(urlString: String, timeout: TimeInterval = 60, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            header(urlString: urlString, timeout: timeout, headers: headers, delegateQueue: delegateQueue) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [上傳檔案 - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - formData: [圖片Data相關參數](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - parameters: [額外參數](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    /// - Returns: Result<ResponseInformation, Error>
    func upload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, parameters: [String: String], headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            upload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formData: formData, parameters: parameters, headers: headers, delegateQueue: delegateQueue) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [上傳檔案 (多個) - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - formDatas: [圖片Data相關參數](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - parameters: [額外參數](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - delegateQueue: OperationQueue?
    /// - Returns: Result<ResponseInformation, Error>
    func multipleUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formDatas: [FormDataInformation], parameters: [String: String], headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            multipleUpload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formDatas: formDatas, parameters: parameters, headers: headers, delegateQueue: delegateQueue) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 二進制檔案上傳 - 大型檔案
    /// - Parameters:
    ///   - httpMethod: HttpMethod?
    ///   - urlString: String
    ///   - timeout: TimeInterval
    ///   - formData: FormDataInformation
    ///   - headers: [String: String?]?
    ///   - delegateQueue: OperationQueue?
    /// - Returns: AsyncThrowingStream<UploadState, Error>
    func binaryUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current) -> AsyncThrowingStream<UploadEvent, Error> {
        
        AsyncThrowingStream { continuation in
            
            let task = binaryUpload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formData: formData, headers: headers, delegateQueue: delegateQueue) { progress in
                continuation.yield(.progress(progress))
            } completion: { result in
                switch result {
                case .success(let isSuccess): continuation.yield(.finished(isSuccess)); continuation.finish()
                case .failure(let error): continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in task?.cancel() }
            
            if let task {
                continuation.yield(.start(task))
            } else {
                continuation.finish(throwing: CustomError.isURLSessionTaskNull)
            }
        }
    }
    
    /// [下載資料 => URLSessionDownloadDelegate](https://www.avanderlee.com/swift/asyncthrowingstream-asyncstream/)
    /// - Parameters:
    ///   - httpMethod: HTTP方法
    ///   - urlString: 下載資料網址
    ///   - timeout: 設定請求超時時間
    ///   - configuration: Timeout
    ///   - delegateQueue: 執行緒
    /// - Returns: AsyncThrowingStream<DownloadState, Error>
    func download(httpMethod: HttpMethod? = .GET, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current) -> AsyncThrowingStream<DownloadEvent, Error> {
        
        AsyncThrowingStream { continuation in
            
            let task = download(httpMethod: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) { progress in
                continuation.yield(.progress(progress))
            } completion: { result in
                switch result {
                case .success(let info): continuation.yield(.finished(info)); continuation.finish()
                case .failure(let error): continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in task?.cancel() }
            
            if let task { continuation.yield(.start(task)); return }
            continuation.finish(throwing: CustomError.isURLSessionTaskNull)
        }
    }
    
    /// [分段下載](https://blog.csdn.net/guoyongming925/article/details/148908499)
    /// - Parameters:
    ///   - urlString: 下載資料網址
    ///   - fragment: 分段數量
    ///   - delegateQueue: OperationQueue
    ///   - timeout: TimeInterval
    ///   - configiguration: URLSessionConfiguration
    /// - Returns: AsyncThrowingStream<FragmentDownloadState, Error>
    func fragmentDownload(urlString: String, fragment: Int = 10, timeout: TimeInterval = .infinity, configiguration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current) -> AsyncThrowingStream<FragmentDownloadEvent, Error> {
        
        AsyncThrowingStream { continuation in
            
            var tasks: [URLSessionTask] = []
            
            fragmentDownload(urlString: urlString, timeout: timeout, fragment: fragment, configiguration: configiguration, delegateQueue: delegateQueue) { info in
                DispatchQueue.main.async { continuation.yield(.progress(info)) }
            } fragmentTask: { task in
                tasks.append(task)
                DispatchQueue.main.async { continuation.yield(.start(task)) }
            } completion: { result in
                switch result {
                case .success(let data): DispatchQueue.main.async { continuation.yield(.finished(data)); continuation.finish() }
                case .failure(let error): DispatchQueue.main.async { continuation.finish(throwing: error) }
                }
            }
            
            continuation.onTermination = { _ in tasks.forEach { $0.cancel() }}
        }
    }
    
    /// [下載資料 (多個) => URLSessionDownloadDelegate](https://juejin.cn/post/7210216031536185402)
    /// - Parameters:
    ///   - httpMethod: HttpMethod?
    ///   - urlStrings: [String]
    ///   - timeout: TimeInterval
    ///   - configuration: URLSessionConfiguration
    ///   - delegateQueue: OperationQueue?
    /// - Returns: AsyncStream<Result<MultipleDownloadEvent, Error>>
    func multipleDownload(httpMethod: HttpMethod? = .GET, urlStrings: [String], timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current) -> AsyncStream<Result<MultipleDownloadEvent, Error>>  {
        
        AsyncStream { continuation in
            
            let stateManager = MultipleDownloadStateManager()
            
            let tasks = multipleDownload(httpMethod: httpMethod, urlStrings: urlStrings, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) { progress in
                continuation.yield(.success(.progress(progress)))
            } completion: { result in
                
                Task {
                    switch result {
                    case .success(let info): continuation.yield(.success(.finished(info)))
                    case .failure(let error): continuation.yield(.failure(error))
                    }
                    
                    let allFinished = await stateManager.taskDidFinish()
                    if allFinished { continuation.finish() }
                }
            }
            
            continuation.onTermination = { _ in tasks.forEach { $0.cancel() }}
            
            Task {
                await stateManager.tasksCount(tasks.count)
                continuation.yield(.success(.start(tasks)))
            }
        }
    }
}

// MARK: - URLSessionDataDelegate
private extension WWNetworking {
    
    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - contentType: [要回傳的格式 => application/json](https://notfalse.net/39/http-message-format)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - queryItems: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - delegateQueue: OperationQueue?
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionTask?
    func request(httpMethod: HttpMethod = .GET, urlString: String, contentType: ContentType = .json, timeout: TimeInterval, queryItems: [URLQueryItem]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil, delegateQueue: OperationQueue?, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        
        guard let urlComponents = URLComponents._build(urlString: urlString, queryItems: queryItems),
              let queryedURL = urlComponents.url
        else {
            result(.failure(CustomError.notUrlFormat)); return nil
        }
        
        var request = URLRequest._build(url: queryedURL, httpMethod: httpMethod, timeout: timeout)
        
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        request.httpBody = httpBody
        request._setValue(contentType, forHTTPHeaderField: .contentType)
        
        let task = fetchData(from: request, delegateQueue: delegateQueue, result: result)
        return task
    }
    
    /// 分段下載開始時的設定
    /// - Parameters:
    ///   - session: URLSession
    ///   - dataTask: URLSessionDataTask
    ///   - response: URLResponse
    ///   - completionHandler: URLSession.ResponseDisposition
    func fragmentDownloadAction(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        fragmentDownloadDatas["\(dataTask)"] = Data()
        completionHandler(.allow)
    }
    
    /// 分段下載完成的處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - dataTask: URLSessionDataTask
    ///   - data: Data
    func fragmentDownloadedAction(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        fragmentDownloadDatas["\(dataTask)"]? += data
        
        guard let response = dataTask.response as? HTTPURLResponse,
              let fragmentDownloadFinishBlock = fragmentDownloadFinishBlock,
              let fragmentDownloadProgressResultBlock = fragmentDownloadProgressResultBlock
        else {
            return
        }
        
        let httpResponse = HttpResponse.builder(response: response)
        if (httpResponse.hasError()) { fragmentDownloadFinishBlock(.failure(httpResponse)); dataTask.cancel(); return }
        
        let downloadData = downloadTotalData(with: fragmentDownloadDatas, for: fragmentDownloadKeys)
        let progress: DownloadProgressInformation = (urlString: dataTask.currentRequest?.url?.absoluteString, totalSize: Int64(fragmentDownloadContentLength), totalWritten: Int64(downloadData.count), writting: Int64(data.count))
        fragmentDownloadProgressResultBlock(progress)
        
        if downloadData.count >= fragmentDownloadContentLength {
            fragmentDownloadFinishBlock(.success(downloadData))
        }
    }
        
    /// 分段下載錯誤的處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - error: Error?
    func fragmentDownloadCompleteAction(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let error = error,
              let fragmentDownloadFinishBlock = fragmentDownloadFinishBlock
        else {
            return
        }

        task.cancel()
        fragmentDownloadFinishBlock(.failure(error))
    }
}

// MARK: - URLSessionTaskDelegate
private extension WWNetworking {
    
    /// 下載進度處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - downloadTask: URLSessionDownloadTask
    ///   - bytesWritten: Int64
    ///   - totalBytesWritten: Int64
    ///   - totalBytesExpectedToWrite: Int64
    func downloadProgressAction(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let response = downloadTask.response as? HTTPURLResponse,
              let downloadProgressResultBlock = downloadProgressResultBlock,
              let downloadTaskResultBlock = downloadTaskResultBlock,
              let urlString = downloadTask.originalRequest?.url?.absoluteString
        else {
            return
        }
        
        let httpResponse = HttpResponse.builder(response: response)
        if (httpResponse.hasError()) { DispatchQueue.main.async {downloadTaskResultBlock(.failure(httpResponse)); downloadTask.cancel(); return }}
        
        let progress: DownloadProgressInformation = (urlString: urlString, totalSize: totalBytesExpectedToWrite, totalWritten: totalBytesWritten, writting: bytesWritten)
        DispatchQueue.main.async { downloadProgressResultBlock(progress) }
    }
    
    /// 下載完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - downloadTask: URLSessionDownloadTask
    ///   - location: URL
    func downloadFinishedAction(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
                
        guard let downloadTaskResultBlock = downloadTaskResultBlock,
              let response = downloadTask.response as? HTTPURLResponse,
              let urlString = downloadTask.currentRequest?.url?.absoluteString
        else {
            return
        }
        
        let httpResponse = HttpResponse.builder(response: response)
        if (httpResponse.hasError()) { DispatchQueue.main.async { downloadTaskResultBlock(.failure(httpResponse)) }; return }
        
        do {
            let fileUrl = try moveLocationFile(at: location).get()
            let data = try Data(contentsOf: fileUrl)
            let info: DownloadResultInformation = (urlString: urlString, location: fileUrl, data: data)
            DispatchQueue.main.async { downloadTaskResultBlock(.success(info)) }
        } catch {
            DispatchQueue.main.async { downloadTaskResultBlock(.failure(error)) }
        }
    }
}

// MARK: - URLSessionUploadTask
private extension WWNetworking {
    
    /// 分段上傳進度處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - bytesSent: Int64
    ///   - totalBytesSent: Int64
    ///   - totalBytesExpectedToSend: Int64
    func fragmentUploadProgressAction(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        guard let fragmentUploadProgressResultBlock = fragmentUploadProgressResultBlock else { return }
        
        let progress: UploadProgressInformation = (urlString: task.currentRequest?.url?.absoluteString, bytesSent: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        
        DispatchQueue.main.async { fragmentUploadProgressResultBlock(progress) }
    }
    
    /// 分段上傳完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - error: Error?
    func fragmentUploadCompleteAction(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let fragmentUploadFinishBlock = fragmentUploadFinishBlock else { return }
        guard let error = error else { fragmentUploadFinishBlock(.success(true)); return }
        
        DispatchQueue.main.async { fragmentUploadFinishBlock(.failure(error)) }
    }
}

// MARK: - SSL Pinning
private extension WWNetworking {
    
    /// [處理 URLSession 的身份驗證挑戰](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411595-urlsession)
    /// - Parameters:
    ///   - session: URLSession
    ///   - challenge: URLAuthenticationChallenge
    ///   - completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?)
    func sslPinning(with session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if WWNetworking.sslPinning.values.isEmpty { return completionHandler(.performDefaultHandling, nil) }
        
        let host = challenge.protectionSpace.host.lowercased()
        let pinning = WWNetworking.sslPinning
        let pinningHosts = pinning.values.map { $0.host }
        
        print("⚠️ [Challenge Host] => \(host)")
        
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

// MARK: - 小工具
private extension WWNetworking {
    
    /// [產生下載用的HttpTask - downloadTask() => URLSessionDownloadDelegate](https://developer.apple.com/documentation/foundation/urlsessiondownloaddelegate)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: URLSessionConfiguration
    ///   - delegateQueue: 執行緒
    /// - Returns: URLSessionDownloadTask
    func downloadTaskMaker(with httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current) -> URLSessionDownloadTask? {
        
        guard let request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { return nil }
        
        let urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        let downloadTask = urlSession.downloadTask(with: request)
        
        downloadTask.delegate = self
        urlSession.finishTasksAndInvalidate()
        
        return downloadTask
    }
    
    /// [抓取資料 - dataTask() => URLSessionDataDelegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate)
    /// - Parameters:
    ///   - request: [URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    ///   - configuration: URLSessionConfiguration
    ///   - delegateQueue: 執行緒
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask
    func fetchData(from request: URLRequest, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue?, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask {
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error { result(.failure(error)); return }
                let info: ResponseInformation = (data: data, response: response as? HTTPURLResponse)
                result(.success(info))
            }
        }
        
        dataTask.resume()
        return dataTask
    }

    /// [斷點續傳下載檔案 (Data) => HTTPHeaderField = Range / ∵ 是一段一段下載 ∴ 自己要一段一段存](https://www.jianshu.com/p/534ec0d9d758)
    /// - urlSession(_:dataTask:didReceive:) => completionHandler(.allow)
    /// - Parameters:
    ///   - urlString: [String](https://stackoverflow.com/questions/58023230/memory-leak-occurring-in-iphone-x-after-updating-to-ios-13)
    ///   - delegateQueue: OperationQueue?
    ///   - offset: HttpDownloadOffset
    ///   - timeout: TimeInterval
    ///   - configiguration: URLSessionConfiguratio
    ///   - result: Result<Data, Error>) -> Void
    /// - Returns: URLSessionDataTask?
    func fragmentDownloadDataTaskMaker(with urlString: String, delegateQueue: OperationQueue?, offset: HttpDownloadOffset = (0, nil), timeout: TimeInterval, configiguration: URLSessionConfiguration, result: ((Result<Data, Error>) -> Void)?) -> URLSessionDataTask? {

        guard let url = URL(string: urlString),
              let headerValue = downloadOffsetMaker(offset: offset)
        else {
            return nil
        }
        
        let urlSession = URLSession(configuration: configiguration, delegate: self, delegateQueue: delegateQueue)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        
        defer { urlSession.finishTasksAndInvalidate() }
        
        request._setValue(headerValue, forHTTPHeaderField: .range)
        fragmentDownloadFinishBlock = result
        
        let dataTask = urlSession.dataTask(with: request)
        dataTask.delegate = self
        
        return dataTask
    }
    
    /// 移動本地下載完成的檔案 (因為在tmp的檔案會不見)
    /// - Parameter location: tmp檔位置
    /// - Returns: Result<URL, any Error>
    func moveLocationFile(at location: URL) -> Result<URL, any Error> {
        
        guard let cachesDirectory = FileManager.default._cachesDirectory() else { return .failure(CustomError.isCachesDirectoryEmpty) }
        
        let fileURL: URL
        
        if #available(iOS 16.0, *) {
            fileURL = cachesDirectory.appending(component: location.lastPathComponent)
        } else {
            fileURL = cachesDirectory.appendingPathComponent(location.lastPathComponent)
        }
        
        switch FileManager.default._moveFile(at: location, to: fileURL) {
        case .success(_): return .success(fileURL)
        case .failure(let error): return .failure(error)
        }
    }
    
    /// Range: bytes=0-1024
    /// - Parameter offset: HttpDownloadOffset
    /// - Returns: String?
    func downloadOffsetMaker(offset: HttpDownloadOffset) -> String? {

        guard let startOffset = offset.start else { return nil }
        guard let endOffset = offset.end else { return String(format: "bytes=%lld-", startOffset) }

        return String(format: "bytes=%lld-%lld", startOffset, endOffset)
    }

    /// 計算下載的檔案總和 (將分段的Data組合起來)
    /// - Parameters:
    ///   - datas: [<Task String>: Data]
    ///   - keys: [<Task String>]
    /// - Returns: Data
    func downloadTotalData(with datas: [String: Data], for keys: [String]) -> Data {

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
    func multipleUploadBodyMaker(boundary: String, formDatas: [FormDataInformation], parameters: [String: String]?) -> Data {
        
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
    
    /// 清除分段下載的暫存資訊
    func cleanFragmentInformation() {
        fragmentDownloadContentLength = -1
        fragmentDownloadDatas = [:]
        fragmentDownloadKeys = []
    }
    
    /// 清除所有的Callback Block (避免記憶體洩漏)
    func cleanAllBlocks() {
        downloadTaskResultBlock = nil
        downloadProgressResultBlock = nil
        fragmentDownloadFinishBlock = nil
        fragmentDownloadProgressResultBlock = nil
        fragmentUploadFinishBlock = nil
        fragmentUploadProgressResultBlock = nil
    }
}
