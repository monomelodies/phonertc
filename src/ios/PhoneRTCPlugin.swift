import Foundation
import AVFoundation

@objc(PhoneRTCPlugin)
class PhoneRTCPlugin : CDVPlugin {
    var sessions: [String: Session]!
    var peerConnectionFactory: RTCPeerConnectionFactory!

    var videoConfig: VideoConfig?
    var videoCapturer: RTCVideoCapturer?
    var videoSource: RTCVideoSource?
    var localVideoView: RTCEAGLVideoView?
    var remoteVideoViews: [VideoTrackViewPair]!
    var camera: String?

    var localVideoTrack: RTCVideoTrack?
    var localAudioTrack: RTCAudioTrack?

    override func pluginInitialize() {
        self.sessions = [:];
        self.remoteVideoViews = [];

        peerConnectionFactory = RTCPeerConnectionFactory()
        RTCPeerConnectionFactory.initializeSSL()
    }
    
    func createSessionObject(_ command: CDVInvokedUrlCommand) {
        if let sessionKey = command.argument(at: 0) as? String {
            // create a session and initialize it.
            if let args: AnyObject = command.argument(at: 1) as AnyObject {
                let config = SessionConfig(data: args)
                let session = Session(plugin: self, peerConnectionFactory: peerConnectionFactory,
                    config: config, callbackId: command.callbackId,
                    sessionKey: sessionKey)
                sessions[sessionKey] = session
            }
        }
    }
    
    func call(_ command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argument(at: 0) as AnyObject
        if let sessionKey = args.object(forKey: "sessionKey") as? String {
            DispatchQueue.main.async {
                if let session = self.sessions[sessionKey] {
                    session.call()
                }
            }
        }
    }
    
