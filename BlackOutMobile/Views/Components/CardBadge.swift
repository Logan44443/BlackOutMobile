import SwiftUI

struct CardBadge: View {
    let count: Int
    var large: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "suit.spade.fill")
                .font(large ? .subheadline : .caption2)
            Text("\(count)")
                .font(large ? .title3.bold() : .caption.bold())
        }
        .foregroundColor(count > 0 ? .accentPurple : .dangerRed)
        .padding(.horizontal, large ? 14 : 10)
        .padding(.vertical, large ? 8 : 5)
        .background(
            (count > 0 ? Color.accentPurple : Color.dangerRed).opacity(0.15)
        )
        .cornerRadius(large ? 12 : 8)
    }
}
