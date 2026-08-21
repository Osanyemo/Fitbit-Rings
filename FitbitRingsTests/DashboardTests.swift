import XCTest
@testable import FitbitRings

final class DashboardTests: XCTestCase {
    func testRingProgressCapsAtOneForRendering() {
        let metric = RingMetric(title: "Steps", value: 12_500, goal: 10_000, unit: "")

        XCTAssertEqual(metric.progress, 1.25)
        XCTAssertEqual(metric.cappedProgress, 1)
    }

    func testDistanceFormattingUsesSelectedUnit() {
        XCTAssertEqual(DashboardFormatting.distance(1_000, unit: .kilometers), "1.00 km")
        XCTAssertEqual(DashboardFormatting.distance(1_609.344, unit: .miles), "1.00 mi")
    }

    func testGoogleHealthMapperBuildsDashboardSnapshot() throws {
        let response = GoogleHealthRollUpResponse(
            bucket: [
                GoogleHealthBucket(
                    dataset: [
                        GoogleHealthDataset(
                            point: [
                                GoogleHealthPoint(
                                    startTime: nil,
                                    endTime: nil,
                                    value: [GoogleHealthValue(intVal: 7_842, fpVal: nil, stringVal: nil, mapVal: nil)]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let snapshot = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(timeIntervalSince1970: 0),
            rollups: [.steps: response],
            latestWorkout: nil,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        )

        XCTAssertEqual(snapshot.activity.steps, 7_842)
        XCTAssertEqual(snapshot.rings.steps.value, 7_842)
        XCTAssertEqual(snapshot.rings.steps.goal, 10_000)
    }

    func testMissingScopesErrorNamesScopes() {
        let error = AuthenticationError.missingScopes(["scope-a", "scope-b"])

        XCTAssertTrue(error.localizedDescription.contains("scope-a"))
        XCTAssertTrue(error.localizedDescription.contains("scope-b"))
    }

    func testGoogleSignInConfigurationDetectsPlaceholderClientID() {
        let info: [String: Any] = [
            "GIDClientID": "REPLACE_WITH_GOOGLE_CLIENT_ID",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["replace_with_google_client_id"]]
            ]
        ]

        let error = GoogleSignInConfiguration.validationError(infoDictionary: info)

        XCTAssertNotNil(error)
        XCTAssertTrue(error?.localizedDescription.contains("GOOGLE_CLIENT_ID") == true)
    }

    func testGoogleSignInConfigurationBuildsCallbackURLScheme() {
        XCTAssertEqual(
            GoogleSignInConfiguration.callbackURLScheme(
                forClientID: "1234567890-abcdef.apps.googleusercontent.com"
            ),
            "com.googleusercontent.apps.1234567890-abcdef"
        )
    }

    func testGoogleSignInConfigurationAcceptsMatchingCallbackURLScheme() {
        let info: [String: Any] = [
            "GIDClientID": "1234567890-abcdef.apps.googleusercontent.com",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["com.googleusercontent.apps.1234567890-abcdef"]]
            ]
        ]

        XCTAssertNil(GoogleSignInConfiguration.validationError(infoDictionary: info))
    }

    func testGoogleSignInConfigurationRejectsMissingCallbackURLScheme() {
        let info: [String: Any] = [
            "GIDClientID": "1234567890-abcdef.apps.googleusercontent.com",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["com.example.unrelated"]]
            ]
        ]

        let error = GoogleSignInConfiguration.validationError(infoDictionary: info)

        XCTAssertTrue(
            error?.localizedDescription.contains("com.googleusercontent.apps.1234567890-abcdef") == true
        )
    }
}
