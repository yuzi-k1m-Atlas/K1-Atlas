import Foundation

struct K1Voice: Identifiable, Hashable {
    let id = UUID()
    let sourceFile: String
    let number: Int
    let name: String
    let rawData: [UInt8]

    var displayNumber: String {
        String(format: "%02d", number)
    }

    var fingerprint: String {
        rawData.map { String(format: "%02X", $0) }.joined()
    }
}//
//  Untitled.swift
//  K1 Atlas
//
//  Created by yuji on 2026/07/05.
//

