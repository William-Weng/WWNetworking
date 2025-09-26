//
//  Model.swift
//  WWNetworking
//
//  Created by Willam.Weng on 2025/9/26.
//

import Foundation

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
            self.tasksCount -= 1
            return self.tasksCount <= 0
        }
    }
}
