//
//  CabinetRepositoryMappingTests.swift
//  pantherappTests
//
//  Pins down CabinetRepository.toSubscription's mapping rules - the
//  username-vs-firstName display-name fallback, subLink-vs-connectUrl
//  priority, and that a missing subscription reads as inactive rather than
//  crashing or defaulting to active.
//

import XCTest
@testable import pantherapp

final class CabinetRepositoryMappingTests: XCTestCase {

    private func makeRepository() -> CabinetRepository {
        CabinetRepository(api: APIClient(), hwid: "test-hwid")
    }

    func testDisplayNamePrefersUsernameOverFirstName() {
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: "ivan", firstName: "Ivan",
            subscription: nil, deviceLimit: 3, currentDevices: 1,
            subLink: nil, connectUrl: nil, trafficUsed: nil, trafficLimit: nil
        )
        XCTAssertEqual(makeRepository().toSubscription(me).displayName, "@ivan")
    }

    func testDisplayNameFallsBackToFirstNameWhenNoUsername() {
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: nil, firstName: "Ivan",
            subscription: nil, deviceLimit: 3, currentDevices: 1,
            subLink: nil, connectUrl: nil, trafficUsed: nil, trafficLimit: nil
        )
        XCTAssertEqual(makeRepository().toSubscription(me).displayName, "Ivan")
    }

    func testMissingSubscriptionReadsAsInactiveNotCrashing() {
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: "ivan", firstName: nil,
            subscription: nil, deviceLimit: 3, currentDevices: 1,
            subLink: nil, connectUrl: nil, trafficUsed: nil, trafficLimit: nil
        )
        let subscription = makeRepository().toSubscription(me)
        XCTAssertFalse(subscription.isActive)
        XCTAssertEqual(subscription.daysLeft, 0)
    }

    func testActiveStatusIsCaseSensitiveExactMatch() {
        let sub = SubscriptionDto(status: "active", planCode: "pro", expiresAt: nil, daysLeft: 12, deviceLimit: 3)
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: nil, firstName: nil,
            subscription: sub, deviceLimit: 3, currentDevices: 1,
            subLink: nil, connectUrl: nil, trafficUsed: nil, trafficLimit: nil
        )
        let subscription = makeRepository().toSubscription(me)
        XCTAssertTrue(subscription.isActive)
        XCTAssertEqual(subscription.daysLeft, 12)
    }

    func testSubLinkTakesPriorityOverConnectUrl() {
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: nil, firstName: nil,
            subscription: nil, deviceLimit: 3, currentDevices: 1,
            subLink: "https://sub.example/a", connectUrl: "https://connect.example/b",
            trafficUsed: nil, trafficLimit: nil
        )
        XCTAssertEqual(makeRepository().toSubscription(me).subLink, "https://sub.example/a")
    }

    func testFallsBackToConnectUrlWhenSubLinkMissing() {
        let me = CabinetMeResponse(
            userId: 1, telegramId: 1, username: nil, firstName: nil,
            subscription: nil, deviceLimit: 3, currentDevices: 1,
            subLink: nil, connectUrl: "https://connect.example/b",
            trafficUsed: nil, trafficLimit: nil
        )
        XCTAssertEqual(makeRepository().toSubscription(me).subLink, "https://connect.example/b")
    }
}
