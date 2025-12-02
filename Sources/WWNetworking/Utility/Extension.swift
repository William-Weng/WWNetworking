//
//  Extension.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import UIKit

// MARK: - String
extension String {
    
    /// String => Data
    /// - Parameters:
    ///   - encoding: 字元編碼
    ///   - isLossyConversion: 失真轉換
    /// - Returns: Data?
    func _data(using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false) -> Data? {
        let data = self.data(using: encoding, allowLossyConversion: isLossyConversion)
        return data
    }
}

// MARK: - Collection (subscript)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - Collection
extension Collection where Self.Element: Hashable {
        
    /// 不要有重複的值 => Array -> Set
    /// - Returns: Set<Self.Element>
    func _set() -> Set<Self.Element> {
        return Set(self)
    }
    
    /// 沒有重複值的Array => Array -> Set -> Array
    /// - Returns: [Self.Element]
    func _arraySet() -> [Self.Element] {
        return Array(self._set())
    }
}

// MARK: - Sequence
extension Sequence {
        
    /// Array => JSON Data
    /// - ["name","William"] => ["name","William"] => 5b226e616d65222c2257696c6c69616d225d
    /// - Returns: Data?
    func _jsonData(options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions()) -> Data? {
        return JSONSerialization._data(with: self, options: options)
    }
}

// MARK: - Dictionary
extension Dictionary {
    
    /// Dictionary => JSON Data
    /// - ["name":"William"] => {"name":"William"} => 7b226e616d65223a2257696c6c69616d227d
    /// - Returns: Data?
    func _jsonData(options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions()) -> Data? {
        return JSONSerialization._data(with: self, options: options)
    }
}

// MARK: - Dictionary
extension Dictionary where Self.Key == String, Self.Value == String? {
    
    /// [將[String: String?] => [URLQueryItem]](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    /// - ["name": "William.Weng", "github": "https://william-weng.github.io/"] => ?name=William.Weng&github=https://william-weng.github.io/
    /// - Returns: [URLQueryItem]
    func _queryItems() -> [URLQueryItem]? {
        
        if self.isEmpty { return nil }
        
        var queryItems: [URLQueryItem] = []

        for (key, value) in self {
            
            guard let value = value else { continue }
            
            let queryItem = URLQueryItem(name: key, value: value)
            queryItems.append(queryItem)
        }
        
        return queryItems
    }
}

// MARK: - JSONSerialization (static)
extension JSONSerialization {
    
    /// [JSONObject => JSON Data](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/利用-jsonserialization-印出美美縮排的-json-308c93b51643)
    /// - ["name":"William"] => {"name":"William"} => 7b226e616d65223a2257696c6c69616d227d
    /// - Parameters:
    ///   - object: Any
    ///   - options: JSONSerialization.WritingOptions
    /// - Returns: Data?
    static func _data(with object: Any, options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions()) -> Data? {
        
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: options)
        else {
            return nil
        }
        
        return data
    }
}

// MARK: - Data
extension Data {

    /// Data加上文字
    /// - Parameters:
    ///   - string: 要加入的字串
    ///   - encoding: .utf8
    ///   - allowLossyConversion: true
    /// - Returns: Bool
    mutating func _append(string: String, using encoding: String.Encoding = .utf8, allowLossyConversion: Bool = true) -> Bool {
        
        guard let data = string._data(using: encoding, isLossyConversion: allowLossyConversion) else { return false }
        self.append(data)
        
        return true
    }
    
    /// Data + Data
    /// - Parameter data: Data
    /// - Returns: Bool
    mutating func _append(data: Data?) -> Bool {
        
        guard let data = data else { return false }
        self.append(data)
        
        return true
    }
}

// MARK: - FileManager
extension FileManager {
    
    ///appSupportDirectory [取得User的資料夾](https://cdfq152313.github.io/post/2016-10-11/)
    /// - UIFileSharingEnabled = YES => iOS設置iTunes文件共享
    /// - Parameter directory: User的資料夾名稱
    /// - Returns: [URL]
    func _userDirectory(for directory: FileManager.SearchPathDirectory) -> [URL] { return Self.default.urls(for: directory, in: .userDomainMask) }

    /// User的「快取」資料夾
    /// - => ~/Library/Caches/
    /// - Returns: URL?
    func _cachesDirectory() -> URL? { return self._userDirectory(for: .cachesDirectory).first }
    
