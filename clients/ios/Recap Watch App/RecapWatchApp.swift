//
//  RecapWatchApp.swift
//  Recap Watch App
//
//  Created by ethan on 1/13/24.
//

import SwiftUI

@main
struct RecapWatchApp: App {
    init() {
        _ = WatchConnectivityManager.shared
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await runFileUploadTask(fileExtension: "pcm")
                }
        }
    }
}
