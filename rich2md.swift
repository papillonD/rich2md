// Rich 2 MD — paste rich text as Markdown in the apps and websites that want it.
//
// Copy formatted text anywhere (Wispr Flow, Google Docs, Notion, a web page, Word, Apple Notes…).
// Switch to a Markdown app or website you've ticked in the menu bar and ⌘V pastes clean Markdown.
// Switch anywhere else and ⌘V pastes the original rich text.
//
// Usage:
//   rich2md                                  run (normally started at login by install.sh)
//   rich2md convert FILE [--flavor NAME]     print the Markdown for an .html or .rtf file
//   rich2md inspect [--flavor NAME]          show what's on the clipboard and the Markdown it would become
//
// Flavors: markdown (default), slack, chat, whatsapp

import AppKit
import UniformTypeIdentifiers

let pollInterval = 0.25          // how often the clipboard is checked for new copies
let tabPollInterval = 0.4        // how often the browser tab address is checked while a copy is held
let indentUnit = "    "
let maxHTMLBytes = 5_000_000

// MARK: - Markdown flavors

struct Flavor: Equatable {
    let name: String
    let bold: String, italic: String, strike: String
    let realHeadings: Bool       // "## Heading" rather than a bold line
    var markdownLinks = true     // [label](url) rather than "label (url)"

    static let markdown = Flavor(name: "markdown", bold: "**", italic: "_", strike: "~~", realHeadings: true)
    static let slack    = Flavor(name: "slack",    bold: "**", italic: "_", strike: "~",  realHeadings: false)
    static let chat     = Flavor(name: "chat",     bold: "**", italic: "_", strike: "~~", realHeadings: false)
    static let whatsapp = Flavor(name: "whatsapp", bold: "*",  italic: "_", strike: "~",  realHeadings: false, markdownLinks: false)
    static let all = [markdown, slack, chat, whatsapp]
    static func named(_ n: String) -> Flavor? { all.first { $0.name == n } }
}

// MARK: - Apps and websites that get Markdown

struct AppTarget {
    let id: String, name: String, group: String, flavor: Flavor
}
struct SiteTarget {
    let host: String, name: String, flavor: Flavor
}

let appGroups = ["Chat", "AI assistants", "Notes & writing", "Code editors", "Terminals"]

let appCatalog: [AppTarget] = [
    .init(id: "com.tinyspeck.slackmacgap", name: "Slack", group: "Chat", flavor: .slack),
    .init(id: "com.hnc.Discord", name: "Discord", group: "Chat", flavor: .markdown),
    .init(id: "Mattermost.Desktop", name: "Mattermost", group: "Chat", flavor: .markdown),
    .init(id: "ru.keepcoder.Telegram", name: "Telegram", group: "Chat", flavor: .chat),
    .init(id: "com.tdesktop.Telegram", name: "Telegram Desktop", group: "Chat", flavor: .chat),
    .init(id: "net.whatsapp.WhatsApp", name: "WhatsApp", group: "Chat", flavor: .whatsapp),

    .init(id: "com.anthropic.claudefordesktop", name: "Claude", group: "AI assistants", flavor: .markdown),
    .init(id: "com.openai.chat", name: "ChatGPT", group: "AI assistants", flavor: .markdown),

    .init(id: "md.obsidian", name: "Obsidian", group: "Notes & writing", flavor: .markdown),
    .init(id: "net.shinyfrog.bear", name: "Bear", group: "Notes & writing", flavor: .markdown),
    .init(id: "pro.writer.mac", name: "iA Writer", group: "Notes & writing", flavor: .markdown),
    .init(id: "abnerworks.Typora", name: "Typora", group: "Notes & writing", flavor: .markdown),
    .init(id: "com.electron.logseq", name: "Logseq", group: "Notes & writing", flavor: .markdown),
    .init(id: "net.cozic.joplin-desktop", name: "Joplin", group: "Notes & writing", flavor: .markdown),
    .init(id: "com.agiletortoise.Drafts-OSX", name: "Drafts", group: "Notes & writing", flavor: .markdown),
    .init(id: "com.zettlr.app", name: "Zettlr", group: "Notes & writing", flavor: .markdown),
    .init(id: "com.github.marktext", name: "MarkText", group: "Notes & writing", flavor: .markdown),

    .init(id: "com.microsoft.VSCode", name: "Visual Studio Code", group: "Code editors", flavor: .markdown),
    .init(id: "com.microsoft.VSCodeInsiders", name: "VS Code Insiders", group: "Code editors", flavor: .markdown),
    .init(id: "com.todesktop.230313mzl4w4u92", name: "Cursor", group: "Code editors", flavor: .markdown),
    .init(id: "com.exafunction.windsurf", name: "Windsurf", group: "Code editors", flavor: .markdown),
    .init(id: "dev.zed.Zed", name: "Zed", group: "Code editors", flavor: .markdown),
    .init(id: "com.sublimetext.4", name: "Sublime Text", group: "Code editors", flavor: .markdown),
    .init(id: "com.barebones.bbedit", name: "BBEdit", group: "Code editors", flavor: .markdown),
    .init(id: "com.panic.Nova", name: "Nova", group: "Code editors", flavor: .markdown),

    .init(id: "com.apple.Terminal", name: "Terminal", group: "Terminals", flavor: .markdown),
    .init(id: "com.googlecode.iterm2", name: "iTerm2", group: "Terminals", flavor: .markdown),
    .init(id: "com.mitchellh.ghostty", name: "Ghostty", group: "Terminals", flavor: .markdown),
    .init(id: "dev.warp.Warp-Stable", name: "Warp", group: "Terminals", flavor: .markdown),
    .init(id: "com.github.wez.wezterm", name: "WezTerm", group: "Terminals", flavor: .markdown),
    .init(id: "net.kovidgoyal.kitty", name: "kitty", group: "Terminals", flavor: .markdown),
    .init(id: "org.alacritty", name: "Alacritty", group: "Terminals", flavor: .markdown),
]

