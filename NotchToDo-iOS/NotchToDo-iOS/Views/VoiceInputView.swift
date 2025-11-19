import SwiftUI
import Speech
import AVFoundation

struct VoiceInputView: View {
    @Binding var recognizedText: String
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Microphone Animation
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(isRecording ? .red : .blue)
                }

                // Status Text
                Text(isRecording ? "Listening..." : "Tap to speak")
                    .font(.title2)
                    .foregroundColor(.primary)

                // Recognized Text
                if !speechRecognizer.transcript.isEmpty {
                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                Spacer()

                // Record Button
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        speechRecognizer.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        recognizedText = speechRecognizer.transcript
                        speechRecognizer.stopRecording()
                        dismiss()
                    }
                    .disabled(speechRecognizer.transcript.isEmpty)
                }
            }
            .onAppear {
                speechRecognizer.requestPermission()
            }
            .onDisappear {
                speechRecognizer.stopRecording()
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopRecording()
            isRecording = false
        } else {
            speechRecognizer.startRecording()
            isRecording = true
        }
    }
}

// MARK: - Speech Recognizer
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isAuthorized = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = status == .authorized
                if status != .authorized {
                    DebugLog.log("Speech recognition not authorized", category: .speech)
                }
            }
        }
    }

    func startRecording() {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DebugLog.log("Audio session setup failed: \(error)", category: .speech)
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            DebugLog.log("Audio engine failed to start: \(error)", category: .speech)
            return
        }

        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}

#Preview {
    VoiceInputView(recognizedText: .constant(""))
}
