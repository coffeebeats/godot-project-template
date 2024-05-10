# godot-project-template

A template repository for a Godot 4+ project.

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. Install the tools [used below](#code-submission) by following each of their specific installation instructions.

### Code submission

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    bin/gdformat -l 88 --check **/*.gd
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    bin/gdlint **/*.gd
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    ```sh
    godot \
        --quit \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir=res:// \
        -ginclude_subdirs \
        -gsuffix=_test.gd \
        -gexit
    ```

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/google-github-actions/release-please-action) automates releases.

### Secrets

After instantiating a project from this template repository, the default GitHub actions and workflows require the following repository secrets to be set:

- `BUTLER_API_KEY` - Used to authenticate the `butler` CLI tool with `itch.io`; required when publishing to `itch.io`.
- `GODOT_SCRIPT_ENCRYPTION_KEY` - Used to encrypt the export Game artifacts; recommended to create one per platform,channel pair.
- Various - Update code-signing and notarization secrets once the project is ready for release.

### Customization

In addition to [Secrets](#secrets), the following files should be customized for the instantiated repository:

- [.github/workflows/release-please.yaml](.github/workflows/release-please.yaml) - set the current project title when publishing.
- [.github/workflows/publish-game.yaml](.github/workflows/publish-game.yaml) - update the default project title and channel when publishing.
- [.github/workflows/export-project.yaml](.github/workflows/export-project.yaml) - update the `encryption-key` input when compiling and exporting.

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-infra/blob/main/CHANGELOG.md).

## **License**

> [!IMPORTANT]
> After instantiating this repository, consider removing this license if the project isn't intended to be open source.

[MIT License](https://github.com/coffeebeats/godot-infra/blob/main/LICENSE)
