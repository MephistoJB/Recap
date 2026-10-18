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
        // The native Mac receiver uses HTTP after recording, not Socket.IO.
        socketManager = nil
        socket = nil
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
