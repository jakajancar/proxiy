//
//  RateCounter.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/10/21.
//

import Foundation

class RateCounter {
    private let slotDuration: TimeInterval
    private var slots: [UInt64]
    private var lastSlotNumber: UInt64
    
    convenience init() {
        self.init(numSlots: 10, slotDuration: 0.1)
    }
    
    init(numSlots: Int, slotDuration: TimeInterval) {
        self.slotDuration = slotDuration
        self.slots = Array(repeating: 0, count: numSlots)
        self.lastSlotNumber = 0
    }
    
    private func shiftSlots() {
        // Monotonically increasing integer that changes every slotDuration
        let currentSlotNumber: UInt64 = UInt64(Date().timeIntervalSince1970 / slotDuration)
        
        // Push slots left as much as needed
        let outdatedSlots = Int(min(currentSlotNumber - lastSlotNumber, UInt64(slots.count)))
        slots.removeFirst(outdatedSlots)
        slots.append(contentsOf: Array(repeating: 0, count: outdatedSlots))
        lastSlotNumber = currentSlotNumber
    }
    
    func add(_ value: UInt64) {
        shiftSlots()
        // Add to last slot
        slots[slots.count-1] += value
    }

    func add(_ value: Int) {
        add(UInt64(value))
    }

    var value: UInt64 {
        shiftSlots()
        return slots.reduce(0, +)
    }
}
