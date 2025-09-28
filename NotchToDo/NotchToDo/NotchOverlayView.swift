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
    @State private var isHaloGlowing: Bool = false
    
    @ObservedObject var controller: NotchOverlayController
    
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
                VStack {
                    statusText
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Debug indicator
                    Text("Gradient: \(controller.isVerticallyExpanding ? "ON" : "OFF")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            
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
            VStack(spacing: 10) {
                if case .idle = listenState {
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
                        
                        Button(controller.isVerticallyExpanding ? "Turn Off Gradient" : "Test Gradient") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                controller.isVerticallyExpanding.toggle()
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(controller.isVerticallyExpanding ? .red : .orange)
                        
                    
                    if !tasks.isEmpty {
                        Button("Clear Tasks") {
                            tasks.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                
                // Always show reset button
                Button("Reset to Idle") {
                    setState(.idle)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
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
                            controller.isVerticallyExpanding ? 
                            LinearGradient(
                                colors: [.black, .blue],
                                startPoint: UnitPoint(x: 0.5, y: 0.3),
                                endPoint: .bottom
                            ) : 
                            LinearGradient(
                                colors: [.black, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .onAppear {
                            print("RoundedRectangle appeared, isVerticallyExpanding: \(controller.isVerticallyExpanding)")
                        }
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
    
    
    // Auto-trigger gradient after a delay
    func autoTriggerGradient() {
        print("Auto-triggering gradient after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            print("Auto-triggering gradient now")
            self.controller.isVerticallyExpanding = true
        }
    }
    
}