let siteCatalog: [SiteTarget] = [
    .init(host: "app.slack.com", name: "Slack", flavor: .slack),
    .init(host: "discord.com", name: "Discord", flavor: .markdown),
    .init(host: "web.whatsapp.com", name: "WhatsApp Web", flavor: .whatsapp),
    .init(host: "web.telegram.org", name: "Telegram Web", flavor: .chat),
    .init(host: "chatgpt.com", name: "ChatGPT", flavor: .markdown),
    .init(host: "claude.ai", name: "Claude", flavor: .markdown),
    .init(host: "gemini.google.com", name: "Gemini", flavor: .markdown),
    .init(host: "perplexity.ai", name: "Perplexity", flavor: .markdown),
    .init(host: "github.com", name: "GitHub", flavor: .markdown),
    .init(host: "gitlab.com", name: "GitLab", flavor: .markdown),
    .init(host: "hackmd.io", name: "HackMD", flavor: .markdown),
    .init(host: "stackoverflow.com", name: "Stack Overflow", flavor: .markdown),
]

/// Copies from these are never converted: their "rich text" is just syntax colouring.
func isIgnoredSource(_ id: String) -> Bool {
    if let a = appCatalog.first(where: { $0.id == id }), a.group == "Code editors" || a.group == "Terminals" { return true }
    return ["com.jetbrains.", "com.apple.dt.Xcode", "com.google.android.studio"].contains { id.hasPrefix($0) }
}

/// Browsers whose current tab address can be read with AppleScript.
let chromiumBrowsers: Set<String> = [
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.brave.Browser",
    "com.microsoft.edgemac", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "org.chromium.Chromium",
]
let safariBrowsers: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]
func isBrowser(_ id: String) -> Bool { chromiumBrowsers.contains(id) || safariBrowsers.contains(id) }

// MARK: - HTML → Markdown

let namedEntities: [String: String] = [
    "nbsp": " ", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "amp": "&", "mdash": "—", "ndash": "–",
    "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "bull": "•", "middot": "·",
    "copy": "©", "reg": "®", "trade": "™", "euro": "€", "pound": "£", "times": "×", "rarr": "→", "larr": "←",
]
let entityRegex = try! NSRegularExpression(pattern: "&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);")

func decodeEntities(_ s: String) -> String {
    guard s.contains("&") else { return s }
    let ns = s as NSString
    var out = "", pos = 0
    for m in entityRegex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        out += ns.substring(with: NSRange(location: pos, length: m.range.location - pos))
        let name = ns.substring(with: m.range(at: 1))
        var rep: String?
        if name.hasPrefix("#") {
            let hex = name.dropFirst().lowercased().hasPrefix("x")
            if let c = UInt32(name.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10), let sc = Unicode.Scalar(c) {
                rep = c == 160 ? " " : String(Character(sc))
            }
        } else {
            rep = namedEntities[name]
        }
        out += rep ?? ns.substring(with: m.range)
        pos = m.range.location + m.range.length
    }
    return out + ns.substring(from: pos)
}

var regexCache: [String: NSRegularExpression] = [:]
func cachedRegex(_ pattern: String) -> NSRegularExpression {
    if let r = regexCache[pattern] { return r }
    let r = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    regexCache[pattern] = r
    return r
}

func firstGroup(_ pattern: String, in s: String) -> String? {
    guard let m = cachedRegex(pattern).firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) else { return nil }
    for g in 1..<m.numberOfRanges where m.range(at: g).location != NSNotFound {
        return (s as NSString).substring(with: m.range(at: g))
    }
    return nil
}

func attr(_ name: String, in attrs: String) -> String? {
    firstGroup("(?:^|\\s)\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))", in: attrs).map(decodeEntities)
}

func styleValue(_ style: String, _ prop: String) -> String? {
    firstGroup("(?:^|;)\\s*\(prop)\\s*:\\s*([^;]+)", in: style)?.trimmingCharacters(in: .whitespaces).lowercased()
}

func isBoldWeight(_ w: String?) -> Bool {
    guard let w = w else { return false }
    if w.hasPrefix("bold") { return true }
    return (Int(w) ?? 0) >= 600
}
func isNormalWeight(_ w: String?) -> Bool {
    guard let w = w else { return false }
    if w == "normal" || w == "lighter" { return true }
    if let n = Int(w) { return n < 600 }
    return false
}

final class MarkdownBuilder {
    enum Effect: Int { case bold = 0, italic, strike }

    let f: Flavor
    init(_ f: Flavor) { self.f = f }

    var out = ""
    var heading: (level: Int, text: String)?
    var lists: [(ordered: Bool, next: Int)] = []
    var liIsWrapper: [Bool] = []            // Lexical (Wispr Flow) nests sub-lists in a marker-less <li>
    var paraIsListItem: [Bool] = []         // Word/Outlook list paragraphs
    var inWordList = false
    var skipDepth = 0, preDepth = 0, tableDepth = 0
    var tableRow = 0, rowCells = 0
    var depth = [0, 0, 0]
    var pending: [Effect] = []              // opening markers held back until the first visible character
    var inline: [(tag: String, effects: [Effect])] = []
    var links: [(start: Int, href: String?)] = []

