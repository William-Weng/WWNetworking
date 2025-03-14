//
//  WWNetworking.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import Foundation

// MARK: - 簡易型的AFNetworking (單例)
open class WWNetworking: NSObject {
    
    public static let shared = WWNetworking()
    
    private var downloadTaskResultBlock: ((Result<DownloadResultInformation, Error>) -> Void)?                                              // 下載檔案完成的動作
    private var downloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?                                                       // 下載進行中的進度 - 檔案

    private var fragmentDownloadFinishBlock: ((Result<Data, Error>) -> Void)?                                                               // 分段下載完成的動作
    private var fragmentDownloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?                                               // 分段下載進行中的進度 - 檔案大小
    private var fragmentDownloadContentLength = -1                                                                                          // 分段下載的檔案總大小
    private var fragmentDownloadDatas: [String: Data] = [:]                                                                                 // 記錄分段下載的Data
    private var fragmentDownloadKeys: [String] = []                                                                                         // 記錄Tasks的順序
    
    private var fragmentUploadFinishBlock: ((Result<Bool, Error>) -> Void)?                                                                 // 分段上傳完成的動作
    private var fragmentUploadProgressResultBlock: ((UploadProgressInformation) -> Void)?                                                   // 分段下載進行中的進度 - 檔案大小
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
}

// MARK: - WWNetworking (public static function)
public extension WWNetworking {
    
    /// 建立一個新的WWNetworking
    /// - Returns: WWNetworking
    static func build() -> WWNetworking { return WWNetworking() }
}

