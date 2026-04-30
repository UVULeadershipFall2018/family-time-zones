import CloudKit
import CoreLocation
import Foundation

/// CloudKit **public** database: inviter creates `Invitation`; invitee owns `InvitationReply` with **time zone** (+ optional coarse location).
final class CloudKitInvitationSync {
    static let shared = CloudKitInvitationSync()

    private let container = CKContainer.default()
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    static let invitationRecordType = "Invitation"
    static let replyRecordType = "InvitationReply"

    private init() {}

    func checkAccountStatus(completion: @escaping (CKAccountStatus, Error?) -> Void) {
        container.accountStatus(completionHandler: completion)
    }

    func uploadInvitation(id: String, inviterDisplayName: String, inviteeEmail: String, completion: @escaping (Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: Self.safeRecordName(id))
        let record = CKRecord(recordType: Self.invitationRecordType, recordID: recordID)
        record["inviterDisplayName"] = inviterDisplayName as CKRecordValue
        record["inviteeEmail"] = inviteeEmail as CKRecordValue
        record["status"] = NSNumber(value: 0)
        record["createdAt"] = Date() as CKRecordValue

        publicDB.save(record) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    func fetchInvitation(id: String, completion: @escaping (CKRecord?, Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: Self.safeRecordName(id))
        publicDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                completion(record, error)
            }
        }
    }

    /// Invitee publishes **time zone** when it changes; optional coarse location for fallback display.
    func uploadReply(
        invitationId: String,
        location: CLLocation?,
        timeZoneIdentifier: String?,
        completion: @escaping (Error?) -> Void
    ) {
        let recordID = CKRecord.ID(recordName: Self.replyRecordName(forInvitationId: invitationId))
        publicDB.fetch(withRecordID: recordID) { existing, fetchError in
            let record: CKRecord
            if let existing = existing, fetchError == nil {
                record = existing
            } else {
                record = CKRecord(recordType: Self.replyRecordType, recordID: recordID)
            }
            record["invitationID"] = invitationId as CKRecordValue
            if let tz = timeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !tz.isEmpty {
                record["timeZoneIdentifier"] = tz as CKRecordValue
            }
            if let loc = location {
                record["latitude"] = NSNumber(value: loc.coordinate.latitude)
                record["longitude"] = NSNumber(value: loc.coordinate.longitude)
            }
            record["updatedAt"] = Date() as CKRecordValue

            self.publicDB.save(record) { _, error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func fetchReplies(invitationId: String, completion: @escaping ([CKRecord], Error?) -> Void) {
        let predicate = NSPredicate(format: "invitationID == %@", invitationId)
        let query = CKQuery(recordType: Self.replyRecordType, predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = CKQueryOperation.maximumResults

        var records: [CKRecord] = []
        operation.recordMatchedBlock = { _, result in
            if case let .success(record) = result {
                records.append(record)
            }
        }
        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(records, nil)
                case .failure(let error):
                    completion(records, error)
                }
            }
        }
        publicDB.add(operation)
    }

    static func safeRecordName(_ id: String) -> String {
        id.replacingOccurrences(of: "/", with: "-")
    }

    private static func replyRecordName(forInvitationId id: String) -> String {
        "reply-" + safeRecordName(id)
    }
}