    func receiveMessage(_ command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argument(at: 0) as AnyObject
        if let sessionKey = args.object(forKey: "sessionKey") as? String {
            if let message = args.object(forKey: "message") as? String {
                if let session = self.sessions[sessionKey] {
                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
                        session.receiveMessage(message)
                    }
                }
            }
        }
    }
    
    func renegotiate(_ command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argument(at: 0) as AnyObject
        if let sessionKey = args.object(forKey: "sessionKey") as? String {
            if let config: AnyObject = args.object(forKey: "config") {
                DispatchQueue.main.async {
                    if let session = self.sessions[sessionKey] {
                        session.config = SessionConfig(data: config)
                        session.createOrUpdateStream()
                    }
                }
            }
        }
    }
    
    func disconnect(_ command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argument(at: 0) as AnyObject
        if let sessionKey = args.object(forKey: "sessionKey") as? String {
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
                if (self.sessions[sessionKey] != nil) {
                    self.sessions[sessionKey]!.disconnect(true)
                }
            }
        }
    }

    func sendMessage(_ callbackId: String, message: Data) {
        let json = (try! JSONSerialization.jsonObject(with: message,
            options: JSONSerialization.ReadingOptions.mutableLeaves)) as! NSDictionary
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json as! [AnyHashable: Any])
        pluginResult?.setKeepCallbackAs(true);
        
        self.commandDelegate!.send(pluginResult, callbackId:callbackId)
    }
    
    func setVideoView(_ command: CDVInvokedUrlCommand) {
        let config: AnyObject = command.argument(at: 0) as AnyObject
        
        DispatchQueue.main.async {
            // create session config from the JS params
            let videoConfig = VideoConfig(data: config)
            
            // make sure that it's not junk
            if videoConfig.container.width == 0 || videoConfig.container.height == 0 {
                return
            }
            
            self.videoConfig = videoConfig

            // get cameraParams from the JS params
            self.camera = config.object(forKey: "camera") as? String
            
            // add local video view
            if self.videoConfig!.local != nil {
                if self.localVideoTrack == nil {
                    if(self.camera == "Front" || self.camera == "Back") {
                        self.initLocalVideoTrack(self.camera!)
                    }else {
                        self.initLocalVideoTrack()
                    }
                }
                
                if self.videoConfig!.local == nil {
                    // remove the local video view if it exists and
                    // the new config doesn't have the `local` property
                    if self.localVideoView != nil {
                        self.localVideoView!.isHidden = true
                        self.localVideoView!.removeFromSuperview()
                        self.localVideoView = nil
                    }
                } else {
                    let params = self.videoConfig!.local!
                    
                    // if the local video view already exists, just
                    // change its position according to the new config.
                    if self.localVideoView != nil {
                        self.localVideoView!.frame = CGRect(
                            x: CGFloat(params.x + self.videoConfig!.container.x),
                            y: CGFloat(params.y + self.videoConfig!.container.y),
                            width: CGFloat(params.width),
                            height: CGFloat(params.height)
                        )
                    } else {
                        // otherwise, create the local video view
                        self.localVideoView = self.createVideoView(params)
                        self.localVideoTrack!.add(self.localVideoView!)
                    }
                }
                
                self.refreshVideoContainer()
            }
        }
    }
    
    func hideVideoView(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            if (self.localVideoView != nil) {
                self.localVideoView!.isHidden = true;
            }    
            for remoteVideoView in self.remoteVideoViews {
                remoteVideoView.videoView.isHidden = true;
            }
        }
    }
    
    func showVideoView(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            if (self.localVideoView != nil) {
                self.localVideoView!.isHidden = false;
            }    
            for remoteVideoView in self.remoteVideoViews {
                remoteVideoView.videoView.isHidden = false;
            } 
        }
    }
    
    func createVideoView(_ params: VideoLayoutParams? = nil) -> RTCEAGLVideoView {
        var view: RTCEAGLVideoView
        
        if params != nil {
            let frame = CGRect(
                x: CGFloat(params!.x + self.videoConfig!.container.x),
                y: CGFloat(params!.y + self.videoConfig!.container.y),
                width: CGFloat(params!.width),
                height: CGFloat(params!.height)
            )
            
            view = RTCEAGLVideoView(frame: frame)
        } else {
            view = RTCEAGLVideoView()
        }
        
        view.isUserInteractionEnabled = false
        
        self.webView!.addSubview(view)
        self.webView!.bringSubview(toFront: view)
        
        return view
    }
    
    func initLocalAudioTrack() {
        localAudioTrack = peerConnectionFactory.audioTrack(withID: "ARDAMSa0")
    }
    
    func initLocalVideoTrack() {
        var cameraID: String?
        for captureDevice in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
            // TODO: Make this camera option configurable
            if (captureDevice as AnyObject).position == AVCaptureDevicePosition.front {
                cameraID = (captureDevice as AnyObject).localizedName
            }
        }
        
        self.videoCapturer = RTCVideoCapturer(deviceName: cameraID)
        self.videoSource = self.peerConnectionFactory.videoSource(
            with: self.videoCapturer,
            constraints: RTCMediaConstraints()
        )
    
        self.localVideoTrack = self.peerConnectionFactory
            .videoTrack(withID: "ARDAMSv0", source: self.videoSource)
    }
    
    func initLocalVideoTrack(_ camera: String) {
        NSLog("PhoneRTC: initLocalVideoTrack(camera: String) invoked")
        var cameraID: String?
        for captureDevice in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
            // TODO: Make this camera option configurable
            if (captureDevice as AnyObject).position == AVCaptureDevicePosition.front {
                if camera == "Front"{
                    cameraID = (captureDevice as AnyObject).localizedName
                }
            }
            if (captureDevice as AnyObject).position == AVCaptureDevicePosition.back {
                if camera == "Back"{
                    cameraID = (captureDevice as AnyObject).localizedName
                }
            }
        }
        
        self.videoCapturer = RTCVideoCapturer(deviceName: cameraID)
        self.videoSource = self.peerConnectionFactory.videoSource(
            with: self.videoCapturer,
            constraints: RTCMediaConstraints()
        )
        
        self.localVideoTrack = self.peerConnectionFactory
            .videoTrack(withID: "ARDAMSv0", source: self.videoSource)
    }
    
    func addRemoteVideoTrack(_ videoTrack: RTCVideoTrack) {
        if self.videoConfig == nil {
            return
        }
        
        // add a video view without position/size as it will get
        // resized and re-positioned in refreshVideoContainer
        let videoView = createVideoView()
        
        videoTrack.add(videoView)
        self.remoteVideoViews.append(VideoTrackViewPair(videoView: videoView, videoTrack: videoTrack))
        
        refreshVideoContainer()
        
        if self.localVideoView != nil {
            self.webView!.bringSubview(toFront: self.localVideoView!)
        }
    }
    
    func removeRemoteVideoTrack(_ videoTrack: RTCVideoTrack) {
        DispatchQueue.main.async {
            for i in 0 ..< self.remoteVideoViews.count {
                let pair = self.remoteVideoViews[i]
                if pair.videoTrack == videoTrack {
                    pair.videoView.isHidden = true
                    pair.videoView.removeFromSuperview()
                    self.remoteVideoViews.remove(at: i)
                    self.refreshVideoContainer()
                    return
                }
            }
        }
    }
    
    func refreshVideoContainer() {
        let n = self.remoteVideoViews.count
        
        if n == 0 {
            return
        }
        
        let rows = n < 9 ? 2 : 3
        let videosInRow = n == 2 ? 2 : Int(ceil(Float(n) / Float(rows)))
        
        let videoSize = Int(Float(self.videoConfig!.container.width) / Float(videosInRow))
        let actualRows = Int(ceil(Float(n) / Float(videosInRow)))
 
        var y = getCenter(actualRows,
            videoSize: videoSize,
            containerSize: self.videoConfig!.container.height)
                + self.videoConfig!.container.y
      
        var videoViewIndex = 0
        
        for row in 0 ..< rows {
            if (videoViewIndex >= n) {
                continue;
            }
            var x = getCenter(row < row - 1 || n % rows == 0 ?
                                videosInRow : n - (min(n, videoViewIndex + videosInRow) - 1),
                videoSize: videoSize,
                containerSize: self.videoConfig!.container.width)
                    + self.videoConfig!.container.x
            
            for video in 0 ..< videosInRow {
                if (videoViewIndex >= n) {
                    continue;
                }
                let pair = self.remoteVideoViews[videoViewIndex]
                videoViewIndex += 1
                pair.videoView.frame = CGRect(
                    x: CGFloat(x),
                    y: CGFloat(y),
                    width: CGFloat(videoSize),
                    height: CGFloat(videoSize)
                )

                x += Int(videoSize)
            }
            
            y += Int(videoSize)
        }
    }
    
    func getCenter(_ videoCount: Int, videoSize: Int, containerSize: Int) -> Int {
        return lroundf(Float(containerSize - videoSize * videoCount) / 2.0)
    }
    
    func onSessionDisconnect(_ sessionKey: String) {
        self.sessions.removeValue(forKey: sessionKey)
        
        if self.sessions.count == 0 {
            DispatchQueue.main.sync {
                if self.localVideoView != nil {
                    self.localVideoView!.isHidden = true
                    self.localVideoView!.removeFromSuperview()
                
                    self.localVideoView = nil
                }
            }
            
            self.localVideoTrack = nil
            self.localAudioTrack = nil
            
            self.videoSource = nil
            self.videoCapturer = nil
        }
    }
}

struct VideoTrackViewPair {
    var videoView: RTCEAGLVideoView
    var videoTrack: RTCVideoTrack
}
