import Foundation

struct AtlasProject {
    var library: [K1Voice] = []
    var singleSlots: [K1Slot] = AtlasProject.makeSingleSlots()
    var multiSlots: [K1Slot] = AtlasProject.makeMultiSlots()

    static func makeSingleSlots() -> [K1Slot] {
        let banks = ["IA", "IB", "IC", "ID", "iA", "iB", "iC", "iD"]

        return banks.enumerated().flatMap { bankIndex, bankName in
            (1...8).map { number in
                let index = bankIndex * 8 + number - 1
                return K1Slot(
                    index: index,
                    label: "\(bankName)-\(number)",
                    programChange: index + 1,
                    type: .single,
                    voice: nil
                )
            }
        }
    }

    static func makeMultiSlots() -> [K1Slot] {
        let banks = ["IA", "IB", "IC", "ID"]

        return banks.enumerated().flatMap { bankIndex, bankName in
            (1...8).map { number in
                let index = bankIndex * 8 + number - 1
                return K1Slot(
                    index: index,
                    label: "\(bankName)-\(number)",
                    programChange: index + 65,
                    type: .multi,
                    voice: nil
                )
            }
        }
    }
}//
//  AtlasProject.swift
//  K1 Atlas
//
//  Created by yuji on 2026/07/05.
//

