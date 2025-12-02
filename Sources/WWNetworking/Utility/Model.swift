//
//  Model.swift
//  WWNetworking
//
//  Created by Willam.Weng on 2025/9/26.
//

import Foundation

// MARK: - struct
public extension WWNetworking {
    
    /// SSLPinning的設定值 => 只分辨host有沒有重複 (不分大小寫)
    struct SSLPinningValue: Hashable {
        
        let host: String
        let cer: String
        
        public init(host: String, cer: String) {
            self.host = host
            self.cer = cer
        }
        
        public static func == (lhs: SSLPinningValue, rhs: SSLPinningValue) -> Bool {
            return lhs.host.lowercased() == rhs.host.lowercased()
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(host.lowercased())
        }
    }
}

// MARK: - actor
extension WWNetworking {
    
    /// 多個下載狀態安全管理器
    actor MultipleDownloadStateManager {
        
        private var tasksCount: Int = 0
        
        /// 記錄task總數
        /// - Parameter count: Int
        func tasksCount(_ count: Int) {
            self.tasksCount = count
        }
        
        /// 計數task是否完成
        /// - Returns: Bool
        func taskDidFinish() -> Bool {
            tasksCount -= 1
            return tasksCount <= 0
        }
    }
}

// MARK: - struct
extension WWNetworking {
    
    /// HTTP回應
    struct HttpResponse: Error {
        
        let statusCode: Int
        let header: [AnyHashable : Any]
        let url: URL?
        
        /// 建立Http錯誤類別
        /// - Parameter response: HTTPURLResponse
        /// - Returns: HttpResponse
        static func builder(response: HTTPURLResponse) -> HttpResponse {
            return HttpResponse(statusCode: response.statusCode, header: response.allHeaderFields, url: response.url)
        }
        
        /// 有沒有錯誤 (除了2xx之內的都錯)
        /// - Returns: Bool
        func hasError() -> Bool {
            switch statusCode {
            case 200...299: return false
            default: return true
            }
        }
    }
}
