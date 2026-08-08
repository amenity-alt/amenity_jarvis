// Jarvis 语音输入：基于 macOS Speech 框架，输出识别文本到 stdout。
// 用法: SpeechInput [-t 秒数] [--wake]

import AVFoundation
import Foundation
import Speech

nonisolated(unsafe) var finished = false

var timeout = 6.0
var wakeMode = false
let args = CommandLine.arguments
if args.contains("--wake") {
    wakeMode = true
    timeout = 30.0
}
if let idx = args.firstIndex(of: "-t"), idx + 1 < args.count {
    timeout = Double(args[idx + 1]) ?? timeout
}

// 1. 申请语音识别权限
let authSem = DispatchSemaphore(value: 0)
nonisolated(unsafe) var authorized = false
SFSpeechRecognizer.requestAuthorization { status in
    authorized = (status == .authorized)
    authSem.signal()
}
authSem.wait()
guard authorized else {
    FileHandle.standardError.write("ERROR: 语音识别未授权\n".data(using: .utf8)!)
    exit(4)
}

// 2. 中文识别器
guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
      recognizer.isAvailable else {
    FileHandle.standardError.write("ERROR: 语音识别不可用\n".data(using: .utf8)!)
    exit(1)
}

let audioEngine = AVAudioEngine()
let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = wakeMode
if wakeMode {
    request.contextualStrings = ["Hey Jarvis", "嘿 贾维斯", "你好贾维斯", "贾维斯"]
}

// 3. 识别结果
let task = recognizer.recognitionTask(with: request) { result, error in
    if let result = result {
        let text = result.bestTranscription.formattedString
        FileHandle.standardOutput.write((text + "\n").data(using: .utf8)!)
        if wakeMode {
            return
        }
        finished = true
        audioEngine.stop()
        exit(0)
    }
    if let error = error {
        FileHandle.standardError.write(("ERROR: \(error.localizedDescription)\n").data(using: .utf8)!)
        finished = true
        audioEngine.stop()
        exit(2)
    }
}

// 4. 开始录音
let inputNode = audioEngine.inputNode
let format = inputNode.outputFormat(forBus: 0)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
    request.append(buffer)
}
do {
    audioEngine.prepare()
    try audioEngine.start()
} catch {
    FileHandle.standardError.write(("ERROR: 无法启动麦克风 \(error)\n").data(using: .utf8)!)
    exit(3)
}

// 5. 超时自动结束
DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
    if !finished {
        audioEngine.stop()
        request.endAudio()
        if wakeMode {
            exit(0)
        }
    }
}
RunLoop.main.run()
