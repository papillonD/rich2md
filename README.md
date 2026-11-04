# Wispr → Slack

A small macOS menu bar helper that makes text dictated in [Wispr Flow](https://wisprflow.ai) paste cleanly into Slack.

When you copy from Wispr Flow, the clipboard holds rich text (HTML). Slack's desktop app doesn't keep that formatting reliably, so headings, lists and bold text arrive flattened or mangled. Wispr → Slack watches for copies made in Wispr Flow and, the moment you switch to Slack, swaps the clipboard for clean Markdown. A plain ⌘V does the right thing. Switch to any other app and the original rich text is put back, so pasting into email, Notion or Google Docs works exactly as before.

## Features

- Works with an ordinary ⌘V: no special shortcut or extra step
- Markdown in Slack, original rich text everywhere else
- Keeps headings, bold, italics, strikethrough, inline code, links, nested bullet and numbered lists, and dividers
- Menu bar icon showing its state, with Pause, Open Log and Quit
- Starts at login and restarts itself if it ever crashes
- Runs entirely on your Mac: no network access, no accounts, no API keys

## Requirements

- macOS 11 (Big Sur) or later
- Apple's command line tools, which provide the Swift compiler. If you don't have them, run `xcode-select --install`
- [Wispr Flow](https://wisprflow.ai) and the Slack desktop app

## Installation

```bash
git clone https://github.com/papillonD/wispr-to-slack.git
cd wispr-to-slack
./install.sh
```

`install.sh` compiles the app, adds it to your login items (as a LaunchAgent at `~/Library/LaunchAgents/local.wispr2md.plist`) and starts it. A clipboard icon appears in your menu bar.

If macOS asks whether `wispr2md` may access the clipboard, allow it.

### Bold text in Slack

By default, bold text is written as `**double asterisks**`. If your Slack shows the asterisks instead of bold text, reinstall with single asterisks, which is Slack's own formatting style:

```bash
./install.sh --slack-bold
```

## Using it

1. Dictate in Wispr Flow as usual and copy the result.
2. Switch to Slack and press ⌘V. The message pastes as formatted Markdown.
3. Switch to any other app and press ⌘V. You get Wispr Flow's original rich text.

Copying anything new from another app clears the captured text, so Wispr → Slack never interferes with your normal clipboard.

### Menu bar icon

| Icon | Meaning |
|---|---|
| Clipboard outline | Running, waiting for a copy from Wispr Flow |
| Filled clipboard | A Wispr Flow copy has been captured and is ready |
| Pause symbol | Paused: Wispr Flow copies are left as they are |

Click the icon to:

- **Pause / Resume** (⌘P)
- **Open Log**, which shows what the app has done, at `~/Library/Logs/wispr2md.log`
- **Quit**, which stops it until you next log in

## How formatting is converted

| Wispr Flow | Pasted into Slack |
|---|---|
| Heading | Bold line |
| Bold | `**text**` (or `*text*` with `--slack-bold`) |
| Italic | `_text_` |
| Strikethrough | `~text~` |
| Inline code | `` `text` `` |
| Link | `[label](https://…)` |
| Bullet list | `- item`, indented four spaces per level |
| Numbered list | `1. item`, keeping the original numbering |
| Divider | `---` |

## Privacy

- Nothing leaves your Mac. The app makes no network connections and needs no API keys or sign-in.
- It only captures a copy if Wispr Flow is the app in front at the moment you copy. Everything else on your clipboard is ignored.
- The log records when text was captured and how many characters it contained, never the text itself.

## Updating

```bash
cd wispr-to-slack
git pull
./install.sh
```

## Uninstalling

```bash
./uninstall.sh
```

This stops the app and removes it from your login items. You can then delete the folder and, if you like, `~/Library/Logs/wispr2md.log`.

## Advanced

### Testing the converter

Convert a saved HTML file and print the Markdown, without touching the clipboard:

```bash
./wispr2md convert sample.html
```

### Using it with other apps

Only Slack receives Markdown by default. To add another app, put its bundle identifier in the `markdownApps` list in `wispr2md.swift`, then run `./install.sh` again. To find an app's bundle identifier:

```bash
osascript -e 'id of app "Obsidian"'
```

### How it works

The app checks the clipboard four times a second. When a new copy appears while Wispr Flow is the frontmost app, it keeps an exact copy of the original rich text and prepares a Markdown version. Each time you switch apps, it puts whichever version suits that app on the clipboard. Pausing or quitting always restores the original.

## Troubleshooting

- **Nothing changes when I paste into Slack.** Check the menu bar icon is there and not paused, then use **Open Log** to see whether the copy was captured. Copy from Wispr Flow's own window, so that Wispr Flow is the app in front when you copy.
- **`install.sh` fails with a compiler error.** Install Apple's command line tools with `xcode-select --install`, then run `./install.sh` again.
- **The icon has disappeared.** You may have quit it. Run `./install.sh` again, or log out and back in.

## Licence

Released under the [MIT Licence](LICENSE).

Wispr → Slack is an independent project and is not affiliated with or endorsed by Wispr or Slack Technologies.
