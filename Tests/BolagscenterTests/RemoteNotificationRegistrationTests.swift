import Foundation
import Testing
@testable import Bolagscenter

struct RemoteNotificationRegistrationTests {
    @Test
    func formatsAPNsDeviceTokenAsLowercaseHexWithoutDelimiters() {
        let token = Data([0x00, 0x0a, 0x10, 0xff])

        #expect(APNsDeviceTokenFormatter.hexString(from: token) == "000a10ff")
    }

    @Test
    func tokenSnapshotRoundTripsThroughJSON() throws {
        let snapshot = APNsTokenSnapshot(
            installationID: "test-installation",
            token: "000a10ff",
            environment: .sandbox,
            authorization: .provisional,
            receivedAt: Date(timeIntervalSince1970: 1_750_000_000),
            appVersion: "0.1.0",
            locale: "sv-SE"
        )
        let data = try JSONEncoder().encode(snapshot)

        #expect(try JSONDecoder().decode(APNsTokenSnapshot.self, from: data) == snapshot)
    }

    @Test
    func mapsEntitlementBuildSettingToBackendAPNsEnvironment() {
        #expect(
            APNsTokenEnvironment.configured(buildSetting: "development")
                == .sandbox
        )
        #expect(
            APNsTokenEnvironment.configured(buildSetting: "production")
                == .production
        )
    }
}
