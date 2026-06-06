import Foundation
let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
print("App Support URL: \(url.path)")
let eventsURL = url.appendingPathComponent("Spill").appendingPathComponent("token-metering").appendingPathComponent("events.json")
print("Events JSON path: \(eventsURL.path)")
print("File exists: \(FileManager.default.fileExists(atPath: eventsURL.path))")
