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
    case age6 = 9
    case age7 = 10
    case age8 = 11
    case age9 = 12
    case age10 = 13
    case age11 = 14

    private var comparisonAge: Int {
        switch self {
        case .general: return 0
        case .age6: return 6
        case .age7: return 7
        case .age8: return 8
        case .age9: return 9
        case .age10: return 10
        case .age11: return 11
        case .age12: return 12
        case .teen: return 13
        case .age14: return 14
        case .mature: return 15
        case .age16: return 16
        case .age17: return 17
        case .adult: return 18
        case .unknown: return -1
        }
    }

    static func < (lhs: MaturityRating, rhs: MaturityRating) -> Bool {
        lhs.comparisonAge < rhs.comparisonAge
    }

    var isBlockedForKids: Bool {
        // The configured under-13 boundary applies to every regional age
        // band, not only the US/UK enum cases. Unknown ratings fail closed.
        self < .teen || self == .adult || self == .unknown
    }

    var ageBand: String {
        switch self {
        case .general: return "All ages"
        case .age6: return "6+"
        case .age7: return "7+"
        case .age8: return "8+"
        case .age9: return "9+"
        case .age10: return "10+"
        case .age11: return "11+"
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

    /// Distinguish an explicit all-ages board result from parental-guidance
    /// tiers such as PG, TV-PG, and TV-Y7. Those ratings are below the app's
    /// teen threshold, but they are not equivalent to a G / All Ages label.
    static func isExplicitAllAgesCertification(
        certification: String,
        region: String? = nil
    ) -> Bool {
        let compact = certification.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "+", with: "PLUS")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        guard !["PG", "TVPG", "TVY7", "TVY7FV"].contains(compact) else { return false }
        return classify(certification: certification, region: region) == .general
    }

    /// Returns a filter tier without conflating parental-guidance labels
    /// with an explicit All Ages classification.
    static func ratingForFiltering(certification: String, region: String? = nil) -> MaturityRating {
        let rating = classify(certification: certification, region: region)
        guard rating == .general,
              !isExplicitAllAgesCertification(certification: certification, region: region) else {
            return rating
        }

        let compact = certification.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "+", with: "PLUS")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        return ["TVY7", "TVY7FV"].contains(compact) ? .age7 : .age10
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

        // Taizen and some international catalogues return descriptive labels
        // rather than a short code (for example "All Ages" or "G - All Ages").
        // Treat these as explicit general-audience ratings, not unknown.
        if compact == "ALLAGES" || compact == "ALLAGESRATING"
            || normalized.contains("ALL AGES")
            || normalized.contains("GENERAL AUDIENCE")
            || normalized == "EVERYONE" {
            return .general
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
        if compact.hasPrefix("TVMA") || compact.hasPrefix("R17") {
            return .age17
        }
        if compact.hasPrefix("R16") {
            return .age16
        }
        if compact.hasPrefix("MA") || compact.hasPrefix("R15") {
            return .mature
        }
        if compact.hasPrefix("TV14") {
            return .age14
        }
        if compact.hasPrefix("PG13") || compact.hasPrefix("R13") {
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
        case ..<6: return .general
        case 6: return .age6
        case 7: return .age7
        case 8: return .age8
        case 9: return .age9
        case 10: return .age10
        case 11: return .age11
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
        // Bulgaria's current film categories map to minimum-age guidance:
        // A = recommended for children; B = no age restriction;
        // C = 12+, C+ = 14+, D/D+ = 16+, X = 18+.
        "BG": [
            "A": .general, "B": .general,
            "C": .age12, "CPLUS": .age14,
            "D": .age16, "DPLUS": .age16,
            "X": .adult
        ],
        "ES": [
            "APTA": .general, "7": .age7, "12": .age12,
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
            "0": .general, "6": .age6, "12": .age12, "16": .age16, "18": .adult
        ],
        "FR": [
            "U": .general, "10": .age10, "12": .age12, "16": .age16, "18": .adult
        ],
        "SE": ["7": .age7, "11": .age11, "15": .mature],
        "DK": ["7": .age7, "11": .age11, "15": .mature],
        "NO": ["6": .age6, "9": .age9, "12": .age12, "15": .mature, "18": .adult],
        "FI": ["7": .age7, "12": .age12, "16": .age16, "18": .adult],
        "PL": ["7": .age7, "12": .age12, "16": .age16, "18": .adult],
        "BE": ["0": .general, "6": .age6, "9": .age9, "12": .age12, "14": .age14, "16": .age16, "18": .adult],
        "AT": ["6": .age6, "10": .age10, "12": .age12, "16": .age16, "18": .adult],
        "IE": ["G": .general, "PG": .general, "12A": .age12, "15A": .mature, "16": .age16, "18": .adult],
        "IT": [
            "T": .general, "VM14": .age14, "VM18": .adult
        ],
        "NL": [
            "AL": .general, "6": .age6, "9": .age9,
            "12": .age12, "14": .age14, "16": .age16, "18": .adult
        ],
        "BR": [
            "L": .general, "10": .age10, "12": .age12,
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

        "L": .general,

        "PG13SG": .teen, "NC16": .age16, "M18": .adult, "R21": .adult,

        "0": .general, "6": .age6, "7": .age7, "8": .age8,
        "9": .age9, "10": .age10, "11": .age11,
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



enum CatalogAgeRatingFilterPolicy {
    /// A configured minimum age is a strict eligibility rule: a missing or
    /// unknown certificate cannot prove that a title meets the minimum.
    /// The All Ages-only toggle remains narrower and excludes only explicit
    /// general-audience classifications.
    static func shouldInclude(
        rating: MaturityRating?,
        minimum: MaturityRating?,
        hideAllAges: Bool
    ) -> Bool {
        if hideAllAges, rating == .general { return false }
        guard let minimum else { return true }
        guard let rating, rating != .unknown else { return false }
        return rating >= minimum
    }
}
