import SwiftUI

struct ToastView: View {
    let systemImage: String
    let text: String
    let isExpanded: Bool
    var onTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(isExpanded ? nil : 1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 340, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassCard(cornerRadius: 16)
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
