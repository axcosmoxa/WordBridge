import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isSingleWord: Bool { !contains(" ") && !contains(".") && count > 0 }
}
