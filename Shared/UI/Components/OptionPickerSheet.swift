//
//  OptionPickerSheet.swift
//  pantherapp
//
//  Custom-styled option picker sheet — replaces the stock .confirmationDialog
//  (plain gray system action sheet, clashes with the app's purple design) for
//  Settings' language/style/theme pickers. Real-device testing flagged the
//  native sheet as looking out of place next to the rest of the app.
//

import SwiftUI

struct OptionPickerSheet<T: Hashable>: View {
    let titleKey: LocalizedStringKey
    let options: [T]
    let label: (T) -> String
    let isSelected: (T) -> Bool
    let onSelect: (T) -> Void

    @Environment(\.pantherColors) private var colors
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.cardStroke)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Text(titleKey)
                .font(.headline)
                .foregroundStyle(colors.textPrimary)
                .padding(.bottom, 12)

            VStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                        dismiss()
                    } label: {
                        HStack {
                            Text(label(option))
                                .font(.body.weight(isSelected(option) ? .semibold : .regular))
                                .foregroundStyle(isSelected(option) ? colors.accent : colors.textPrimary)
                            Spacer()
                            if isSelected(option) {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(colors.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            isSelected(option) ? colors.accent.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(colors.surface)
        .presentationDetents([.height(96 + CGFloat(options.count) * 52)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}
