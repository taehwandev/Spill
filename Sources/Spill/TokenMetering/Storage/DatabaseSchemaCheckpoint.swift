import Foundation

struct DatabaseSchemaCheckpoint: Equatable {
    let fileIdentity: String?
    let schemaVersion: Int
}
