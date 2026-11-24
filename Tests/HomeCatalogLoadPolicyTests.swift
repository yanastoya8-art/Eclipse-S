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

    func testServiceErrorWrappingPreservesStructuredTMDBFailures() {
        let original = TMDBError.httpError(
            statusCode: 401,
            path: "/trending/all",
            message: "Invalid API key"
        )

        guard case .httpError(let statusCode, let path, let message) = TMDBError.wrapping(original) else {
            XCTFail("A structured TMDB HTTP error must not be downgraded to a network error.")
            return
        }

        XCTAssertEqual(statusCode, 401)
        XCTAssertEqual(path, "/trending/all")
        XCTAssertEqual(message, "Invalid API key")
        XCTAssertTrue(
            HomeCatalogFailurePresentation.message(
                for: TMDBError.wrapping(original)
            ).contains("rejected")
        )
    }

    func testServiceErrorWrappingRetainsUnderlyingTransportFailures() {
        guard case .networkError(let underlying) = TMDBError.wrapping(URLError(.notConnectedToInternet)) else {
            XCTFail("A URLSession transport failure should remain a network error.")
            return
        }
        XCTAssertEqual((underlying as? URLError)?.code, .notConnectedToInternet)
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

    func testNestedTMDBTransportErrorsAreClassifiedRecursively() {
        let error = TMDBError.networkError(
            TMDBError.networkError(URLError(.timedOut))
        )

        let message = HomeCatalogFailurePresentation.message(for: error)
        XCTAssertTrue(message.contains("too long"))
        XCTAssertTrue(message.contains("Retry"))
    }

    func testInvalidURLAndDecodingErrorsHaveDistinctGuidance() {
        let invalidURL = HomeCatalogFailurePresentation.message(for: TMDBError.invalidURL)
        let decoding = HomeCatalogFailurePresentation.message(for: TMDBError.decodingError)

        XCTAssertTrue(invalidURL.contains("request URL"))
        XCTAssertTrue(decoding.contains("could not read"))
        XCTAssertFalse(invalidURL.contains("internet connection"))
        XCTAssertFalse(decoding.contains("internet connection"))
    }

    func testBadRequestIsNotMisreportedAsConnectivityFailure() {
        let message = HomeCatalogFailurePresentation.message(
            for: TMDBError.httpError(statusCode: 400, path: "/discover/movie", message: "Invalid parameter")
        )

        XCTAssertTrue(message.contains("rejected a Home request"))
        XCTAssertFalse(message.contains("internet connection"))
    }

    func testBrowsePaginationKeepsFailedPageAvailableForRetry() {
        let cursor = DiscoverPaginationCursor()
        XCTAssertEqual(cursor.nextPage, 2)
        XCTAssertEqual(cursor.currentPage, 1)
        XCTAssertTrue(cursor.hasMorePages)
    }

    func testBrowsePaginationAdvancesOnlyAfterSuccessfulPage() {
        var cursor = DiscoverPaginationCursor()
        cursor.didLoadPage(hasUniqueItems: true)

        XCTAssertEqual(cursor.currentPage, 2)
        XCTAssertEqual(cursor.nextPage, 3)
        XCTAssertEqual(cursor.consecutiveEmptyPages, 0)
        XCTAssertTrue(cursor.hasMorePages)
    }

    func testBrowsePaginationStopsAfterBoundedFilteredEmptyPages() {
        var cursor = DiscoverPaginationCursor()
        for _ in 0..<DiscoverPaginationCursor.maximumConsecutiveEmptyPages {
            cursor.didLoadPage(hasUniqueItems: false)
        }

        XCTAssertEqual(cursor.currentPage, 5)
        XCTAssertEqual(cursor.consecutiveEmptyPages, DiscoverPaginationCursor.maximumConsecutiveEmptyPages)
        XCTAssertFalse(cursor.hasMorePages)
    }

    func testBrowsePaginationResetsWhenCategoryChanges() {
        var cursor = DiscoverPaginationCursor()
        cursor.didLoadPage(hasUniqueItems: true)
        cursor.didLoadPage(hasUniqueItems: false)

        cursor.reset()

        XCTAssertEqual(cursor.currentPage, 1)
        XCTAssertEqual(cursor.nextPage, 2)
        XCTAssertEqual(cursor.consecutiveEmptyPages, 0)
        XCTAssertTrue(cursor.hasMorePages)
    }
}


