import Testing
@testable import Bolagscenter

struct PermissionPolicyTests {
    private let policy = PermissionPolicy()

    @Test
    func ownerCanManageOwnershipAndUsers() {
        #expect(policy.allows(.manageOwnership, for: .owner))
        #expect(policy.allows(.manageUsers, for: .owner))
    }

    @Test
    func auditorCannotMutateCompanyOrOwnership() {
        #expect(!policy.allows(.editCompany, for: .auditor))
        #expect(!policy.allows(.manageOwnership, for: .auditor))
        #expect(!policy.allows(.manageFinance, for: .auditor))
        #expect(policy.allows(.viewFinance, for: .auditor))
    }

    @Test
    func readOnlyAdvisorCannotCreateDeadlinesOrDocuments() {
        #expect(!policy.allows(.manageDeadlines, for: .readOnlyAdvisor))
        #expect(!policy.allows(.manageDocuments, for: .readOnlyAdvisor))
        #expect(policy.allows(.viewCompany, for: .readOnlyAdvisor))
    }

    @Test
    func boardMemberCanManageBoardButNotOwnership() {
        #expect(policy.allows(.manageBoard, for: .boardMember))
        #expect(!policy.allows(.manageOwnership, for: .boardMember))
    }

    @Test
    func chiefExecutiveCanManageBoardButNotShareholderRegister() {
        #expect(policy.allows(.manageBoard, for: .chiefExecutive))
        #expect(policy.allows(.manageFinance, for: .chiefExecutive))
        #expect(!policy.allows(.manageOwnership, for: .chiefExecutive))
    }
}
