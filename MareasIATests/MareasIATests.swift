//
//  MareasIATests.swift
//  MareasIATests
//
//  Created by Alexander Rojas on 31/03/26.
//

import XCTest
@testable import MareasIA

final class MareasIATests: XCTestCase {

    override func setUpWithError() throws {
        URLProtocol.registerClass(URLProtocolMock.self)
    }

    override func tearDownWithError() throws {
        URLProtocolMock.testResponses = [:]
        URLProtocol.unregisterClass(URLProtocolMock.self)
    }

    func testExample() async throws {
        // This is an example of a functional test case.
        _ = try await fetchTodayTides_parsesJSONAndInfersEvents()
    }

    func testPerformanceExample() throws {
        self.measure {
        }
    }

    // MARK: - Model behavior

    func citySuggestion_subtitleIncludesCountryWhenPresent() {
        let s = CitySuggestion(name: "Vigo", country: "Spain", latitude: 42.0, longitude: -8.0)
        XCTAssertEqual(s.subtitle, "Vigo, Spain")
    }

    func citySuggestion_subtitleFallsBackToNameWhenCountryMissing() {
        let s = CitySuggestion(name: "Vigo", country: nil, latitude: 42.0, longitude: -8.0)
        XCTAssertEqual(s.subtitle, "Vigo")

        let s2 = CitySuggestion(name: "Vigo", country: "", latitude: 42.0, longitude: -8.0)
        XCTAssertEqual(s2.subtitle, "Vigo")
    }

    // MARK: - TideService integration (with network stubbing)

    func fetchTodayTides_parsesJSONAndInfersEvents() async throws {
        // Prepare marine API response with times and tide heights that include highs and lows
        let json: [String: Any] = [
            "timezone": "UTC",
            "hourly": [
                "time": [
                    "2026-04-07T00:00",
                    "2026-04-07T01:00",
                    "2026-04-07T02:00",
                    "2026-04-07T03:00",
                    "2026-04-07T04:00"
                ],
                "tide_height": [1.0, 2.5, 1.0, 3.0, 2.0]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        URLProtocolMock.testResponses = ["marine-api.open-meteo.com": (200, data)]

        let result = try await TideService.fetchTodayTides(latitude: 42.24, longitude: -8.72)

        XCTAssertEqual(result.points.count, 5)
        XCTAssertEqual(result.points[1].height, 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.points[3].height, 3.0, accuracy: 0.0001)

        // Expect two highs (at 01:00 and 03:00) and one low (at 02:00)
        let highs = result.events.filter { $0.kind == .high }
        let lows = result.events.filter { $0.kind == .low }

        XCTAssertEqual(highs.count, 2)
        XCTAssertEqual(lows.count, 1)

        // Events should be sorted by time ascending
        let times = result.events.map { $0.time }
        let sortedTimes = times.sorted()
        XCTAssertEqual(times, sortedTimes)
    }

    func fetchTodayTides_throwsInvalidDataWhenHourlyMissing() async {
        let json: [String: Any] = [
            "timezone": "UTC"
            // no hourly
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        URLProtocolMock.testResponses = ["marine-api.open-meteo.com": (200, data)]

        do {
            _ = try await TideService.fetchTodayTides(latitude: 0, longitude: 0)
            XCTFail("Expected invalidData error")
        } catch let error as TideServiceError {
            XCTAssertEqual(error, TideServiceError.invalidData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func fetchTodayTides_throwsInvalidDataWhenArraysMismatch() async {
        let json: [String: Any] = [
            "timezone": "UTC",
            "hourly": [
                "time": ["2026-04-07T00:00","2026-04-07T01:00"],
                "tide_height": [1.0]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        URLProtocolMock.testResponses = ["marine-api.open-meteo.com": (200, data)]

        do {
            _ = try await TideService.fetchTodayTides(latitude: 0, longitude: 0)
            XCTFail("Expected invalidData error")
        } catch let error as TideServiceError {
            XCTAssertEqual(error, TideServiceError.invalidData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func searchCities_parsesGeocodingResponseIntoCitySuggestions() async throws {
        let json: [String: Any] = [
            "results": [
                [
                    "name": "Vigo",
                    "country": "Spain",
                    "latitude": 42.2406,
                    "longitude": -8.7207
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        URLProtocolMock.testResponses = ["geocoding-api.open-meteo.com": (200, data)]

        let results = try await TideService.searchCities(query: "Vigo")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Vigo")
        XCTAssertEqual(results.first?.country, "Spain")
        XCTAssertEqual(results.first?.latitude, 42.2406)
    }

    func searchCities_throwsNetworkErrorOnNon200Response() async {
        URLProtocolMock.testResponses = ["geocoding-api.open-meteo.com": (500, Data())]

        do {
            _ = try await TideService.searchCities(query: "Vigo")
            XCTFail("Expected networkError")
        } catch let error as TideServiceError {
            XCTAssertEqual(error, TideServiceError.networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - URLProtocolMock

final class URLProtocolMock: URLProtocol {
    static var testResponses: [String: (Int, Data?)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            let resp = HTTPURLResponse(url: request.url ?? URL(string: "about:blank")!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        if let (status, data) = URLProtocolMock.testResponses[host] {
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let d = data { client?.urlProtocol(self, didLoad: d) }
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