    static let inlineTags: Set<String> = ["b", "strong", "i", "em", "s", "del", "strike", "span", "font", "u",
                                          "mark", "small", "big", "ins", "cite", "abbr", "sup", "sub", "label"]
    static let blockTags: Set<String> = ["p", "div", "section", "article", "header", "footer", "blockquote", "figure",
                                         "figcaption", "dd", "dt", "dl", "address", "main", "aside", "nav", "details", "summary"]

    func marker(_ e: Effect) -> String { [f.bold, f.italic, f.strike][e.rawValue] }
    func newline() { if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" } }
    func blankLine() { newline(); if !out.isEmpty && !out.hasSuffix("\n\n") { out += "\n" } }

    func flushPending() {
        for e in pending { out += marker(e) }
        pending = []
    }

    /// Closing marker: keep trailing spaces outside it so Markdown still parses.
    func closeMarker(_ m: String) {
        var trailing = ""
        while out.hasSuffix(" ") { out.removeLast(); trailing += " " }
        out += m + trailing
    }

    func open(_ e: Effect) {
        depth[e.rawValue] += 1
        if depth[e.rawValue] == 1 { pending.append(e) }
    }

    func close(_ e: Effect) {
        guard depth[e.rawValue] > 0 else { return }
        depth[e.rawValue] -= 1
        guard depth[e.rawValue] == 0 else { return }
        if let i = pending.firstIndex(of: e) { pending.remove(at: i) } else { closeMarker(marker(e)) }
    }

    func text(_ raw: String) {
        guard skipDepth == 0 else { return }
        let decoded = decodeEntities(raw).replacingOccurrences(of: "\u{00A0}", with: " ")
        if preDepth > 0 { out += decoded; return }
        var t = decoded.replacingOccurrences(of: "[ \\t\\r\\n]+", with: " ", options: .regularExpression)
        if heading != nil { heading!.text += t; return }
        if out.isEmpty || out.hasSuffix("\n") || out.hasSuffix(" ") { t = String(t.drop(while: { $0 == " " })) }
        guard !t.isEmpty else { return }
        let lead = t.prefix(while: { $0 == " " })
        let rest = t.dropFirst(lead.count)
        out += lead
        if !rest.isEmpty { flushPending(); out += rest }
    }

    func effects(for name: String, attrs: String) -> [Effect] {
        let style = (attr("style", in: attrs) ?? "").lowercased()
        let weight = styleValue(style, "font-weight")
        let fontStyle = styleValue(style, "font-style")
        let deco = (styleValue(style, "text-decoration") ?? "") + (styleValue(style, "text-decoration-line") ?? "")
        var fx: [Effect] = []
        switch name {
        case "b", "strong":
            if !isNormalWeight(weight) { fx.append(.bold) }    // Google Docs wraps everything in <b style="font-weight:normal">
        case "i", "em":
            if fontStyle != "normal" { fx.append(.italic) }
        case "s", "del", "strike":
            fx.append(.strike)
        default:
            if isBoldWeight(weight) { fx.append(.bold) }
            if fontStyle?.contains("italic") == true || fontStyle?.contains("oblique") == true { fx.append(.italic) }
            if deco.contains("line-through") { fx.append(.strike) }
        }
        return fx
    }

    func tag(_ name: String, closing: Bool, attrs: String) {
        if ["head", "style", "script", "title", "template", "noscript"].contains(name) {
            skipDepth = max(skipDepth + (closing ? -1 : 1), 0)
            return
        }
        guard skipDepth == 0 else { return }

        // Inside a code block only line breaks matter.
        if preDepth > 0 && name != "pre" {
            if name == "br" || (closing && (name == "div" || name == "p")) { newline() }
            return
        }

        if MarkdownBuilder.inlineTags.contains(name) {
            if !closing {
                let fx = heading == nil ? effects(for: name, attrs: attrs) : []
                inline.append((name, fx))
                fx.forEach(open)
            } else if let i = inline.lastIndex(where: { $0.tag == name }) {
                for entry in inline[i...].reversed() { entry.effects.reversed().forEach(close) }
                inline.removeSubrange(i...)
            }
            return
        }

        if MarkdownBuilder.blockTags.contains(name) {
            if tableDepth > 0 {
                if !out.hasSuffix(" ") && !out.hasSuffix("|") { out += " " }
                return
            }
            if name == "p" {
                if !closing {
                    if let level = firstGroup("mso-list:\\s*\\S+\\s+level(\\d+)", in: attr("style", in: attrs) ?? "").flatMap({ Int($0) }) {
                        if paraIsListItem.isEmpty && inWordList { newline() } else { blankLine() }
                        inWordList = true
                        out += String(repeating: indentUnit, count: max(level - 1, 0)) + "- "
                        paraIsListItem.append(true)
                        return
                    }
                    paraIsListItem.append(false)
                    inWordList = false
                } else if paraIsListItem.popLast() == true {
                    newline()
                    return
                }
            }
            if lists.isEmpty { closing ? newline() : blankLine() }
            return
        }

        switch name {
        case "br":
            if heading != nil { heading!.text += " " }
            else if tableDepth > 0 || !lists.isEmpty { if !out.hasSuffix(" ") { out += " " } }
            else { newline() }

        case "h1", "h2", "h3", "h4", "h5", "h6":
            guard tableDepth == 0 else { return }
            if !closing {
                blankLine()
                heading = (Int(name.dropFirst()) ?? 2, "")
            } else if let h = heading {
                heading = nil
                let t = h.text.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty {
                    out += f.realHeadings ? String(repeating: "#", count: h.level) + " " + t : f.bold + t + f.bold
                }
                newline()
            }

        case "ul", "ol":
            guard tableDepth == 0 else { return }
            if !closing {
                if lists.isEmpty { blankLine() }
                lists.append((name == "ol", Int(attr("start", in: attrs) ?? "") ?? 1))
            } else {
                if !lists.isEmpty { lists.removeLast() }
                newline()
            }

        case "li":
            guard tableDepth == 0 else { return }
            if !closing {
                let wrapper = (attr("class", in: attrs) ?? "").contains("nested-listitem")
                liIsWrapper.append(wrapper)
                guard !wrapper else { return }
                newline()
                var level = max(lists.count - 1, 0)
                if let l = attr("aria-level", in: attrs).flatMap({ Int($0) }), l >= 1 { level = l - 1 }   // Google Docs
                var mark = "- "
                if let m = attr("data-md-marker", in: attrs) {
                    mark = m + " "
                } else if let last = lists.last, last.ordered {
                    mark = "\(last.next). "
                    lists[lists.count - 1].next += 1
                }
                out += String(repeating: indentUnit, count: level) + mark
            } else if !liIsWrapper.isEmpty {
                liIsWrapper.removeLast()
            }

        case "pre":
            guard tableDepth == 0 else { return }
            if !closing {
                if lists.isEmpty { blankLine() } else { newline() }
                out += "```\n"
                preDepth += 1
            } else if preDepth > 0 {
                preDepth -= 1
                newline()
                out += "```"
                newline()
            }

        case "code", "kbd", "samp", "tt":
            guard heading == nil else { return }
            if !closing { flushPending(); out += "`" }
            else if out.hasSuffix("`") { out.removeLast() }     // empty code span
            else { closeMarker("`") }

        case "a":
            guard heading == nil else { return }
            if !closing {
                flushPending()
                links.append((out.utf8.count, attr("href", in: attrs)))
            } else if let link = links.popLast() {
                guard let href = link.href, href.hasPrefix("http://") || href.hasPrefix("https://") || href.hasPrefix("mailto:"),
                      link.start <= out.utf8.count else { return }
                let label = String(decoding: out.utf8.dropFirst(link.start), as: UTF8.self)
                let trimmed = label.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let lead = label.prefix(while: { $0 == " " })
                let trail = String(label.reversed().prefix(while: { $0 == " " }))
                out = String(decoding: out.utf8.prefix(link.start), as: UTF8.self)
                let rendered = (trimmed == href || "mailto:" + trimmed == href) ? href
                    : f.markdownLinks ? "[\(trimmed)](\(href))" : "\(trimmed) (\(href))"
                out += String(lead) + rendered + trail
            }

        case "table":
            if !closing { blankLine(); tableDepth += 1; tableRow = 0 }
            else if tableDepth > 0 { tableDepth -= 1; newline() }

        case "tr":
            guard tableDepth == 1 else { return }
            if !closing {
                newline(); out += "|"; rowCells = 0
            } else {
                if tableRow == 0 && f.realHeadings && rowCells > 0 {
                    newline(); out += "|" + String(repeating: " --- |", count: rowCells)
                }
                tableRow += 1
            }

        case "td", "th":
            guard tableDepth == 1 else { return }
            if !closing { out += " " }
            else {
                while out.hasSuffix(" ") { out.removeLast() }
                out += " |"
                rowCells += 1
            }

        case "hr":
            guard tableDepth == 0 else { return }
            blankLine(); out += "---"; newline()

        default:
            break
        }
    }

    func finish() -> String {
        let lines = out.components(separatedBy: "\n").map { line -> String in
            var l = line
            while l.hasSuffix(" ") { l.removeLast() }
            return l
        }
        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

let tokenRegex = try! NSRegularExpression(
    pattern: "<!--[\\s\\S]*?-->|<!\\[(if[^\\]]*|endif)\\]>|<![^>]*>|<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>")

func htmlToMarkdown(_ html: String, _ flavor: Flavor) -> String {
    let b = MarkdownBuilder(flavor)
    let ns = html as NSString
    var pos = 0
    var conditionals: [Bool] = []   // Word's <![if !supportLists]> hides its own bullet characters
    for m in tokenRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
        if m.range.location > pos { b.text(ns.substring(with: NSRange(location: pos, length: m.range.location - pos))) }
        pos = m.range.location + m.range.length
        if m.range(at: 1).location != NSNotFound {
            let cond = ns.substring(with: m.range(at: 1))
            if cond.lowercased().hasPrefix("if") {
                let hide = cond.contains("supportLists")
                conditionals.append(hide)
                if hide { b.skipDepth += 1 }
            } else if conditionals.popLast() == true {
                b.skipDepth = max(b.skipDepth - 1, 0)
            }
            continue
        }
        guard m.range(at: 3).location != NSNotFound else { continue }   // comment or doctype
        b.tag(ns.substring(with: m.range(at: 3)).lowercased(),
              closing: ns.substring(with: m.range(at: 2)) == "/",
              attrs: ns.substring(with: m.range(at: 4)))
    }
    if pos < ns.length { b.text(ns.substring(from: pos)) }
    return b.finish()
}

// MARK: - RTF and web archives → HTML

func escapeHTML(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
}

func inlineHTML(_ s: NSAttributedString, plain: Bool) -> String {
    var out = ""
    s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { a, r, _ in
        var t = escapeHTML((s.string as NSString).substring(with: r))
        guard !t.isEmpty, !plain else { out += t; return }
        if let font = a[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            if traits.contains(.bold) { t = "<b>\(t)</b>" }
            if traits.contains(.italic) { t = "<i>\(t)</i>" }
        }
        if let st = a[.strikethroughStyle] as? Int, st != 0 { t = "<s>\(t)</s>" }
        if let link = a[.link] {
            let href = (link as? URL)?.absoluteString ?? (link as? String) ?? ""
            if !href.isEmpty { t = "<a href=\"\(escapeHTML(href))\">\(t)</a>" }
        }
        out += t
    }
    return out
}

/// Turns RTF (Apple Notes, TextEdit, Pages…) into simple HTML the converter understands.
func attributedToHTML(_ s: NSAttributedString) -> String {
    let full = NSRange(location: 0, length: s.length)
    let str = s.string as NSString
    var sizes: [CGFloat: Int] = [:]
    s.enumerateAttribute(.font, in: full) { v, r, _ in
        if let f = v as? NSFont { sizes[f.pointSize, default: 0] += r.length }
    }
    let base = sizes.max { $0.value < $1.value }?.key ?? 12
    let markerRegex = try! NSRegularExpression(pattern: "^\\t*([^\\t\\n]{1,8})\\t")
    var html = "", inList = false
    var topList: NSTextList?
    var counters: [ObjectIdentifier: Int] = [:]
    let bulletFormats = ["disc", "circle", "square", "hyphen", "check", "diamond", "box"]

    str.enumerateSubstrings(in: full, options: .byParagraphs) { _, r, _, _ in
        var range = r
        let style = r.length > 0 ? s.attribute(.paragraphStyle, at: r.location, effectiveRange: nil) as? NSParagraphStyle : nil
        let textLists = style?.textLists ?? []
        var marker: String?
        if inList && (textLists.isEmpty || textLists.first !== topList) {
            html += "</ul>"
            inList = false
        }
        if !textLists.isEmpty {
            let text = str.substring(with: r)
            if let m = markerRegex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                let mk = (text as NSString).substring(with: m.range(at: 1))
                if mk.range(of: "^[0-9]+[.)]$", options: .regularExpression) != nil { marker = String(mk.dropLast()) + "." }
                range = NSRange(location: r.location + m.range.length, length: r.length - m.range.length)
            }
            if !inList { html += "<ul>"; inList = true; topList = textLists.first }
            if marker == nil, let list = textLists.last,
               !bulletFormats.contains(where: { list.markerFormat.rawValue.contains($0) }) {
                let n = counters[ObjectIdentifier(list)] ?? list.startingItemNumber
                counters[ObjectIdentifier(list)] = n + 1
                marker = "\(n)."
            }
        }
        var maxSize: CGFloat = 0
        s.enumerateAttribute(.font, in: range) { v, _, _ in
            if let f = v as? NSFont { maxSize = max(maxSize, f.pointSize) }
        }
        let plainText = str.substring(with: range).trimmingCharacters(in: .whitespaces)
        let level = (!textLists.isEmpty || plainText.isEmpty || plainText.count > 120) ? 0
            : maxSize >= base * 1.5 ? 1 : maxSize >= base * 1.2 ? 2 : 0
        let body = inlineHTML(s.attributedSubstring(from: range), plain: level > 0)
        if !textLists.isEmpty {
            html += "<li aria-level=\"\(textLists.count)\"" + (marker.map { " data-md-marker=\"\($0)\"" } ?? "") + ">\(body)</li>"
        } else if level > 0 {
            html += "<h\(level)>\(body)</h\(level)>"
        } else {
            html += "<p>\(body)</p>"
        }
    }
    if inList { html += "</ul>" }
    return html
}

func htmlFromWebArchive(_ data: Data) -> String? {
    guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let main = plist["WebMainResource"] as? [String: Any],
          let d = main["WebResourceData"] as? Data else { return nil }
    return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1)
}

