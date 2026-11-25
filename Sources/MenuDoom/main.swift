// MenuDoom: Doom, running inside a battery icon in the macOS menu bar.
//
// Left-click the battery  -> it grabs the keyboard (outline turns green). Play.
// Click anywhere else     -> keyboard goes back to your other apps.
// Right-click the battery -> menu (choose WAD, quit).

import AppKit
import DoomGeneric

// MARK: - Look & feel

/// Size of the menu bar image, in points. The system battery icon is about this size.
let iconSize = CGSize(width: 30, height: 14)
/// The battery body; Doom is drawn inside it.
let bodyRect = CGRect(x: 0.5, y: 0.5, width: 26, height: 13)
/// The little terminal nub on the right.
let nubRect = CGRect(x: 27.5, y: 4.5, width: 2, height: 5)
/// Which part of the Doom frame sits in the middle of the battery, as a fraction from the top.
/// 0.42 centres the 3D view (the bottom of the screen is the status bar).
let focusFromTop: CGFloat = 0.42

// MARK: - Doom key codes

func dk(_ value: Int) -> UInt8 { UInt8(truncatingIfNeeded: value) }
func dk(_ value: Int32) -> UInt8 { UInt8(truncatingIfNeeded: value) }
func dk(_ value: UInt32) -> UInt8 { UInt8(truncatingIfNeeded: value) }

/// macOS virtual key code -> Doom key code, for keys that aren't plain characters.
let specialKeys: [UInt16: UInt8] = [
    123: dk(MDG_KEY_LEFT), 124: dk(MDG_KEY_RIGHT),
    125: dk(MDG_KEY_DOWN), 126: dk(MDG_KEY_UP),
    36: dk(MDG_KEY_ENTER), 76: dk(MDG_KEY_ENTER),
    53: dk(MDG_KEY_ESCAPE), 48: dk(MDG_KEY_TAB),
    51: dk(MDG_KEY_BACKSPACE), 117: dk(MDG_KEY_BACKSPACE),
    49: dk(MDG_KEY_USE), // space
    // F1...F10 are Doom key codes 0x80+0x3b ... 0x80+0x44
    122: dk(MDG_KEY_F1), 120: dk(MDG_KEY_F1) + 1, 99: dk(MDG_KEY_F1) + 2,
    118: dk(MDG_KEY_F1) + 3, 96: dk(MDG_KEY_F1) + 4, 97: dk(MDG_KEY_F1) + 5,
    98: dk(MDG_KEY_F1) + 6, 100: dk(MDG_KEY_F1) + 7, 101: dk(MDG_KEY_F1) + 8,
    109: dk(MDG_KEY_F1) + 9,
    103: 0x80 + 0x57, // F11
]

/// Modifier keys -> Doom key codes. Control and Command both fire.
let modifierKeys: [(NSEvent.ModifierFlags, UInt8)] = [
    (.control, dk(MDG_KEY_FIRE)),
    (.command, dk(MDG_KEY_FIRE)),
    (.shift, dk(MDG_KEY_RSHIFT)),   // run
    (.option, dk(MDG_KEY_RALT)),    // strafe
]

// MARK: - Invisible window that receives the keyboard while you play

final class KeyCatcherWindow: NSWindow {
    weak var handler: AppDelegate?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .keyUp, .flagsChanged:
            handler?.handleKey(event)
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var catcher: KeyCatcherWindow!
    var timer: Timer?

    var started = false
    var focused = false
    var heldKeys = Set<UInt8>()
    var lastFlags: NSEvent.ModifierFlags = []
    var lastFrame: CGImage?
    var lastRelease = Date.distantPast

    let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MenuDoom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Lets the startup code at the bottom of the file create the delegate.
    nonisolated override init() { super.init() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.toolTip = "MenuDoom: click to play, right-click for menu"
        }

        catcher = KeyCatcherWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        catcher.isOpaque = false
        catcher.backgroundColor = .clear
        catcher.hasShadow = false
        catcher.ignoresMouseEvents = true
        catcher.isReleasedWhenClosed = false
        catcher.level = .statusBar
        catcher.handler = self

