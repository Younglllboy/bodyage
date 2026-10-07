import SwiftUI

enum Palette {
    static let background = Color(red: 0.025, green: 0.03, blue: 0.055)
    static let card = Color(red: 0.085, green: 0.095, blue: 0.135)
    static let ink = Color(red: 0.97, green: 0.97, blue: 0.93)
    static let secondary = Color(red: 0.70, green: 0.73, blue: 0.81)
    static let mint = Color(red: 0.62, green: 0.96, blue: 0.78)
    static let amber = Color(red: 1.0, green: 0.80, blue: 0.49)
    static let lilac = Color(red: 0.76, green: 0.69, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.63, blue: 0.67)
    static let blue = Color(red: 0.53, green: 0.82, blue: 1.0)
}

struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(spacing: 12) { content }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10).padding(.bottom, 16)
        }
        .scrollIndicators(.hidden).background(Palette.background)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 9) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.055)))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(.caption2, design: .rounded, weight: .medium))
            .tracking(0.7).foregroundStyle(Palette.secondary)
    }
}

struct SmallNote: View {
    let text: String
    var body: some View {
        Text(text).font(.caption2).foregroundStyle(Palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SpringPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.65),
                       value: configuration.isPressed)
    }
}

struct MenuRow: View {
    let title: String
    let symbol: String
    var color: Color = Palette.mint
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color).frame(width: 32, height: 34)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if let detail { SmallNote(text: detail) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Palette.secondary)
                .accessibilityHidden(true)
        }
        .padding(10).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

// Decorative only; neither shape nor motion encodes a health score.
struct AgeBloom: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 54.0
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50, style: .continuous)
                .fill(LinearGradient(colors: [Palette.mint.opacity(0.22), Palette.blue.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 98).rotationEffect(.degrees(appeared ? -12 : -24))
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .stroke(LinearGradient(colors: [Palette.mint, Palette.blue.opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                .frame(width: 105, height: 96).rotationEffect(.degrees(appeared ? 12 : 0))
            Image(systemName: "sparkle").font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.amber).offset(x: 58, y: -38)
                .rotationEffect(.degrees(appeared ? 12 : -20))
            Circle().fill(Palette.lilac).frame(width: 7, height: 7).offset(x: -64, y: 23)
            Circle().fill(Palette.mint).frame(width: 4, height: 4).offset(x: 51, y: 44)
            VStack(spacing: -2) {
                Text(label).font(.system(size: numberSize, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: label)
                Text("岁").font(.caption2).foregroundStyle(Palette.secondary)
            }.frame(width: 105)
        }
        .frame(width: 148, height: 110).scaleEffect(appeared ? 1 : 0.92)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) { appeared = true }
        }
        .accessibilityHidden(true)
    }
}

extension Metric {
    var shortTitle: String {
        switch self {
        case .vo2Max: return "体能"
        case .restingHeartRate: return "心率"
        case .hrv: return "HRV"
        case .respiratoryRate: return "呼吸"
        case .sleepHours: return "睡眠"
        case .exerciseMinutes: return "运动"
        }
    }
    var symbol: String {
        switch self {
        case .vo2Max: return "sparkles"
        case .restingHeartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .respiratoryRate: return "lungs.fill"
        case .sleepHours: return "moon.stars.fill"
        case .exerciseMinutes: return "figure.walk"
        }
    }
    var accent: Color {
        switch self {
        case .vo2Max, .exerciseMinutes: return Palette.mint
        case .restingHeartRate, .hrv: return Palette.coral
        case .respiratoryRate: return Palette.blue
        case .sleepHours: return Palette.lilac
        }
    }
    func formatted(_ value: Double) -> String {
        String(format: self == .exerciseMinutes || self == .restingHeartRate || self == .hrv ? "%.0f" : "%.1f", value)
    }
}

struct Sparkline: View {
    let values: [DailyValue]
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            let sorted = values.sorted { $0.date < $1.date }
            let minimum = (sorted.map(\.value).min() ?? 0) - 0.5
            let maximum = (sorted.map(\.value).max() ?? 1) + 0.5
            let first = sorted.first?.date ?? Date()
            let last = sorted.last?.date ?? first
            let span = max(1, last.timeIntervalSince(first))
            let point: (DailyValue) -> CGPoint = { item in
                CGPoint(x: 3 + max(0, geometry.size.width - 6) * item.date.timeIntervalSince(first) / span,
                        y: 3 + max(0, geometry.size.height - 6) * (1 - (item.value - minimum) / (maximum - minimum)))
            }
            Path { path in
                for (index, item) in sorted.enumerated() {
                    let adjacent = index > 0 && Calendar.current.dateComponents([.day],
                        from: sorted[index - 1].date, to: item.date).day == 1
                    if adjacent { path.addLine(to: point(item)) }
                    else { path.move(to: point(item)) }
                }
            }.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ForEach(sorted) { item in
                Circle().fill(color).frame(width: 5, height: 5).position(point(item))
            }
        }.frame(height: 48).accessibilityHidden(true)
    }
}
