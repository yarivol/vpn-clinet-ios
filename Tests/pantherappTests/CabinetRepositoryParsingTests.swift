//
//  CabinetRepositoryParsingTests.swift
//  pantherappTests
//
//  Pins down CabinetRepository.parseServers against Remnawave's real
//  per-protocol JSON shapes - this exact parsing already had one live bug
//  (hysteria's flat settings.address/settings.port, missed because vless/
//  trojan use nested settings.vnext[]/settings.servers[] instead) found and
//  fixed during the Xray-core migration on Android and mirrored here. The
//  fixture below exercises all three shapes plus the two filter rules
//  (hide "Авто" entries, treat 0.0.0.0 as an offline placeholder) so a
//  future refactor can't quietly reintroduce that class of bug.
//

import XCTest
@testable import pantherapp

final class CabinetRepositoryParsingTests: XCTestCase {

    private func makeRepository() -> CabinetRepository {
        CabinetRepository(api: APIClient(), hwid: "test-hwid")
    }

    private let fixtureJSON = """
    [
        {
            "remarks": "🌀 Авто-подбор",
            "outbounds": [
                { "tag": "proxy", "protocol": "vless", "settings": { "vnext": [ { "address": "1.1.1.1", "port": 443 } ] } }
            ]
        },
        {
            "remarks": "Германия",
            "outbounds": [
                { "tag": "proxy", "protocol": "vless", "settings": { "vnext": [ { "address": "1.2.3.4", "port": 443 } ] } },
                { "tag": "direct", "protocol": "freedom", "settings": {} }
            ]
        },
        {
            "remarks": "Канада",
            "outbounds": [
                { "tag": "proxy", "protocol": "trojan", "settings": { "servers": [ { "address": "5.6.7.8", "port": 443 } ] } }
            ]
        },
        {
            "remarks": "Обход Глушилок #1",
            "outbounds": [
                { "tag": "proxy", "protocol": "hysteria2", "settings": { "address": "9.9.9.9", "port": 50000 } }
            ]
        },
        {
            "remarks": "Финляндия",
            "outbounds": [
                { "tag": "proxy", "protocol": "vless", "settings": { "vnext": [ { "address": "0.0.0.0", "port": 1 } ] } }
            ]
        }
    ]
    """

    func testFiltersAutoSelectEntries() {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        XCTAssertFalse(servers.contains { $0.name.contains("Авто") })
    }

    func testParsesVlessVnextShape() throws {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        let germany = try XCTUnwrap(servers.first { $0.name == "Германия" })
        XCTAssertEqual(germany.host, "1.2.3.4")
        XCTAssertEqual(germany.port, 443)
        XCTAssertTrue(germany.isOnline)
    }

    func testParsesTrojanServersShape() throws {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        let canada = try XCTUnwrap(servers.first { $0.name == "Канада" })
        XCTAssertEqual(canada.host, "5.6.7.8")
        XCTAssertEqual(canada.port, 443)
        XCTAssertTrue(canada.isOnline)
    }

    /// The shape that was actually missed on first pass: hysteria has no
    /// nested vnext/servers array, host/port sit directly under `settings`.
    func testParsesHysteriaFlatAddressShape() throws {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        let bypass = try XCTUnwrap(servers.first { $0.name == "Обход Глушилок #1" })
        XCTAssertEqual(bypass.host, "9.9.9.9")
        XCTAssertEqual(bypass.port, 50000)
        XCTAssertTrue(bypass.isOnline)
    }

    func testTreatsZeroAddressAsOfflinePlaceholder() throws {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        let finland = try XCTUnwrap(servers.first { $0.name == "Финляндия" })
        XCTAssertFalse(finland.isOnline)
        XCTAssertNil(finland.host)
        XCTAssertNil(finland.port)
    }

    func testEachKeptServerCarriesItsOwnRawConfig() {
        let servers = makeRepository().parseServers(from: Data(fixtureJSON.utf8))
        for server in servers {
            XCTAssertNotNil(server.rawConfig, "\(server.name) should carry its own standalone config")
        }
    }

    func testMalformedJSONReturnsEmptyRatherThanCrashing() {
        let servers = makeRepository().parseServers(from: Data("not json".utf8))
        XCTAssertEqual(servers, [])
    }
}
