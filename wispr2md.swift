// wispr2md — watches the clipboard and, when you copy from Wispr Flow,
// replaces the rich HTML with Slack-friendly Markdown so a plain ⌘V works.
//
// Usage:
//   wispr2md                 run the watcher (normally started by launchd)
//   wispr2md convert FILE    print the Markdown for an HTML file (for testing)
//
// Options:
//   --bold slack             use *single* asterisks (Slack mrkdwn) instead of **double**

import AppKit

let wisprBundlePrefix = "com.electron.wispr-flow"
let pollInterval = 0.25
let indentUnit = "    "

var bold = "**"
if let i = CommandLine.arguments.firstIndex(of: "--bold"),
   i + 1 < CommandLine.arguments.count,
   CommandLine.arguments[i + 1] == "slack" {
    bold = "*"
}

// MARK: - HTML → Markdown

func decodeEntities(_ s: String) -> String {
    guard s.contains("&") else { return s }
    var out = s
    for (k, v) in ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"] {
        out = out.replacingOccurrences(of: k, with: v)
    }
    let re = try! NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
    for m in re.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed() {
        let ns = out as NSString
        let hex = ns.substring(with: m.range(at: 1)) == "x"
        if let code = UInt32(ns.substring(with: m.range(at: 2)), radix: hex ? 16 : 10),
           let scalar = Unicode.Scalar(code),
           let r = Range(m.range, in: out) {
            out.replaceSubrange(r, with: String(Character(scalar)))
        }
    }
    return out.replacingOccurrences(of: "&amp;", with: "&")
}

func attr(_ name: String, in attrs: String) -> String? {
    let re = try! NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*(\"([^\"]*)\"|'([^']*)')", options: .caseInsensitive)
    guard let m = re.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)) else { return nil }
    for g in [2, 3] where m.range(at: g).location != NSNotFound {
        return decodeEntities((attrs as NSString).substring(with: m.range(at: g)))
    }
    return nil
}

final class MarkdownBuilder {
    var out = ""
    var heading: String?                  // buffers heading text so it can be trimmed and wrapped
    var lists: [(ordered: Bool, next: Int)] = []
    var liIsWrapper: [Bool] = []          // Lexical nests sub-lists in a marker-less <li>
    var skipDepth = 0
    var boldDepth = 0, italicDepth = 0, strikeDepth = 0
    var links: [(start: Int, href: String?)] = []

