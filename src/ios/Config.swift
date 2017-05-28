import Foundation

class SessionConfig {
    var isInitiator: Bool
    var turn: TurnConfig
    var streams: StreamsConfig
    
    init(data: AnyObject) {
        self.isInitiator = data.object(forKey: "isInitiator") as! Bool
        
        let turnObject: Any = data.object(forKey: "turn")!
        self.turn = TurnConfig(
            host: (turnObject as AnyObject).object(forKey: "host") as! String,
            username: (turnObject as AnyObject).object(forKey: "username") as! String,
            password: (turnObject as AnyObject).object(forKey: "password") as! String
        )
        
        let streamsObject: Any = data.object(forKey: "streams")!
        self.streams = StreamsConfig(
            audio: (streamsObject as AnyObject).object(forKey: "audio") as! Bool,
            video: (streamsObject as AnyObject).object(forKey: "video") as! Bool
        )
    }
}

struct TurnConfig {
    var host: String
    var username: String
    var password: String
}

struct StreamsConfig {
    var audio: Bool
    var video: Bool
}

class VideoConfig {
    var container: VideoLayoutParams
    var local: VideoLayoutParams?
    
    init(data: AnyObject) {
        let containerParams: Any = data.object(forKey: "containerParams")!
        let localParams: Any? = data.object(forKey: "local")
        
        self.container = VideoLayoutParams(data: containerParams as AnyObject)
        
        if localParams != nil {
            self.local = VideoLayoutParams(data: localParams! as AnyObject)
        }
    }
}

class VideoLayoutParams {
    var x, y, width, height: Int
    
    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    init(data: AnyObject) {
        let position: [AnyObject] = data.object(forKey: "position")! as! [AnyObject]
        self.x = position[0] as! Int
        self.y = position[1] as! Int
        
        let size: [AnyObject] = data.object(forKey: "size")! as! [AnyObject]
        self.width = size[0] as! Int
        self.height = size[1] as! Int
    }
}
