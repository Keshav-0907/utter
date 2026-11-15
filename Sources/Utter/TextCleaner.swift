import Foundation

/// Tier-1 cleanup: fast deterministic rules. An LLM tier can be layered on later.
enum TextCleaner {
    private static let word = #"(?<![\w'])(?:um+|uh+|uhm+|erm+|hmm+|mhm)(?![\w'])"#
    /// A filler that is a whole sentence: "It works. Um. Next" -> "It works. Next"
    private static let fillerSentence = try! NSRegularExpression(pattern: "(?i)(^|(?<=[.!?])\\s+)\(word)[.!?]\\s*")
    /// "said that, um." or "said that um." -> "said that."
    private static let fillerBeforeStop = try! NSRegularExpression(pattern: "(?i),?\\s*\(word)\\s*(?=[.!?])")
    /// "check, uh, whether" -> "check whether"
    private static let fillerInCommas = try! NSRegularExpression(pattern: "(?i),\\s*\(word),\\s*")
    private static let filler = try! NSRegularExpression(pattern: "(?i)\(word),?\\s*")
    private static let spaces = try! NSRegularExpression(pattern: #"[ \t]{2,}"#)
    private static let spaceBeforePunctuation = try! NSRegularExpression(pattern: #"\s+([,.!?;:])"#)
    private static let sentenceStart = try! NSRegularExpression(pattern: #"(?<=[.!?])\s+\p{Ll}"#)

    static func clean(_ raw: String, removeFillers: Bool) -> String {
        var text = raw
        if removeFillers {
            text = replace(fillerSentence, in: text, with: "$1")
            text = replace(fillerBeforeStop, in: text, with: "")
            text = replace(fillerInCommas, in: text, with: " ")
            text = replace(filler, in: text, with: "")
        }
        text = replace(spaceBeforePunctuation, in: text, with: "$1")
        text = replace(spaces, in: text, with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A removed leading filler can leave stray punctuation or a lowercase start.
        while let first = text.first, ",.;:".contains(first) {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }
        // Removing a filler that opened a sentence leaves the next word lowercase.
        if removeFillers {
            let matches = sentenceStart.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: text) else { continue }
                text.replaceSubrange(range, with: text[range].uppercased())
            }
        }
        return text
    }

    private static func replace(_ regex: NSRegularExpression, in text: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}