    func newline() { if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" } }
    func blankLine() { newline(); if !out.isEmpty && !out.hasSuffix("\n\n") { out += "\n" } }

    func text(_ raw: String) {
        guard skipDepth == 0 else { return }
        var t = decodeEntities(raw).replacingOccurrences(of: "[ \\t\\r\\n]+", with: " ", options: .regularExpression)
        if heading != nil { heading! += t; return }
        if out.isEmpty || out.hasSuffix("\n") || out.hasSuffix(" ") { t = String(t.drop(while: { $0 == " " })) }
        out += t
    }

    /// Closing inline marker: keep trailing spaces outside it so Markdown still parses.
    func closeMarker(_ m: String) {
        var trailing = ""
        while out.hasSuffix(" ") { out.removeLast(); trailing += " " }
        out += m + trailing
    }

    func tag(_ name: String, closing: Bool, attrs: String) {
        if ["head", "style", "script", "title"].contains(name) {
            skipDepth += closing ? -1 : 1; skipDepth = max(skipDepth, 0); return
        }
        guard skipDepth == 0 else { return }

        switch name {
        case "p", "div":
            if lists.isEmpty { closing ? newline() : blankLine() }
        case "br":
            if heading == nil { newline() }
        case "h1", "h2", "h3", "h4", "h5", "h6":
            if !closing { blankLine(); heading = "" }
            else if let h = heading {
                heading = nil
                let t = h.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { out += bold + t + bold }
                newline()
            }
        case "ul", "ol":
            if !closing {
                if lists.isEmpty { blankLine() }
                lists.append((name == "ol", Int(attr("start", in: attrs) ?? "") ?? 1))
            } else {
                if !lists.isEmpty { lists.removeLast() }
                newline()
            }
        case "li":
            if !closing {
                let wrapper = (attr("class", in: attrs) ?? "").contains("nested-listitem")
                liIsWrapper.append(wrapper)
                guard !wrapper else { return }
                newline()
                let depth = max(lists.count - 1, 0)
                var marker = "- "
                if let last = lists.last, last.ordered {
                    marker = "\(last.next). "
                    lists[lists.count - 1].next += 1
                }
                out += String(repeating: indentUnit, count: depth) + marker
            } else if !liIsWrapper.isEmpty {
                liIsWrapper.removeLast()
            }
        case "b", "strong":
            guard heading == nil else { return }
            if !closing { boldDepth += 1; if boldDepth == 1 { out += bold } }
            else if boldDepth > 0 { boldDepth -= 1; if boldDepth == 0 { closeMarker(bold) } }
        case "i", "em":
            guard heading == nil else { return }
            if !closing { italicDepth += 1; if italicDepth == 1 { out += "_" } }
            else if italicDepth > 0 { italicDepth -= 1; if italicDepth == 0 { closeMarker("_") } }
        case "s", "del", "strike":
            guard heading == nil else { return }
            if !closing { strikeDepth += 1; if strikeDepth == 1 { out += "~" } }
            else if strikeDepth > 0 { strikeDepth -= 1; if strikeDepth == 0 { closeMarker("~") } }
        case "code":
            if heading == nil { closing ? closeMarker("`") : (out += "`") }
        case "a":
            guard heading == nil else { return }
            if !closing { links.append((out.count, attr("href", in: attrs))) }
            else if let link = links.popLast(), let href = link.href, !href.isEmpty {
                let label = String(out.dropFirst(link.start))
                out = String(out.prefix(link.start))
                out += (label.trimmingCharacters(in: .whitespaces) == href || label.isEmpty) ? href : "[\(label)](\(href))"
            }
        case "hr":
            blankLine(); out += "---"; newline()
        default:
            break
        }
    }

    func finish() -> String {
        let lines = out.components(separatedBy: "\n").map { line -> String in
            var l = line; while l.hasSuffix(" ") { l.removeLast() }; return l
        }
        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func htmlToMarkdown(_ html: String) -> String {
    let b = MarkdownBuilder()
    let re = try! NSRegularExpression(pattern: "<!--[\\s\\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>")
    let ns = html as NSString
    var pos = 0
    for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
        if m.range.location > pos { b.text(ns.substring(with: NSRange(location: pos, length: m.range.location - pos))) }
        pos = m.range.location + m.range.length
        guard m.range(at: 2).location != NSNotFound else { continue }  // comment
        b.tag(ns.substring(with: m.range(at: 2)).lowercased(),
              closing: ns.substring(with: m.range(at: 1)) == "/",
              attrs: ns.substring(with: m.range(at: 3)))
    }
    if pos < ns.length { b.text(ns.substring(from: pos)) }
    return b.finish()
}

// MARK: - Entry points

func log(_ msg: String) {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    FileHandle.standardError.write("\(f.string(from: Date())) \(msg)\n".data(using: .utf8)!)
}

let args = CommandLine.arguments
if args.count >= 3, args[1] == "convert" {
    guard let html = try? String(contentsOfFile: args[2], encoding: .utf8) else {
        FileHandle.standardError.write("Can't read \(args[2])\n".data(using: .utf8)!); exit(1)
    }
    print(htmlToMarkdown(html))
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, but allowed a menu bar icon

// Apps that should receive Markdown. Every other app gets Wispr Flow's original rich text.
let markdownApps: Set<String> = ["com.tinyspeck.slackmacgap"]
let logPath = NSString(string: "~/Library/Logs/wispr2md.log").expandingTildeInPath

enum Mode { case original, markdown }

struct Captured {
    let items: [[NSPasteboard.PasteboardType: Data]]   // exact copy of what Wispr Flow put on the clipboard
    let markdown: String
}

let pb = NSPasteboard.general
var lastChange = pb.changeCount   // last changeCount we've seen (including our own writes)
var captured: Captured?
var showing = Mode.original
var paused = false
var menuBar: MenuBarController?

func snapshotClipboard() -> [[NSPasteboard.PasteboardType: Data]] {
    (pb.pasteboardItems ?? []).map { item in
        var dict: [NSPasteboard.PasteboardType: Data] = [:]
        for t in item.types { if let d = item.data(forType: t) { dict[t] = d } }
        return dict
    }
}

func show(_ mode: Mode, reason: String) {
    guard let cap = captured, mode != showing else { return }
    pb.clearContents()
    switch mode {
    case .markdown:
        pb.setString(cap.markdown, forType: .string)
    case .original:
        pb.writeObjects(cap.items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (t, d) in dict { item.setData(d, forType: t) }
            return item
        })
    }
    showing = mode
    lastChange = pb.changeCount
    log("\(reason) → clipboard set to \(mode == .markdown ? "Markdown" : "original rich text")")
    menuBar?.refresh()
}

// MARK: - Menu bar icon

final class MenuBarController: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let stateLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let clipboardLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "p")

