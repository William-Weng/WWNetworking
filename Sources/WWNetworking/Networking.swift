//
//  WWNetworking.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import Foundation

// MARK: - 簡易型的AFNetworking (單例)
open class WWNetworking: NSObject {
    
    public typealias DownloadProgressInformation = (urlString: String?, totalSize: Int64, totalWritten: Int64, writting: Int64)                 // 網路下載資料 => (URL / 大小 / 己下載 / 一段段的下載量)
    public typealias ResponseInformation = (data: Data?, response: HTTPURLResponse?)                                                            // 網路回傳的資料
    public typealias HttpDownloadOffset = (start: Int?, end: Int?)                                                                              // 續傳下載開始~結束位置設定值 (bytes=0-1024)
    public typealias DownloadResultInformation = (urlString: String, data: Data?)                                                               // 網路下載資料的結果資訊 => (URL, Data)
    public typealias UploadProgressInformation = (urlString: String?, bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) // 網路下載資料 => (URL / 段落上傳大小 / 己上傳大小 / 總大小)

    public class Constant: NSObject {}
    
    public static let shared = WWNetworking()
    
    private var downloadTaskResultBlock: ((Result<DownloadResultInformation, Error>) -> Void)?                                                  // 下載檔案完成的動作
    private var downloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?                                                           // 下載進行中的進度 - 檔案

    private var fragmentDownloadFinishBlock: ((Result<Data, Error>) -> Void)?                                                                   // 分段下載完成的動作
    private var fragmentDownloadProgressResultBlock: ((DownloadProgressInformation) -> Void)?                                                   // 分段下載進行中的進度 - 檔案大小
    private var fragmentDownloadContentLength = -1                                                                                              // 分段下載的檔案總大小
    private var fragmentDownloadDatas: [String: Data] = [:]                                                                                     // 記錄分段下載的Data
    private var fragmentDownloadKeys: [String] = []                                                                                             // 記錄Tasks的順序
    
    private var fragmentUploadFinishBlock: ((Result<Bool, Error>) -> Void)?                                                                     // 分段上傳完成的動作
    private var fragmentUploadProgressResultBlock: ((UploadProgressInformation) -> Void)?                                                       // 分段下載進行中的進度 - 檔案大小
}

// MARK: - URLSessionTaskDelegate
extension WWNetworking: URLSessionTaskDelegate {
 
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.fragmentDownloadCompleteAction(session, task: task, didCompleteWithError: error)
        self.fragmentUploadCompleteAction(session, task: task, didCompleteWithError: error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        self.fragmentUploadProgressAction(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }
}

// MARK: - URLSessionDataDelegate
extension WWNetworking: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.fragmentDownloadAction(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.fragmentDownloadedAction(session, dataTask: dataTask, didReceive: data)
    }
}

