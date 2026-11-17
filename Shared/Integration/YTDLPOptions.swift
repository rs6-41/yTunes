import Foundation

nonisolated enum YTDLPOptions {
    enum ParseError: LocalizedError {
        case unclosedQuote
        case trailingEscape

        var errorDescription: String? {
            switch self {
            case .unclosedQuote:
                String(localized: "オプションの引用符が閉じられていません。")
            case .trailingEscape:
                String(localized: "オプションの末尾に単独のバックスラッシュがあります。")
            }
        }
    }

    static func parse(_ text: String) throws -> [String] {
        var arguments: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false
        var started = false

        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                started = true
            } else if character == "\\", quote != "'" {
                escaped = true
                started = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
                started = true
            } else if character.isWhitespace {
                if started {
                    arguments.append(current)
                    current = ""
                    started = false
                }
            } else {
                current.append(character)
                started = true
            }
        }

        guard !escaped else { throw ParseError.trailingEscape }
        guard quote == nil else { throw ParseError.unclosedQuote }
        if started { arguments.append(current) }
        return arguments
    }
}