/// The richest HTML available on the clipboard: HTML, then Safari/Mail web archives, then RTF.
func richHTML(_ pb: NSPasteboard) -> String? {
    if let h = pb.string(forType: .html), !h.isEmpty { return h }
    for t in ["Apple Web Archive pasteboard type", "com.apple.webarchive"] {
        if let d = pb.data(forType: .init(t)), let h = htmlFromWebArchive(d) { return h }
    }
    if let d = pb.data(forType: .rtf), let s = NSAttributedString(rtf: d, documentAttributes: nil) { return attributedToHTML(s) }
    if let d = pb.data(forType: .rtfd), let s = NSAttributedString(rtfd: d, documentAttributes: nil) { return attributedToHTML(s) }
    return nil
}

// MARK: - Command line tools

func log(_ msg: String) {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    FileHandle.standardError.write("\(f.string(from: Date())) \(msg)\n".data(using: .utf8)!)
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("\(msg)\n".data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
var cliFlavor = Flavor.markdown
if let i = args.firstIndex(of: "--flavor") {
    guard i + 1 < args.count, let f = Flavor.named(args[i + 1]) else {
        fail("Unknown flavor. Use one of: \(Flavor.all.map(\.name).joined(separator: ", "))")
    }
    cliFlavor = f
}

if args.count >= 2, args[1] == "convert" {
    guard args.count >= 3 else { fail("Usage: rich2md convert FILE [--flavor NAME]") }
    let path = args[2]
    if path.lowercased().hasSuffix(".rtf") {
        guard let s = try? NSAttributedString(url: URL(fileURLWithPath: path), options: [:], documentAttributes: nil) else {
            fail("Can't read \(path)")
        }
        print(htmlToMarkdown(attributedToHTML(s), cliFlavor))
    } else {
        guard let html = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Can't read \(path)") }
        print(htmlToMarkdown(html, cliFlavor))
    }
    exit(0)
}

if args.count >= 2, args[1] == "inspect" {
    let pb = NSPasteboard.general
    print("Clipboard types:")
    for t in pb.types ?? [] { print("  \(t.rawValue)") }
    if let html = richHTML(pb) {
        print("\nMarkdown (\(cliFlavor.name)):\n")
        print(htmlToMarkdown(html, cliFlavor))
    } else {
        print("\nNo rich text on the clipboard.")
    }
    exit(0)
}

if args.count >= 2 {
    fail("Usage: rich2md [convert FILE | inspect] [--flavor \(Flavor.all.map(\.name).joined(separator: "|"))]")
}

// MARK: - Settings

struct CustomApp: Codable { var id: String; var name: String }

struct Config: Codable {
    var disabled: [String] = []          // "app:<bundle id>" or "site:<host>" the user has unticked
    var customApps: [CustomApp] = []
    var customSites: [String] = []

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        disabled = try c.decodeIfPresent([String].self, forKey: .disabled) ?? []
        customApps = try c.decodeIfPresent([CustomApp].self, forKey: .customApps) ?? []
        customSites = try c.decodeIfPresent([String].self, forKey: .customSites) ?? []
    }
}

let supportDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Rich 2 MD")
let configURL = supportDir.appendingPathComponent("config.json")
let logPath = NSString(string: "~/Library/Logs/rich2md.log").expandingTildeInPath

func loadConfig() -> Config {
    guard let d = try? Data(contentsOf: configURL), let c = try? JSONDecoder().decode(Config.self, from: d) else { return Config() }
    return c
}

var config = loadConfig()

func saveConfig() {
    try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let d = try? enc.encode(config) { try? d.write(to: configURL, options: .atomic) }
}

func isEnabled(_ key: String) -> Bool { !config.disabled.contains(key) }

func isInstalled(_ id: String) -> Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil }

