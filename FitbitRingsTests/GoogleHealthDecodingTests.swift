import XCTest
@testable import FitbitRings

final class GoogleHealthDecodingTests: XCTestCase {
    func testRollupResponseDecodesNumericValues() throws {
        let json = """
        {
          "bucket": [
            {
              "dataset": [
                {
                  "point": [
                    {
                      "value": [
                        { "intVal": 382 },
                        { "fpVal": 12.5 }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.googleHealthDecoder.decode(
            GoogleHealthRollUpResponse.self,
            from: json
        )

        let values = decoded.bucket.flatMap(\.dataset).flatMap(\.point).flatMap(\.value)
        XCTAssertEqual(values.compactMap(\.numericValue).reduce(0, +), 394.5)
    }

    func testRecordResponseDecodesWorkoutRecord() throws {
        let json = """
        {
          "records": [
            {
              "startTime": "2026-08-20T12:00:00.000Z",
              "endTime": "2026-08-20T12:30:00.000Z",
              "values": {
                "type": { "stringVal": "Run" },
                "distance": { "fpVal": 5000.0 },
                "calories": { "fpVal": 320.0 }
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
            latestWorkout: decoded.records.first,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        ).latestWorkout

        XCTAssertEqual(workout?.type, "Run")
        XCTAssertEqual(workout?.durationSeconds, 1_800)
        XCTAssertEqual(workout?.distanceMeters, 5_000)
        XCTAssertEqual(workout?.calories, 320)
    }
}
