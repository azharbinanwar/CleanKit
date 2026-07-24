import SwiftUI

struct ToolCard: View {
    let toolName: String
    let subtitle: String
    let icon: String
    let color: Color
    var status: String? = nil
    var categoryCount: Int? = nil
    let onOpen: () -> Void
    var onScan: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            AppCard(isHovered: isHovered, padding: 24, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(isHovered ? color.opacity(0.1) : Color.primary.opacity(0.03))
                                .frame(width: 44, height: 44)
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(isHovered ? color : .primary.opacity(0.7))
                        }
                        Spacer()
                        
                        if let onScan = onScan, status == "Scan Now" {
                            Button(action: onScan) {
                                Text("Scan Now")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(color)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        } else if let status = status, status != "Scan Now" {
                            Text(status)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(toolName)
                            .font(.system(size: 15, weight: .bold))
                        Text(categoryCount != nil ? "\(categoryCount!) \(subtitle)" : subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
