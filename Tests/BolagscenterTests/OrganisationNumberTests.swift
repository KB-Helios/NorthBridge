import Testing
@testable import Bolagscenter

struct OrganisationNumberTests {
    @Test
    func acceptsAndFormatsValidSwedishOrganisationNumber() throws {
        let number = try OrganisationNumber("556016-0680")

        #expect(number.digits == "5560160680")
        #expect(number.formatted == "556016-0680")
    }

    @Test
    func rejectsInvalidChecksum() {
        #expect(throws: OrganisationNumber.ValidationError.invalidChecksum) {
            try OrganisationNumber("556016-0681")
        }
    }

    @Test
    func rejectsPersonalNumberShape() {
        #expect(throws: OrganisationNumber.ValidationError.invalidOrganisationNumber) {
            try OrganisationNumber("191212-1212")
        }
    }
}
