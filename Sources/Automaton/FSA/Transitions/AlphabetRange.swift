import Foundation

public enum AlphabetRange {
    case epsilon
    case char(Character)
    case range(Character,Character)

    var invariant: Bool {
        switch self {
        case .epsilon: return true
        case .char(_): return true
        case let (.range(ch1,ch2)): return ch1 <= ch2
        }
    }
    var lower: Character {
        switch self {
        case .epsilon: return "𝛆"
        case let .char(ch): return ch
        case let .range(ch1,_): return ch1
        }
    }
    var upper: Character {
        switch self {
        case .epsilon: return "𝛆"
        case let .char(ch): return ch
        case let .range(_,ch2): return ch2
        }
    }
   
    enum CodingKeys: String, CodingKey {
        case epsilonKey, charKey, rangeKey
    }

    /// Given lhs rhs, overlap exists if
    ///     lhs.start <= rhs.end && lhs.end >= rhs.start
    /// Returns true iff lhs.start <= rhs.end && lhs.end >= rhs.start
    static func overlapping(lhs: AlphabetRange, rhs: AlphabetRange) -> Bool {
        switch (lhs, rhs) {
        case let (.char(lch), .char(rch)):
            return lch == rch
        case let (.range(l1,l2), .range(r1,r2)):
            return l1 <= r2 && l2 >= r1
        case let (.range(ch1,ch2), .char(ch)):
            return ch1 <= ch && ch <= ch2
        case let (.char(ch), .range(ch1,ch2)):
            return ch1 <= ch && ch <= ch2
        case (.epsilon, .epsilon):
            return true
        case (.epsilon, _):
            return false
        case (_, .epsilon):
            return false
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first
        switch key {
        case .epsilonKey:
            self = .epsilon
        case .charKey:
            let ch = try container.decode(Character.self, forKey: .charKey)
            self = .char(ch)
        case .rangeKey:
            let (lower, upper): (Character, Character) = try container.decodeValues(for: .rangeKey)
            self = .range(lower, upper)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unabled to decode enum.")
            )
        }
    }
}

extension AlphabetRange: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .epsilon:
            try container.encode(true, forKey: .epsilonKey)
        case .char(let ch):
            try container.encode(ch, forKey: .charKey)
        case .range(let lower, let upper):
            try container.encodeValues(lower, upper, for: .rangeKey)
        }
    }
}

extension AlphabetRange: CustomStringConvertible {
    public var description: String {
        switch self {
        case .epsilon: return "𝛆"
        case let (.char(ch)): return "\(ch)"
        case let (.range(ch1,ch2)): return "\(ch1) - \(ch2)"
        }
    }
}

extension AlphabetRange: Equatable {
    public static func == (lhs: AlphabetRange, rhs: AlphabetRange) -> Bool {
        switch (lhs, rhs) {
        case (.epsilon, .epsilon):
            return true
        case let (.char(lch), .char(rch)):
            return lch == rch
        case let (.range(l1,l2), .range(r1,r2)):
            return l1 == r1 && l2 == r2
        case let (.range(l1,l2), .char(r1)):
            return (l1,l2) == (r1,r1)
        case let (.char(l1), .range(r1,r2)):
            return (l1,l1) == (r1,r2)
        case (.epsilon, _):
            return false
        case (_, .epsilon):
            return false
        }
    }
}

extension AlphabetRange: Comparable {
    public static func < (lhs: AlphabetRange, rhs: AlphabetRange) -> Bool {
        switch (lhs, rhs) {
        case let (.char(lch), .char(rch)):
            return lch < rch
        case let (.range(l1,l2), .range(r1,r2)):
            return (l1,l2) < (r1,r2)
        case let (.range(ch1,ch2), .char(ch)):
            return (ch1,ch2) < (ch,ch)
        case let (.char(ch), .range(ch1,ch2)):
            return (ch,ch) < (ch1,ch2)
        case let (.epsilon, x):
            return .epsilon < x
        case let (x, .epsilon):
            return .epsilon < x
        }
    }
}

// MARK: - Helper Extension for AlphabetRange

