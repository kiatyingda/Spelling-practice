import SwiftUI

/// new → learning → mastered as one segmented bar.
struct SheetProgressBar: View {
    let sheet: Sheet

    var body: some View {
        let total = max(sheet.items.count, 1)
        GeometryReader { geo in
            HStack(spacing: 0) {
                Theme.mastered.frame(width: geo.size.width * CGFloat(sheet.count(.mastered)) / CGFloat(total))
                Theme.learning.frame(width: geo.size.width * CGFloat(sheet.count(.learning)) / CGFloat(total))
                Theme.new
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.6), value: sheet.count(.mastered))
        .accessibilityElement()
        .accessibilityLabel("\(sheet.count(.mastered)) of \(sheet.items.count) mastered")
    }
}

struct SheetProgressLegend: View {
    let sheet: Sheet

    var body: some View {
        HStack(spacing: 16) {
            entry(Theme.new, "\(sheet.count(.new)) new")
            entry(Theme.learning, "\(sheet.count(.learning)) learning")
            entry(Theme.mastered, "\(sheet.count(.mastered)) mastered")
        }
        .font(.subheadline)
        .foregroundStyle(Theme.muted)
    }

    private func entry(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

struct Tag: View {
    let text: String
    var tone: Color? = nil

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(tone == nil ? Theme.ink : .white)
            .background(Capsule().fill(tone ?? Theme.line))
    }
}

/// Back / title / action header used across screens (the system nav bar is hidden for bigger targets).
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .lineLimit(1)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
    }
}

extension View {
    /// Large text field with the app's surface styling.
    func fieldStyle() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: Theme.touch)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
    }
}
