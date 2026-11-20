import Foundation
import XCTest
@testable import Eclipse

final class HomeCatalogLoadPolicyTests: XCTestCase {
    func testJustForYouCatalogRequestsItsHiddenTrendingSeed() {
        XCTAssertTrue(HomeCatalogLoadPolicy.requiresTrendingSeed(enabledCatalogIDs: ["forYou"]))
        XCTAssertTrue(HomeCatalogLoadPolicy.requiresTrendingSeed(enabledCatalogIDs: ["trending", "forYou"]))
    }

    func testHiddenTrendingSeedDoesNotCountAsAVisibleForYouShelf() {
        let trending = TMDBSearchResult(
            id: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            voteAverage: 8.4,
            popularity: 100,
            adult: false,
            genreIds: [18]
        )
        let catalogs = ["trending": [trending]]

        XCTAssertEqual(
            HomeCatalogLoadPolicy.visibleCatalogCount(catalogs, enabledCatalogIDs: ["forYou"]),
            0
        )
        XCTAssertEqual(
            HomeCatalogLoadPolicy.visibleCatalogCount(catalogs, enabledCatalogIDs: ["trending"]),
            1
        )
    }

    func testDynamicWidgetResultsCountOnlyWhenTheirParentCatalogIsEnabled() {
        let sample = TMDBSearchResult(
            id: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            voteAverage: 8.4,
            popularity: 100,
            adult: false,
            genreIds: [18]
        )
        let widgets = [
            "network_213": [sample],
            "genre_18": [sample],
            "company_420": [sample],
            "featured": [sample]
        ]

        XCTAssertEqual(
            HomeCatalogLoadPolicy.visibleWidgetCatalogCount(
                widgets,
                enabledCatalogIDs: ["networks", "featured"]
            ),
            2
        )
    }

    func testTrendingSeedIsNotRequestedWhenNeitherTrendingNorRecommendationsAreEnabled() {
        XCTAssertFalse(HomeCatalogLoadPolicy.requiresTrendingSeed(enabledCatalogIDs: ["popularMovies", "featured"]))
    }

    func testJustForYouFallsBackToTrendingForProfilesWithoutTasteHistory() {
        let trending = TMDBSearchResult(
            id: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            voteAverage: 8.4,
            popularity: 100,
            adult: false,
            genreIds: [18]
        )

        let results = HomeCatalogLoadPolicy.forYouResults(recommendations: [], trending: [trending])
        XCTAssertEqual(results.map(\.id), [550])
    }

    func testPersonalizedRecommendationsTakePrecedenceOverTrendingFallback() {
        let recommendation = TMDBSearchResult(
            id: 1399,
            mediaType: "tv",
            title: nil,
            name: "Game of Thrones",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2011-04-17",
            voteAverage: 8.4,
            popularity: 100,
            adult: false,
            genreIds: [18]
        )
        let trending = TMDBSearchResult(
            id: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            voteAverage: 8.4,
            popularity: 100,
            adult: false,
            genreIds: [18]
        )

        let results = HomeCatalogLoadPolicy.forYouResults(
            recommendations: [recommendation],
            trending: [trending]
        )
        XCTAssertEqual(results.map(\.id), [1399])
    }

    func testAniListOnlyHomeCatalogsCountAsLoadedContent() {
        XCTAssertTrue(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 2,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            permitsEmptyResults: false
        ))
    }

    func testSuccessfulAnimeCatalogPreventsFalseConnectionFailureWhenTMDBIsEmpty() {
        XCTAssertTrue(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 1,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            permitsEmptyResults: false
        ))
    }

    func testEmptyRemoteCatalogsDoNotCountAsLoaded() {
        XCTAssertFalse(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 0,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            permitsEmptyResults: false
        ))
    }

    func testVisibleForYouRecommendationCountsAsLoadedWithoutRemoteCatalogResults() {
        XCTAssertTrue(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 0,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            recommendationCatalogCount: 1,
            permitsEmptyResults: false
        ))
    }

    func testEmptyRecommendationShelfDoesNotMaskFailedRemoteCatalogs() {
        XCTAssertFalse(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 0,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            recommendationCatalogCount: 0,
            permitsEmptyResults: false
        ))
    }

    func testLocalOnlyConfigurationCanCompleteWithoutRemoteResults() {
        XCTAssertTrue(HomeCatalogLoadPolicy.hasLoadedContent(
            tmdbCatalogCount: 0,
            animeCatalogCount: 0,
            stremioCatalogCount: 0,
            traktCatalogCount: 0,
            widgetCatalogCount: 0,
            permitsEmptyResults: true
        ))
    }
}


