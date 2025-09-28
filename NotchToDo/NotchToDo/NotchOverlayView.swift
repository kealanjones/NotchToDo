import SwiftUI

enum ListenState: Equatable {
    case idle
    case wake
    case listening
    case transcribing
    case error(String)
}

struct NotchOverlayView: View {
    @State private var listenState: ListenState = .idle
    @State private var inputRMS: Float = 0.0
    @State private var tasks: [String] = []
    @State var isVerticallyExpanding: Bool = false
    @State private var isHaloGlowing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Halo animation around notch area
            HaloAnimationView(
                state: listenState,
                inputRMS: inputRMS,
                isGlowing: isHaloGlowing
            )
            .frame(width: 100, height: 100)
            
            // Status text
            statusText
                .font(.headline)
                .foregroundColor(.white)
            
            // Task list
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                                HStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                    Text(task)
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Test controls (remove in production)
            if case .idle = listenState {
                VStack(spacing: 10) {
                    Button("Simulate Wake Word") {
                        setState(.listening)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Simulate Transcript") {
                        setState(.transcribing)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            setState(.idle)
                            addTask("buy milk")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                        Button("Add Test Task") {
                            addTask("Test task \(tasks.count + 1)")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Hold for Glow") {
                            // This will be handled by onLongPressGesture
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
                        .onLongPressGesture(
                            minimumDuration: 0.1,
                            maximumDistance: 50,
                            perform: {
                                // Action when long press completes
                            },
                            onPressingChanged: { isPressing in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isHaloGlowing = isPressing
                                }
                            }
                        )
                        
                    
                    if !tasks.isEmpty {
                        Button("Clear Tasks") {
                            tasks.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40) // More space for notch area
        .padding(.bottom, 20)
        .frame(width: 270, height: 400)
        .background(
            VStack(spacing: 0) {
                // Top border to connect with notch
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)
                
                // Main content area with rounded bottom corners - always visible
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        isVerticallyExpanding ? 
                        LinearGradient(
                            colors: [.black, .black, .green],
                            startPoint: .top,
                            endPoint: .bottom
                        ) : 
                        LinearGradient(
                            colors: [.black, .blue.opacity(1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 260)
                    .offset(y: -1) // Overlap the top border slightly
            }
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
    }
    
    private var statusText: some View {
        switch listenState {
        case .idle:
            Text("Ready")
        case .wake:
            Text("Wake word detected...")
        case .listening:
            Text("Listening...")
        case .transcribing:
            Text("Processing...")
        case .error(let message):
            Text("Error: \(message)")
                .foregroundColor(.red)
        }
    }
    
    func setState(_ newState: ListenState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            listenState = newState
        }
    }
    
    func updateInputRMS(_ rms: Float) {
        inputRMS = rms
    }
    
    func addTask(_ task: String) {
        tasks.append(task)
    }
    
    func setVerticallyExpanding(_ expanding: Bool) {
        print("setVerticallyExpanding called with: \(expanding)")
        isVerticallyExpanding = expanding
        print("isVerticallyExpanding is now: \(isVerticallyExpanding)")
    }
    
    // Auto-trigger gradient after a delay
    func autoTriggerGradient() {
        print("Auto-triggering gradient after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            print("Auto-triggering gradient now")
            self.isVerticallyExpanding = true
        }
    }
    
}