func normalizedHost(_ s: String) -> String? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty, let url = URL(string: trimmed.contains("://") ? trimmed : "https://" + trimmed),
          var host = url.host, host.contains(".") else { return nil }
    if host.hasPrefix("www.") { host.removeFirst(4) }
    return host
}

func siteMatches(_ host: String, _ site: String) -> Bool { host == site || host.hasSuffix("." + site) }

/// Flavor for an app, if it's ticked.
func appFlavor(_ id: String) -> Flavor? {
    guard isEnabled("app:" + id) else { return nil }
    if let a = appCatalog.first(where: { $0.id == id }) { return a.flavor }
    return config.customApps.contains { $0.id == id } ? .markdown : nil
}

/// The ticked website matching a host, if any.
func siteTarget(_ host: String) -> (name: String, flavor: Flavor)? {
    if let s = siteCatalog.first(where: { siteMatches(host, $0.host) }), isEnabled("site:" + s.host) { return (s.name, s.flavor) }
    if let s = config.customSites.first(where: { siteMatches(host, $0) }), isEnabled("site:" + s) { return (s, .markdown) }
    return nil
}

func isKnownSite(_ host: String) -> Bool {
    siteCatalog.contains { siteMatches(host, $0.host) } || config.customSites.contains { siteMatches(host, $0) }
}