final class CatalogContentFilterRegressionTests: XCTestCase {
    func testRuntimeFilterUsesShortestReportedEpisodeRuntime() {
        XCTAssertEqual(CatalogRuntimeFilterPolicy.shortestReportedRuntime([24, 12, 22]), 12)
        XCTAssertEqual(CatalogRuntimeFilterPolicy.shortestReportedRuntime([0, -1, 25]), 25)
        XCTAssertNil(CatalogRuntimeFilterPolicy.shortestReportedRuntime(nil))
    }

    func testRuntimeFilterFailsClosedForUnknownRuntime() {
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: nil))
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 0))
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 19))
        XCTAssertTrue(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 20))
        XCTAssertTrue(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 42))
    }

    func testUnofficialProductionFilterChecksProductionCompanyNames() {
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "A New Web Series",
            overview: nil,
            productionCompanies: ["Example Creator Studio"]
        ))
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "Fan Project",
            overview: nil,
            productionCompanies: ["Independent Fanmade Studios"]
        ))
        XCTAssertFalse(TMDBContentFilter.isUnofficialCreatorContent(
            title: "A Feature Film",
            overview: nil,
            productionCompanies: ["Studio Ghibli"]
        ))
    }
}

final class CatalogRuntimeAndProductionFilterPolicyTests: XCTestCase {
    func testMinimumRuntimeRejectsUnknownAndShortEpisodes() {
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: nil))
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 0))
        XCTAssertFalse(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 19))
        XCTAssertTrue(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 20))
        XCTAssertTrue(CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: 45))
    }

    func testSeriesRuntimeUsesShortestReportedEpisode() {
        XCTAssertEqual(CatalogRuntimeFilterPolicy.shortestReportedRuntime([42, 18, 45]), 18)
        XCTAssertEqual(CatalogRuntimeFilterPolicy.shortestReportedRuntime([20, 24, 42]), 20)
        XCTAssertNil(CatalogRuntimeFilterPolicy.shortestReportedRuntime([0, -1, nil].compactMap { $0 }))
        XCTAssertNil(CatalogRuntimeFilterPolicy.shortestReportedRuntime(nil))
    }

    func testUnofficialProductionDetectionIncludesProductionCompanyMetadata() {
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "A New Series",
            overview: "An original scripted show",
            productionCompanies: ["YouTuber Studios"]
        ))
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "A Fan Project",
            overview: nil,
            productionCompanies: ["Independent Web Animation"]
        ))
        XCTAssertFalse(TMDBContentFilter.isUnofficialCreatorContent(
            title: "A New Series",
            overview: "An original scripted show",
            productionCompanies: ["Warner Bros. Television"]
        ))
    }

    func testUnofficialProductionDetectionCatchesCreatorPlatformTerms() {
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "Creator Original",
            overview: "A series made for YouTube by a digital creator",
            productionCompanies: []
        ))
        XCTAssertTrue(TMDBContentFilter.isUnofficialCreatorContent(
            title: "Fan Series",
            overview: "An independent web series",
            productionCompanies: []
        ))
    }
}



final class BrowseAnimeClassifierTests: XCTestCase {
    private func result(
        genreIDs: [Int]?,
        language: String?,
        countries: [String]?
    ) -> TMDBSearchResult {
        TMDBSearchResult(
            id: 42,
            mediaType: "tv",
            title: nil,
            name: "Fixture",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2026-01-01",
            voteAverage: 7,
            popularity: 10,
            adult: false,
            genreIds: genreIDs,
            originalLanguage: language,
            originCountry: countries
        )
    }

    func testMetadataIncompleteAnimationIsNotDroppedFromTVBrowse() {
        let item = result(genreIDs: [16], language: nil, countries: nil)
        XCTAssertTrue(BrowseAnimeClassifier.shouldIncludeInTV(item))
        XCTAssertTrue(BrowseAnimeClassifier.isAnime(item))
    }

    func testConfirmedJapaneseAnimationIsKeptOutOfTVBrowse() {
        let item = result(genreIDs: [16], language: "ja", countries: ["JP"])
        XCTAssertFalse(BrowseAnimeClassifier.shouldIncludeInTV(item))
    }

    func testWesternAnimationRemainsInTVBrowse() {
        let item = result(genreIDs: [16], language: "en", countries: ["US"])
        XCTAssertTrue(BrowseAnimeClassifier.shouldIncludeInTV(item))
        XCTAssertFalse(BrowseAnimeClassifier.isAnime(item))
    }
}
