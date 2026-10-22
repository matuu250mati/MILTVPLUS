# Android Kotlin plugin migration — MILTVPLUS

## Scope

This work is limited to the Android build configuration and the four plugins reported by Flutter:
- `device_info_plus`
- `file_picker`
- `package_info_plus`
- `shared_preferences_android`

Working branch: `codex/m3u-integrity-report`.

## Verified baseline

- Flutter CI and Android QA APK jobs passed on commit `0dc96d1a6012d9f1db48f95554159fe5ec1d52c7`.
- The checked-in Android scaffold starts at AGP `8.11.1`, Gradle `8.14.3`, and Kotlin Gradle plugin `2.2.20`.
- `tool/bootstrap_android.sh` currently rewrites generated build files to AGP `9.0.1`, Gradle `9.1.0`, and Kotlin Gradle plugin `2.3.20` at CI time.
- The bootstrap explicitly keeps `android.builtInKotlin=false` and `android.newDsl=false`; therefore this toolchain upgrade does **not** itself migrate plugins off KGP.
- `pubspec.yaml` currently constrains `package_info_plus` to 8.x, `device_info_plus` to 11.x, and `file_picker` to 10.x.
- `shared_preferences` and `shared_preferences_android` are explicitly pinned to `2.3.5` and `2.3.4` to avoid untested Android implementation/API drift.
- A committed `pubspec.lock` was not found at the time of inspection, so the exact resolved dependency graph must be captured in CI before choosing upgrades. The Android workflow now prints Flutter/Dart and the resolved versions of all four target packages.

## Safety rules

1. Do not enable `android.builtInKotlin=true` until every Android plugin in the resolved dependency graph and the app's own Gradle configuration support it.
2. Do not upgrade `device_info_plus` to a release requiring AGP newer than 8.11.1 without coordinating and validating the Gradle toolchain.
3. Do not jump `file_picker` to 13.x without auditing its breaking Dart API changes (including `pickFiles` return type and `saveFile` arguments) at every call site.
4. Do not change the `shared_preferences_android` pin until the resolved dependency constraints and regression tests confirm a compatible pair.
5. Never treat a successful APK build alone as proof that the KGP warning is resolved.

## Completion criteria

- Record the exact Flutter/Dart versions and resolved versions of all four plugins in the CI log.
- Make the smallest compatible dependency/configuration change.
- Run dependency resolution, `flutter analyze`, all `flutter test` tests, Flutter Web release build, Android QA APK build, and APK signature verification.
- Re-check the build log for the KGP warning. If a plugin still applies KGP, keep the migration marked incomplete rather than suppressing the warning.
- Preserve the current app structure and avoid publishing/releasing production artifacts until all required checks pass.

## Status

Investigation in progress. The last recorded CI passed, but the Kotlin plugin migration is not yet verified complete.
