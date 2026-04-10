//
//  Helpers.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import Foundation

enum Formatters {
    static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func tokens(_ value: Int64) -> String {
        let d = Double(value)
        if d >= 1_000_000_000 {
            return String(format: "%.1fB", d / 1_000_000_000)
        } else if d >= 1_000_000 {
            return String(format: "%.1fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.1fK", d / 1_000)
        }
        return "\(value)"
    }

    static func tokens(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percentage(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.1f%%", value)
        }
        return String(format: "%.1f%%", value)
    }
}
