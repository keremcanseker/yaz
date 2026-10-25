<div align="center">

# yaz

**A small, quiet note app for macOS.** Tabs, a few markdown touches, and nothing else.

*yaz* is Turkish for "write".

</div>

<!-- Screenshot goes here once the landing page is live: ![yaz](.github/yaz.png) -->

I wanted somewhere to write that opens instantly, keeps every tab between launches, and saves plain markdown. Most note apps grow a sidebar, sync, tags and a database. yaz is about 800 lines of Swift and stays that way on purpose.

## Features

- **Tabs.** `⌘T` new, `⌘W` close, `⌘1` to `⌘9` to jump, `⌘⇧[` and `⌘⇧]` to move between them.
- **Never loses a note.** The whole session, unsaved tabs included, is written back automatically and restored on the next launch.
- **Plain markdown on disk.** `⌘S` saves a `.md` file, `⌘O` opens one or many. The first line becomes the tab title.
- **Light markdown, rendered as you type.** Headers, checkboxes (`☐` / `☑`), arrows and rules are styled live in the editor, with no preview pane.
- **Typing sounds.** An optional soft key click, pooled so fast typing stays smooth.
- **Zoom.** `⌘+`, `⌘-` and `⌘0` scale the whole page.
- **Geist** as the typeface, bundled with the app.

## How it is built

- Swift, SwiftUI for the window and tabs, AppKit (`NSTextView`, a custom `NSLayoutManager`) for the editor
- Live styling restyles the text storage on each edit; checkbox glyphs get kerning so they line up whatever font falls back
- `AVAudioPlayer` pool for key sounds
- Session state is a small Codable file
- Project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`

## Build

Requires macOS 14+ and Xcode 16+.

```sh
brew install xcodegen
xcodegen generate
open yaz.xcodeproj
```

---

Built by [Keremcan Şeker](https://github.com/keremcanseker).
