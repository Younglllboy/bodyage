import Foundation

/// Display-only difference uses the same rounded age as the large number.
/// Censored endpoints have no exact difference and are not treated as point estimates.
public struct AgePresentation: Equatable, Sendable {
    public let ageLabel: String
    public let difference: Int?
    public var differenceLabel: String {
        guard let difference else { return "已到参考边界" }
        return "\(difference > 0 ? "+" : "")\(difference) 岁"
    }
    public init(position: AgePosition, chronologicalAge: Int) {
        ageLabel = position.label
        difference = position.boundary == .within ? Int(position.years.rounded()) - chronologicalAge : nil
    }
}