        NotificationCenter.default.addObserver(self, selector: #selector(lostFocus(_:)),
                                               name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(lostFocus(_:)),
                                               name: NSWindow.didResignKeyNotification, object: catcher)

        redraw()

        if let wad = findWAD() {
            startDoom(wad: wad)
        } else {
            chooseWAD()
        }
    }

    // MARK: Starting Doom

    func findWAD() -> String? {
        let fm = FileManager.default
        if let saved = UserDefaults.standard.string(forKey: "wadPath"), fm.fileExists(atPath: saved) {
            return saved
        }
        var candidates = [supportDir.appendingPathComponent("doom1.wad")]
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(exeDir.appendingPathComponent("doom1.wad"))
        }
        // The project folder this was built from (handy when running from Xcode).
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        candidates.append(projectDir.appendingPathComponent("doom1.wad"))

        return candidates.first { fm.fileExists(atPath: $0.path) }?.path
    }

    func chooseWAD() {
        activateApp()
        let panel = NSOpenPanel()
        panel.title = "Choose a Doom WAD"
        panel.message = "Choose doom1.wad (the free shareware Doom data file) or another IWAD."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard url.pathExtension.lowercased() == "wad" else {
            showAlert("That isn't a .wad file", "Pick doom1.wad or another Doom IWAD.")
            return
        }
        UserDefaults.standard.set(url.path, forKey: "wadPath")

        if started {
            showAlert("WAD saved", "Quit and reopen MenuDoom to load it.")
        } else {
            startDoom(wad: url.path)
        }
    }

    func startDoom(wad: String) {
        guard !started else { return }
        started = true

        // Doom keeps its config and save games in the working directory.
        FileManager.default.changeCurrentDirectoryPath(supportDir.path)

        // Doom keeps a pointer to argv for its whole life, so this is never freed.
        let args = ["MenuDoom", "-iwad", wad]
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: args.count + 1)
        for (i, arg) in args.enumerated() { argv[i] = strdup(arg) }
        argv[args.count] = nil
        doomgeneric_Create(Int32(args.count), argv)

        // Doom runs at 35 tics a second; ticking faster just lets it catch up smoothly.
        // .common mode keeps the game running while a menu is open.
        let t = Timer(timeInterval: 1.0 / 70.0, target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc func tick() {
        doomgeneric_Tick()
        if mdg_take_frame() != 0 {
            captureFrame()
            redraw()
        }
    }

    // MARK: Drawing

    func captureFrame() {
        let w = Int(mdg_width()), h = Int(mdg_height())
        guard let pixels = mdg_pixels() else { return }
        let data = Data(bytes: pixels, count: w * h * 4)
        guard let provider = CGDataProvider(data: data as CFData) else { return }
        // Doom's pixels are 0x00RRGGBB in native (little-endian) order.
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                                | CGBitmapInfo.byteOrder32Little.rawValue)
        lastFrame = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: info, provider: provider, decode: nil,
                            shouldInterpolate: true, intent: .defaultIntent)
    }

    func redraw() {
        guard let button = statusItem.button else { return }
        let scale = button.window?.backingScaleFactor ?? 2
        let pw = Int(iconSize.width * scale), ph = Int(iconSize.height * scale)
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.scaleBy(x: scale, y: scale)
        ctx.interpolationQuality = .high

        let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let ink: CGColor = focused ? NSColor.systemGreen.cgColor
                                   : (isDark ? CGColor(gray: 1, alpha: 0.9) : CGColor(gray: 0, alpha: 0.85))

        // Doom, clipped to the inside of the battery.
        let inner = bodyRect.insetBy(dx: 2, dy: 2)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: inner, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        ctx.clip()
        if let frame = lastFrame {
            // Fill the battery's width and crop the top and bottom.
            let drawW = inner.width
            let drawH = drawW * CGFloat(frame.height) / CGFloat(frame.width)
            let y = inner.midY - drawH * (1 - focusFromTop)
            ctx.draw(frame, in: CGRect(x: inner.minX, y: y, width: drawW, height: drawH))
        } else {
            ctx.setFillColor(ink.copy(alpha: 0.25)!)
            ctx.fill(inner)
        }
        ctx.restoreGState()

        // Battery outline and nub.
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(1)
        ctx.addPath(CGPath(roundedRect: bodyRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
        ctx.strokePath()
        ctx.setFillColor(ink.copy(alpha: 0.6)!)
        ctx.addPath(CGPath(roundedRect: nubRect, cornerWidth: 1, cornerHeight: 1, transform: nil))
        ctx.fillPath()

        if let image = ctx.makeImage() {
            button.image = NSImage(cgImage: image, size: iconSize)
        }
    }

    // MARK: Clicks and focus

    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (!focused && event?.modifierFlags.contains(.control) == true) {
            showMenu()
            return
        }
        if !started {
            chooseWAD()
            return
        }
        if focused {
            releaseFocus()
        } else if Date().timeIntervalSince(lastRelease) > 0.3 {
            // (Clicking the icon can steal focus a moment before this click arrives;
            // don't immediately grab it back.)
            grabFocus()
        }
    }

    func showMenu() {
        releaseFocus()
        let menu = NSMenu()
        let hint = NSMenuItem(title: started ? "Click the battery to play" : "No WAD loaded yet",
                              action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Choose WAD…", action: #selector(menuChooseWAD), keyEquivalent: "")
        choose.target = self
        menu.addItem(choose)
        let folder = NSMenuItem(title: "Show Saves Folder", action: #selector(menuShowFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MenuDoom", action: #selector(menuQuit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func menuChooseWAD() { chooseWAD() }
    @objc func menuShowFolder() { NSWorkspace.shared.open(supportDir) }
    @objc func menuQuit() { NSApp.terminate(nil) }

    func grabFocus() {
        focused = true
        heldKeys.removeAll()
        lastFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        activateApp()
        if let barWindow = statusItem.button?.window {
            catcher.setFrameOrigin(NSPoint(x: barWindow.frame.midX, y: barWindow.frame.minY - 2))
        }
        catcher.makeKeyAndOrderFront(nil)
        redraw()
    }

    func releaseFocus() {
        guard focused else { return }
        focused = false
        lastRelease = Date()
        // Let go of anything still held so Doom doesn't keep running forward forever.
        for key in heldKeys { mdg_push_key(0, key) }
        heldKeys.removeAll()
        catcher.orderOut(nil)
        if NSApp.isActive { NSApp.hide(nil) } // hand the keyboard back to the previous app
        redraw()
    }

    @objc func lostFocus(_ note: Notification) { releaseFocus() }

    func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Keyboard

    func handleKey(_ event: NSEvent) {
        guard focused else { return }
        switch event.type {
        case .keyDown:
            if !event.isARepeat, let key = doomKey(for: event) { setKey(key, down: true) }
        case .keyUp:
            if let key = doomKey(for: event) { setKey(key, down: false) }
        case .flagsChanged:
            let now = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            for (flag, key) in modifierKeys where lastFlags.contains(flag) != now.contains(flag) {
                setKey(key, down: now.contains(flag))
            }
            lastFlags = now
        default:
            break
        }
    }

    func setKey(_ key: UInt8, down: Bool) {
        if down {
            guard heldKeys.insert(key).inserted else { return }
        } else {
            guard heldKeys.remove(key) != nil else { return }
        }
        mdg_push_key(down ? 1 : 0, key)
    }

    func doomKey(for event: NSEvent) -> UInt8? {
        if let special = specialKeys[event.keyCode] { return special }
        guard let scalar = event.charactersIgnoringModifiers?.lowercased().unicodeScalars.first,
              scalar.value >= 32, scalar.value < 127 else { return nil }
        return UInt8(scalar.value)
    }

    func showAlert(_ title: String, _ text: String) {
        activateApp()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only: no Dock icon
app.run()