// MARK: - Browser tab addresses

var tabScripts: [String: NSAppleScript] = [:]
var deniedBrowsers: Set<String> = []

/// Host of the active tab, or nil if it can't be read (no window, Firefox, or permission not granted).
func activeHost(_ browserID: String) -> String? {
    guard isBrowser(browserID), !deniedBrowsers.contains(browserID) else { return nil }
    let script: NSAppleScript
    if let s = tabScripts[browserID] {
        script = s
    } else {
        let body = safariBrowsers.contains(browserID) ? "URL of current tab of front window" : "URL of active tab of front window"
        guard let s = NSAppleScript(source: "with timeout of 2 seconds\ntell application id \"\(browserID)\" to return \(body)\nend timeout") else { return nil }
        tabScripts[browserID] = s
        script = s
    }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error = error {
        let code = error[NSAppleScript.errorNumber] as? Int ?? 0
        if code == -1743 || code == -1744 {
            if !deniedBrowsers.contains(browserID) { log("no permission to read tab addresses in \(browserID)") }
            deniedBrowsers.insert(browserID)
            menuBar?.refresh()
        }
        return nil
    }
    return result.stringValue.flatMap(normalizedHost)
}

// MARK: - Clipboard engine

final class Capture {
    let items: [[NSPasteboard.PasteboardType: Data]]   // exact copy of the original clipboard
    let html: String
    let sourceKey: String
    let sourceName: String
    var cache: [String: String] = [:]

    init(items: [[NSPasteboard.PasteboardType: Data]], html: String, sourceKey: String, sourceName: String) {
        self.items = items; self.html = html; self.sourceKey = sourceKey; self.sourceName = sourceName
    }

    func markdown(_ f: Flavor) -> String {
        if let m = cache[f.name] { return m }
        let m = htmlToMarkdown(html, f)
        cache[f.name] = m
        return m
    }
}

