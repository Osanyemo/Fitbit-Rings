import XCTest
@testable import FitbitRings

final class GoogleHealthDecodingTests: XCTestCase {
    func testRollupResponseDecodesNumericValues() throws {
        let json = """
        {
          "rollupDataPoints": [
            {
              "steps": { "countSum": "382" },
              "activeMinutes": {
                "activeMinutesRollupByActivityLevel": [
                  { "activityLevel": "LIGHT", "activeMinutesSum": "12" },
                  { "activityLevel": "MODERATE", "activeMinutesSum": "7" }
                ]
              },
              "activeEnergyBurned": { "kcalSum": 42.5 },
              "distance": { "millimetersSum": "12500" },
              "totalCalories": { "kcalSum": 2100.75 }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.googleHealthDecoder.decode(
            GoogleHealthRollUpResponse.self,
            from: json
        )
        let point = try XCTUnwrap(decoded.rollupDataPoints.first)

        XCTAssertEqual(point.steps?.countSum?.intValue, 382)
        XCTAssertEqual(
            point.activeMinutes?.activeMinutesRollupByActivityLevel.compactMap { $0.activeMinutesSum?.intValue },
            [12, 7]
        )
        XCTAssertEqual(point.activeEnergyBurned?.kcalSum, 42.5)
        XCTAssertEqual(point.distance?.millimetersSum?.doubleValue, 12_500)
        XCTAssertEqual(point.totalCalories?.kcalSum, 2100.75)
    }

    func testMapperBuildsDashboardFromV4Rollups() throws {
        let snapshot = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(timeIntervalSince1970: 0),
            rollups: [
                .steps: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: GoogleHealthStepsRollup(countSum: GoogleHealthNumericValue(7_842)),
                            activeMinutes: nil,
                            activeEnergyBurned: nil,
                            distance: nil,
                            totalCalories: nil
                        )
                    ]
                ),
                .activeMinutes: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: nil,
                            activeMinutes: GoogleHealthActiveMinutesRollup(
                                activeMinutesRollupByActivityLevel: [
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "LIGHT",
                                        activeMinutesSum: GoogleHealthNumericValue(10)
                                    ),
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "VIGOROUS",
                                        activeMinutesSum: GoogleHealthNumericValue(5)
                                    )
                                ]
                            ),
                            activeEnergyBurned: nil,
                            distance: nil,
                            totalCalories: nil
                        )
                    ]
                ),
                .activeEnergyBurned: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: nil,
                            activeMinutes: nil,
                            activeEnergyBurned: GoogleHealthEnergyRollup(kcalSum: 325),
                            distance: nil,
                            totalCalories: nil
                        )
                    ]
                ),
                .distance: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: nil,
                            activeMinutes: nil,
                            activeEnergyBurned: nil,
                            distance: GoogleHealthDistanceRollup(millimetersSum: GoogleHealthNumericValue(4_500_000)),
                            totalCalories: nil
                        )
                    ]
                ),
                .totalCalories: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: nil,
                            activeMinutes: nil,
                            activeEnergyBurned: nil,
                            distance: nil,
                            totalCalories: GoogleHealthEnergyRollup(kcalSum: 2_180)
                        )
                    ]
                )
            ],
            latestWorkout: nil,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        )

        XCTAssertEqual(snapshot.activity.steps, 7_842)
        XCTAssertEqual(snapshot.rings.active.value, 15)
        XCTAssertEqual(snapshot.activity.activeCalories, 325)
        XCTAssertEqual(snapshot.activity.distanceMeters, 4_500)
        XCTAssertEqual(snapshot.activity.totalCalories, 2_180)
        XCTAssertTrue(snapshot.activity.hasData(for: .steps))
        XCTAssertTrue(snapshot.activity.hasData(for: .distance))
    }

    func testMapperDistinguishesMissingValuesFromProvidedZero() throws {
        let zeroSteps = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(timeIntervalSince1970: 0),
            rollups: [
                .steps: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            steps: GoogleHealthStepsRollup(countSum: GoogleHealthNumericValue(0)),
                            activeMinutes: nil,
                            activeEnergyBurned: nil,
                            distance: nil,
                            totalCalories: nil
                        )
                    ]
                )
            ],
            latestWorkout: nil,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        )
        let missingSteps = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(timeIntervalSince1970: 0),
            rollups: [:],
            latestWorkout: nil,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        )

        XCTAssertEqual(zeroSteps.activity.steps, 0)
        XCTAssertTrue(zeroSteps.activity.hasData(for: .steps))
        XCTAssertEqual(missingSteps.activity.steps, 0)
        XCTAssertFalse(missingSteps.activity.hasData(for: .steps))
    }

    func testActivityMapperAggregatesDuplicateBucketLabels() throws {
        let date = Date(timeIntervalSince1970: 0)
        let activityData = GoogleHealthMapper.mapActivityData(
            dailyRollups: [
                .activeMinutes: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            activeMinutes: GoogleHealthActiveMinutesRollup(
                                activeMinutesRollupByActivityLevel: [
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "LIGHT",
                                        activeMinutesSum: GoogleHealthNumericValue(10)
                                    ),
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "MODERATE",
                                        activeMinutesSum: GoogleHealthNumericValue(5)
                                    ),
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "VIGOROUS",
                                        activeMinutesSum: GoogleHealthNumericValue(3)
                                    )
                                ]
                            )
                        ),
                        GoogleHealthRollupDataPoint(
                            activeMinutes: GoogleHealthActiveMinutesRollup(
                                activeMinutesRollupByActivityLevel: [
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: " lightly_active ",
                                        activeMinutesSum: GoogleHealthNumericValue(7)
                                    ),
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "MODERATELY_ACTIVE",
                                        activeMinutesSum: GoogleHealthNumericValue(11)
                                    ),
                                    GoogleHealthActiveMinutesByActivityLevel(
                                        activityLevel: "VERY_ACTIVE",
                                        activeMinutesSum: GoogleHealthNumericValue(13)
                                    )
                                ]
                            )
                        )
                    ]
                )
            ],
            hourlyRollups: [:],
            range: DateInterval(start: date, duration: 14 * 86_400),
            loadedAt: date
        )

        let activityLevel = try XCTUnwrap(activityData.bucketedSeries.first { $0.type == .activeMinutes })
        XCTAssertEqual(activityLevel.title, "Activity Intensity")
        XCTAssertEqual(activityLevel.buckets.map(\.label), ["Light", "Moderate", "Vigorous"])
        XCTAssertEqual(activityLevel.buckets.map(\.value), [17, 16, 16])
    }

    func testActivityMapperHidesEmptyRollupsButKeepsExplicitZeroPoints() throws {
        let date = Date(timeIntervalSince1970: 0)
        let activityData = GoogleHealthMapper.mapActivityData(
            dailyRollups: [
                .steps: GoogleHealthRollUpResponse(rollupDataPoints: []),
                .floors: GoogleHealthRollUpResponse(
                    rollupDataPoints: [
                        GoogleHealthRollupDataPoint(
                            floors: GoogleHealthCountRollup(
                                countSum: GoogleHealthNumericValue(0),
                                floorsSum: nil,
                                lengthsSum: nil
                            )
                        )
                    ]
                )
            ],
            hourlyRollups: [:],
            range: DateInterval(start: date, duration: 14 * 86_400),
            loadedAt: date
        )

        XCTAssertNil(activityData.series(for: .steps))

        let floors = try XCTUnwrap(activityData.series(for: .floors))
        XCTAssertEqual(floors.points.map(\.value), [0])
        XCTAssertFalse(activityData.isEmpty)
    }

    func testActivityMapperDecodesAndMapsSupportedRollupMetrics() throws {
        let json = """
        {
          "rollupDataPoints": [
            {
              "activeZoneMinutes": {
                "fatBurnMinutesSum": "2",
                "cardioMinutesSum": "3",
                "peakMinutesSum": "4"
              },
              "floors": { "floorsSum": "6" },
              "swimLengthsData": { "lengthsSum": "8" },
              "caloriesInHeartRateZone": { "caloriesKcalSum": "120" },
              "timeInHeartRateZone": { "minutesSum": "24" }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.googleHealthDecoder.decode(
            GoogleHealthRollUpResponse.self,
            from: json
        )
        let point = try XCTUnwrap(decoded.rollupDataPoints.first)

        XCTAssertEqual(point.activeZoneMinutes?.fatBurnMinutesSum?.intValue, 2)
        XCTAssertEqual(point.floors?.floorsSum?.intValue, 6)
        XCTAssertEqual(point.swimLengthsData?.lengthsSum?.intValue, 8)
        XCTAssertEqual(point.caloriesInHeartRateZone?.caloriesKcalSum?.intValue, 120)
        XCTAssertEqual(point.timeInHeartRateZone?.minutesSum?.intValue, 24)

        let activityData = GoogleHealthMapper.mapActivityData(
            dailyRollups: [
                .activeZoneMinutes: decoded,
                .floors: decoded,
                .swimLengthsData: decoded,
                .caloriesInHeartRateZone: decoded,
                .timeInHeartRateZone: decoded
            ],
            hourlyRollups: [:],
            range: DateInterval(start: Date(timeIntervalSince1970: 0), duration: 14 * 86_400)
        )

        XCTAssertEqual(try latestValue(.activeZoneMinutes, in: activityData), 9)
        XCTAssertEqual(try latestValue(.floors, in: activityData), 6)
        XCTAssertEqual(try latestValue(.swimLengthsData, in: activityData), 8)
        XCTAssertEqual(try latestValue(.caloriesInHeartRateZone, in: activityData), 120)
        XCTAssertEqual(try latestValue(.timeInHeartRateZone, in: activityData), 24)
    }

    func testDataPointResponseDecodesWorkoutRecord() throws {
        let json = """
        {
          "dataPoints": [
            {
              "exercise": {
                "interval": {
                  "startTime": "2026-08-20T12:00:00.000Z",
                  "endTime": "2026-08-20T12:30:00.000Z"
                },
                "exerciseType": "RUNNING",
                "displayName": "Run",
                "metricsSummary": {
                  "distanceMillimeters": 5000000.0,
                  "caloriesKcal": 320.0
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.googleHealthDecoder.decode(
            GoogleHealthListResponse.self,
            from: json
        )

        let workout = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(),
            rollups: [:],
            latestWorkout: decoded.dataPoints.first,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        ).latestWorkout

        XCTAssertEqual(workout?.type, "Run")
        XCTAssertEqual(workout?.durationSeconds, 1_800)
        XCTAssertEqual(workout?.distanceMeters, 5_000)
        XCTAssertEqual(workout?.calories, 320)
    }

    func testDataPointResponseDecodesHeartAndSleepRecords() throws {
        let heartJSON = """
        {
          "dataPoints": [
            {
              "heartRate": {
                "sampleTime": { "physicalTime": "2026-08-20T13:15:00Z" },
                "beatsPerMinute": "72"
              }
            },
            {
              "dailyRestingHeartRate": {
                "beatsPerMinute": "58"
              }
            },
            {
              "sleep": {
                "interval": {
                  "startTime": "2026-08-20T04:00:00Z",
                  "endTime": "2026-08-20T11:00:00Z"
                },
                "summary": {
                  "minutesAsleep": "390"
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.googleHealthDecoder.decode(
            GoogleHealthListResponse.self,
            from: heartJSON
        )

        let snapshot = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(),
            rollups: [:],
            latestWorkout: nil,
            latestHeartRate: decoded.dataPoints[0],
            restingHeartRate: decoded.dataPoints[1],
            sleep: decoded.dataPoints[2]
        )

        XCTAssertEqual(snapshot.heart.mostRecentHeartRate, 72)
        XCTAssertEqual(snapshot.heart.restingHeartRate, 58)
        XCTAssertEqual(snapshot.sleep?.durationSeconds, 23_400)
    }

    func testGoogleHealthClientBuildsV4RequestShapes() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let httpClient = CapturingHTTPClient()
        let client = GoogleHealthClient(networkClient: httpClient, calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!

        _ = try await client.fetchDashboard(goals: .defaultGoals, date: date)

        let requests = httpClient.recordedRequests()
        let stepsRequest = try XCTUnwrap(
            requests.first { $0.url?.path == "/v4/users/me/dataTypes/steps/dataPoints:dailyRollUp" }
        )
        XCTAssertEqual(stepsRequest.httpMethod, "POST")
        XCTAssertEqual(stepsRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = String(data: try XCTUnwrap(stepsRequest.httpBody), encoding: .utf8)
        XCTAssertTrue(body?.contains("\"windowSizeDays\":1") == true)
        XCTAssertTrue(body?.contains("\"day\":20") == true)

        let exerciseRequest = try XCTUnwrap(
            requests.first { $0.url?.path == "/v4/users/me/dataTypes/exercise/dataPoints:reconcile" }
        )
        let queryItems = URLComponents(
            url: try XCTUnwrap(exerciseRequest.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(queryItems?.first(named: "pageSize")?.value, "1")
        XCTAssertNil(queryItems?.first(named: "orderBy"))
        XCTAssertTrue(
            queryItems?.first(named: "filter")?.value?.contains("exercise.interval.civil_start_time") == true
        )
    }

    func testGoogleHealthClientBuildsActivityRollupAndReconcileRequests() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let httpClient = CapturingHTTPClient()
        let client = GoogleHealthClient(networkClient: httpClient, calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!

        _ = try await client.fetchActivityData(date: date)

        let requests = httpClient.recordedRequests()
        let hourlySteps = try XCTUnwrap(
            requests.first { $0.url?.path == "/v4/users/me/dataTypes/steps/dataPoints:rollUp" }
        )
        let hourlyBody = String(data: try XCTUnwrap(hourlySteps.httpBody), encoding: .utf8)
        XCTAssertTrue(hourlyBody?.contains("\"windowSize\":\"3600s\"") == true)

        let activityLevel = try XCTUnwrap(
            requests.first { $0.url?.path == "/v4/users/me/dataTypes/activity-level/dataPoints:reconcile" }
        )
        let queryItems = URLComponents(
            url: try XCTUnwrap(activityLevel.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertTrue(queryItems?.first(named: "filter")?.value?.contains("activity_level.date") == true)
    }

    func testReconcilePaginationIncludesPageTokenAndExerciseLimit() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let httpClient = PagingHTTPClient()
        let client = GoogleHealthClient(networkClient: httpClient, calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!

        _ = try await client.fetchWorkoutData(date: date)

        let requests = httpClient.recordedRequests()
        XCTAssertEqual(requests.count, 2)

        let firstItems = URLComponents(
            url: try XCTUnwrap(requests.first?.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(firstItems?.first(named: "pageSize")?.value, "25")
        XCTAssertNil(firstItems?.first(named: "pageToken"))

        let secondItems = URLComponents(
            url: try XCTUnwrap(requests.last?.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(secondItems?.first(named: "pageToken")?.value, "next-page")
    }
}

private func latestValue(
    _ type: GoogleHealthDataType,
    in activityData: ActivityDashboardData,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> Double {
    try XCTUnwrap(activityData.series(for: type)?.latestPoint?.value, file: file, line: line)
}

private final class CapturingHTTPClient: HTTPClient {
    private let queue = DispatchQueue(label: "CapturingHTTPClient")
    private var requests: [URLRequest] = []

    func send<T: Decodable>(_ request: URLRequest, decoding type: T.Type) async throws -> T {
        queue.sync {
            requests.append(request)
        }

        let json: String
        if request.url?.path.contains("dataPoints:dailyRollUp") == true {
            json = #"{"rollupDataPoints":[]}"#
        } else if request.url?.path.contains("dataPoints:rollUp") == true {
            json = #"{"rollupDataPoints":[]}"#
        } else {
            json = #"{"dataPoints":[]}"#
        }
        return try JSONDecoder.googleHealthDecoder.decode(T.self, from: Data(json.utf8))
    }

    func recordedRequests() -> [URLRequest] {
        queue.sync { requests }
    }
}

private final class PagingHTTPClient: HTTPClient {
    private let queue = DispatchQueue(label: "PagingHTTPClient")
    private var requests: [URLRequest] = []

    func send<T: Decodable>(_ request: URLRequest, decoding type: T.Type) async throws -> T {
        let requestNumber = queue.sync { () -> Int in
            requests.append(request)
            return requests.count
        }

        let json = requestNumber == 1
            ? #"{"dataPoints":[{"dataPointName":"first"}],"nextPageToken":"next-page"}"#
            : #"{"dataPoints":[{"dataPointName":"second"}]}"#

        return try JSONDecoder.googleHealthDecoder.decode(T.self, from: Data(json.utf8))
    }

    func recordedRequests() -> [URLRequest] {
        queue.sync { requests }
    }
}

private extension Array where Element == URLQueryItem {
    func first(named name: String) -> URLQueryItem? {
        first { $0.name == name }
    }
}
