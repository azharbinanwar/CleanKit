import SwiftUI

struct GroupRing: View {
    let color: Color
    let fraction: Double
    let isSpinning: Bool
    var size: CGFloat = 24
    var strokeWidth: CGFloat = 1.5

    @State private var spinDegrees: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.05), lineWidth: strokeWidth)

            if isSpinning {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(spinDegrees - 90))
                    .onAppear {
                        spinDegrees = 0
                        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                            spinDegrees = 360
                        }
                    }
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat(min(fraction, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)
            }
        }
        .frame(width: size, height: size)
    }
}
