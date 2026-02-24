# **godot-project-template**

A template repository for a Godot 4+ project.

## **Development**

### **Setup**

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. Install the tools [used below](#code-submission) by following each of their specific installation instructions.

### **Code submission**

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    gdformat -l 88 --check **/*.gd
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    gdlint **/*.gd
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    > [!NOTE]
    > Schema migration tests require committed golden files in [tests/testdata/golden/saves](./tests/testdata/golden/saves/). If a golden file is missing (e.g. after a schema version bump), tests will fail. Regenerate goldens by running tests with `TEST_GENERATE_GOLDENS=1`. Be sure to review and commit the generated files before submitting.

    ```sh
    godot \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir="res://" \
        -ginclude_subdirs \
        -gprefix="" \
        -gsuffix="_test.gd" \
        -gexit
    ```

### **Tools**

#### **Translation**

Translation is supported using `gettext` tools. A `messages.pot` template file is located at [project/locale/messages.pot](project/locale/messages.pot) and contains messages used by the template. Translations to english have already been added, so new language support is as simple as creating a new `po` file with the translations.

Finally, CI/CD runs check that translations are accurate; any changes to template files will result in fuzzy messages, blocking releases.

#### **Fonts**

MSDF rendering is recommended for fonts, but many fonts contain overlapping contours [which render incorrectly in Godot](https://github.com/godotengine/godot/issues/52247). This can be fixed using [FontForge's `removeOverlap` utility](https://fontforge.org/docs/scripting/python/fontforge.html#fontforge.font.removeOverlap). This process is not automated, so if font artifacts are seen when using MSDF rendering, they must be fixed manually.

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/googleapis/release-please-action) automates releases.

### **Secrets**

After instantiating a project from this template repository, the default GitHub actions and workflows require the following repository secrets to be set:

- `BUTLER_API_KEY` - Used to authenticate the `butler` CLI tool with `itch.io`; required when publishing to `itch.io`.
- `GHA_TOKEN` - Used to commit formatting fixes to pull requests.
- `GODOT_SCRIPT_ENCRYPTION_KEY` - Used to encrypt the export Game artifacts; recommended to create one per platform,channel pair.
- Various - Update code-signing and notarization secrets once the project is ready for release.
- `RELEASE_PLEASE_TOKEN` - Enables release pull requests to run CI/CD workflows.

### **Customization**

In addition to [Secrets](#secrets), the following files should be customized for the instantiated repository:

- [.github/workflows/release-please.yaml](.github/workflows/release-please.yaml) - set the current project title when publishing.
- [.github/workflows/publish-game.yaml](.github/workflows/publish-game.yaml) - update the default project title and channel when publishing.
- [.github/workflows/export-project.yaml](.github/workflows/export-project.yaml) - update the `encryption-key` input when compiling and exporting.

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-project-template/blob/main/CHANGELOG.md).

## **License**

> [!IMPORTANT]
> After instantiating this repository, consider removing this license if the project isn't intended to be open source.

[MIT License](https://github.com/coffeebeats/godot-project-template/blob/main/LICENSE)