// MARK: - WWNetworking (public function)
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
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionTask?
    func request(httpMethod: HttpMethod = .GET, urlString: String, timeout: TimeInterval = 60, contentType: ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBodyType: HttpBobyType? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        let task = request(httpMethod: httpMethod, urlString: urlString, contentType: contentType, timeout: timeout, queryItems: paramaters?._queryItems(), headers: headers, httpBody: httpBodyType?.data()) { result($0) }
        return task
    }
    
    /// [取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)](https://github.com/pro648/tips/blob/master/sources/URLSession详解.md)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - result: Result<ResponseInformation?, Error>
    /// - Returns: URLSessionTask?
    func header(urlString: String, timeout: TimeInterval = 60, headers: [String: String?]? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        
        let task = request(httpMethod: .HEAD, urlString: urlString, timeout: timeout, contentType: .plain, paramaters: nil, headers: headers, httpBodyType: nil) { _result in

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
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask?
    func upload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, parameters: [String: String]? = nil, headers: [String: String?]? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(MyError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = multipleUploadBodyMaker(boundary: boundary, formDatas: [formData], parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return fetchData(from: request, result: result)
    }
    
    /// [上傳檔案 (多個) - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - formDatas: [圖片Data相關參數](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - parameters: [額外參數](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask?
    func multipleUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formDatas: [FormDataInformation], parameters: [String: String]? = nil, headers: [String: String?]? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(MyError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = multipleUploadBodyMaker(boundary: boundary, formDatas: formDatas, parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return fetchData(from: request, result: result)
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
    func binaryUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .main, progress: @escaping ((UploadProgressInformation) -> Void), completion: @escaping (Result<Bool, Error>) -> Void) -> URLSessionUploadTask? {
        
        cleanAllBlocks()
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { completion(.failure(MyError.notOpenURL)); return nil }
        
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
    ///   - urlString: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: [URLSession設定 / timeout](https://draveness.me/ios-yuan-dai-ma-jie-xi-sdwebimage/)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - isResume: [是否要立刻執行Task](https://liuyousama.top/2020/10/18/Kingfisher源码阅读/)
    ///   - progress: [下載進度](https://www.appcoda.com.tw/ios-concurrency/)
    ///   - completion: 下載完成後
    /// - Returns: URLSessionDownloadTask?
    func download(httpMethod: HttpMethod? = .GET, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .main, isResume: Bool = true, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> URLSessionDownloadTask? {
        
        guard let downloadTask = self.downloadTaskMaker(with: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) else { completion(.failure(MyError.notUrlFormat)); return nil }
        
        downloadTaskResultBlock = completion
        downloadProgressResultBlock = progress
        
        if (isResume) { downloadTask.resume() }
        
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
    func multipleDownload(httpMethod: HttpMethod? = .GET, urlStrings: [String], timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .main, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> [URLSessionDownloadTask] {
        
        cleanAllBlocks()
        
        let _urlStrings = urlStrings._arraySet()
        
        let downloadTasks = _urlStrings.compactMap { urlString in
            
            self.download(httpMethod: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue) { info in
                progress(info)
            } completion: { result in
                completion(result)
            }
        }
        
        return downloadTasks
    }

    /// [分段下載](https://www.jianshu.com/p/534ec0d9d758)
    /// - Parameters:
    ///   - urlString: String
    ///   - timeout: TimeInterval
    ///   - fragment: 分段數量
    ///   - delegateQueue: OperationQueue
    ///   - configiguration: URLSessionConfiguration
    ///   - progress: 下載進度
    ///   - fragmentTask: URLSessionTask
    ///   - completion: Result<Data, Error>
    func fragmentDownload(urlString: String, timeout: TimeInterval = .infinity, fragment: Int = 2, delegateQueue: OperationQueue? = .main, configiguration: URLSessionConfiguration = .default, progress: @escaping ((DownloadProgressInformation) -> Void), fragmentTask: @escaping (URLSessionTask) -> Void, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard fragment > 0 else { completion(.failure(MyError.fragmentCountError)); return }
        
        fragmentDownloadProgressResultBlock = progress
        cleanFragmentInformation()
        
        self.header(urlString: urlString, timeout: timeout) { result in

            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let info):

                guard let contentLengthString = info.response?._headerField(with: .contentLength) as? String,
                      let contentLength = Int(contentLengthString),
                      let fragmentSize = Optional.some((contentLength / fragment) + 1)
                else {
                    completion(.failure(MyError.notUrlDownload)); return
                }
                
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

// MARK: - WWNetworking (public function + async / await)
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
    /// - Returns: Result<ResponseInformation, Error>
    func request(httpMethod: HttpMethod = .GET, urlString: String, timeout: TimeInterval = 60, contentType: ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBodyType: HttpBobyType? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            request(httpMethod: httpMethod, urlString: urlString, timeout: timeout, contentType: contentType, paramaters: paramaters, headers: headers, httpBodyType: httpBodyType) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [執行多個Request](https://youtu.be/s2PiL_Vte4E)
    /// - Parameter types: [[RequestInformationType]](https://onevcat.com/2021/07/swift-concurrency/)
    /// - Returns: [Result<ResponseInformation, Error>]
    func multipleRequest(types: [RequestInformationType]) async -> [Result<ResponseInformation, Error>] {
        
        var requests: [Result<ResponseInformation, Error>] = []
        
        for type in types {
            async let request = request(httpMethod: type.httpMethod, urlString: type.urlString, timeout: type.timeout, contentType: type.contentType, paramaters: type.paramaters, headers: type.headers, httpBodyType: type.httpBodyType)
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
                    await self.request(httpMethod: type.httpMethod, urlString: type.urlString, timeout: type.timeout, contentType: type.contentType, paramaters: type.paramaters, headers: type.headers, httpBodyType: type.httpBodyType)
                }
            }
            
            var requests: [Result<ResponseInformation, Error>] = []
            for await request in group { requests.append(request) }
            
            return requests
        }
    }
        
    /// 取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    /// - Returns: Result<ResponseInformation, Error>
    func header(urlString: String, timeout: TimeInterval = 60, headers: [String: String?]? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            header(urlString: urlString, timeout: timeout, headers: headers) { result in
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
    /// - Returns: Result<ResponseInformation, Error>
    func upload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, parameters: [String: String], headers: [String: String?]? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            upload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formData: formData, parameters: parameters, headers: headers) { result in
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
    /// - Returns: Result<ResponseInformation, Error>
    func multipleUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formDatas: [FormDataInformation], parameters: [String: String], headers: [String: String?]? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            multipleUpload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formDatas: formDatas, parameters: parameters, headers: headers) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [二進制檔案上傳 - 大型檔案](https://www.swiftbysundell.com/articles/http-post-and-file-upload-requests-using-urlsession/)
    /// - Parameters:
    ///   - httpMethod: [HttpMethod?](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
    ///   - urlString: String
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - formData: [FormDataInformation](https://ithelp.ithome.com.tw/articles/10185514)
    ///   - delegateQueue: OperationQueue?
    ///   - progress: UploadProgressInformation
    ///   - completion: Result<Bool, Error>
    /// - Returns: URLSessionUploadTask?
    @MainActor
    func binaryUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .main, sessionTask: @escaping ((URLSessionTask?) -> Void), progress: @escaping ((UploadProgressInformation) -> Void)) async -> Result<Bool, Error> {
        
        await withCheckedContinuation { continuation in
            
            let task = binaryUpload(httpMethod: httpMethod, urlString: urlString, timeout: timeout, formData: formData, headers: headers, delegateQueue: delegateQueue) { info in
                progress(info)
            } completion: { result in
                Task { @MainActor in continuation.resume(returning: result) }
            }
            
            sessionTask(task)
        }
    }
    
    /// [下載資料 => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: [Timeout](https://draveness.me/ios-yuan-dai-ma-jie-xi-sdwebimage/)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - isResume: [是否要立刻執行Task](https://liuyousama.top/2020/10/18/Kingfisher源码阅读/)
    ///   - progress: [下載進度](https://www.appcoda.com.tw/ios-concurrency/)
    ///   - sessionTask: 執行的Task
    /// - Returns: Result<DownloadResultInformation, Error>
    func download(httpMethod: HttpMethod? = .GET, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .main, isResume: Bool = true, sessionTask: @escaping ((URLSessionTask?) -> Void), progress: @escaping ((DownloadProgressInformation) -> Void)) async -> Result<DownloadResultInformation, Error> {
        
        await withCheckedContinuation { continuation in
            
            let task = download(httpMethod: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegateQueue: delegateQueue, isResume: isResume) { info in
                progress(info)
            } completion: { result in
                 continuation.resume(returning: result)
            }
            
            sessionTask(task)
        }
    }
    
    /// [分段下載](https://www.jianshu.com/p/534ec0d9d758)
    /// - Parameters:
    ///   - urlString: String
    ///   - fragment: 分段數量
    ///   - delegateQueue: OperationQueue
    ///   - timeout: TimeInterval
    ///   - progress: 下載進度
    ///   - fragmentTask: URLSessionTask
    /// - Returns: Result<Data, Error>
    @MainActor
    func fragmentDownload(urlString: String, fragment: Int = 2, delegateQueue: OperationQueue? = .main, timeout: TimeInterval = .infinity, configiguration: URLSessionConfiguration = .default, progress: @escaping ((DownloadProgressInformation) -> Void), fragmentTask: @escaping (URLSessionTask) -> Void) async -> Result<Data, Error> {
        
        await withCheckedContinuation { continuation in
            
            fragmentDownload(urlString: urlString, timeout: timeout, fragment: fragment, delegateQueue: delegateQueue, configiguration: configiguration) { info in
                progress(info)
            } fragmentTask: { task in
                fragmentTask(task)
            }
            completion: { result in
                Task { @MainActor in continuation.resume(returning: result) }
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
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionTask?
    func request(httpMethod: HttpMethod = .GET, urlString: String, contentType: ContentType = .json, timeout: TimeInterval, queryItems: [URLQueryItem]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        
        guard let urlComponents = URLComponents._build(urlString: urlString, queryItems: queryItems),
              let queryedURL = urlComponents.url,
              var request = Optional.some(URLRequest._build(url: queryedURL, httpMethod: httpMethod, timeout: timeout))
        else {
            result(.failure(MyError.notUrlFormat)); return nil
        }
        
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        request.httpBody = httpBody
        request._setValue(contentType, forHTTPHeaderField: .contentType)
        
        let task = fetchData(from: request, result: result)
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
        
        guard let fragmentDownloadFinishBlock = fragmentDownloadFinishBlock,
              let fragmentDownloadProgressResultBlock = fragmentDownloadProgressResultBlock,
              let downloadData = Optional.some(downloadTotalData(with: fragmentDownloadDatas, for: fragmentDownloadKeys))
        else {
            return
        }
        
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
        
        guard let block = downloadProgressResultBlock,
              let urlString = downloadTask.originalRequest?.url?.absoluteString
        else {
            return
        }
        
        let progress: DownloadProgressInformation = (urlString: urlString, totalSize: totalBytesExpectedToWrite, totalWritten: totalBytesWritten, writting: bytesWritten)
        block(progress)
    }
    
    /// 下載完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - downloadTask: URLSessionDownloadTask
    ///   - location: URL
    func downloadFinishedAction(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        guard let block = downloadTaskResultBlock,
              let urlString = downloadTask.currentRequest?.url?.absoluteString
        else {
            return
        }
        
        do {
            let data = try Data(contentsOf: location)
            let info: DownloadResultInformation = (urlString: urlString, data: data)
            block(.success(info))
        } catch {
            block(.failure(error))
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
        
        fragmentUploadProgressResultBlock(progress)
    }
    
    /// 分段上傳完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - error: Error?
    func fragmentUploadCompleteAction(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let fragmentUploadFinishBlock = fragmentUploadFinishBlock else { return }
        guard let error = error else { fragmentUploadFinishBlock(.success(true)); return }
        
        fragmentUploadFinishBlock(.failure(error))
    }
}

// MARK: - WWNetworking (private function)
private extension WWNetworking {
    
    /// [產生下載用的HttpTask - downloadTask() => URLSessionDownloadDelegate](https://developer.apple.com/documentation/foundation/urlsessiondownloaddelegate)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - timeout: [設定請求超時時間](https://blog.csdn.net/qq_28091923/article/details/86233229)
    ///   - configuration: URLSessionConfiguration
    ///   - delegateQueue: 執行緒
    /// - Returns: URLSessionDownloadTask
    func downloadTaskMaker(with httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .main) -> URLSessionDownloadTask? {
        
        guard let request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { return nil }
        
        let urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        let downloadTask = urlSession.downloadTask(with: request)
        
        if #available(iOS 15.0, *) { downloadTask.delegate = self }
        urlSession.finishTasksAndInvalidate()
        
        return downloadTask
    }
    
    /// [抓取資料 - dataTask() => URLSessionDataDelegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate)
    /// - Parameters:
    ///   - request: [URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    ///   - result: Result<ResponseInformation, Error>
    /// - Returns: URLSessionDataTask
    func fetchData(from request: URLRequest, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask {
                
        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in

            if let error = error { result(.failure(error)); return }

            let info: ResponseInformation = (data: data, response: response as? HTTPURLResponse)
            result(.success(info))
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
              var request = Optional.some(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)),
              let urlSession = Optional.some(URLSession(configuration: configiguration, delegate: self, delegateQueue: delegateQueue)),
              let headerValue = downloadOffsetMaker(offset: offset)
        else {
            return nil
        }
        
        defer { urlSession.finishTasksAndInvalidate() }
        
        request._setValue(headerValue, forHTTPHeaderField: .range)
        fragmentDownloadFinishBlock = result
        
        let dataTask = urlSession.dataTask(with: request)
        if #available(iOS 15.0, *) { dataTask.delegate = self }
        
        return dataTask
    }

    /// Range: bytes=0-1024
    /// - Parameter offset: HttpDownloadOffset
    /// - Returns: String?
    func downloadOffsetMaker(offset: HttpDownloadOffset) -> String? {

        guard let startOffset = offset.start else { return nil }
        guard let endOffset = offset.end else { return String(format: "bytes=%lld-", startOffset) }

        return String(format: "bytes=%lld-%lld", startOffset, endOffset)
    }

    /// 計算下載的檔案總和
    /// - Parameters:
    ///   - datas: [<Task String>: Data]
    ///   - keys: [<Task String>]
    /// - Returns: Data
    func downloadTotalData(with datas: [String: Data], for keys: [String]) -> Data {

        var downloadData = Data()
        for key in keys { if let _data = datas[key] { downloadData += _data }}

        return downloadData
    }
    
    /// 上傳檔案的Body設定 (多個)
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
    
    /// 清除分段下載的暫存檔
    func cleanFragmentInformation() {
        fragmentDownloadContentLength = -1
        fragmentDownloadDatas = [:]
        fragmentDownloadKeys = []
    }
    
    /// 清除所有的Block
    func cleanAllBlocks() {
        downloadTaskResultBlock = nil
        downloadProgressResultBlock = nil
        fragmentDownloadFinishBlock = nil
        fragmentDownloadProgressResultBlock = nil
        fragmentUploadFinishBlock = nil
        fragmentUploadProgressResultBlock = nil
    }
}
