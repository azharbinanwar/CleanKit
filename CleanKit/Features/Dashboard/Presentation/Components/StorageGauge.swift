import SwiftUI

struct StorageGauge: View {
    let title: String
    let subtitle: String
    let usedFraction: Double
    let details: [(label: String, value: String)]
    var onRefresh: () -> Void
    var onAction: () -> Void

    var body: some View {
        AppCard(padding: 32, cornerRadius: 32) {
            HStack(spacing: 0) {
                // Action Column
                Button(action: onAction) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 15)
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.white)
                        }
                        Text("Optimize")
                            .font(.system(size: 11, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 100)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider().frame(height: 120).padding(.horizontal, 20)
                
                // Gauge Center
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: 4))
                    Circle()
                        .trim(from: 0, to: CGFloat(usedFraction))
                        .stroke(
                            LinearGradient(colors: [.accentColor, .accentColor.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: -5) {
                        Text("\(Int(usedFraction * 100))")
                            .font(.system(size: 64, weight: .thin, design: .rounded))
                            .tracking(-3)
                        Text("%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, height: 160)
                .padding(.horizontal, 40)
                
                // Stats Column
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 28, weight: .bold))
                        HStack(spacing: 8) {
                            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                            Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 40) {
                        ForEach(details, id: \.label) { detail in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detail.label).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase).tracking(1)
                                Text(detail.value).font(.system(size: 18, weight: .medium))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Refresh
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
