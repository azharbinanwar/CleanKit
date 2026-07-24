import SwiftUI

struct AppLoading: View {
    var size: CGFloat = 16
    var strokeWidth: CGFloat = 2
    var color: Color = .accentColor
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}
