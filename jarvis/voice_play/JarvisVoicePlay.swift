// JarvisVoicePlay.swift — 科幻感语音处理链：轻微降调 + 宇宙干扰失真 + 空间混响
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

    // 轻微降调 + 略慢，更有 AI 感
    let pitch = AVAudioUnitTimePitch()
    pitch.pitch = cents
    pitch.rate = 0.95

    // 宇宙干扰失真（科技感核心）
    let distortion = AVAudioUnitDistortion()
    distortion.loadFactoryPreset(.speechCosmicInterference)
    distortion.wetDryMix = 18

    // 空间混响
    let reverb = AVAudioUnitReverb()
    reverb.loadFactoryPreset(.mediumHall)
    reverb.wetDryMix = 30

    engine.attach(player)
    engine.attach(pitch)
    engine.attach(distortion)
    engine.attach(reverb)
    engine.connect(player, to: pitch, format: nil)
    engine.connect(pitch, to: distortion, format: nil)
    engine.connect(distortion, to: reverb, format: nil)
    engine.connect(reverb, to: engine.mainMixerNode, format: nil)
    engine.mainMixerNode.outputVolume = 1.0
    try engine.start()
    player.scheduleFile(file, at: nil)
    player.play()
    Thread.sleep(forTimeInterval: duration + 0.8)
    player.stop()
    engine.stop()
} catch {
    FileHandle.standardError.write("ERROR: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(3)
}
exit(0)