    /// 移動檔案
    /// - Parameters:
    ///   - atURL: 從這裡移動 =>
    ///   - toURL: => 到這裡
    /// - Returns: Result<Bool, Error>
    func _moveFile(at atURL: URL, to toURL: URL) -> Result<Bool, Error> {
        
        do {
            try moveItem(at: atURL, to: toURL)
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - UIImage
extension UIImage {
    
    /// UIImage => Data
    /// - jpeg / png
    /// - Parameter mimeType: jpeg / png
    /// - Returns: Data?
    func _data(mimeType: WWNetworking.MimeType = .png) -> Data? {

        switch mimeType {
        case .jpeg(let compressionQuality): return jpegData(compressionQuality: compressionQuality)
        case .png: return pngData()
        }
    }
}

// MARK: - URLComponents (static)
extension URLComponents {
    
    /// 產生URLComponents
    /// - Parameters:
    ///   - urlString: UrlString
    ///   - queryItems: Query參數
    /// - Returns: URLComponents?
    static func _build(urlString: String, queryItems: [URLQueryItem]?) -> URLComponents? {
        
        guard var urlComponents = URLComponents(string: urlString) else { return nil }
                        
        if let queryItems = queryItems {
            
            let urlComponentsQueryItems = urlComponents.queryItems ?? []
            let newQueryItems = (urlComponentsQueryItems + queryItems)
            
            urlComponents.queryItems = newQueryItems
        }
        
        return urlComponents
    }
    
    /// 產生URLComponents
    /// - Parameters:
    ///   - urlString: UrlString
    ///   - paramater: Query參數
    /// - Returns: URLComponents?
    static func _build(urlString: String, paramater: [String: String?]?) -> URLComponents? {
        return Self._build(urlString: urlString, queryItems: paramater?._queryItems())
    }
}

// MARK: - URLRequest
extension URLRequest {
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - url: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    ///   - timeoutInterval: TimeInterval
    /// - Returns: URLRequest
    static func _build(url: URL, httpMethod: WWNetworking.HttpMethod? = nil, timeout: TimeInterval) -> URLRequest {
        return Self._build(url: url, httpMethod: httpMethod?.rawValue, timeout: timeout)
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - url: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    ///   - timeout: TimeInterval
    /// - Returns: URLRequest
    static func _build(url: URL, httpMethod: String? = nil, timeout: TimeInterval) -> URLRequest {
        
        var request = URLRequest(url: url)
        
        request.httpMethod = httpMethod
        request.timeoutInterval = timeout
        
        return request
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - string: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    ///   - timeout: TimeInterval
    /// - Returns: URLRequest?
    static func _build(string: String, httpMethod: String? = nil, timeout: TimeInterval) -> URLRequest? {
        guard let url = URL(string: string) else { return nil }
        return Self._build(url: url, httpMethod: httpMethod, timeout: timeout)
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - string: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    ///   - timeout: TimeInterval
    /// - Returns: URLRequest?
    static func _build(string: String, httpMethod: WWNetworking.HttpMethod? = nil, timeout: TimeInterval) -> URLRequest? {
        guard let url = URL(string: string) else { return nil }
        return Self._build(url: url, httpMethod: httpMethod, timeout: timeout)
    }
}

// MARK: - URLRequest (mutating)
extension URLRequest {
    
    /// enum版的.setValue(_,forHTTPHeaderField:_)
    /// - Parameters:
    ///   - value: 要設定的值
    ///   - field: 要設定的欄位
    mutating func _setValue(_ value: String?, forHTTPHeaderField field: WWNetworking.HTTPHeaderField) {
        self.setValue(value, forHTTPHeaderField: field.rawValue)
    }
    
    /// enum版的.setValue(_,forHTTPHeaderField:_)
    /// - Parameters:
    ///   - value: 要設定的值
    ///   - field: 要設定的欄位
    mutating func _setValue(_ value: WWNetworking.ContentType, forHTTPHeaderField field: WWNetworking.HTTPHeaderField) {
        self.setValue("\(value)", forHTTPHeaderField: field.rawValue)
    }
}

// MARK: - HTTPURLResponse
extension HTTPURLResponse {
    
    /// 取得其中一個Field
    /// - Parameter key: AnyHashable
    /// - Returns: Any?
    func _headerField(for key: AnyHashable) -> Any? {
        return self.allHeaderFields[key]
    }
    
    /// 取得其中一個Field
    /// - Parameter key: HTTPHeaderField
    /// - Returns: Any?
    func _headerField(with key: WWNetworking.HTTPHeaderField) -> Any? {
        return self._headerField(for: key.rawValue)
    }
}

// MARK: - URLSessionConfiguration
extension URLSessionConfiguration {
    
    /// 設定timeoutIntervalForRequest / timeoutIntervalForResource
    /// - Parameter timeoutInterval: TimeInterval
    /// - Returns: Self
    func _timeoutInterval(_ timeoutInterval: TimeInterval) -> URLSessionConfiguration {
        self.timeoutIntervalForRequest = timeoutInterval
        self.timeoutIntervalForResource = timeoutInterval
        return self
    }
}

// MARK: - URLAuthenticationChallenge
extension URLAuthenticationChallenge {
    
    /// [執行 SSL Pinning 檢查 (比對公鑰 -> SSL/TLS)](https://yu-jack.github.io/2020/03/02/ssl-pinning/)
    /// - Parameters:
    ///   - bundle: 憑證所在的 Bundle
    ///   - certificate: 憑證檔案名稱
    /// - Returns: Result<SecTrust, Error>
    func _checkAuthenticationSSLPinning(bundle: Bundle, filename certificate: String) -> Result<SecTrust, Error> {
        
        guard _checkAuthenticationMethod(NSURLAuthenticationMethodServerTrust) else { return .failure(WWNetworking.CustomError.notSSL) }
        
        do {
            let serverTrust = try _serverTrust().get()
            let serverCertificate = try _serverCertificate(with: serverTrust, at: 0).get()
            let serverPublicKey = try _serverPublicKey(with: serverCertificate, at: 0).get()
            let localPublicKey = try _localPublicKey(with: bundle, resource: certificate).get()

            if (serverPublicKey != localPublicKey) { return .failure(WWNetworking.CustomError.publicKeyError(serverPublicKey, localPublicKey)) }
            return .success(serverTrust)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - URLAuthenticationChallenge (private)
private extension URLAuthenticationChallenge {
    
    /// 檢查身份驗證方法是否為伺服器信任
    /// - Parameter method: 身份驗證方法
    /// - Returns: Bool
    func _checkAuthenticationMethod(_ method: String) -> Bool {
        return protectionSpace.authenticationMethod == method
    }
    
    /// [從 Challenge 中取得伺服器信任物件 (SecTrust)](https://ithelp.ithome.com.tw/articles/10300900)
    /// - Returns: Result<SecTrust, Error>
    func _serverTrust() -> Result<SecTrust, Error> {
        
        var trustError: CFError?
        
        guard let securityTrust = protectionSpace.serverTrust else { return .failure(WWNetworking.CustomError.isEmpty) }
        guard SecTrustEvaluateWithError(securityTrust, &trustError) else { return .failure(trustError ?? WWNetworking.CustomError.notSecurityTrust) }
        
        return .success(securityTrust)
    }
    
    /// [從 SecTrust 中取得憑證 (SecCertificate)](https://johnchihhonglin.medium.com/ssl-pinning-加強-app-和-server-通訊安全的方法-e1ad5619d4df)
    /// - Parameters:
    ///   - securityTrust: SecTrust
    ///   - index: Int
    /// - Returns: Result<SecCertificate, Error>
    func _serverCertificate(with securityTrust: SecTrust, at index: Int) -> Result<SecCertificate, Error> {
        guard let certificate = SecTrustGetCertificateAtIndex(securityTrust, index) else { return .failure(WWNetworking.CustomError.isEmpty) }
        return .success(certificate)
    }
    
    /// 從憑證中取得公鑰 (SecKey)
    /// - Parameters:
    ///   - certificate: SecCertificate
    ///   - index: Int
    /// - Returns: Result<SecKey, Error>
    func _serverPublicKey(with certificate: SecCertificate, at index: Int) -> Result<SecKey, Error> {
        guard let publicKey = SecCertificateCopyKey(certificate) else { return .failure(WWNetworking.CustomError.isEmpty) }
        return .success(publicKey)
    }
    
    /// [從本地 Bundle 中讀取憑證並取得其公鑰](https://ithelp.ithome.com.tw/articles/10252867)
    /// - Parameters:
    ///   - bundle: Bundle
    ///   - certificate: String
    /// - Returns: Result<SecKey, Error>
    func _localPublicKey(with bundle: Bundle, resource certificate: String) -> Result<SecKey, Error> {
        
        guard let path = bundle.path(forResource: certificate, ofType: nil),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
              let certificate = SecCertificateCreateWithData(nil, data),
              let publicKey = SecCertificateCopyKey(certificate)
        else {
            return .failure(WWNetworking.CustomError.isEmpty)
        }
        
        return .success(publicKey)
    }
}

// MARK: - SecKey
extension SecKey {
    
    /// SecKey => base64字串
    /// - Parameter options: Data.Base64EncodingOptions
    /// - Returns: Result<String, Error>
    func _base64String(options: Data.Base64EncodingOptions = []) -> Result<String, Error> {
        
        var error: Unmanaged<CFError>?
        
        guard let keyData = SecKeyCopyExternalRepresentation(self, &error) as Data? else {
            if let err = error?.takeRetainedValue() { return .failure(err) }
            return .failure(WWNetworking.CustomError.unknown)
        }
        
        return .success(keyData.base64EncodedString(options: options))
    }
}
