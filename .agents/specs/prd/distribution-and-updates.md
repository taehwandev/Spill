# Distribution And Updates PRD

## Document Contract

- Status: active
- Audience: product, engineering, QA, and release maintainers
- Purpose: define update UX and the supported distribution model
- Source of truth: this document owns update and distribution product requirements
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Release checklist](../../checklists/release.md)

## Update UX

Requirements:

- Users can check for updates from the status menu and Preferences.
- Preferences shows current version, latest known version, last check time, and
  update state.
- Update states include not checked, checking, up to date, update available,
  download opened, failed, and unavailable.
- Release notes and download/install actions must be explicit user actions.
- Automatic installation is not required for MVP.
- Sparkle appcast support may be used only when signing, notarization, appcast,
  and key management are ready.

Acceptance:

- Manual update check has a visible success or failure state.
- Update failures are redacted and actionable.
- Update UX does not imply signed automatic updates before release
  infrastructure exists.

## Distribution Requirements

Spill should be distributable outside the Mac App Store with Developer ID
signing and notarization.

The app should be open source and free by default. Paid support, sponsored
builds, or paid higher-frequency/multi-device web features can be considered
later, but core local functionality should remain usable without payment.

References:

- Apple Developer ID: https://developer.apple.com/support/developer-id/
- Apple notarization:
  https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Apple `NSStatusBar`: https://developer.apple.com/documentation/appkit/nsstatusbar
- Apple `NSScreen.safeAreaInsets`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
- [Private Usage Upload PRD](token-metering/private-usage-upload.md)
- [Local token metering architecture](../ard.md)

## Open Coverage Decision

The README currently names a minimum macOS version, while the former root PRD
did not own a compatibility matrix. Product and release review must define the
supported macOS versions, hardware architectures, upgrade path, and deprecation
policy in this document.

## Verification

- Verify manual update state transitions and redacted failures.
- Verify release artifacts satisfy the repository release checklist.
- Verify accepted compatibility requirements against build, package, and smoke
  verification environments.
