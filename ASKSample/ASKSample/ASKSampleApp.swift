/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Launches the main app view for ASKSample.
*/

import SwiftUI

@main
struct ASKSampleApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 18.0, *) {
                ContentView()
            } else {
                // Fallback on earlier versions
            }
        }
    }
}
