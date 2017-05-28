import Foundation

class PCObserver : NSObject, RTCPeerConnectionDelegate {
    var session: Session
    
    init(session: Session) {
        self.session = session
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        addedStream stream: RTCMediaStream!) {
        print("PCO onAddStream.")
            
        DispatchQueue.main.async {
            if stream.videoTracks.count > 0 {
                self.session.addVideoTrack(stream.videoTracks[0] as! RTCVideoTrack)
            }
        }
        
        self.session.sendMessage(
            "{\"type\": \"__answered\"}".data(using: String.Encoding.utf8)!)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        removedStream stream: RTCMediaStream!) {
        print("PCO onRemoveStream.")
        /*
        dispatch_async(dispatch_get_main_queue()) {
            if stream.videoTracks.count > 0 {
                self.session.removeVideoTrack(stream.videoTracks[0] as RTCVideoTrack)
            }
        }*/
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        iceGatheringChanged newState: RTCICEGatheringState) {
        print("PCO onIceGatheringChange. \(newState)")
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        iceConnectionChanged newState: RTCICEConnectionState) {
        print("PCO onIceConnectionChange. \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        gotICECandidate candidate: RTCICECandidate!) {
        print("PCO onICECandidate.\n  Mid[\(candidate.sdpMid)] Index[\(candidate.sdpMLineIndex)] Sdp[\(candidate.sdp)]")
            
        var jsonError: NSError?

        let json: Any = [
            "type": "candidate",
            "label": candidate.sdpMLineIndex,
            "id": candidate.sdpMid,
            "candidate": candidate.sdp
        ]
            
        let data: Data?
        do {
            data = try JSONSerialization.data(withJSONObject: json,
                        options: JSONSerialization.WritingOptions())
        } catch let error as NSError {
            jsonError = error
            data = nil
        }
            
        self.session.sendMessage(data!)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        signalingStateChanged stateChanged: RTCSignalingState) {
        print("PCO onSignalingStateChange: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!,
        didOpen dataChannel: RTCDataChannel!) {
        print("PCO didOpenDataChannel.")
    }
    
    func peerConnectionOnError(_ peerConnection: RTCPeerConnection!) {
        print("PCO onError.")
    }
    
    func peerConnection(onRenegotiationNeeded peerConnection: RTCPeerConnection!) {
        print("PCO onRenegotiationNeeded.")
        // TODO: Handle this
    }
}
