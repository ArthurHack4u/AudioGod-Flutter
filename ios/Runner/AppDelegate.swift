import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    var engine = AVAudioEngine()
    var playerNode = AVAudioPlayerNode()
    var eqNode = AVAudioUnitEQ(numberOfBands: 5)
    var audioFile: AVAudioFile?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.tuempresa.audio_god_eq/audio", binaryMessenger: controller.binaryMessenger)
        
        setupEqualizer()
        engine.attach(playerNode); engine.attach(eqNode)
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        try? engine.start()

        channel.setMethodCallHandler({ (call, result) in
            if call.method == "playNativeIOS" {
                guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else { return }
                self.playAudio(path: path, result: result)
            } else if call.method == "updateEqIOS" {
                guard let args = call.arguments as? [String: Any], let index = args["band"] as? Int, let gain = args["gain"] as? Double else { return }
                let dbValue = Float((gain - 0.5) * 24.0)
                if index < self.eqNode.bands.count { self.eqNode.bands[index].gain = dbValue }
                result("OK")
            } else if call.method == "pauseNativeIOS" {
                if self.playerNode.isPlaying { self.playerNode.pause(); result(false) } 
                else { self.playerNode.play(); result(true) }
            } else if call.method == "getDeviceName" {
                let route = AVAudioSession.sharedInstance().currentRoute
                var output = "Speaker"
                if let port = route.outputs.first {
                    switch port.portType {
                    case .headphones, .headsetMic: output = "Wired Headphones"
                    case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP: output = port.portName
                    case .usbAudio: output = "USB DAC"
                    default: output = port.portName
                    }
                }
                result(output)
            } else if call.method == "activarEQ" { result("OK") } 
            else { result(FlutterMethodNotImplemented) }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func setupEqualizer() {
        let freqs: [Float] = [60, 250, 1000, 4000, 16000]
        for i in 0..<5 {
            eqNode.bands[i].filterType = .parametric
            eqNode.bands[i].frequency = freqs[i]
            eqNode.bands[i].bandwidth = 1.0
            eqNode.bands[i].gain = 0
            eqNode.bands[i].bypass = false
        }
    }
    
    func playAudio(path: String, result: FlutterResult) {
        let url = URL(fileURLWithPath: path)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioFile = try AVAudioFile(forReading: url)
            playerNode.stop()
            playerNode.scheduleFile(audioFile!, at: nil, completionHandler: nil)
            playerNode.play()
            result("PLAYING")
        } catch { result(FlutterError(code: "ERR", message: error.localizedDescription, details: nil)) }
    }
}