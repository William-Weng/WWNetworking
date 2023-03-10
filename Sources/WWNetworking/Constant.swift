//
//  Constant.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/25.
//

import UIKit

// MARK: - 常數
public extension WWNetworking.Constant {

    /// [HTTP 請求方法](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Methods)
    enum HttpMethod: String {
        case GET = "GET"
        case HEAD = "HEAD"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
        case CONNECT = "CONNECT"
        case OPTIONS = "OPTIONS"
        case TRACE = "TRACE"
        case PATCH = "PATCH"
    }
    
    /// [HTTP標頭欄位](https://zh.wikipedia.org/wiki/HTTP头字段)
    enum HTTPHeaderField: String {
        case acceptRanges = "Accept-Ranges"
        case authorization = "Authorization"
        case contentType = "Content-Type"
        case contentLength = "Content-Length"
        case contentRange = "Content-Range"
        case contentDisposition = "Content-Disposition"
        case date = "Date"
        case lastModified = "Last-Modified"
        case range = "Range"
    }
    
    /// 自訂錯誤
    enum MyError: Error, LocalizedError {
        
        var errorDescription: String { errorMessage() }

        case unknown
        case isEmpty
        case isCancel
        case notUrlFormat
        case notGeocodeLocation
        case notUrlDownload
        case notCallTelephone
        case notEncoding
        case notOpenURL
        case notOpenSettingsPage
        case notSupports
        case unregistered
        
        /// 顯示錯誤說明
        /// - Returns: String
        private func errorMessage() -> String {

            switch self {
            case .unknown: return "未知錯誤"
            case .notUrlFormat: return "URL格式錯誤"
            case .notCallTelephone: return "播打電話錯誤"
            case .notOpenURL: return "打開URL錯誤"
            case .notOpenSettingsPage: return "打開APP設定頁錯誤"
            case .notGeocodeLocation: return "地理編碼錯誤"
            case .notUrlDownload: return "URL下載錯誤"
            case .isEmpty: return "資料是空的"
            case .isCancel: return "取消"
            case .notSupports: return "該手機不支援"
            case .notEncoding: return "該資料編碼錯誤"
            case .unregistered: return "尚未註冊"
            }
        }
    }
    
    /// [網頁檔案類型的MimeType](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types)
    enum MimeType {
        case jpeg(compressionQuality: CGFloat)
        case png
    }
    
    /// [HTTP Content-Type](https://www.runoob.com/http/http-content-type.html) => Content-Type: application/json
    enum ContentType: CustomStringConvertible {
        
        public var description: String { return toString() }
        
        case plain
        case html
        case xml
        case json
        case png
        case jpeg
        case formUrlEncoded
        case formData
        case octetStream
        case bearer(forKey: String)
        
        /// [轉成MIME文字](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
        /// - Returns: String
        private func toString() -> String {
            
            switch self {
            case .plain: return "text/plain"
            case .html: return "text/html"
            case .xml: return "text/xml"
            case .json: return "application/json"
            case .png: return "image/png"
            case .jpeg: return "image/jpeg"
            case .formUrlEncoded: return "application/x-www-form-urlencoded"
            case .formData: return "multipart/form-data"
            case .octetStream: return "application/octet-stream"
            case .bearer(forKey: let key): return "Bearer \(key)"
            }
        }
    }
}
