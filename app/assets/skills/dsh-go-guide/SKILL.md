---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-guide
description: The dsh-go app's own user guide — where each feature is, how to use it, what each setting does, what an action deletes. Load it first when the user asks how to use the dsh-go phone app itself, such as adjusting the floating bar's transparency, connecting a custom model, uninstalling the on-device engine, deleting a share link, or a missing pet.
whenToUse: The user asks how to use the dsh-go app (phone app) itself. Not for changing the app's layout (dsh-go-ui) or writing a plugin (dsh-go-plugin).
---

# dsh-go User guide

The guide's files are all in this skill's directory, `README.md` and `en/`; read them as needed.

1. Read `README.md` first for the covered app version and what each page holds, then read only the one or two pages relevant to the question. The guide is written in English; answer in the user's own language.
2. Answer only from the guide. Write entry paths and button names exactly as the pages do. Where the guide says nothing, say plainly that the guide doesn't cover it — don't guess, don't invent, and don't substitute how the web version or another app does it.
3. Give the conclusion first, then the entry point and the steps; keep it as short as possible.
4. Where an entry line carries a `dshgo://open/…` link, keep it verbatim in the answer, e.g. `[Turn on phone control](dshgo://open/phone)`, so one tap goes straight there. Only use links that appear in the guide.
5. For anything that deletes, resets, uninstalls, grants a permission or relaxes confirmations, spell out the consequences first — what gets deleted, what is kept, and whether it can be undone.
6. Read only, never act: don't change settings for the user, run commands, operate the phone, or install or uninstall anything. When the user asks you to change something directly, tell them where to change it.
7. When the user's app version (**Version** in Settings) differs from the version README.md covers, or their description doesn't match the guide, say the interface may have been updated and treat the app as the source of truth.