let pb = NSPasteboard.general
var lastChange = pb.changeCount   // last changeCount seen, including our own writes
var capture: Capture?
var showing: Flavor?              // nil = the original rich text is on the clipboard
var showingFor = ""
var paused = false
var lastExternalApp: NSRunningApplication?
var menuBar: MenuBar?
let myPID = ProcessInfo.processInfo.processIdentifier

let skipTypes: Set<String> = [
    "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType",
    "com.agilebits.onepassword", "public.file-url",
]

func squash(_ s: String) -> String { String(s.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map(Character.init)) }

func isOnlyCode(_ md: String) -> Bool {
    if md.hasPrefix("```") && md.hasSuffix("```") && md.components(separatedBy: "```").count == 3 { return true }
    return md.hasPrefix("`") && md.hasSuffix("`") && !md.dropFirst().dropLast().contains("`")
}

func snapshotClipboard() -> [[NSPasteboard.PasteboardType: Data]] {
    (pb.pasteboardItems ?? []).map { item in
        var dict: [NSPasteboard.PasteboardType: Data] = [:]
        for t in item.types { if let d = item.data(forType: t) { dict[t] = d } }
        return dict
    }
}

/// Decide whether a new copy is worth holding on to.
func tryCapture() -> Capture? {
    guard let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
          front.processIdentifier != myPID, !isIgnoredSource(id) else { return nil }
    let types = Set((pb.types ?? []).map(\.rawValue))
    guard types.isDisjoint(with: skipTypes),
          let plain = pb.string(forType: .string),
          plain.contains(where: { $0.isNewline }),             // single lines (commands, names, URLs) are left alone
          let html = richHTML(pb), html.utf8.count < maxHTMLBytes else { return nil }
    let md = htmlToMarkdown(html, .markdown)
    guard !md.isEmpty, squash(md) != squash(plain), !isOnlyCode(md) else { return nil }

    deniedBrowsers.removeAll()                                // retry in case permission was granted since
    var key = "app:" + id, name = front.localizedName ?? id
    if isBrowser(id), let host = activeHost(id) { key = "site:" + host; name = host }
    let cap = Capture(items: snapshotClipboard(), html: html, sourceKey: key, sourceName: name)
    cap.cache[Flavor.markdown.name] = md
    log("captured rich text from \(name)")
    return cap
}

func apply(_ want: Flavor?, for target: String) {
    guard let cap = capture, want != showing else { return }
    pb.clearContents()
    if let f = want {
        pb.setString(cap.markdown(f), forType: .string)
    } else {
        pb.writeObjects(cap.items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (t, d) in dict { item.setData(d, forType: t) }
            return item
        })
    }
    showing = want
    showingFor = target
    lastChange = pb.changeCount
    log("\(target): clipboard set to " + (want.map { "Markdown (\($0.name))" } ?? "original rich text"))
    menuBar?.refresh()
}

/// Put the right version on the clipboard for whatever is in front now.
func reevaluate() {
    guard !paused, let cap = capture, pb.changeCount == lastChange,
          let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier else { return }
    var key = "app:" + id, name = front.localizedName ?? id
    var flavor = appFlavor(id)
    if isBrowser(id), let host = activeHost(id) {
        key = "site:" + host
        name = host
        if let site = siteTarget(host) { name = site.name; flavor = site.flavor }
    }
    apply(key == cap.sourceKey ? nil : flavor, for: name)
}

// MARK: - Menu bar

