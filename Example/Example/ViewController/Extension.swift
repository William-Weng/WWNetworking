//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2024/2/20.
//

import UIKit

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

// MARK: - Data (class function)
extension Data {
    
    /// Data => JSON
    /// - 7b2268747470223a2022626f6479227d => {"http": "body"}
    /// - Returns: Any?
    func _jsonSerialization(options: JSONSerialization.ReadingOptions = .allowFragments) -> Any? {
        let json = try? JSONSerialization.jsonObject(with: self, options: options)
        return json
    }
}
