//
//  Delegate.swift
//  WWNetworking
//
//  Created by William.Weng on 2025/12/29.
//

import Foundation

// MARK: - Delegate
public extension WWNetworking {
    
    protocol Delegate: AnyObject {
        
        // SSL-Pinning的結果
        func authChalleng(_ networking: WWNetworking, host: String?, disposition: URLSession.AuthChallengeDisposition?, credential: URLCredential?)
    }
}

