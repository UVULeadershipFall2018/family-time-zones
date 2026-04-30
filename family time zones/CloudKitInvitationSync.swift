import CloudKit
import CoreLocation
import Foundation

/// Syncs invitation metadata and invitee coarse location via CloudKit **public** database.
/// Invitee writes `InvitationReply` records they own; inviter reads them by `invitationID` (no CKShare required).
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

    /// Inviter publishes the invitation so the invitee can verify the link and post a reply.
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

    /// Invitee (or ongoing updates) publishes coarse location on a record they create/own.
    func uploadReply(invitationId: String, location: CLLocation?, completion: @escaping (Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: Self.replyRecordName(forInvitationId: invitationId))
        publicDB.fetch(withRecordID: recordID) { existing, fetchError in
            let record: CKRecord
            if let existing = existing, fetchError == nil {
                record = existing
            } else {
                record = CKRecord(recordType: Self.replyRecordType, recordID: recordID)
            }
            record["invitationID"] = invitationId as CKRecordValue
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

    /// Inviter pulls all replies for one invitation id (newest wins in caller).
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
