import Foundation

public struct WordRemapping: Codable, Equatable, Identifiable, Sendable {
	public var id: UUID
	public var isEnabled: Bool
	public var match: String
	public var replacement: String

	public init(
		id: UUID = UUID(),
		isEnabled: Bool = true,
		match: String,
		replacement: String
	) {
		self.id = id
		self.isEnabled = isEnabled
		self.match = match
		self.replacement = replacement
	}
}

private struct CompiledRemapping: Sendable {
	let regex: NSRegularExpression
	let template: String
}

public enum WordRemappingApplier {
	private static let lock = NSLock()
	private nonisolated(unsafe) static var cachedRules: [WordRemapping]?
	private nonisolated(unsafe) static var cachedCompiled: [CompiledRemapping] = []

	public static func apply(_ text: String, remappings: [WordRemapping]) -> String {
		guard !remappings.isEmpty else { return text }
		let compiled = compiledRules(for: remappings)
		guard !compiled.isEmpty else { return text }
		var output = text
		for rule in compiled {
			let range = NSRange(output.startIndex..., in: output)
			output = rule.regex.stringByReplacingMatches(in: output, range: range, withTemplate: rule.template)
		}
		return output
	}

	/// Precompiled regexes for the current rules list; recompiled when settings change.
	private static func compiledRules(for remappings: [WordRemapping]) -> [CompiledRemapping] {
		lock.withLock {
			if let cachedRules, cachedRules == remappings { return cachedCompiled }
			let compiled: [CompiledRemapping] = remappings.compactMap { remapping in
				guard remapping.isEnabled else { return nil }
				let trimmed = remapping.match.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty else { return nil }
				let escaped = NSRegularExpression.escapedPattern(for: trimmed)
				guard let regex = try? NSRegularExpression(
					pattern: "(?<!\\w)\(escaped)(?!\\w)",
					options: [.caseInsensitive]
				) else { return nil }
				let replacement = processEscapeSequences(remapping.replacement)
				return CompiledRemapping(regex: regex, template: NSRegularExpression.escapedTemplate(for: replacement))
			}
			cachedRules = remappings
			cachedCompiled = compiled
			return compiled
		}
	}

	/// Processes escape sequences in a string: `\n` → newline, `\t` → tab, `\\` → backslash
	private static func processEscapeSequences(_ string: String) -> String {
		let placeholder = "\u{0000}"
		return string
			.replacingOccurrences(of: "\\\\", with: placeholder)
			.replacingOccurrences(of: "\\n", with: "\n")
			.replacingOccurrences(of: "\\t", with: "\t")
			.replacingOccurrences(of: "\\r", with: "\r")
			.replacingOccurrences(of: placeholder, with: "\\")
	}
}
