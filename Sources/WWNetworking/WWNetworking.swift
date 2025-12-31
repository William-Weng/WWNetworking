//
//  Networking.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import Foundation

// MARK: - 簡易型的AFNetworking (單例)
public actor WWNetworking {
    
    public static let shared = WWNetworking()
        
    let util = Utility()
    var sslPinning: SSLPinningInformation = (bundle: .main, values: [])                             // SSL-Pinning設定值
    weak var delegate: WWNetworking.Delegate?
    
    private let downloadDelegateProxy = DownloadDelegateProxy()
    private let taskDelegateProxy = TaskDelegateProxy()
    private let dataDelegateProxy = DataDelegateProxy()
    
    private var downloadTaskResultBlock: ((Result<DownloadResultInformation, Error>) -> Void)?      // 下載檔案完成的動作
    private var downloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?               // 下載進行中的進度 - 檔案

    private var fragmentDownloadFinishBlock: ((Result<Data, Error>) -> Void)?                       // 分段下載完成的動作
    private var fragmentDownloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?       // 分段下載進行中的進度 - 檔案大小
    private var fragmentDownloadContentLength = -1                                                  // 分段下載的檔案總大小
    private var fragmentDownloadDatas: [String: Data] = [:]                                         // 記錄分段下載的Data
    private var fragmentDownloadKeys: [String] = []                                                 // 記錄Tasks的順序
    
    private var fragmentUploadFinishBlock: ((Result<Bool, Error>) -> Void)?                         // 分段上傳完成的動作
    private var fragmentUploadProgressResultBlock: ((UploadProgressInformation) -> Void)?           // 分段下載進行中的進度 - 檔案大小
    
    private init() {
        initDelegateProxy()
    }
    
    deinit { removeDelegateProxy() }
}

// MARK: - 公開函數 (static)
public extension WWNetworking {
    
    /// 建立一個新的WWNetworking
    /// - Returns: WWNetworking
    static func builder() -> WWNetworking { return WWNetworking() }
}

// MARK: - 公開函數
public extension WWNetworking {
    