final class HomeCatalogFilterPolicyTests: XCTestCase {
    func testAnimeShelvesKeepAnimeSpecificFiltersWhenCatalogFiltersRefresh() {
        for catalogID in ["trendingAnime", "popularAnime", "topRatedAnime", "airingAnime", "bestAnime"] {
            XCTAssertTrue(HomeCatalogFilterPolicy.usesAnimeFiltering(catalogID: catalogID))
        }
        XCTAssertFalse(HomeCatalogFilterPolicy.usesAnimeFiltering(catalogID: "popularMovies"))
    }

    func testUpcomingShelvesKeepTheirUpcomingReleaseExceptionOnRefresh() {
        XCTAssertTrue(HomeCatalogFilterPolicy.allowsUpcomingContent(catalogID: "upcomingMovies"))
        XCTAssertTrue(HomeCatalogFilterPolicy.allowsUpcomingContent(catalogID: "upcomingTV"))
        XCTAssertFalse(HomeCatalogFilterPolicy.allowsUpcomingContent(catalogID: "popularMovies"))
    }
}

final class HomeCatalogFailurePresentationTests: XCTestCase {
    func testMissingTMDBKeyShowsActionableConfigurationGuidance() {
        let error = NSError(
            domain: "TMDBError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "TMDB API key is missing"]
        )

        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("TMDB_API_KEY"))
        XCTAssertTrue(message.contains("rebuild"))
    }

    func testRejectedTMDBKeyIsNotMisreportedAsNetworkFailure() {
        let error = NSError(
            domain: "TMDBError",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "TMDB HTTP 401: Invalid API key"]
        )

        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("rejected"))
        XCTAssertTrue(message.contains("401/403"))
    }

    func testRateLimitExplainsRetryAction() {
        let error = NSError(
            domain: "TMDBError",
            code: 429,
            userInfo: [NSLocalizedDescriptionKey: "TMDB HTTP 429"]
        )

        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("rate-limited"))
        XCTAssertTrue(message.contains("Retry"))
    }

    func testActualTMDBErrorCasesAreClassifiedByTheirStructuredStatus() {
        let unauthorized = HomeCatalogFailurePresentation.message(
            for: TMDBError.httpError(statusCode: 401, path: "/trending/all", message: "Invalid API key")
        )
        XCTAssertTrue(unauthorized.contains("rejected"))
        XCTAssertTrue(unauthorized.contains("401/403"))

        let rateLimited = HomeCatalogFailurePresentation.message(
            for: TMDBError.httpError(statusCode: 429, path: "/trending/all", message: "Rate limit exceeded")
        )
        XCTAssertTrue(rateLimited.contains("rate-limited"))
        XCTAssertTrue(rateLimited.contains("Retry"))

        let unavailable = HomeCatalogFailurePresentation.message(
            for: TMDBError.httpError(statusCode: 503, path: "/trending/all", message: nil)
        )
        XCTAssertTrue(unavailable.contains("temporarily unavailable"))
        XCTAssertTrue(unavailable.contains("503"))
    }

    func testWrappedTMDBTransportErrorPreservesConnectivityGuidance() {
        let error = TMDBError.networkError(URLError(.notConnectedToInternet))
        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("internet connection"))
        XCTAssertTrue(message.contains("Retry"))
    }

    func testActualMissingTMDBKeyErrorShowsBuildConfigurationGuidance() {
        let message = HomeCatalogFailurePresentation.message(for: TMDBError.missingAPIKey)
        XCTAssertTrue(message.contains("TMDB_API_KEY"))
        XCTAssertTrue(message.contains("rebuild"))
    }

    func testOfflineFailureSuggestsCheckingConnectivity() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )

        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("internet connection"))
        XCTAssertTrue(message.contains("Retry"))
    }
}