final class MenuBar: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        refresh()
    }

    func refresh() {
        let symbol = paused ? "pause.circle" : (capture == nil ? "doc.on.clipboard" : "doc.on.clipboard.fill")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Rich 2 MD")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.appearsDisabled = paused
        item.button?.toolTip = paused
            ? "Rich 2 MD is paused. Click to resume or quit."
            : "Rich 2 MD is running: rich text you copy pastes as Markdown in the apps and websites you've ticked, and as rich text everywhere else. Click for options."
    }

    func menuNeedsUpdate(_ m: NSMenu) {
        guard m === menu else { return }
        m.removeAllItems()
        m.addItem(info(paused ? "Rich 2 MD: Paused" : "Rich 2 MD: On"))
        m.addItem(info(statusText()))
        m.addItem(.separator())

        let apps = NSMenuItem(title: "Markdown Apps", action: nil, keyEquivalent: "")
        apps.submenu = appsMenu()
        m.addItem(apps)
        let sites = NSMenuItem(title: "Markdown Websites", action: nil, keyEquivalent: "")
        sites.submenu = sitesMenu()
        m.addItem(sites)
        if !deniedBrowsers.isEmpty {
            m.addItem(action("Allow Website Detection…", #selector(openAutomationSettings)))
        }
        m.addItem(.separator())
        m.addItem(action(paused ? "Resume" : "Pause", #selector(togglePause), key: "p"))
        m.addItem(action("Open Log", #selector(openLog)))
        m.addItem(.separator())
        m.addItem(action("Quit Rich 2 MD", #selector(quit), key: "q"))
    }

    func statusText() -> String {
        if paused { return "Copies are left as they are" }
        guard let cap = capture else { return "Waiting for rich text to be copied" }
        if showing != nil { return "Clipboard: Markdown for \(showingFor)" }
        return "Clipboard: rich text from \(cap.sourceName)"
    }

    // Menu item helpers

    func info(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    func action(_ title: String, _ sel: Selector, key: String = "", object: Any? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        i.representedObject = object
        return i
    }

    func toggle(_ title: String, key: String, custom: Bool, into m: NSMenu) {
        let i = action(title, #selector(toggleEntry(_:)), object: key)
        i.state = isEnabled(key) ? .on : .off
        i.indentationLevel = 1
        m.addItem(i)
        if custom {   // hold ⌥ to remove entries you added
            let r = action("Remove \(title)", #selector(removeEntry(_:)), object: key)
            r.isAlternate = true
            r.keyEquivalentModifierMask = .option
            r.indentationLevel = 1
            m.addItem(r)
        }
    }

    func appsMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        m.addItem(info("Paste Markdown into these apps:"))
        var any = false
        for group in appGroups {
            let entries = appCatalog.filter { $0.group == group && isInstalled($0.id) }
            guard !entries.isEmpty else { continue }
            any = true
            m.addItem(.separator())
            m.addItem(info(group))
            for e in entries { toggle(e.name, key: "app:" + e.id, custom: false, into: m) }
        }
        if !config.customApps.isEmpty {
            any = true
            m.addItem(.separator())
            m.addItem(info("Added by you (hold ⌥ to remove)"))
            for a in config.customApps { toggle(a.name, key: "app:" + a.id, custom: true, into: m) }
        }
        if !any { m.addItem(info("No Markdown apps found")) }
        m.addItem(.separator())
        m.addItem(action("Add Other App…", #selector(addApp)))
        return m
    }

    func sitesMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        m.addItem(info("Paste Markdown on these websites:"))
        m.addItem(.separator())
        for s in siteCatalog { toggle("\(s.name) (\(s.host))", key: "site:" + s.host, custom: false, into: m) }
        if !config.customSites.isEmpty {
            m.addItem(.separator())
            m.addItem(info("Added by you (hold ⌥ to remove)"))
            for s in config.customSites { toggle(s, key: "site:" + s, custom: true, into: m) }
        }
        m.addItem(.separator())
        if let app = lastExternalApp, !app.isTerminated, let id = app.bundleIdentifier,
           let host = activeHost(id), !isKnownSite(host) {
            m.addItem(action("Add \(host)", #selector(addCurrentSite(_:)), object: host))
        }
        m.addItem(action("Add Website…", #selector(addSite)))
        m.addItem(info("Works in Safari, Chrome, Arc, Brave, Edge and Vivaldi"))
        return m
    }

    // Actions

    @objc func toggleEntry(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let i = config.disabled.firstIndex(of: key) { config.disabled.remove(at: i) } else { config.disabled.append(key) }
        saveConfig()
        log("\(key) \(isEnabled(key) ? "ticked" : "unticked")")
        reevaluate()
    }

    @objc func removeEntry(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        config.customApps.removeAll { "app:" + $0.id == key }
        config.customSites.removeAll { "site:" + $0 == key }
        config.disabled.removeAll { $0 == key }
        saveConfig()
        log("removed \(key)")
        reevaluate()
    }

    @objc func addApp() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose an app that should receive Markdown"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        let key = "app:" + id
        if !appCatalog.contains(where: { $0.id == id }) && !config.customApps.contains(where: { $0.id == id }) {
            config.customApps.append(CustomApp(id: id, name: FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")))
        }
        config.disabled.removeAll { $0 == key }
        saveConfig()
        log("added \(key)")
    }

    @objc func addCurrentSite(_ sender: NSMenuItem) {
        guard let host = sender.representedObject as? String else { return }
        addHost(host)
    }

    @objc func addSite() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Add a website"
        alert.informativeText = "Rich text will paste as Markdown on this site and its subdomains."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "notion.so or https://example.com/page"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let host = normalizedHost(field.stringValue) else {
            let bad = NSAlert()
            bad.messageText = "That doesn't look like a website address."
            bad.runModal()
            return
        }
        addHost(host)
    }

    func addHost(_ host: String) {
        if !isKnownSite(host) { config.customSites.append(host) }
        config.disabled.removeAll { $0 == "site:" + host }
        saveConfig()
        log("added site:\(host)")
        reevaluate()
    }

    @objc func openAutomationSettings() {
        deniedBrowsers.removeAll()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    @objc func togglePause() {
        if !paused {
            apply(nil, for: "paused")   // never leave Markdown behind while paused
            capture = nil
            showing = nil
        }
        paused.toggle()
        log(paused ? "paused from menu bar" : "resumed from menu bar")
        refresh()
    }

    @objc func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
    }

    @objc func quit() {
        apply(nil, for: "quitting")     // leave the clipboard as it was copied
        log("quit from menu bar")
        exit(0)                         // clean exit: launchd won't restart it until next login
    }
}

// MARK: - Start

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, but allowed a menu bar icon

log("Rich 2 MD started")
lastExternalApp = NSWorkspace.shared.frontmostApplication
menuBar = MenuBar()

// New copies: hold on to rich text worth converting; anything else clears what we held.
Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
    guard pb.changeCount != lastChange else { return }
    lastChange = pb.changeCount
    let had = capture != nil
    capture = nil
    showing = nil
    if !paused { capture = tryCapture() }
    if had || capture != nil { menuBar?.refresh() }
}

// Switching browser tabs doesn't switch apps, so watch the tab address while something is held.
Timer.scheduledTimer(withTimeInterval: tabPollInterval, repeats: true) { _ in
    guard !paused, capture != nil, let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, isBrowser(id) else { return }
    reevaluate()
}

// Switching apps.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
    if let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, a.processIdentifier != myPID {
        lastExternalApp = a
    }
    reevaluate()
}

app.run()