extension AlphabetRange {
    /// Check if this range contains a specific character
    func contains(character: Character) -> Bool {
        switch self {
        case .char(let c):
            return c == character
        case .range(let start, let end):
            return character >= start && character <= end
        case .epsilon:
            return false
        }
    }
}

public enum AlphabetEpsRange {
    case epsilon
    case char(Character)
    case range(Character,Character)
    
    var invariant: Bool {
        switch self {
        case .epsilon: return true
        case .char(_): return true
        case let (.range(ch1,ch2)): return ch1 <= ch2
        }
    }
    var lower: Character {
        switch self {
        case .epsilon: fatalError()
        case let .char(ch): return ch
        case let .range(ch1,_): return ch1
        }
    }
    var upper: Character {
        switch self {
        case .epsilon: fatalError()
        case let .char(ch): return ch
        case let .range(_,ch2): return ch2
        }
    }
    
    enum CodingKeys: CodingKey {
        case epsilonKey, charKey, rangeKey
    }

    /// Given lhs rhs, overlap exists if
    ///     lhs.start <= rhs.end && lhs.end >= rhs.start
    /// Returns true iff lhs.start <= rhs.end && lhs.end >= rhs.start
    static func overlapping(lhs: AlphabetEpsRange, rhs: AlphabetEpsRange) -> Bool {
        switch (lhs, rhs) {
        case let (.char(lch), .char(rch)):
            return lch == rch
        case let (.range(l1,l2), .range(r1,r2)):
            return l1 <= r2 && l2 >= r1
        case let (.range(ch1,ch2), .char(ch)):
            return ch1 <= ch && ch <= ch2
        case let (.char(ch), .range(ch1,ch2)):
            return ch1 <= ch && ch <= ch2
        case (.epsilon, .epsilon):
            return true
        case (.epsilon, _):
            return false
        case (_, .epsilon):
            return false
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first
        switch key {
        case .epsilonKey:
            self = .epsilon
        case .charKey:
            let ch = try container.decode(Character.self, forKey: .charKey)
            self = .char(ch)
        case .rangeKey:
            let (lower, upper): (Character, Character) = try container.decodeValues(for: .rangeKey)
            self = .range(lower,upper)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unabled to decode enum.")
            )
        }
    }
}

extension AlphabetEpsRange: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .epsilon:
            try container.encode(true, forKey: .epsilonKey)
        case .char(let ch):
            try container.encode(ch, forKey: .charKey)
        case .range(let lower, let upper):
            try container.encodeValues(lower, upper, for: .rangeKey)
        }
    }
}

extension AlphabetEpsRange: Equatable {
    public static func == (lhs: AlphabetEpsRange, rhs: AlphabetEpsRange) -> Bool {
        switch (lhs, rhs) {
        case (.epsilon, .epsilon):
            return true
        case let (.char(lch), .char(rch)):
            return lch == rch
        case let (.range(l1,l2), .range(r1,r2)):
            return l1 == r1 && l2 == r2
        case let (.range(l1,l2), .char(r1)):
            return (l1,l2) == (r1,r1)
        case let (.char(l1), .range(r1,r2)):
            return (l1,l1) == (r1,r2)
        case (.epsilon, _):
            return false
        case (_, .epsilon):
            return false
        }
    }
}

extension AlphabetEpsRange: CustomStringConvertible {
    public var description: String {
         switch self {
         case .epsilon: return "𝛆"
         case let (.char(ch)): return "\(ch)"
         case let (.range(ch1,ch2)): return "\(ch1) - \(ch2)"
         }
     }
}

extension AlphabetEpsRange: Comparable {
    public static func < (lhs: AlphabetEpsRange, rhs: AlphabetEpsRange) -> Bool {
        switch (lhs, rhs) {
        case let (.char(lch), .char(rch)):
            return lch < rch
        case let (.range(l1,l2), .range(r1,r2)):
            return (l1,l2) < (r1,r2)
        case let (.range(ch1,ch2), .char(ch)):
            return (ch1,ch2) < (ch,ch)
        case let (.char(ch), .range(ch1,ch2)):
            return (ch,ch) < (ch1,ch2)
        case let (.epsilon, x):
            return .epsilon < x
        case let (x, .epsilon):
            return .epsilon < x
        }
    }
}
