//
//  DiceSessionManager.swift
//  ASKDemo
//
//  Created by Wasiq on 07/05/2025.
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI
import UserNotifications
import AudioToolbox

@available(iOS 18.0, *)
@Observable
class DiceSessionManager: NSObject {
    var diceColor: DiceColor?
    var diceValue = DiceValue.one
    var peripheralConnected = false
    var pickerDismissed = true

    private var currentDice: ASAccessory?
    private var session = ASAccessorySession()
    private var manager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var rollResultCharacteristic: CBCharacteristic?

    private static let diceRollCharacteristicUUID = "0xFF3F"

    private static let pinkDice: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = DiceColor.pink.serviceUUID

        return ASPickerDisplayItem(
            name: DiceColor.pink.displayName,
            productImage: UIImage(named: DiceColor.pink.diceName)!,
            descriptor: descriptor
        )
    }()

    private static let blueDice: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = DiceColor.blue.serviceUUID

        return ASPickerDisplayItem(
            name: DiceColor.blue.displayName,
            productImage: UIImage(named: DiceColor.blue.diceName)!,
            descriptor: descriptor
        )
    }()

    override init() {
        super.init()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
        self.session.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent(event:))
    }

    // MARK: - DiceSessionManager actions

    func presentPicker() async {
        do {
            try await session.showPicker(for: [Self.pinkDice, Self.blueDice])
        } catch let error {
            print("Failed to show picker due to: \(error.localizedDescription)")
        }
    }

    func removeDice() async {
        guard let currentDice else { return }

        if peripheralConnected {
            disconnect()
        }

        do {
            try await session.removeAccessory(currentDice)
            self.diceColor = nil
            self.currentDice = nil
            self.manager = nil
        } catch let error {
            print("Failed to remove accessory due to: \(error.localizedDescription)")
            return
        }
    }

    func connect() {
        guard
            let manager, manager.state == .poweredOn,
            let peripheral
        else {
            return
        }

        manager.connect(peripheral)
    }

    func disconnect() {
        guard let peripheral, let manager else { return }
        manager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - ASAccessorySession functions

    private func saveDice(dice: ASAccessory) {
        currentDice = dice

        if manager == nil {
            manager = CBCentralManager(delegate: self, queue: nil)
        }

        if dice.displayName == DiceColor.pink.displayName {
            diceColor = .pink
        } else if dice.displayName == DiceColor.blue.displayName {
            diceColor = .blue
        }
    }

    private func handleSessionEvent(event: ASAccessoryEvent) {
        switch event.eventType {
        case .accessoryAdded, .accessoryChanged:
            guard let dice = event.accessory else { return }
            saveDice(dice: dice)
        case .activated:
            guard let dice = session.accessories.first else { return }
            saveDice(dice: dice)
        case .accessoryRemoved:
            self.diceColor = nil
            self.currentDice = nil
            self.manager = nil
        case .pickerDidPresent:
            pickerDismissed = false
        case .pickerDidDismiss:
            pickerDismissed = true
        default:
            print("Received event type \(event.eventType)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

@available(iOS 18.0, *)
extension DiceSessionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central manager state: \(central.state)")
        switch central.state {
        case .poweredOn:
            if let peripheralUUID = currentDice?.bluetoothIdentifier {
                peripheral = central.retrievePeripherals(withIdentifiers: [peripheralUUID]).first
                peripheral?.delegate = self
            }
        default:
            peripheral = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral)")
        guard let diceColor else { return }
        peripheral.delegate = self
        peripheral.discoverServices([diceColor.serviceUUID])

        peripheralConnected = true
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("Disconnected from peripheral: \(peripheral)")
        peripheralConnected = false
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("Failed to connect to peripheral: \(peripheral), error: \(error.debugDescription)")
    }
}

// MARK: - CBPeripheralDelegate

@available(iOS 18.0, *)
extension DiceSessionManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard
            error == nil,
            let services = peripheral.services
        else {
            return
        }

        for service in services {
            peripheral.discoverCharacteristics([CBUUID(string: Self.diceRollCharacteristicUUID)], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard
            error == nil,
            let characteristics = service.characteristics
        else {
            return
        }

        for characteristic in characteristics where characteristic.uuid == CBUUID(string: Self.diceRollCharacteristicUUID) {
            rollResultCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard
            error == nil,
            characteristic.uuid == CBUUID(string: Self.diceRollCharacteristicUUID),
            let data = characteristic.value,
            let diceValue = String(data: data, encoding: .utf8)
        else {
            return
        }

        print("New dice value received: \(diceValue)")

        // Trigger local notification
        let content = UNMutableNotificationContent()
        content.title = "Dice Rolled"
        content.body = "New value: \(diceValue)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        // Trigger vibration
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        DispatchQueue.main.async {
            withAnimation {
                self.diceValue = DiceValue(rawValue: diceValue)!
            }
        }
    }
}
