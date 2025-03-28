//
//  Constant.swift
//  WWNetworking
//
//  Created by William.Weng on 2021/8/25.
//

import UIKit

// MARK: - typealias
public extension WWNetworking {
    
    typealias DownloadProgressInformation = (urlString: String?, totalSize: Int64, totalWritten: Int64, writting: Int64)                    // 網路下載資料 => (URL / 大小 / 己下載 / 一段段的下載量)
    typealias ResponseInformation = (data: Data?, response: HTTPURLResponse?)                                                               // 網路回傳的資料
    typealias HttpDownloadOffset = (start: Int?, end: Int?)                                                                                 // 續傳下載開始~結束位置設定值 (bytes=0-1024)
    typealias DownloadResultInformation = (urlString: String, data: Data?)                                                                  // 網路下載資料的結果資訊 (URL, Data)
    typealias UploadProgressInformation = (urlString: String?, bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)    // 網路上傳資料 (URL / 段落上傳大小 / 己上傳大小 / 總大小)
    typealias FormDataInformation = (name: String, filename: String, contentType: ContentType, data: Data)                                  // 上傳檔案資訊 (參數名稱 / 檔名 / 檔案類型 / 資料)
    typealias RequestInformationType = (httpMethod: HttpMethod,                                                                             // 多個request的參數值 (同單個request)
                                        urlString: String,
                                        timeout: TimeInterval,
                                        contentType: ContentType,
                                        paramaters: [String: String?]?,
                                        headers: [String: String?]?,
                                        httpBodyType: HttpBobyType?)
}

// MARK: - 常數
public extension WWNetworking {

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
        case soupAction = "SOAPAction"
    }
    
    /// HttpBody的類型 (Data)
    enum HttpBobyType {
        
        case string(_ string: String?, encoding: String.Encoding = .utf8, isLossyConversion: Bool = false)
        case array(_ array: [Any]?, options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions())
        case dictionary(_ dictionary: [String: Any]?, options: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions())
        case form(_ dictionary: [String: String]?, encoding: String.Encoding = .utf8, isLossyConversion: Bool = false)
        case custom(_ data: Data?)
        
        /// 轉成Data
        /// - Returns: Data?
        func data() -> Data? {
            
            switch self {
            case .string(let string, let encoding, let isLossyConversion): return string?._data(using: encoding, isLossyConversion: isLossyConversion)
            case .array(let array, let options): return array?._jsonData(options: options)
            case .dictionary(let dictionary, let options): return dictionary?._jsonData(options: options)
            case .form(let dictionary, let encoding, let isLossyConversion): return dictionary?.map { "\($0)=\($1)" }.joined(separator: "&")._data(using: encoding, isLossyConversion: isLossyConversion)
            case .custom(let data): return data
            }
        }
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
        case fragmentCountError

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
            case .fragmentCountError: return "分段下載數量至少要有一段"
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
        case formData(boundary: String)
        case flac
        case mp3
        case mp4
        case mpeg
        case mpga
        case m4a
        case ogg
        case wav
        case webm
        case octetStream
        case bearer(forKey: String)
        case custom(value: String)
        
        /// [轉成MIME文字](https://developer.mozilla.org/zh-TW/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
        /// - Returns: [String](https://www.iana.org/assignments/media-types/media-types.xhtml)
        private func toString() -> String {
            
            switch self {
            case .plain: return "text/plain"
            case .html: return "text/html"
            case .xml: return "text/xml"
            case .json: return "application/json"
            case .png: return "image/png"
            case .jpeg: return "image/jpeg"
            case .mp3: return "audio/mpeg"
            case .mpeg: return "audio/mpeg"
            case .mpga: return "audio/mpeg"
            case .mp4: return "audio/mp4"
            case .ogg: return "audio/ogg"
            case .wav: return "audio/wav"
            case .webm: return "audio/webm"
            case .m4a: return "audio/m4a"
            case .flac: return "audio/flac"
            case .formUrlEncoded: return "application/x-www-form-urlencoded"
            case .formData(boundary: let boundary): return "multipart/form-data; boundary=\(boundary)"
            case .octetStream: return "application/octet-stream"
            case .bearer(forKey: let key): return "Bearer \(key)"
            case .custom(value: let value): return value
            }
        }
    }
}
