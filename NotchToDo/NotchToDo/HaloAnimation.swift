import SwiftUI

struct HaloAnimationView: View {
    let state: ListenState
    let inputRMS: Float
    let isGlowing: Bool
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Light violet dynamic glow background when button is held
            if isGlowing {
                ZStack {
                    // Outer glow layer - light violet with complex movement
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.4), .blue.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .scaleEffect(1.0 + sin(animationPhase * 0.01) * 0.6 + cos(animationPhase * 0.03) * 0.3)
                        .opacity(0.3 + sin(animationPhase * 0.02) * 0.7)
                        .rotationEffect(.degrees(sin(animationPhase * 0.005) * 15))
                    
                    // Middle glow layer - dynamic pulsing
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.6), .blue.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 10)
                        .scaleEffect(1.0 + sin(animationPhase * 0.03) * 0.8 + cos(animationPhase * 0.07) * 0.4)
                        .opacity(0.4 + sin(animationPhase * 0.04) * 0.6)
                        .rotationEffect(.degrees(cos(animationPhase * 0.008) * 20))
                    
                    // Inner glow layer - very dynamic breathing
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.8), .blue.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 6)
                        .scaleEffect(1.0 + sin(animationPhase * 0.05) * 1.0 + cos(animationPhase * 0.09) * 0.5)
                        .opacity(0.5 + sin(animationPhase * 0.06) * 0.5)
                        .rotationEffect(.degrees(sin(animationPhase * 0.012) * 25))
                    
                    // Core glow - most dynamic center
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(1.0), .blue.opacity(0.7), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 3)
                        .scaleEffect(1.0 + sin(animationPhase * 0.08) * 1.2 + cos(animationPhase * 0.11) * 0.6)
                        .opacity(0.6 + sin(animationPhase * 0.09) * 0.4)
                        .rotationEffect(.degrees(cos(animationPhase * 0.015) * 30))
                    
                    // Additional dynamic layer - orbiting effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)
                        .scaleEffect(1.0 + sin(animationPhase * 0.06) * 0.4)
                        .opacity(0.2 + sin(animationPhase * 0.08) * 0.3)
                        .offset(
                            x: sin(animationPhase * 0.02) * 20,
                            y: cos(animationPhase * 0.02) * 15
                        )
                }
                .animation(.easeInOut(duration: 0.2), value: isGlowing)
            }
            
        }
        .onAppear {
            startAnimation()
            // Start continuous animation - faster
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                animationPhase = 360
            }
        }
        .onChange(of: state) { newState in
            updateAnimation(for: newState)
        }
        .onChange(of: inputRMS) { newRMS in
            updateAnimationForRMS(newRMS)
        }
    }
    
    private var haloLineWidth: CGFloat {
        switch state {
        case .idle:
            return 2
        case .wake, .listening, .transcribing:
            return 4 + CGFloat(inputRMS * 2)
        case .error:
            return 2
        }
    }
    
    private var haloSize: CGFloat {
        let baseSize: CGFloat = 80
        switch state {
        case .idle:
            return baseSize
        case .wake, .listening, .transcribing:
            return baseSize + CGFloat(inputRMS * 20)
        case .error:
            return baseSize
        }
    }
    
    private var haloOpacity: Double {
        switch state {
        case .idle:
            return 0.3
        case .wake, .listening, .transcribing:
            return 0.8 + Double(inputRMS * 0.2)
        case .error:
            return 0.3
        }
    }
    
    private var haloScale: CGFloat {
        switch state {
        case .idle:
            return 1.0
        case .wake, .listening, .transcribing:
            return 1.0 + CGFloat(inputRMS * 0.2)
        case .error:
            return 1.0
        }
    }
    
    private func startAnimation() {
        animationPhase = 0
    }
    
    private func updateAnimation(for newState: ListenState) {
        switch newState {
        case .idle:
            animationPhase = 0
        case .wake, .listening, .transcribing:
            animationPhase = 360
        case .error:
            animationPhase = 0
        }
    }
    
    private func updateAnimationForRMS(_ rms: Float) {
        // Animation speed increases with RMS
        _ = 1.0 + Double(rms * 2)
        // TODO: Update animation speed based on RMS
    }
    
}
