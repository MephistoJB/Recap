//
//  WatchConnectivityManager.swift
//  Recap
//
//  Created by ethan on 1/27/24.
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchConnectivityManager()
    private var session: WCSession?
    @Published var configurationStatus = "Noch nicht an Watch gesendet"

    func sendConnectionSettings() throws {
        guard ConnectionSettings.isConfigured else { throw ConnectionSettings.SettingsError.invalid }
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            throw NSError(domain: "Recap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Watch noch nicht bereit. Recap auf der gekoppelten Watch öffnen und erneut versuchen."])
        }
        try session.updateApplicationContext(["recapConnection": ["address": ConnectionSettings.address, "token": ConnectionSettings.token]])
        configurationStatus = "Zur Übertragung vorgemerkt · Bestätigung der Watch steht aus"
    }


    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        if let validSession = session, validSession.isReachable {
            validSession.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
        } else {
            errorHandler?(NSError(domain: "com.owl.Owl", code: -1, userInfo: [NSLocalizedDescriptionKey: "WatchConnectivity session not reachable"]))
        }
    }

    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let confirmed = message["configurationSaved"] as? Bool {
            DispatchQueue.main.async { self.configurationStatus = confirmed ? "Auf der Watch gespeichert" : "Watch konnte die Verbindung nicht speichern" }
        }
        if let event = message["event"] as? String {
            if event == "startedStreaming", let captureUUID = message["captureUUID"] as? String {
                DispatchQueue.main.async {
                    CaptureManager.shared.currentCapture = Capture(deviceName: "apple_watch", captureUUID: captureUUID)
                }
            } else if event == "stoppedStreaming" {
                DispatchQueue.main.async {
                    CaptureManager.shared.currentCapture = nil
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let saved = applicationContext["configurationSaved"] as? Bool {
            DispatchQueue.main.async { self.configurationStatus = saved ? "Auf der Watch gespeichert" : "Watch konnte die Verbindung nicht speichern" }
        }
    }
    
}
