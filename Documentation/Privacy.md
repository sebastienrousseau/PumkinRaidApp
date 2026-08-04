# Privacy

Pumkin Raid has no advertising SDK, tracking domain, or developer-operated
analytics endpoint. Solo gameplay works offline. Settings, local scores, and
progression are stored only in the app's `UserDefaults` container.

The privacy manifest declares `CA92.1` for app-only `UserDefaults` persistence.
Game Center is optional and is operated through Apple's GameKit framework;
assisted scores are not submitted.

Re-audit the manifest and App Store privacy answers whenever analytics, cloud
storage, account, advertising, or third-party SDK functionality is introduced.
