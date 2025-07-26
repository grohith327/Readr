//
//  readrApp.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/22/25.
//

import SwiftUI

@main
struct ReadrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
