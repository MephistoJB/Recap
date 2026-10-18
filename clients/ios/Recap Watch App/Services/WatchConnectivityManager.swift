//
//  WatchConnectivityManager.swift
//  Recap Watch App
//
//  Created by ethan on 1/27/24.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()
    private var session: WCSession?

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
        }
    }

    private func receiveConfiguration(_ context: [String: Any]) {
        guard let config = context["recapConnection"] as? [String: String],
              let address = config["address"], let token = config["token"] else { return }
        do {
            try ConnectionSettings.save(address: address, token: token)
            try session?.updateApplicationContext(["configurationSaved": true])
            sendMessage(["configurationSaved": true])
        } catch {
            try? session?.updateApplicationContext(["configurationSaved": false])
            sendMessage(["configurationSaved": false])
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveConfiguration(applicationContext)
    }

    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated { receiveConfiguration(session.receivedApplicationContext) }
    }

}
