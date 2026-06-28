import Foundation

enum PrivateUsageConnectionResultNotification {
    static let didFinish = Notification.Name("SpillPrivateUsageConnectionDidFinish")

    private static let environmentKey = "environment"
    private static let errorMessageKey = "errorMessage"

    struct Payload: Equatable, Sendable {
        let environment: PrivateUsageUploadEnvironment
        let errorMessage: String?

        var didSucceed: Bool {
            errorMessage == nil
        }
    }

    static func postSuccess(
        environment: PrivateUsageUploadEnvironment,
        center: NotificationCenter = .default
    ) {
        post(
            Payload(environment: environment, errorMessage: nil),
            center: center
        )
    }

    static func postFailure(
        environment: PrivateUsageUploadEnvironment,
        error: Error,
        center: NotificationCenter = .default
    ) {
        postFailure(
            environment: environment,
            errorMessage: safeMessage(for: error),
            center: center
        )
    }

    static func postFailure(
        environment: PrivateUsageUploadEnvironment,
        errorMessage: String,
        center: NotificationCenter = .default
    ) {
        post(
            Payload(environment: environment, errorMessage: errorMessage),
            center: center
        )
    }

    static func payload(from notification: Notification) -> Payload? {
        guard notification.name == didFinish,
              let rawEnvironment = notification.userInfo?[environmentKey] as? String,
              let environment = PrivateUsageUploadEnvironment(rawValue: rawEnvironment)
        else {
            return nil
        }

        return Payload(
            environment: environment,
            errorMessage: notification.userInfo?[errorMessageKey] as? String
        )
    }

    private static func post(
        _ payload: Payload,
        center: NotificationCenter
    ) {
        var userInfo: [String: Any] = [
            environmentKey: payload.environment.rawValue
        ]
        if let errorMessage = payload.errorMessage {
            userInfo[errorMessageKey] = errorMessage
        }
        center.post(name: didFinish, object: nil, userInfo: userInfo)
    }

    private static func safeMessage(for error: Error) -> String {
        if let uploadError = error as? PrivateUsageUploadError {
            return uploadError.safeUserMessage
        }

        return TokenMeteringL10n.text(.privateUsageUploadUnavailableMessage)
    }
}
