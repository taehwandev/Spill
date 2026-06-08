import Foundation
import XCTest

final class ReleaseNotarizationContractTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func testReleaseWorkflowUsesApiKeyNotarizationWithoutLegacyAppleCredentials() throws {
        let workflow = try read(".github/workflows/release.yml")

        XCTAssertTrue(workflow.contains("node scripts/verify-release-env.mjs"))
        XCTAssertTrue(workflow.contains("./scripts/notarize-release-artifacts.sh --app .build/Spill.app"))
        XCTAssertTrue(workflow.contains("./scripts/notarize-release-artifacts.sh --artifacts .build/release-artifacts"))
        XCTAssertTrue(workflow.contains("SPILL_SKIP_BUILD: \"1\""))
        XCTAssertTrue(workflow.contains("APPLE_NOTARYTOOL_API_KEY: ${{ secrets.APPLE_NOTARYTOOL_API_KEY }}"))
        XCTAssertTrue(workflow.contains("APPLE_NOTARYTOOL_API_KEY_ID: ${{ secrets.APPLE_NOTARYTOOL_API_KEY_ID }}"))
        XCTAssertTrue(workflow.contains("APPLE_NOTARYTOOL_API_ISSUER: ${{ secrets.APPLE_NOTARYTOOL_API_ISSUER }}"))
        XCTAssertTrue(workflow.contains("SPILL_BUILD_PRIVATE_USAGE_RELAY_URL: ${{ vars.SPILL_BUILD_PRIVATE_USAGE_RELAY_URL }}"))
        XCTAssertTrue(workflow.contains("SPILL_BUILD_PRIVATE_USAGE_WEB_URL: ${{ vars.SPILL_BUILD_PRIVATE_USAGE_WEB_URL }}"))
        XCTAssertTrue(workflow.contains(".build/release-artifacts/notarytool-logs/**"))

