/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Defines dice color options.
*/

import CoreBluetooth
import SwiftUI

enum DiceColor: String {
    case blue, pink

    var color: Color {
        switch self {
            case .pink: .pink
            case .blue: .cyan
        }
    }

    var displayName: String {
        "\(self.rawValue.capitalized) Dice"
    }

    var diceName: String {
        "\(self.rawValue)"
    }

    var serviceUUID: CBUUID {
        switch self {
            case .pink: CBUUID(string: "12345678-1234-5678-1234-567812345678")
            case .blue: CBUUID(string: "87654321-4321-6789-4321-678987654321")
        }
    }
}
