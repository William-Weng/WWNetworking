//
//  Extension.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/3.
//

import UIKit

// MARK: - Collection (override class function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - Collection (class function)
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

// MARK: - Dictionary (class function)
extension Dictionary {
    
    /// Dictionary => JSON Data
    /// - ["name":"William"] => {"name":"William"} => 7b226e616d65223a2257696c6c69616d227d
    /// - Returns: Data?
    func _jsonSerialization() -> Data? {
        
        guard JSONSerialization.isValidJSONObject(self),
              let data = try? JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions())
        else {
            return nil
        }
        
        return data
    }
}

// MARK: - Dictionary (class function)
extension Dictionary where Self.Key == String, Self.Value == String? {
    
    /// [將[String: String?] => [URLQueryItem]](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-2-a17b2d4cc056)
    /// - ["name": "William.Weng", "github": "https://william-weng.github.io/"] => ?name=William.Weng&github=https://william-weng.github.io/
    /// - Returns: [URLQueryItem]
    func _queryItems() -> [URLQueryItem]? {
        
        if self.isEmpty { return nil }
        
        var queryItems: [URLQueryItem] = []

        for (key, value) in self {
            guard let queryItem = Optional.some(URLQueryItem(name: key, value: value)) else { return queryItems }
            queryItems.append(queryItem)
        }

        return queryItems
    }
}

extension UIImage {
    
    /// UIImage => Data
    /// - jpeg / png
    /// - Parameter mimeType: jpeg / png
    /// - Returns: Data?
    func _data(mimeType: WWNetworking.Constant.MimeType = .png) -> Data? {

        switch mimeType {
        case .jpeg(let compressionQuality): return jpegData(compressionQuality: compressionQuality)
        case .png: return pngData()
        }
    }
}

// MARK: - URLComponents (static function)
extension URLComponents {
    
    /// 產生URLComponents
    /// - Parameters:
    ///   - urlString: UrlString
    ///   - queryItems: Query參數
    /// - Returns: URLComponents?
    static func _build(urlString: String, queryItems: [URLQueryItem]?) -> URLComponents? {
        
        guard var urlComponents = URLComponents(string: urlString) else { return nil }
        urlComponents.queryItems = queryItems
        
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

// MARK: - URLRequest (class function)
extension URLRequest {
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - url: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    static func _build(url: URL, httpMethod: WWNetworking.Constant.HttpMethod? = nil) -> URLRequest {
        return Self._build(url: url, httpMethod: httpMethod?.rawValue)
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - url: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    static func _build(url: URL, httpMethod: String? = nil) -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        return request
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - string: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    static func _build(string: String, httpMethod: String? = nil) -> URLRequest? {
        guard let url = URL(string: string) else { return nil }
        return Self._build(url: url, httpMethod: httpMethod)
    }
    
    /// 產生URLRequest
    /// - Parameters:
    ///   - string: URL網址
    ///   - httpMethod: HTTP方法 (GET / POST / ...)
    static func _build(string: String, httpMethod: WWNetworking.Constant.HttpMethod? = nil) -> URLRequest? {
        guard let url = URL(string: string) else { return nil }
        return Self._build(url: url, httpMethod: httpMethod)
    }
}

// MARK: - URLRequest (class function)
extension URLRequest {
    
    /// enum版的.setValue(_,forHTTPHeaderField:_)
    /// - Parameters:
    ///   - value: 要設定的值
    ///   - field: 要設定的欄位
    mutating func _setValue(_ value: String?, forHTTPHeaderField field: WWNetworking.Constant.HTTPHeaderField) {
        self.setValue(value, forHTTPHeaderField: field.rawValue)
    }
    
    /// enum版的.setValue(_,forHTTPHeaderField:_)
    /// - Parameters:
    ///   - value: 要設定的值
    ///   - field: 要設定的欄位
    mutating func _setValue(_ value: WWNetworking.Constant.ContentType, forHTTPHeaderField field: WWNetworking.Constant.HTTPHeaderField) {
        self.setValue("\(value)", forHTTPHeaderField: field.rawValue)
    }
}

// MARK: - Data (class function)
extension Data {

    /// Data加上文字
    /// - Parameters:
    ///   - string: 要加入的字串
    ///   - encoding: .utf8
    ///   - allowLossyConversion: true
    /// - Returns: Bool
    mutating func _append(string: String, using encoding: String.Encoding = .utf8, allowLossyConversion: Bool = true) -> Bool {
        
        guard let data = string.data(using: encoding, allowLossyConversion: allowLossyConversion) else { return false }
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

// MARK: - HTTPURLResponse (class function)
extension HTTPURLResponse {
    
    /// 取得其中一個Field
    /// - Parameter key: AnyHashable
    /// - Returns: Any?
    func _headerField(for key: AnyHashable) -> Any? {
        return self.allHeaderFields[key]
    }
    
    /// 取得其中一個Field
    /// - Parameter key: Constant.HTTPHeaderField
    /// - Returns: Any?
    func _headerField(with key: WWNetworking.Constant.HTTPHeaderField) -> Any? {
        return self._headerField(for: key.rawValue)
    }
}

// MARK: - URLSessionConfiguration (class function)
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

