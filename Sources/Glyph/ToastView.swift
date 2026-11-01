import SwiftUI

struct ToastView: View {
    let systemImage: String
    let text: String
    let isExpanded: Bool
    var onTap: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.top, 1)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(isExpanded ? 8 : 1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 340, alignment: .leading)
            .glassCard(cornerRadius: 16)
            .padding(.top, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
