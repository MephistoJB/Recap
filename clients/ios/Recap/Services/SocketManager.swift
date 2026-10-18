//
//  SocketManager.swift
//  Recap
//
//  Created by ethan on 1/15/24.
//

import Foundation
import SocketIO

class SocketManager: ObservableObject {
    static let shared = SocketManager() // Singleton instance

    let socket: SocketIOClient?
    
    private let socketManager: SocketIO.SocketManager?
   
    private init() {
        guard let url = URL(string: AppConstants.apiBaseURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            socketManager = nil
            socket = nil
            return
        }

        let manager = SocketIO.SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(1),
            .reconnectWaitMax(5),
            .extraHeaders(["Authorization": "Bearer \(AppConstants.clientToken)"])
        ])
        socketManager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        socket.on(clientEvent: .connect) { data, ack in
            print("socket connected")
        }

        connect()
    }

    func connect() {
        guard let socket, !socket.status.active else { return }
        socket.connect()
    }

    func sendAudioData(_ data: Data, capture: Capture) {
        socket?.emit("audio_data", data, capture.deviceName, capture.captureUUID)
    }
    
    func finishAudio(capture: Capture) {
        socket?.emit("finish_audio", capture.captureUUID)
    }
    
}
