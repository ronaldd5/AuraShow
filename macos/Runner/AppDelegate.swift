import Cocoa
import FlutterMacOS
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
    
    // Audio Capture Variables
    var audioEngine: AVAudioEngine?
    var audioChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        
        // 1. Setup Audio Capture Channel
        audioChannel = FlutterEventChannel(name: "com.aurashow.audio/capture", binaryMessenger: controller.engine.binaryMessenger)
        audioChannel?.setStreamHandler(self)
        
        super.applicationDidFinishLaunching(notification)
    }
}

// Extension to handle Audio Streaming
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        startAudioCapture()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        return nil
    }

    func startAudioCapture() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        // Tap the microphone and send data to Flutter
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            
            // Convert pointer to array
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
            
            // Send to Flutter (Main Thread required)
            DispatchQueue.main.async {
                self.eventSink?(samples)
            }
        }
        
        do {
            try audioEngine?.start()
        } catch {
            print("Audio Engine Error: \(error)")
        }
    }
}