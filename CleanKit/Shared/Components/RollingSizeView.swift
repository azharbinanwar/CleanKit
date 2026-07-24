import SwiftUI

struct RollingSizeView: View {
    let value: Int64
    var body: some View {
        Text(value.formattedSize)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}
