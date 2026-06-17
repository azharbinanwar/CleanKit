import SwiftUI

struct StorageInfo {
    let total: Int64
    let free: Int64
    var used: Int64 { total - free }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func load() -> StorageInfo {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total = (attrs?[.systemSize] as? Int64) ?? 0
        let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
        return StorageInfo(total: total, free: free)
    }
}

struct StorageBarView: View {
    let info: StorageInfo

    var barColor: Color {
        info.usedFraction > 0.9 ? .red : info.usedFraction > 0.75 ? .orange : .accentColor
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * info.usedFraction)
                        .animation(.easeInOut(duration: 0.6), value: info.usedFraction)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(info.used.formattedSize) used")
                    .foregroundColor(.primary)
                Spacer()
                Text("\(info.free.formattedSize) free")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(info.total.formattedSize) total")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
