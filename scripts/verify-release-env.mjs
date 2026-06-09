#!/usr/bin/env node

const requiredSigningEnv = [
  'MACOS_DEVELOPER_ID_CERTIFICATE_BASE64',
  'MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD',
  'MACOS_CODESIGN_IDENTITY',
];

const requiredApiKeyEnv = [
  'APPLE_NOTARYTOOL_API_KEY_ID',
  'APPLE_NOTARYTOOL_API_ISSUER',
];

const profileAuthEnv = [
  'APPLE_NOTARYTOOL_PROFILE',
  'APPLE_NOTARYTOOL_KEYCHAIN',
];

const isPresent = (name) => Boolean((process.env[name] ?? '').trim());

const missing = [];
const invalid = [];

for (const name of requiredSigningEnv) {
  if (!isPresent(name)) missing.push(name);
}

const hasInlineApiKey = isPresent('APPLE_NOTARYTOOL_API_KEY');
const hasApiKeyPath = isPresent('APPLE_NOTARYTOOL_API_KEY_PATH');
const hasApiKeyMaterial = hasInlineApiKey || hasApiKeyPath;
const hasProfileAuth = profileAuthEnv.some(isPresent);

if (hasInlineApiKey && hasApiKeyPath) {
  invalid.push('Set only one of APPLE_NOTARYTOOL_API_KEY or APPLE_NOTARYTOOL_API_KEY_PATH.');
}

if (hasProfileAuth && hasApiKeyMaterial) {
  invalid.push('Set only one notarytool auth method: API key env/path or keychain profile auth.');
}

if (hasProfileAuth && !hasApiKeyMaterial) {
  invalid.push('notarytool keychain profile auth is not supported by the Spill release pipeline. Use App Store Connect API key auth.');
}

if (!hasApiKeyMaterial) {
  missing.push('APPLE_NOTARYTOOL_API_KEY');
}

if (hasApiKeyMaterial) {
  for (const name of requiredApiKeyEnv) {
    if (!isPresent(name)) missing.push(name);
  }
}

if (isPresent('MACOS_CODESIGN_IDENTITY') && !process.env.MACOS_CODESIGN_IDENTITY.trim().startsWith('Developer ID Application:')) {
  invalid.push('MACOS_CODESIGN_IDENTITY must be a Developer ID Application identity for notarized macOS distribution.');
}

if (missing.length > 0 || invalid.length > 0) {
  for (const message of invalid) {
    console.error(message);
  }
  if (missing.length > 0) {
    console.error(`Missing required release environment variables: ${[...new Set(missing)].join(', ')}`);
  }
  process.exit(2);
}

console.log('macOS Developer ID signing and App Store Connect API-key notarization environment is present.');
