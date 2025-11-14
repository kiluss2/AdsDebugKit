//
//  DateFormatter+Extensions.swift
//  AdsDebugKit
//
//  Created on 2025.
//

import Foundation

extension DateFormatter {
    static let cached: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}


