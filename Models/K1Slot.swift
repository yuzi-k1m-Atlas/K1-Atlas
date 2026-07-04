import Foundation

enum K1SlotType: String, Codable {
    case single
    case multi
}

struct K1Slot: Identifiable {
    let id = UUID()
    let index: Int
    let label: String
    let programChange: Int
    let type: K1SlotType
    var voice: K1Voice?
}
//  K1Slot.swift
//  K1 Atlas
//
//  Created by yuji on 2026/07/05.
//

