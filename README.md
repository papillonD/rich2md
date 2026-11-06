# Rich 2 MD

A small macOS menu bar helper that pastes rich text as Markdown in the apps and websites that want Markdown, and as normal rich text everywhere else.

Copy formatted text from anywhere: a [Wispr Flow](https://wisprflow.ai) summary, a Google Doc, a Notion page, a web page, an email, Apple Notes. Switch to Slack, Obsidian, VS Code, ChatGPT or GitHub and press ⌘V: you get clean Markdown with headings, lists, bold and links intact. Switch to Google Docs or Mail and ⌘V pastes the original rich text, exactly as before.

## Features

- Works with an ordinary ⌘V: no special shortcut or extra step
- Choose which apps and websites get Markdown from the menu bar
- Detects websites by the address of your current browser tab (Safari, Chrome, Arc, Brave, Edge, Vivaldi)
- Uses the right Markdown style for each destination, for example bold headings for Slack and `*single*` asterisks for WhatsApp
- Converts headings, bold, italics, strikethrough, links, inline code, code blocks, nested bullet and numbered lists, tables and dividers
- Understands rich text from browsers, Google Docs, Notion, Wispr Flow, Microsoft Word and Outlook, Apple Notes, TextEdit and Pages
- Leaves commands, code and single-line copies alone, so copying a command from a web page into Terminal still pastes cleanly
- Starts at login and restarts itself if it ever crashes
- Runs entirely on your Mac: no network access, no accounts, no API keys

## Requirements

- macOS 11 (Big Sur) or later
- Apple's command line tools, which provide the Swift compiler. If you don't have them, run `xcode-select --install`

## Installation

```bash
git clone https://github.com/papillonD/rich2md.git
cd rich2md
./install.sh
```

`install.sh` compiles the app, adds it to your login items (as a LaunchAgent at `~/Library/LaunchAgents/local.rich2md.plist`) and starts it. A clipboard icon appears in your menu bar.

If you installed an earlier version of this tool, `install.sh` removes it for you.

### Permissions

macOS may ask you to allow two things. Both are optional, but each one unlocks a feature:

- **Clipboard access.** Allow it, or Rich 2 MD can't see what you copy.
- **"Rich 2 MD wants access to control Google Chrome"** (or Safari, Arc…). This appears the first time Rich 2 MD needs to know which website you're on. It only reads the address of the current tab, never the page contents. If you don't allow it, Markdown apps still work but Markdown websites don't. You can change your mind later in **System Settings → Privacy & Security → Automation**, or from **Allow Website Detection…** in the menu.

## Using it

1. Copy formatted text from anywhere.
2. Switch to a Markdown app or website you've ticked and press ⌘V. You get Markdown.
3. Switch anywhere else and press ⌘V. You get the original rich text.

You can switch back and forth as often as you like. Copying something new replaces what Rich 2 MD is holding.

### Choosing apps and websites

Click the menu bar icon:

- **Markdown Apps** lists the Markdown apps installed on your Mac. Tick or untick each one. **Add Other App…** adds any app that isn't listed.
- **Markdown Websites** lists popular Markdown websites. If you're on a site that isn't listed, **Add *site name*** adds it in one click, or use **Add Website…** to type an address. A site includes its subdomains.
- To remove an app or website you added, open the menu, hold ⌥ and choose **Remove…**.

Your choices are saved in `~/Library/Application Support/Rich 2 MD/config.json` and survive updates.

### Menu bar icon

| Icon | Meaning |
|---|---|
| Clipboard outline | Running, waiting for rich text to be copied |
| Filled clipboard | Rich text has been captured and is ready |
| Pause symbol | Paused: copies are left as they are |

The menu also has **Pause / Resume** (⌘P), **Open Log** and **Quit**. Pausing or quitting always puts the original rich text back on the clipboard. After **Quit**, Rich 2 MD stays off until you next log in or run `./install.sh`.

## Supported apps and websites

Everything below is ticked by default. Apps only appear in the menu if they're installed.

| Group | Apps |
|---|---|
| Chat | Slack, Discord, Mattermost, Telegram, WhatsApp |
| AI assistants | Claude, ChatGPT |
| Notes & writing | Obsidian, Bear, iA Writer, Typora, Logseq, Joplin, Drafts, Zettlr, MarkText |
| Code editors | Visual Studio Code, Cursor, Windsurf, Zed, Sublime Text, BBEdit, Nova |
| Terminals | Terminal, iTerm2, Ghostty, Warp, WezTerm, kitty, Alacritty |

**Websites:** Slack, Discord, WhatsApp Web, Telegram Web, ChatGPT, Claude, Gemini, Perplexity, GitHub, GitLab, HackMD, Stack Overflow.

Notion, Google Docs, Mail, Apple Notes, Word and Teams aren't on the list, because they already keep rich text formatting when you paste. Add them yourself if you prefer Markdown there.

## How formatting is converted

| Rich text | Markdown | Slack | WhatsApp |
|---|---|---|---|
| Heading | `## Heading` | `**Heading**` | `*Heading*` |
| Bold | `**text**` | `**text**` | `*text*` |
| Italic | `_text_` | `_text_` | `_text_` |
| Strikethrough | `~~text~~` | `~text~` | `~text~` |
| Link | `[label](https://…)` | `[label](https://…)` | `label (https://…)` |
| Bullet list | `- item`, indented four spaces per level | same | same |
| Numbered list | `1. item`, keeping the original numbering | same | same |
| Code | `` `code` `` and fenced code blocks | same | same |
| Table | Markdown table | rows of `\| cells \|` | rows of `\| cells \|` |

Telegram uses the Slack style but with `~~double~~` strikethrough. Apps and websites you add yourself get standard Markdown.

### What it leaves alone

Rich 2 MD only holds on to a copy when converting it adds something. It ignores:

- copies from code editors and terminals, whose rich text is just syntax colouring
- single-line copies, such as a name, a URL or a command
- copies that are only code
- copies that would come out the same as the plain text
- passwords from password managers, and copied files or images

## Privacy

- Nothing leaves your Mac. Rich 2 MD makes no network connections and needs no API keys or sign-in.
- To recognise websites it reads the address of the current tab in your browser, only while it's holding a copy or when you open its menu. It never reads page contents.
- The log records which app or website text was copied from and pasted into, never the text itself.

## Updating

```bash
cd rich2md
git pull
./install.sh
```

Each build is a new, unsigned binary, so macOS may ask for the clipboard and browser permissions again after an update.

## Uninstalling

```bash
./uninstall.sh          # stop it and remove it from login items, keeping your settings
./uninstall.sh --all    # also delete your settings and the log
```

You can then delete the folder.

## Advanced

### Command line

```bash
build/rich2md convert page.html                 # print the Markdown for an HTML or RTF file
build/rich2md convert page.html --flavor slack  # flavors: markdown, slack, chat, whatsapp
build/rich2md inspect                           # show what's on the clipboard and the Markdown it would become
```

### Tests

```bash
tests/run.sh
```

This converts each sample in `tests/fixtures/` and compares the result with `tests/expected/`. To add a test, save an HTML or RTF file as `tests/fixtures/NAME.html`, check the output of `build/rich2md convert`, and save it as `tests/expected/NAME.md` (or `NAME.slack.md` for the Slack flavor).

### Adding apps or websites to the built-in list

The lists live at the top of `rich2md.swift`, in `appCatalog` and `siteCatalog`. To find an app's bundle identifier:

```bash
osascript -e 'id of app "Obsidian"'
```

Pull requests that add popular Markdown apps or websites are welcome.

### How it works

Rich 2 MD checks the clipboard four times a second. When you copy rich text worth converting, it keeps an exact copy of the original and turns the HTML (or RTF) into Markdown. Each time you switch apps, or switch tabs in a supported browser, it puts the version that suits the destination on the clipboard. Copying from and pasting into the same app or website always gives you the original.

## Troubleshooting

- **Nothing changes when I paste.** Check that the menu bar icon is there and not paused, that the destination is ticked, and use **Open Log** to see whether the copy was captured. Single-line copies are deliberately left alone.
- **Websites aren't detected.** Choose **Allow Website Detection…** in the menu, or turn on Rich 2 MD for your browser under **System Settings → Privacy & Security → Automation**. Firefox isn't supported, because it can't report the current tab address.
- **`install.sh` fails with a compiler error.** Install Apple's command line tools with `xcode-select --install`, then run `./install.sh` again.
- **The icon has disappeared.** You may have quit it. Run `./install.sh` again, or log out and back in. On MacBooks with a notch, icons that don't fit can be hidden behind it.

## Licence

Released under the [MIT Licence](LICENSE).

Rich 2 MD is an independent project and is not affiliated with or endorsed by any of the apps or websites it works with.