// MARK: - URLSessionDownloadDelegate
extension WWNetworking: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadProgressAction(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
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
    ///   - contentType: [要回傳的格式 => application/json](https://notfalse.net/39/http-message-format)
    ///   - queryItems: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - result: Result<Constant.ResponseInformation, Error>
    func request(with httpMethod: Constant.HttpMethod = .GET, urlString: String, contentType: Constant.ContentType = .json, queryItems: [URLQueryItem]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) {
        
        guard let urlComponents = URLComponents._build(urlString: urlString, queryItems: queryItems),
              let queryedURL = urlComponents.url,
              var request = Optional.some(URLRequest._build(url: queryedURL, httpMethod: httpMethod))
        else {
            result(.failure(Constant.MyError.notUrlFormat)); return
        }
        
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }

        request.httpBody = httpBody
        request._setValue(contentType, forHTTPHeaderField: .contentType)

        fetchData(from: request, result: result)
    }

    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - paramaters: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - contentType: Constant.ContentType
    ///   - result: Result<Constant.ResponseInformation, Error>
    func request(with httpMethod: Constant.HttpMethod = .GET, urlString: String, contentType: Constant.ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) {
        self.request(with: httpMethod, urlString: urlString, contentType: contentType, queryItems: paramaters?._queryItems(), headers: headers, httpBody: httpBody) { result($0) }
    }

    /// 取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - result: Result<Constant.ResponseInformation?, Error>
    func header(urlString: String, headers: [String: String?]? = nil, result: @escaping (Result<ResponseInformation, Error>) -> Void) {

        self.request(with: .HEAD, urlString: urlString, contentType: .plain, paramaters: nil, headers: headers, httpBody: nil) { _result in

            switch _result {
            case .failure(let error): result(.failure(error))
            case .success(let info): result(.success(info))
            }
        }
    }
    
    /// [上傳檔案 - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - parameters: [圖片Data](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - filename: [上傳後的檔案名稱 => 123456_<filename>.png](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - contentType: 檔案類型 (MIME) => image/png
    ///   - result: Result<Constant.ResponseInformation, Error>
    func upload(with httpMethod: Constant.HttpMethod? = .POST, urlString: String, parameters: [String: Data], headers: [String: String?]? = nil, filename: String, contentType: Constant.ContentType = .png, result: @escaping (Result<ResponseInformation, Error>) -> Void) {
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod) else { result(.failure(Constant.MyError.notUrlFormat)); return }

        let boundary = "Boundary+\(arc4random())\(arc4random())"
        var body = Data()
        
        request._setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: .contentType)

        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        parameters.first.map { (name, data) in
            _ = body._append(string: "--\(boundary)\r\n")
            _ = body._append(string: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            _ = body._append(string: "Content-Type: \(contentType)\r\n\r\n")
            _ = body._append(data: data)
            _ = body._append(string: "\r\n")
            _ = body._append(string: "--\(boundary)--\r\n")
        }

        request.httpBody = body

        fetchData(from: request, result: result)
    }
    
    /// [片段上傳 - 大型檔案](https://www.swiftbysundell.com/articles/http-post-and-file-upload-requests-using-urlsession/)
    /// - Parameters:
    ///   - httpMethod: [Constant.HttpMethod?](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
    ///   - urlString: String
    ///   - parameters: [String: Data]
    ///   - headers:  [String: String?]?
    ///   - filename: String
    ///   - contentType: [Constant.ContentType](https://ithelp.ithome.com.tw/articles/10185514)
    ///   - delegateQueue: OperationQueue?
    ///   - progress: UploadProgressInformation
    ///   - completion: Result<Bool, Error>
    /// - Returns: URLSessionUploadTask?
    func fragmentUpload(with httpMethod: Constant.HttpMethod? = .POST, urlString: String, parameters: [String: Data], headers: [String: String?]? = nil, filename: String, contentType: Constant.ContentType = .octetStream, delegateQueue: OperationQueue? = .main, progress: @escaping ((UploadProgressInformation) -> Void), completion: @escaping (Result<Bool, Error>) -> Void) -> URLSessionUploadTask? {
        
        cleanAllBlocks()
        
        guard var request = URLRequest._build(string: urlString, httpMethod: httpMethod) else { completion(.failure(Constant.MyError.notOpenURL)); return nil }
        
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        var uploadTask: URLSessionUploadTask?
        
        request._setValue("\(contentType)", forHTTPHeaderField: .contentType)
        
        parameters.first.map { (field, data) in
            request.setValue(filename, forHTTPHeaderField: field)
            uploadTask = urlSession.uploadTask(with: request, from: data)
        }
        
        if let headers = headers {
            headers.forEach { key, value in if let value = value { request.addValue(value, forHTTPHeaderField: key) }}
        }
        
        fragmentUploadProgressResultBlock = progress
        fragmentUploadFinishBlock = completion
        
        uploadTask?.resume()
        
        return uploadTask
    }

    /// [下載資料 => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [Timeout](https://draveness.me/ios-yuan-dai-ma-jie-xi-sdwebimage/)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - isResume: [是否要立刻執行Task](https://liuyousama.top/2020/10/18/Kingfisher源码阅读/)
    ///   - progress: [下載進度](https://www.appcoda.com.tw/ios-concurrency/)
    ///   - completion: 下載完成後
    /// - Returns: URLSessionTask?
    func download(with httpMethod: Constant.HttpMethod? = .GET, urlString: String, timeout: TimeInterval = .infinity, delegateQueue: OperationQueue? = .main, isResume: Bool = true, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> URLSessionTask? {
        
        guard let downloadTask = self.downloadTaskMaker(with: httpMethod, urlString: urlString, timeout: timeout, delegateQueue: delegateQueue) else { completion(.failure(Constant.MyError.notUrlFormat)); return nil }
        
        downloadTaskResultBlock = completion
        downloadProgressResultBlock = progress

        if (isResume) { downloadTask.resume() }
                
        return downloadTask
    }

    /// [下載資料 (多個) => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlStrings: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: Timeout
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - progress: 下載進度
    ///   - completion: 下載完成後
    /// - Returns: [URLSessionTask]
    func multipleDownload(with httpMethod: Constant.HttpMethod? = .GET, urlStrings: [String], timeout: TimeInterval = .infinity, delegateQueue: OperationQueue? = .main, progress: @escaping ((DownloadProgressInformation) -> Void), completion: @escaping ((Result<DownloadResultInformation, Error>) -> Void)) -> [URLSessionTask] {
        
        cleanAllBlocks()
        
        let _urlStrings = urlStrings._arraySet()
        
        let downloadTasks = _urlStrings.compactMap { urlString in
            
            self.download(with: httpMethod, urlString: urlString, timeout: timeout, delegateQueue: delegateQueue) { info in
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
    ///   - fragment: 分段數量
    ///   - delegateQueue: OperationQueue
    ///   - timeoutInterval: TimeInterval
    ///   - result: Result<FragmentDownloadDataInfomation, Error>
    ///   - progress: 下載進度
    ///   - completion: (Result<Data, Error>
    func fragmentDownload(with urlString: String, fragment: Int = 2, delegateQueue: OperationQueue? = .main, timeoutInterval: TimeInterval = .infinity, progress: @escaping ((DownloadProgressInformation) -> Void), completion: ((Result<Data, Error>) -> Void)?) {

        guard fragment > 0 else { return }
        
        fragmentDownloadProgressResultBlock = progress
        cleanFragmentInformation()
        
        self.header(urlString: urlString) { result in

            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let info):

                guard let contentLengthString = info.response?._headerField(with: .contentLength) as? String,
                      let contentLength = Int(contentLengthString),
                      let fragmentSize = Optional.some((contentLength / fragment) + 1)
                else {
                    completion?(.failure(Constant.MyError.notUrlDownload)); return
                }

                self.fragmentDownloadContentLength = contentLength

                for index in 0..<fragment {

                    let offset: HttpDownloadOffset = (index * fragmentSize, (index + 1) * fragmentSize - 1)

                    let _task = self.fragmentDownloadDataTaskMaker(with: urlString, delegateQueue: delegateQueue, offset: offset, timeout: timeoutInterval) { _result in
                        switch _result {
                        case .failure(let error): completion?(.failure(error))
                        case .success(let info): completion?(.success(info))
                        }
                    }

                    if let _task = _task {
                        self.fragmentDownloadKeys.append("\(_task)")
                        _task.resume()
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
    ///   - contentType: [要回傳的格式 => application/json](https://notfalse.net/39/http-message-format)
    ///   - queryItems: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    /// - Returns: Result<ResponseInformation, Error>
    func asyncRequest(with httpMethod: Constant.HttpMethod = .GET, urlString: String, contentType: Constant.ContentType = .json, queryItems: [URLQueryItem]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            request(with: httpMethod, urlString: urlString, contentType: contentType, queryItems: queryItems, headers: headers, httpBody: httpBody) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [發出URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: 網址
    ///   - paramaters: 參數 => ?name=william
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - httpBody: Data => 所有的資料只要轉成Data都可以傳
    ///   - contentType: Constant.ContentType
    /// - Returns: Result<ResponseInformation, Error>
    func asyncRequest(with httpMethod: Constant.HttpMethod = .GET, urlString: String, contentType: Constant.ContentType = .json, paramaters: [String: String?]? = nil, headers: [String: String?]? = nil, httpBody: Data? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            request(with: httpMethod, urlString: urlString, contentType: contentType, paramaters: paramaters, headers: headers, httpBody: httpBody) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 取得該URL資源的HEAD資訊 (檔案大小 / 類型 / 上傳日期…)
    /// - Parameters:
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    /// - Returns: Result<ResponseInformation, Error>
    func asyncHeader(urlString: String, headers: [String: String?]? = nil) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            header(urlString: urlString, headers: headers) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [上傳檔案 - 模仿Form](https://www.w3schools.com/nodejs/nodejs_uploadfiles.asp)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://imququ.com/post/web-proxy.html)
    ///   - parameters: [圖片Data](https://pjchender.blogspot.com/2017/06/chrome-dev-tools.html)
    ///   - headers: [Http Header](https://zh.wikipedia.org/zh-tw/HTTP头字段)
    ///   - filename: [上傳後的檔案名稱 => 123456_<filename>.png](https://ithelp.ithome.com.tw/articles/10244974?sc=rss.iron)
    ///   - contentType: 檔案類型 (MIME) => image/png
    /// - Returns: Result<ResponseInformation, Error>
    func asyncUpload(with httpMethod: Constant.HttpMethod? = .POST, urlString: String, parameters: [String: Data], headers: [String: String?]? = nil, filename: String, contentType: Constant.ContentType = .png) async -> Result<ResponseInformation, Error> {
        
        await withCheckedContinuation { continuation in
            upload(with: httpMethod, urlString: urlString, parameters: parameters, headers: headers, filename: filename, contentType: contentType) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// [片段上傳 - 大型檔案](https://www.swiftbysundell.com/articles/http-post-and-file-upload-requests-using-urlsession/)
    /// - Parameters:
    ///   - httpMethod: [Constant.HttpMethod?](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
    ///   - urlString: String
    ///   - parameters: [String: Data]
    ///   - headers:  [String: String?]?
    ///   - filename: String
    ///   - contentType: [Constant.ContentType](https://ithelp.ithome.com.tw/articles/10185514)
    ///   - delegateQueue: OperationQueue?
    ///   - progress: UploadProgressInformation
    ///   - completion: Result<Bool, Error>
    /// - Returns: URLSessionUploadTask?
    @MainActor
    func asyncFragmentUpload(with httpMethod: Constant.HttpMethod? = .POST, urlString: String, parameters: [String: Data], headers: [String: String?]? = nil, filename: String, contentType: Constant.ContentType = .octetStream, delegateQueue: OperationQueue? = .main, sessionTask: @escaping ((URLSessionTask?) -> Void), progress: @escaping ((UploadProgressInformation) -> Void)) async -> Result<Bool, Error> {
        
        await withCheckedContinuation { continuation in
            
            let task = fragmentUpload(with: httpMethod, urlString: urlString, parameters: parameters, headers: headers, filename: filename, contentType: contentType, delegateQueue: delegateQueue) { info in
                progress(info)
            } completion: { result in
                Task { @MainActor in
                    continuation.resume(returning: result)
                }
            }
            
            sessionTask(task)
        }
    }
    
    /// [下載資料 => URLSessionDownloadDelegate](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-3-34699564fb12)
    /// - Parameters:
    ///   - httpMethod: [HTTP方法](https://imququ.com/post/four-ways-to-post-data-in-http.html)
    ///   - urlString: [網址](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/2c17813523194f578281c430e8ecca02)
    ///   - timeout: [Timeout](https://draveness.me/ios-yuan-dai-ma-jie-xi-sdwebimage/)
    ///   - delegateQueue: [執行緒](https://zh-tw.coderbridge.com/series/01d31194cb3c428d9ca2575c91e8b997/posts/c44ba1db0ded4d53aec73a8e589ca1e5)
    ///   - isResume: [是否要立刻執行Task](https://liuyousama.top/2020/10/18/Kingfisher源码阅读/)
    ///   - progress: [下載進度](https://www.appcoda.com.tw/ios-concurrency/)
    ///   - sessionTask: 執行的Task
    /// - Returns: Result<DownloadResultInformation, Error>
    @MainActor
    func asyncDownload(with httpMethod: Constant.HttpMethod? = .GET, urlString: String, timeout: TimeInterval = .infinity, delegateQueue: OperationQueue? = .main, isResume: Bool = true, sessionTask: @escaping ((URLSessionTask?) -> Void), progress: @escaping ((DownloadProgressInformation) -> Void)) async -> Result<DownloadResultInformation, Error> {
        
        await withCheckedContinuation { continuation in
            
            let task = download(with: httpMethod, urlString: urlString, timeout: timeout, delegateQueue: delegateQueue, isResume: isResume) { info in
                progress(info)
            } completion: { result in
                Task { @MainActor in
                    continuation.resume(returning: result)
                }
            }
            
            sessionTask(task)
        }
    }
    
    /// [分段下載](https://www.jianshu.com/p/534ec0d9d758)
    /// - Parameters:
    ///   - urlString: String
    ///   - fragment: 分段數量
    ///   - delegateQueue: OperationQueue
    ///   - timeoutInterval: TimeInterval
    ///   - progress: 下載進度
    /// - Returns: Result<Data, Error>
    @MainActor
    func asyncFragmentDownload(with urlString: String, fragment: Int = 2, delegateQueue: OperationQueue? = .main, timeoutInterval: TimeInterval = .infinity, progress: @escaping ((DownloadProgressInformation) -> Void)) async -> Result<Data, Error> {
        
        await withCheckedContinuation { continuation in
            
            fragmentDownload(with: urlString, fragment: fragment, delegateQueue: delegateQueue, timeoutInterval: timeoutInterval) { info in
                progress(info)
            } completion: { result in
                Task { @MainActor in
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

// MARK: - URLSessionDataDelegate
private extension WWNetworking {
    
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
    ///   - timeout: Timeout
    ///   - delegateQueue: 執行緒
    /// - Returns: URLSessionDownloadTask
    func downloadTaskMaker(with httpMethod: Constant.HttpMethod? = .POST, urlString: String, timeout: TimeInterval = .infinity, delegateQueue: OperationQueue? = .main) -> URLSessionDownloadTask? {

        guard let request = URLRequest._build(string: urlString, httpMethod: httpMethod) else { return nil }

        let configiguration = URLSessionConfiguration.background(withIdentifier: urlString)._timeoutInterval(timeout)
        let urlSession = URLSession(configuration: configiguration, delegate: self, delegateQueue: delegateQueue)
        let downloadTask = urlSession.downloadTask(with: request)

        return downloadTask
    }
    
    /// [抓取資料 - dataTask() => URLSessionDataDelegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate)
    /// - Parameters:
    ///   - request: [URLRequest](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    ///   - result: Result<Constant.ResponseInformation, Error>
    func fetchData(from request: URLRequest, result: @escaping (Result<ResponseInformation, Error>) -> Void) {

        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in

            if let error = error { result(.failure(error)); return }

            let info: ResponseInformation = (data: data, response: response as? HTTPURLResponse)
            result(.success(info))
        }
        
        dataTask.resume()
    }

    /// [斷點續傳下載檔案 (Data) => HTTPHeaderField = Range / ∵ 是一段一段下載 ∴ 自己要一段一段存](https://www.jianshu.com/p/534ec0d9d758)
    /// - urlSession(_:dataTask:didReceive:) => completionHandler(.allow)
    /// - Parameters:
    ///   - urlString: String
    ///   - delegateQueue: OperationQueue?
    ///   - offset: HttpDownloadOffset
    ///   - timeout: TimeInterval
    ///   - result: Result<Data, Error>) -> Void
    /// - Returns: URLSessionDataTask?
    func fragmentDownloadDataTaskMaker(with urlString: String, delegateQueue: OperationQueue? = .main, offset: HttpDownloadOffset = (0, nil), timeout: TimeInterval = .infinity, result: ((Result<Data, Error>) -> Void)?) -> URLSessionDataTask? {

        guard let url = URL(string: urlString),
              var request = Optional.some(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)),
              let configiguration = Optional.some(URLSessionConfiguration.background(withIdentifier: urlString)._timeoutInterval(timeout)),
              let urlSession = Optional.some(URLSession(configuration: configiguration, delegate: self, delegateQueue: delegateQueue)),
              let headerValue = downloadOffsetMaker(offset: offset)
        else {
            return nil
        }

        request._setValue(headerValue, forHTTPHeaderField: .range)
        fragmentDownloadFinishBlock = result

        return urlSession.dataTask(with: request)
    }

    /// Range: bytes=0-1024
    /// - Parameter offset: Constant.HttpDownloadOffset
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
