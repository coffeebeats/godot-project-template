---
name: add-translation
description: Add a new translatable string to the project. Use when adding UI elements, buttons, labels, or any user-facing text that needs localization.
allowed-tools: Read, Edit, Bash, Grep, Glob
---

Add a translatable string to the project. Only edit two files: `project/locale/messages.pot` and `project/locale/en_US.po`. Other locale files are updated automatically by a propagation command.

## Translation file format

Both files use **key-based `msgid`** values (e.g., `main_play`, `options_sound_volume`). Keys follow a hierarchical `snake_case` convention matching the UI location (e.g., `main_` for main menu, `save_slots_` for save UI, `options_sound_` for sound settings).

Each entry has a `#.` translator comment explaining what the string is and where it appears. If the string needs disambiguation, add a `msgctxt` line (see existing `button_prompt` and `actions_*` entries for examples).

## Steps

1. **Read both files** to find the correct insertion point. Place the new entry near related entries (group by UI area).

2. **Edit `messages.pot`** — add the entry with an empty `msgstr`:

   ```po
   #. Description of the string for translators, including where it appears.
   msgid "my_new_key"
   msgstr ""
   ```

3. **Edit `en_US.po`** — add the same entry with the English text as `msgstr`:

   ```po
   #. Description of the string for translators, including where it appears.
   msgid "my_new_key"
   msgstr "My English Text"
   ```

4. **Propagate to other locales** by running:

   ```sh
   for f in project/locale/*.po; do
     [ "$(basename "$f")" = "en_US.po" ] && continue
     poswap project/locale/en_US.po -t "$f" "${f}.tmp"
     msgmerge --update --backup=none "$f" "${f}.tmp"
     rm "${f}.tmp"
   done
   ```

5. **Validate** all translation files:

   ```sh
   for f in project/locale/*.pot project/locale/*.po; do
     msgfmt "$f" --check
   done
   ```

## Reference the key

Use the **key-based `msgid`** (not the English text) when referencing the string:
- In `.tscn` scene files: set `text = "my_new_key"`
- In GDScript: `tr("my_new_key")`