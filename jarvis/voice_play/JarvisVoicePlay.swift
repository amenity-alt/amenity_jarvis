// JarvisVoicePlay.swift — 变调播放 TTS 音频（AVAudioUnitTimePitch），让 Jarvis 声音更低沉
// 用法: JarvisVoicePlay <audio-file> <cents>

import AVFoundation

let args = CommandLine.arguments
guard args.count >= 3, let cents = Float(args[2]) else {
    FileHandle.standardError.write("用法: JarvisVoicePlay <file> <cents>\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: args[1])
guard FileManager.default.fileExists(atPath: args[1]) else {
    exit(2)
}
do {
    let file = try AVAudioFile(forReading: url)
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let pitch = AVAudioUnitTimePitch()
    pitch.pitch = cents
    pitch.rate = 1.0
    engine.attach(player)
    engine.attach(pitch)
    engine.connect(player, to: pitch, format: nil)
    engine.connect(pitch, to: engine.mainMixerNode, format: nil)
    engine.mainMixerNode.outputVolume = 1.0
    try engine.start()
    player.scheduleFile(file, at: nil)
    player.play()
    Thread.sleep(forTimeInterval: duration + 0.6)
    player.stop()
    engine.stop()
} catch {
    FileHandle.standardError.write("ERROR: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(3)
}
exit(0)