        XCTAssertFalse(workflow.contains("APPLE_ID"))
        XCTAssertFalse(workflow.contains("APPLE_PASSWORD"))
        XCTAssertFalse(workflow.contains("APPLE_TEAM_ID"))
        XCTAssertFalse(workflow.contains("APPLE_APP_SPECIFIC_PASSWORD"))
        XCTAssertFalse(workflow.contains("SPILL_NOTARY_KEYCHAIN_PROFILE"))
        XCTAssertFalse(workflow.contains("store-credentials"))
        XCTAssertFalse(workflow.contains("--apple-id"))
        XCTAssertFalse(workflow.contains("--password"))
        XCTAssertFalse(workflow.contains("--keychain-profile"))
    }

    func testPackageScriptLeavesNotarizationToSeparateScript() throws {
        let packageScript = try read("scripts/package-release.sh")

        XCTAssertTrue(packageScript.contains("SPILL_SKIP_BUILD"))
        XCTAssertFalse(packageScript.contains("notarytool submit"))
        XCTAssertFalse(packageScript.contains("stapler staple"))
        XCTAssertFalse(packageScript.contains("SPILL_NOTARY_KEYCHAIN_PROFILE"))
        XCTAssertFalse(packageScript.contains("--keychain-profile"))
    }

    func testReleaseBuildUsesProductionWebConnectionAndRegistersURLScheme() throws {
        let buildScript = try read("scripts/build-app.sh")
        let envExample = try read(".env.example")
        let uploadModels = try read("Sources/Spill/TokenMetering/PrivateUsageUploadModels.swift")

        XCTAssertTrue(buildScript.contains("swift build -c release --package-path \"$ROOT_DIR\""))
        XCTAssertTrue(buildScript.contains("<key>CFBundleURLSchemes</key>"))
        XCTAssertTrue(buildScript.contains("<string>spill</string>"))
        XCTAssertTrue(buildScript.contains("SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT"))
        XCTAssertTrue(buildScript.contains("SPILL_BUILD_PRIVATE_USAGE_RELAY_URL"))
        XCTAssertTrue(buildScript.contains("SPILL_BUILD_PRIVATE_USAGE_WEB_URL"))
        XCTAssertTrue(buildScript.contains("<key>SPILLPrivateUsageEnvironment</key>"))
        XCTAssertTrue(buildScript.contains("<key>SPILLPrivateUsageRelayURL</key>"))
        XCTAssertTrue(buildScript.contains("<key>SPILLPrivateUsageWebURL</key>"))
        XCTAssertTrue(buildScript.contains("SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED"))
        XCTAssertTrue(buildScript.contains("PRIVATE_USAGE_REQUIRES_CONFIGURATION=false"))
        XCTAssertTrue(buildScript.contains("is required when SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED=1"))
        XCTAssertTrue(buildScript.contains("PRIVATE_USAGE_RELAY_URL=\"${SPILL_BUILD_PRIVATE_USAGE_RELAY_URL:-}\""))
        XCTAssertTrue(buildScript.contains("PRIVATE_USAGE_WEB_URL=\"${SPILL_BUILD_PRIVATE_USAGE_WEB_URL:-}\""))
        XCTAssertFalse(buildScript.contains("DEFAULT_PRIVATE_USAGE_WEB_URL"))
        XCTAssertFalse(buildScript.contains("DEFAULT_PRIVATE_USAGE_RELAY_URL"))
        XCTAssertTrue(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED=0"))
        XCTAssertTrue(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT="))
        XCTAssertTrue(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_WEB_URL="))
        XCTAssertTrue(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_RELAY_URL="))
        XCTAssertFalse(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_WEB_URL=http"))
        XCTAssertFalse(envExample.contains("SPILL_BUILD_PRIVATE_USAGE_RELAY_URL=http"))
        XCTAssertTrue(uploadModels.contains("#else\n        return .production\n        #endif"))
        XCTAssertTrue(uploadModels.contains("SPILL_PRIVATE_USAGE_WEB_URL"))
        XCTAssertTrue(uploadModels.contains("SPILLPrivateUsageWebURL"))
        XCTAssertTrue(uploadModels.contains("SPILLPrivateUsageRelayURL"))
        XCTAssertFalse(uploadModels.contains("#/connect-device"))
        XCTAssertFalse(uploadModels.contains("functions/v1/private-usage-relay"))
    }

    func testReleaseBuildKeepsPrivateUsageUploadDebugOnly() throws {
        let uploadModels = try read("Sources/Spill/TokenMetering/PrivateUsageUploadModels.swift")
        let preferencesSection = try read("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift")
        let appDelegate = try read("Sources/Spill/App/AppDelegate.swift")

        XCTAssertTrue(uploadModels.contains("enum PrivateUsageUploadFeatureAvailability"))
        XCTAssertTrue(uploadModels.contains("#if DEBUG\n        return true\n        #else\n        return false\n        #endif"))
        XCTAssertTrue(preferencesSection.contains("if PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild"))
        XCTAssertTrue(appDelegate.contains("guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else"))
    }

    func testNotarizationScriptProtectsInlineApiKeyAndValidatesJsonStatus() throws {
        let script = try read("scripts/notarize-release-artifacts.sh")

        XCTAssertTrue(script.contains(#"NOTARYTOOL_API_KEY_VALUE="${APPLE_NOTARYTOOL_API_KEY:-}""#))
        XCTAssertTrue(script.contains("unset APPLE_NOTARYTOOL_API_KEY"))
        XCTAssertTrue(script.contains("mktemp -d"))
        XCTAssertTrue(script.contains("umask 077"))
        XCTAssertTrue(script.contains("printf '%s' \"$NOTARYTOOL_API_KEY_VALUE\""))
        XCTAssertFalse(script.contains("printf '%s' \"$APPLE_NOTARYTOOL_API_KEY\""))

        XCTAssertTrue(script.contains("--key \"$api_key_path\""))
        XCTAssertTrue(script.contains("--key-id \"$APPLE_NOTARYTOOL_API_KEY_ID\""))
        XCTAssertTrue(script.contains("--issuer \"$APPLE_NOTARYTOOL_API_ISSUER\""))
        XCTAssertTrue(script.contains("--wait"))
        XCTAssertTrue(script.contains("--timeout \"$APPLE_NOTARYTOOL_TIMEOUT\""))
        XCTAssertTrue(script.contains("--output-format json"))

        XCTAssertTrue(script.contains("json_field \"$submit_json\" id"))
        XCTAssertTrue(script.contains("json_field \"$submit_json\" status"))
        XCTAssertTrue(script.contains("if [[ \"$status\" != \"Accepted\" ]]"))
        XCTAssertTrue(script.contains("xcrun notarytool log"))
        XCTAssertTrue(script.contains("safe_artifact_label \"$artifact\""))

        XCTAssertFalse(script.contains("APPLE_ID"))
        XCTAssertFalse(script.contains("APPLE_PASSWORD"))
        XCTAssertFalse(script.contains("APPLE_TEAM_ID"))
        XCTAssertFalse(script.contains("APPLE_APP_SPECIFIC_PASSWORD"))
        XCTAssertFalse(script.contains("store-credentials"))
        XCTAssertFalse(script.contains("--apple-id"))
        XCTAssertFalse(script.contains("--password"))
        XCTAssertFalse(script.contains("--keychain-profile"))
    }

    func testReleaseArtifactHelpersDeduplicateAndHashDiagnosticLabels() throws {
        let helper = try read("scripts/release-artifacts.sh")

        XCTAssertTrue(helper.contains("canonical_artifact_path()"))
        XCTAssertTrue(helper.contains("safe_artifact_label()"))
        XCTAssertTrue(helper.contains("collect_unique_artifacts()"))
        XCTAssertTrue(helper.contains("local -a artifacts=()"))
        XCTAssertTrue(helper.contains("shasum -a 256"))
        XCTAssertTrue(helper.contains("substr($1, 1, 12)"))
    }

    func testReleaseEnvVerifierAcceptsApiKeyContract() throws {
        let result = try runVerifier(environment: validReleaseEnvironment())

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("App Store Connect API-key notarization environment is present"))
    }

    func testReleaseEnvVerifierRejectsInlineKeyAndKeyPathConflict() throws {
        var environment = validReleaseEnvironment()
        environment["APPLE_NOTARYTOOL_API_KEY_PATH"] = "/tmp/AuthKey_PLACEHOLDER.p8"

        let result = try runVerifier(environment: environment)

        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.stderr.contains("Set only one of APPLE_NOTARYTOOL_API_KEY or APPLE_NOTARYTOOL_API_KEY_PATH"))
    }

    func testReleaseEnvVerifierRejectsProfileAndApiKeyAuthMix() throws {
        var environment = validReleaseEnvironment()
        environment["APPLE_NOTARYTOOL_PROFILE"] = "release-notary-profile"

        let result = try runVerifier(environment: environment)

        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.stderr.contains("Set only one notarytool auth method"))
    }

    func testReleaseDocsUseApiKeySecretNamesOnly() throws {
        let docs = try [
            read("README.md"),
            read(".env.example"),
            read(".env.release.example"),
            read(".agents/build-and-run.md")
        ].joined(separator: "\n")

        XCTAssertTrue(docs.contains("APPLE_NOTARYTOOL_API_KEY"))
        XCTAssertTrue(docs.contains("APPLE_NOTARYTOOL_API_KEY_ID"))
        XCTAssertTrue(docs.contains("APPLE_NOTARYTOOL_API_ISSUER"))
        XCTAssertFalse(docs.contains("APPLE_ID"))
        XCTAssertFalse(docs.contains("APPLE_PASSWORD"))
        XCTAssertFalse(docs.contains("APPLE_TEAM_ID"))
        XCTAssertFalse(docs.contains("APPLE_APP_SPECIFIC_PASSWORD"))
        XCTAssertFalse(docs.contains("SPILL_NOTARY_KEYCHAIN_PROFILE"))
        XCTAssertFalse(docs.contains("store-credentials"))
    }

    private func validReleaseEnvironment() -> [String: String] {
        [
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin",
            "MACOS_DEVELOPER_ID_CERTIFICATE_BASE64": "base64-placeholder",
            "MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD": "certificate-password-placeholder",
            "MACOS_CODESIGN_IDENTITY": "Developer ID Application: Example Name (TEAMID)",
            "APPLE_NOTARYTOOL_API_KEY": "placeholder-private-key-content",
            "APPLE_NOTARYTOOL_API_KEY_ID": "KEYID12345",
            "APPLE_NOTARYTOOL_API_ISSUER": "00000000-0000-0000-0000-000000000000"
        ]
    }

    private func runVerifier(environment: [String: String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", root.appendingPathComponent("scripts/verify-release-env.mjs").path]
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return (
            process.terminationStatus,
            String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
