## 0.1.0

* Add platform-aware app update checks for Android, macOS, Windows, and iOS/iPadOS.
* Add installer channel metadata from Rosemary backend, including APK, DMG, EXE, MSI, App Store, and TestFlight flows.
* Add store-link launching for iOS/iPadOS updates and external update channels.
* Improve desktop installer handling for macOS and Windows packages.
* Update generated request/response models for the new cross-platform update payload.
* Add `url_launcher` dependency for external update flows.

## 0.0.2

* Fix: update check endpoint changed to `/update`.
* Docs: README improved for pub.dev (badges, example).
* Feat: add minimal example app under `example/`.
* Feat: Android APK auto-install support via `open_file_plus`.

## 0.0.1

* Initial release.
* Added support for Rosemary backend.
* Included script interpreter for update patches.
* Added APK installation support for Android.
