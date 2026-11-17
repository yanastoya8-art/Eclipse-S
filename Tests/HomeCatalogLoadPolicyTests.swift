import Foundation
import XCTest
@testable import Eclipse

final class HomeCatalogLoadPolicyTests: XCTestCase {
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