    /// SSL-Pinning設定 => host + .cer
    /// - Parameters:
    ///   - sslPinning: SSLPinningInformation
    ///   - delegate: WWNetworking.Delegate?
    func sslPinningSetting(_ sslPinning: SSLPinningInformation, delegate: WWNetworking.Delegate? = nil) {
        self.sslPinning = sslPinning
        self.delegate = delegate
    }
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
    @discardableResult
    func request(httpMethod: HttpMethod = .GET, urlString: String, timeout: TimeInterval = 60, contentType: ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBodyType: HttpBobyType? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionTask? {
        let task = util.request(httpMethod: httpMethod, urlString: urlString, contentType: contentType, timeout: timeout, queryItems: paramaters?._queryItems(), headers: headers, httpBody: httpBodyType?.data(), delegate: dataDelegateProxy, delegateQueue: delegateQueue) { result($0) }
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
    @discardableResult
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
    @discardableResult
    func upload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, parameters: [String: String]? = nil, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(CustomError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = util.multipleUploadBodyMaker(boundary: boundary, formDatas: [formData], parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return util.fetchData(from: request, delegate: dataDelegateProxy, delegateQueue: delegateQueue, result: result)
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
    @discardableResult
    func multipleUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formDatas: [FormDataInformation], parameters: [String: String]? = nil, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, result: @escaping (Result<ResponseInformation, Error>) -> Void) -> URLSessionDataTask? {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { result(.failure(CustomError.notUrlFormat)); return nil }
        
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        let httpBody = util.multipleUploadBodyMaker(boundary: boundary, formDatas: formDatas, parameters: parameters)
        
        if let headers = headers { headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}}
        
        request._setValue(.formData(boundary: boundary), forHTTPHeaderField: .contentType)
        request.httpBody = httpBody
        
        return util.fetchData(from: request, delegate: dataDelegateProxy, delegateQueue: delegateQueue, result: result)
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
    @discardableResult
    func binaryUpload(httpMethod: HttpMethod? = .POST, urlString: String, timeout: TimeInterval = 60, formData: FormDataInformation, headers: [String: String?]? = nil, delegateQueue: OperationQueue? = .current, progress: @escaping ((UploadProgressInformation) -> Void), completion: @escaping (Result<Bool, Error>) -> Void) -> URLSessionUploadTask? {
        
        cleanAllBlocks()
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod, timeout: timeout) else { completion(.failure(CustomError.notOpenURL)); return nil }
        
        let urlSession = URLSession(configuration: .default, delegate: dataDelegateProxy, delegateQueue: delegateQueue)
        var uploadTask: URLSessionUploadTask?
        
        request._setValue("\(formData.contentType)", forHTTPHeaderField: .contentType)
        request.setValue(formData.filename, forHTTPHeaderField: formData.name)
        uploadTask = urlSession.uploadTask(with: request, from: formData.data)
                
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        fragmentUploadProgressResultBlock = progress
        fragmentUploadFinishBlock = completion
        
        uploadTask?.delegate = taskDelegateProxy
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
    @discardableResult
    func download(httpMethod: HttpMethod? = .GET, urlString: String, timeout: TimeInterval = 60, configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = .current, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> URLSessionDownloadTask? {
        
        guard let downloadTask = util.downloadTaskMaker(with: httpMethod, urlString: urlString, timeout: timeout, configuration: configuration, delegate: downloadDelegateProxy, delegateQueue: delegateQueue) else { completion(.failure(CustomError.notUrlFormat)); return nil }
        
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
    @discardableResult
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
                    let task = self.util.fragmentDownloadDataTaskMaker(with: urlString, delegate: self.dataDelegateProxy, delegateQueue: delegateQueue, offset: offset, timeout: timeout, configiguration: configiguration)

                    self.fragmentDownloadFinishBlock = completion

                    if let task = task {
                        self.fragmentDownloadKeys.append("\(task)")
                        task.resume()
                        fragmentTask(task)
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
            
            if let task { continuation.yield(.start(task)); return }
            continuation.finish(throwing: CustomError.isURLSessionTaskNull)
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
                Task { @MainActor in continuation.yield(.progress(info)) }
            } fragmentTask: { task in
                tasks.append(task)
                Task { @MainActor in continuation.yield(.start(task)) }
            } completion: { result in
                switch result {
                case .success(let data): Task { @MainActor in continuation.yield(.finished(data)); continuation.finish() }
                case .failure(let error): Task { @MainActor in continuation.finish(throwing: error) }
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
extension WWNetworking {
    
    /// 分段下載開始時的設定
    /// - Parameters:
    ///   - session: URLSession
    ///   - dataTask: URLSessionDataTask
    ///   - response: URLResponse
    ///   - completionHandler: URLSession.ResponseDisposition
    func fragmentDownloadAction(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) async {
        fragmentDownloadDatas["\(dataTask)"] = Data()
        completionHandler(.allow)
    }
    
    /// 分段下載完成的處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - dataTask: URLSessionDataTask
    ///   - data: Data
    func fragmentDownloadedAction(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) async {
        
        fragmentDownloadDatas["\(dataTask)"]? += data
        
        guard let response = dataTask.response as? HTTPURLResponse,
              let fragmentDownloadFinishBlock = fragmentDownloadFinishBlock,
              let fragmentDownloadProgressResultBlock = fragmentDownloadProgressResultBlock
        else {
            return
        }
        
        let httpResponse = HttpResponse.builder(response: response)
        if (httpResponse.hasError()) { fragmentDownloadFinishBlock(.failure(httpResponse)); dataTask.cancel(); return }
        
        let downloadData = util.downloadTotalDatas(fragmentDownloadDatas, for: fragmentDownloadKeys)
        let progress: DownloadProgressInformation = (urlString: dataTask.currentRequest?.url?.absoluteString, totalSize: Int64(fragmentDownloadContentLength), totalWritten: Int64(downloadData.count), writting: Int64(data.count))
        fragmentDownloadProgressResultBlock(progress)
        
        if downloadData.count >= fragmentDownloadContentLength { fragmentDownloadFinishBlock(.success(downloadData)) }
    }
    
    /// [分段下載完成的處理](https://myapollo.com.tw/post/http-status-code-206/)
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - error: Error?
    func fragmentDownloadCompleteAction(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) async {
        
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
extension WWNetworking {
    
    /// 下載進度處理
    /// - Parameters:
    ///   - result: Result<WWNetworking.DownloadProgressInformation, any Error>
    func downloadProgressAction(result: Result<WWNetworking.DownloadProgressInformation, any Error>) async {
        
        guard let downloadProgressResultBlock = downloadProgressResultBlock,
              let downloadTaskResultBlock = downloadTaskResultBlock
        else {
            return
        }
        
        switch result {
        case .success(let info): Task { @MainActor in downloadProgressResultBlock(info) }
        case .failure(let error): Task { @MainActor in downloadTaskResultBlock(.failure(error)) }
        }
    }
    
    /// 下載完成處理
    /// - Parameter result: Result<WWNetworking.DownloadResultInformation, Error>
    func downloadFinishedAction(result: Result<WWNetworking.DownloadResultInformation, Error>) {
        
        guard let downloadTaskResultBlock = downloadTaskResultBlock else { return }
        
        switch result {
        case .success(let info): Task { @MainActor in downloadTaskResultBlock(.success(info)) }
        case .failure(let error): Task { @MainActor in downloadTaskResultBlock(.failure(error)) }
        }
    }
}

// MARK: - URLSessionUploadTask
extension WWNetworking {
    
    /// 分段上傳進度處理
    /// - Parameters:
    ///   - progress: URLSession
    func fragmentUploadProgressAction(_ progress: UploadProgressInformation) async {
        guard let fragmentUploadProgressResultBlock = fragmentUploadProgressResultBlock else { return }
        Task { @MainActor in fragmentUploadProgressResultBlock(progress) }
    }
    
    /// 分段上傳上傳完成處理
    /// - Parameters:
    ///   - session: URLSession
    ///   - task: URLSessionTask
    ///   - error: Error?
    func fragmentUploadCompleteAction(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) async {
        
        guard let fragmentUploadFinishBlock = fragmentUploadFinishBlock else { return }
        
        Task { @MainActor in
            if let error = error { fragmentUploadFinishBlock(.failure(error)) }; return
            fragmentUploadFinishBlock(.success(true));
        }
    }
}

// MARK: - 小工具
private extension WWNetworking {
    
    /// 初始化DelegateProxy
    func initDelegateProxy() {
        downloadDelegateProxy.owner = self
        taskDelegateProxy.owner = self
        dataDelegateProxy.owner = self
    }
    
    /// 清除DelegateProxy
    func removeDelegateProxy() {
        delegate = nil
        downloadDelegateProxy.owner = nil
        taskDelegateProxy.owner = nil
        dataDelegateProxy.owner = nil
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
