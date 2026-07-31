import Foundation
import SwiftData

enum BolagscenterSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            UserAccountRecord.self,
            CompanyRecord.self,
            CompanyProfileRecord.self,
            CompanyMembershipRecord.self,
            CompanyResponsibilityRecord.self,
            CompanyRegistrationRecord.self,
            BeneficialOwnerRecord.self,
            CompanyIndustryCodeRecord.self,
            CompanyHistoryEventRecord.self,
            PersonRecord.self,
            BoardMemberRecord.self,
            BoardMeetingRecord.self,
            MeetingAttendanceRecord.self,
            AgendaItemRecord.self,
            BoardResolutionRecord.self,
            ActionItemRecord.self,
            ShareholderRecord.self,
            ShareClassRecord.self,
            ShareTransactionRecord.self,
            ShareCertificateRecord.self,
            DocumentRecord.self,
            DocumentVersionRecord.self,
            DeadlineRecord.self,
            DeadlineSupportingDocumentRecord.self,
            DeadlineReminderRecord.self,
            DeadlineActionEventRecord.self,
            FinancialMetricRecord.self,
            FinancialPlanRecord.self,
            IntegrationRecord.self,
            AuditEventRecord.self,
            NotificationPreferenceRecord.self,
            CompanyInvitationRecord.self
        ]
    }
}

enum BolagscenterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BolagscenterSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
