import Foundation

enum MaturityRating: Int, Comparable, Codable, Sendable {

    case general = 0

    case teen = 1

    case mature = 2

    case adult = 3

    case unknown = 4
    case age12 = 5
    case age14 = 6
    case age16 = 7
    case age17 = 8

    private var comparisonAge: Int {
        switch self {
        case .general: return 0
        case .age12: return 12
        case .teen: return 13
        case .age14: return 14
        case .mature: return 15
        case .age16: return 16
        case .age17: return 17
        case .adult: return 18
        case .unknown: return Int.max
        }
    }

    static func < (lhs: MaturityRating, rhs: MaturityRating) -> Bool {
        lhs.comparisonAge < rhs.comparisonAge
    }

    var isBlockedForKids: Bool {
        self == .mature || self == .age16 || self == .age17 || self == .adult || self == .unknown
    }

    var ageBand: String {
        switch self {
        case .general: return "All ages"
        case .age12: return "12+"
        case .teen: return "13+"
        case .age14: return "14+"
        case .mature: return "15+"
        case .age16: return "16+"
        case .age17: return "17+"
        case .adult: return "18+"
        case .unknown: return "Not rated"
        }
    }

    static func strictest(_ lhs: MaturityRating, _ rhs: MaturityRating) -> MaturityRating {
        if lhs == .unknown { return rhs }
        if rhs == .unknown { return lhs }
        return lhs > rhs ? lhs : rhs
    }

    static func classify(certification: String, region: String? = nil) -> MaturityRating {
        let normalized = certification.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .unknown }

        let compact = normalized
            .replacingOccurrences(of: "+", with: "PLUS")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        guard !compact.isEmpty else { return .unknown }

        let normalizedRegion = region?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let normalizedRegion, let regional = regionalRatings[normalizedRegion]?[compact] {
            return regional
        }

        if let exact = exactRatings[compact] {
            return exact
        }

        if normalized.contains("18禁") || normalized.contains("限制級")
            || normalized.contains("成人") || normalized.contains("청소년관람불가") {
            return .adult
        }
        if normalized.contains("輔導級") || normalized.contains("보호자") {
            return .mature
        }
        if normalized.contains("普遍級") || normalized.contains("전체관람가") {
            return .general
        }

        if compact.hasPrefix("R18") || compact.hasPrefix("R21") || compact.hasPrefix("NC17")
            || compact.hasPrefix("X18") || compact.hasPrefix("AO") || compact.hasPrefix("RX") {
            return .adult
        }
        if compact.hasPrefix("MA") || compact.hasPrefix("R15") || compact.hasPrefix("R16")
            || compact.hasPrefix("R17") || compact.hasPrefix("TVMA") {
            return .mature
        }
        if compact.hasPrefix("TV14") || compact.hasPrefix("PG13") || compact.hasPrefix("R13") {
            return .teen
        }
        if compact.hasPrefix("TVY") || compact.hasPrefix("TVG") {
            return .general
        }

        if compact.hasPrefix("PG") {
            if let age = leadingAge(in: String(compact.dropFirst(2))) {
                return tier(forMinimumAge: age)
            }
            return .general
        }

        if let age = leadingAge(in: compact) {
            return tier(forMinimumAge: age)
        }

