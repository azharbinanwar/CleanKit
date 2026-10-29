import SwiftUI

struct AppBanner: View {
    let icon: String
    let message: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            if let actionTitle, let action {
                AppButton(title: actionTitle, style: .glass) { action() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }
}
