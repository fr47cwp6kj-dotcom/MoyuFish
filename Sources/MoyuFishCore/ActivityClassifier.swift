import Foundation

public enum ActivityClassifier {
    public static func classify(applicationName: String, rules: [ClassificationRule]) -> ActivityCategory {
        let normalized = applicationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rules.first {
            $0.target.kind == .application &&
            $0.target.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }?.category ?? .unclassified
    }
}