        return .unknown
    }

    private static func tier(forMinimumAge age: Int) -> MaturityRating {
        switch age {
        case ..<12: return .general
        case 12: return .age12
        case 13: return .teen
        case 14: return .age14
        case 15: return .mature
        case 16: return .age16
        case 17: return .age17
        default: return .adult
        }
    }

    static func classify(certifications: [String], region: String? = nil) -> MaturityRating {
        certifications.reduce(MaturityRating.unknown) { result, value in
            strictest(result, classify(certification: value, region: region))
        }
    }

    static let europeanRegionCodes: Set<String> = [
        "AT", "BE", "BG", "CH", "CY", "CZ", "DE", "DK", "EE", "ES",
        "FI", "FR", "GB", "GR", "HR", "HU", "IE", "IS", "IT", "LI",
        "LT", "LU", "LV", "MT", "NL", "NO", "PL", "PT", "RO", "SE",
        "SI", "SK"
    ]

    static var preferredEuropeanRegions: [String] {
        var regions: [String] = []
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            if let region = Locale.current.region?.identifier,
               europeanRegionCodes.contains(region) {
                regions.append(region)
            }
        } else if let region = Locale.current.regionCode,
                  europeanRegionCodes.contains(region) {
            regions.append(region)
        }
        for region in ["BG", "GB", "DE", "FR", "ES", "IT", "NL", "SE", "NO", "DK", "FI", "PL", "IE", "PT", "AT", "BE", "CH", "CZ", "GR", "RO", "HU"] where !regions.contains(region) {
            regions.append(region)
        }
        return regions
    }

    static func preferredEuropeanCertification(
        certificationsByRegion: [String: [String]]
    ) -> Certification? {
        let european = certificationsByRegion.filter {
            europeanRegionCodes.contains($0.key.uppercased())
        }
        guard !european.isEmpty else { return nil }
        return preferredCertification(
            certificationsByRegion: european,
            regions: preferredEuropeanRegions
        )
    }

    static var preferredRegions: [String] {
        var regions: [String] = []
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            if let region = Locale.current.region?.identifier { regions.append(region) }
        } else if let region = Locale.current.regionCode {
            regions.append(region)
        }
        for fallback in ["US", "GB"] where !regions.contains(fallback) {
            regions.append(fallback)
        }
        return regions
    }

    struct Certification: Equatable {
        let value: String
        let region: String
        let rating: MaturityRating

        var ageBand: String { rating.ageBand }

        var displayValue: String {
            "\(value) · \(region) · \(ageBand)"
        }
    }

    static func preferredCertification(
        certificationsByRegion: [String: [String]],
        regions: [String] = preferredRegions
    ) -> Certification? {
        let candidates = certificationsByRegion.flatMap { region, values in
            values.compactMap { value -> Certification? in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return Certification(
                    value: trimmed,
                    region: region.uppercased(),
                    rating: classify(certification: trimmed, region: region)
                )
            }
        }.sorted { lhs, rhs in
            if lhs.rating != rhs.rating {
                if lhs.rating == .unknown { return false }
                if rhs.rating == .unknown { return true }
                return lhs.rating > rhs.rating
            }
            if lhs.region != rhs.region { return lhs.region < rhs.region }
            return lhs.value < rhs.value
        }

        for region in regions.map({ $0.uppercased() }) {
            if let candidate = candidates.first(where: { $0.region == region && $0.rating != .unknown }) {
                return candidate
            }
        }
        if let candidate = candidates.first(where: { $0.rating != .unknown }) {
            return candidate
        }
        for region in regions.map({ $0.uppercased() }) {
            if let candidate = candidates.first(where: { $0.region == region }) {
                return candidate
            }
        }
        return candidates.first
    }

    static func classify(certificationsByRegion: [String: [String]]) -> MaturityRating {
        preferredCertification(certificationsByRegion: certificationsByRegion)?.rating ?? .unknown
    }

    private static func leadingAge(in compact: String) -> Int? {
        let digits = compact.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 2, let value = Int(digits) else { return nil }
        return value
    }

    private static let regionalRatings: [String: [String: MaturityRating]] = [
        // India: CBFC certificates are not interchangeable with US/UK labels.
        "IN": [
            "U": .general, "UA": .age12, "UA7PLUS": .general,
            "UA13PLUS": .teen, "UA16PLUS": .age16, "A": .adult, "S": .adult
        ],
        // Canada: provincial boards use 14A/18A; A is adult-only.
        "CA": [
            "G": .general, "PG": .general, "14A": .age14,
            "18A": .adult, "R": .adult, "A": .adult
        ],
        "GB": [
            "U": .general, "PG": .general, "12A": .age12,
            "12": .age12, "15": .mature, "18": .adult, "R18": .adult
        ],
        // Bulgaria: A/B/C/D/X are national age-category labels.
        "BG": [
            "A": .general, "B": .age12, "C": .age16, "D": .adult, "X": .adult
        ],
        "ES": [
            "APTA": .general, "7": .general, "12": .age12,
            "16": .age16, "18": .adult, "X": .adult
        ],
        "JP": [
            "G": .general, "PG12": .age12, "R15PLUS": .mature, "R18PLUS": .adult
        ],
        "KR": [
            "ALL": .general, "12": .age12, "15": .mature, "19": .adult
        ],
        "AU": [
            "G": .general, "PG": .general, "M": .mature,
            "MA15": .mature, "MA15PLUS": .mature, "R18PLUS": .adult, "X18PLUS": .adult
        ],
        "DE": [
            "0": .general, "6": .general, "12": .age12, "16": .age16, "18": .adult
        ],
        "FR": [
            "U": .general, "10": .general, "12": .age12, "16": .age16, "18": .adult
        ],
        "IT": [
            "T": .general, "VM14": .age14, "VM18": .adult
        ],
        "NL": [
            "AL": .general, "6": .general, "9": .general,
            "12": .age12, "14": .age14, "16": .age16, "18": .adult
        ],
        "BR": [
            "L": .general, "10": .general, "12": .age12,
            "14": .age14, "16": .age16, "18": .adult
        ],
        "SG": [
            "G": .general, "PG": .general, "PG13": .teen,
            "NC16": .age16, "M18": .adult, "R21": .adult
        ]
    ]

    private static let exactRatings: [String: MaturityRating] = [

        "G": .general, "TVY": .general, "TVY7": .general, "TVY7FV": .general,
        "TVG": .general, "PG": .general, "TVPG": .general,
        "PG13": .teen, "TV14": .age14,
        "R": .age17, "TVMA": .age17,
        "NC17": .adult, "X": .adult, "XXX": .adult, "AO": .adult,
        "ADULT": .adult, "ADULTONLY": .adult, "UNRATED": .unknown, "NR": .unknown,

        "U": .general, "UC": .general,
        "12": .age12, "12A": .age12, "13": .teen, "14": .age14,
        "15": .mature, "16": .age16, "17": .age17,
        "18": .adult, "R18": .adult,

        "E": .general, "M": .mature, "MA15": .mature, "MA15PLUS": .mature,
        "R13": .teen, "R15": .mature, "R16": .age16,
        "R18PLUS": .adult, "X18PLUS": .adult, "RC": .adult,

        "PG12": .age12, "R15PLUS": .mature,
        "T": .teen, "TPLUS": .mature, "A": .general,
        "R17": .age17, "RPLUS": .age17, "RX": .adult,

        "ALL": .general, "19": .adult,

        "L": .general, "10": .general, "14": .age14, "16": .age16,

        "PG13SG": .teen, "NC16": .age16, "M18": .adult, "R21": .adult,

        "0": .general, "6": .general, "7": .general, "9": .general,
        "AL": .general, "TP": .general
    ]

    static let matureTextMarkers: Set<String> = [
        "adult", "adults only", "aged up", "boys love", "doujinshi", "ecchi",
        "erotic", "erotica", "explicit", "gore", "hentai", "incest",
        "josei", "lolicon", "mature", "nsfw", "nudity", "pornographic",
        "pornography", "prostitution", "r 18", "r18", "rape", "seinen",
        "sexual content", "sexually explicit", "shotacon", "smut",
        "softcore", "yaoi", "yuri", "18 plus"
    ]

    static func containsMatureText(_ text: String) -> Bool {
        let normalized = " " + text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + " "
        return matureTextMarkers.contains { normalized.contains(" \($0) ") }
    }
}
