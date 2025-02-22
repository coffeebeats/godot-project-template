# Changelog

## 1.6.2 (2025-02-22)

## What's Changed
* fix(ci): use correct variable type by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/299


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.6.1...v1.6.2

## 1.6.1 (2025-02-22)

## What's Changed
* fix(ci): set default value for `workflow_dispatch`-only input by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/297


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.6.0...v1.6.1

## 1.6.0 (2025-02-22)

## What's Changed
* feat(ci): make `publish-game` workflow standalone by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/280
* fix(ci): use PAT for `release-please` workflow to allow workflow file updates by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/282
* fix(ci): pass `RELEASE_PLEASE_TOKEN` to correct action by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/283
* chore(ci): restore default `GITHUB_TOKEN` permissions as documentation by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/285
* fix(project): remove incorrect, fuzzy translations of "Language" and "Display Language" by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/286
* fix(ci): use latest `godot-infra` changes to transfer entire compilation output directory to `export` job by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/287
* fix(ci): don't create cache directory now that source filepath is itself a directory by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/288
* fix(ci): bundle Agility SDK when exporting for Windows by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/289
* fix(ci): ensure `extra-bundled-files` is exported from `compile` job by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/290
* fix(ci): make bundled filepaths relative by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/291
* fix(ci): correctly loop over bundled files by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/292
* fix(ci): update `bundle` step now that `compile` step output is space-delimited by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/293
* fix(ci): revert pin of workflow actions to `main` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/281
* fix(project): eliminate crashing and stray nodes on main menu scene by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/294
* fix(project): eliminate `SteamConfigurator` errors by loading scene at runtime by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/295
* fix(web): eliminate unsupported API calls, set correct audio playback type by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/296


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.5.1...v1.6.0

## 1.5.1 (2025-02-18)

## What's Changed
* chore(addons): update `std`, `gut`, and `phantom_camera` to latest by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/266
* fix(system): work around import error likely resulting from engine bug by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/268
* fix(project): improve action set loading in main menu and placeholder game scene by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/269
* fix(project): translate new gameplay action sets by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/277
* chore(ci): disable `web` releases by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/278


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.5.0...v1.5.1

## 1.5.0 (2025-02-15)

## What's Changed
* chore(addons): update `std` to `v1.15.0` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/243
* chore(addons): update `std` to `v1.15.1` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/245
* feat(platform): integrate statistics support (e.g. achievements, leaderboards, and stats) by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/246
* chore(addons): update `std` to `v1.15.3` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/247
* fix(system): check for custom locale directory before attempting to read it by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/248
* feat(project): create `Tooltip` class for animated UI popovers  by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/249
* chore(project): remove redundant `ui_back` action by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/250
* chore(addons): update `std` to `v1.15.4` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/251
* fix(project): remove unnecessary signal disconnection; update default settings tab by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/252
* fix(system): create a `Systems` shim which allows globally accessing system components by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/253
* chore(addons): update `std` to `v1.15.5` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/254
* fix(project): revamp `Modal` to better handle stacking and focus by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/255
* feat(system): create an `Audio` system component using `std` types by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/256
* feat(project): add menu sounds and a main menu background music track by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/257
* fix(project): add dialog behavior to `Modal`; refactor main menu modals by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/258
* fix(project): implement an action prompt `Glyph` variant by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/259
* chore(addons): update `phantom_camera` to `0.8.2.3` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/260
* chore(addons): update addons to latest by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/261
* chore(addons): update `std` and `gut` to latest by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/262


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.4.0...v1.5.0

## 1.4.0 (2025-01-30)

## What's Changed
* chore(addons): update `std` to `v1.10.3` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/201
* fix(platform): restructure conditional nodes, fix orphaned nodes by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/203
* chore(addons): update `std` to `v1.11.1` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/204
* fix(platform): use updated config writer class name by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/205
* feat(system): implement a save system which supports a fixed number of slots and asynchronous loading of custom save data by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/211
* feat(project): create a save slot selection menu by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/212
* fix(project): change `System` reference to fix error by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/213
* chore(project,system): migrate `print` statements to `StdLogger` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/214
* fix(system): move save to trash if possible, delete contents first otherwise by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/215
* fix(system): clear cached save data on slot change; add `get_save_data` method by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/216
* feat(project): create a menu for managing save slots by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/218
* feat(project): create an example scene and example save data by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/219
* feat(project): create loading screen; wire up sample scene by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/220
* feat(project): implement font scaling; remove fragmented theming by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/221
* feat(project): add translation files for all planned languages; update source code to use message keys by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/222
* feat(ci): check and update translations during CI/CD runs by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/223
* fix(project): translate actions and action sets within the controls menu by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/224
* refactor(ci): streamline translation workflows; compile changed `.po` files into `.mo` files by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/225
* fix(project): localize Steam Input actions manifest; centralize input action translation by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/226
* feat(project,system): add language as a user setting by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/228
* feat(project): add translation support to the `Rebinder` scene; reorganize controls menu files by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/229
* feat(system): add support for custom translations by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/230
* feat(project,system): add a setting for changing button prompts by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/231
* fix(project): implement glyph option to hide when cursor is visible by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/232


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.3.0...v1.4.0

## 1.3.0 (2025-01-08)

## What's Changed
* fix(system): update action set configuration by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/178
* chore(addons): update `std` to latest by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/180
* chore(addons): update `std` to `v1.9.1` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/181
* chore(addons): update `std` to latest by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/182
* fix(ui): update `Glyph` scene to be simpler to work with by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/183
* feat(project): implement a `Binding` component to rebind actions by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/184
* fix(project): minor input/configuration adjustments; wire up tab switching by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/185
* chore(addons): update `std` to `v1.9.4` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/186
* fix(ui,project): expand Controls menu, add action set rebinding options by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/187
* refactor(project): move top-level `ui` folder, shared fonts and themes under `project/ui` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/188
* fix(ci): ensure failing tests fail the CI run by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/189
* chore(addons): update `std` to `v1.9.6` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/190
* chore(addons): update `std` to `v1.9.7` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/191
* chore(addons): update `std` to `v1.9.8` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/192
* chore(addons): update `GodotSteam` and `phantom_camera` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/193
* chore(addons): update `std` to `v1.9.9` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/194
* feat(project): implement Godot-backed rebinding for action sets by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/195
* chore(addons): update `std` to `v1.9.11` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/196
* feat(input): set up Steam- and Godot-backed component swapping by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/197
* chore(addons): update `std` to `v1.10.0` by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/198
* feat(platform): create a `Profile` platform component; add separate profile-specific settings by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/199
* fix(system): properly swap between Godot and Steam input by @coffeebeats in https://github.com/coffeebeats/godot-project-template/pull/200


**Full Changelog**: https://github.com/coffeebeats/godot-project-template/compare/v1.2.0...v1.3.0

## Changelog