    override init() {
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        stateLine.isEnabled = false
        clipboardLine.isEnabled = false
        menu.addItem(stateLine)
        menu.addItem(clipboardLine)
        menu.addItem(.separator())
        pauseItem.target = self
        menu.addItem(pauseItem)
        let logItem = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Wispr → Slack", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        refresh()
    }

    func refresh() {
        // Outline icon = waiting; filled icon = a Wispr Flow copy is on the clipboard; pause icon = paused.
        let symbol = paused ? "pause.circle" : (captured == nil ? "doc.on.clipboard" : "doc.on.clipboard.fill")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Wispr to Slack")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.appearsDisabled = paused

        stateLine.title = paused ? "Wispr → Slack: Paused" : "Wispr → Slack: On"
        clipboardLine.title =
            paused ? "Wispr Flow copies are left as they are"
            : captured == nil ? "Waiting for a copy from Wispr Flow"
            : showing == .markdown ? "Clipboard holds Markdown (for Slack)"
            : "Clipboard holds Wispr Flow's original (Markdown in Slack)"
        pauseItem.title = paused ? "Resume" : "Pause"
        item.button?.toolTip = paused
            ? "Wispr → Slack is paused. Click to resume or quit."
            : "Wispr → Slack is running: Wispr Flow copies paste as Markdown in Slack and as rich text everywhere else. Click to pause or quit."
    }

    @objc func togglePause() {
        if !paused {
            show(.original, reason: "paused")   // never leave Markdown behind while paused
            captured = nil
            showing = .original
        }
        paused.toggle()
        log(paused ? "paused from menu bar" : "resumed from menu bar")
        refresh()
    }

    @objc func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
    }

    @objc func quit() {
        show(.original, reason: "quitting")     // leave the clipboard as Wispr Flow made it
        log("quit from menu bar")
        exit(0)                                 // clean exit: launchd won't restart it until next login
    }
}

// MARK: - Clipboard watching

func modeFor(_ appID: String) -> Mode { markdownApps.contains(appID) ? .markdown : .original }

log("wispr2md started (bold marker: \(bold))")
menuBar = MenuBarController()

// Detect new copies. A copy made while Wispr Flow is in front is captured; any other copy clears the capture.
Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
    guard pb.changeCount != lastChange else { return }
    lastChange = pb.changeCount
    let hadCapture = captured != nil
    captured = nil
    showing = .original
    defer { if hadCapture || captured != nil { menuBar?.refresh() } }
    guard !paused,
          let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
          front.hasPrefix(wisprBundlePrefix),
          pb.types?.contains(.html) == true,
          let html = pb.string(forType: .html) else { return }
    let md = htmlToMarkdown(html)
    guard !md.isEmpty else { return }
    captured = Captured(items: snapshotClipboard(), markdown: md)
    log("captured Wispr Flow copy (\(md.count) chars of Markdown ready)")
}

// Swap the clipboard whenever you switch apps.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
    // If something new was copied and the timer hasn't seen it yet, don't overwrite it.
    guard !paused, captured != nil, pb.changeCount == lastChange,
          let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
    else { return }
    show(modeFor(id), reason: "\(id) active")
}

app.run()
