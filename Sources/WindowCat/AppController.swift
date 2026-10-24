import AppKit
import CatCore

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let tracker = WindowTracker()
    private let statusDragView = StatusDragView()
    private var catMenu: NSMenu!
    private var companionMenu: NSMenu!
    private var companionMenuKey = ""
    private var skin = 1
    private var notice: String?
    private var demos: [DiagnosticWindow] = []
    private var companions: [WindowIdentity: CatCompanion] = [:]
    private var companionOrder: [WindowIdentity] = []
    private var selectedID: WindowIdentity?
    private var selected: CatCompanion? { selectedID.flatMap { companions[$0] } }
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var previousTick = ProcessInfo.processInfo.systemUptime
    private var previousUIUpdate: TimeInterval = 0
    private var paused = false
    private var systemSleeping = false
    private var speed: CGFloat = 68
    private var automaticNaps = true
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var modeItems: [CatMode: NSMenuItem] = [:]
    private var infoItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var napItem: NSMenuItem!
    private var removeItem: NSMenuItem!
    private var speedItems: [NSMenuItem] = []
    private let dragPanel = OverlayPanel(size: 192, name: "Cat drag preview")
    private let dragView = CatView()
    private let outline = OverlayPanel(size: 100, name: "Drop target")
    private var dragSkin: Int?
    private var dragCandidate: WindowTarget?
    private var lastHitTest: TimeInterval = 0
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let storedSpeed = UserDefaults.standard.double(forKey: "walkingSpeed")
        speed = storedSpeed > 0 ? storedSpeed : 68
        if UserDefaults.standard.object(forKey: "automaticNaps") != nil { automaticNaps = UserDefaults.standard.bool(forKey: "automaticNaps") }
        dragPanel.contentView = dragView
        outline.contentView = DropOutline()
        wireStatusDrag()
        tracker.onChange = { [weak self] states in self?.accept(states) }
        tracker.onPermissionChange = { [weak self] _ in self?.updateUI() }
        buildMenu()
        observeSystem()
        tracker.start()
        updateUI()
        if let index = CommandLine.arguments.firstIndex(of: "--external-diagnostics"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self.runExternalDiagnostics(path: path)
                NSApp.terminate(nil)
            }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--diagnostics"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                Task { @MainActor in
                    await self?.runDiagnostics(directory: path)
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func wireStatusDrag() {
        statusDragView.onBegin = { [weak self] point in
            guard let self else { return }
            self.beginDrag(skin: self.skin, point: point)
        }
        statusDragView.onDrag = { [weak self] in self?.moveDrag($0) }
        statusDragView.onDrop = { [weak self] in self?.finishDrag($0) }
        statusDragView.onClick = { [weak self] in self?.showMenu() }
    }
    private func announce(_ message: String) {
        notice = message
        statusDragView.toolTip = message
        updateUI()
    }
    private func showMenu() {
        updateUI()
        guard let button = statusItem.button else { return }
        catMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
    }

    private func beginDrag(skin: Int, point: CGPoint) {
        cancelDrag()
        dragSkin = skin; dragView.skin = skin; dragView.action = .idle
        dragView.angle = 0; dragView.frameIndex = 0; dragView.facingForward = true; dragView.leap = 0
        lastHitTest = 0
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancelDrag(); self?.announce(tr(.dragCancelled)); return nil }
            return event
        }
        moveDrag(point)
    }

    private func moveDrag(_ point: CGPoint, force: Bool = false) {
        guard dragSkin != nil else { return }
        dragPanel.place(anchor: CGPoint(x: point.x, y: point.y - 18))
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastHitTest >= 0.1 else { return }
        lastHitTest = now
        dragCandidate = tracker.candidate(at: point)
        if let candidate = dragCandidate {
            outline.setFrame(candidate.initialRect.insetBy(dx: -4, dy: -4), display: true)
            outline.contentView?.needsDisplay = true
            outline.orderFrontRegardless()
            dragPanel.orderFrontRegardless()
        } else { outline.orderOut(nil) }
    }

    private func finishDrag(_ point: CGPoint) {
        guard let skin = dragSkin else { return }
        moveDrag(point, force: true)
        let candidate = dragCandidate
        cancelDrag()
        guard let target = candidate else {
            announce(tr(.noWindow)); showMenu(); return
        }
        place(skin: skin, on: target)
    }

    private func cancelDrag() {
        dragSkin = nil; dragCandidate = nil
        dragPanel.orderOut(nil); outline.orderOut(nil)
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    private func place(skin: Int, on target: WindowTarget) {
        let id = target.identity
        if let existing = companions[id] {
            existing.skin = skin; selectedID = id
        } else {
            guard companions.count < 12 else { announce(tr(.limit)); return }
            companions[id] = CatCompanion(target: target, skin: skin, speed: speed, automaticNaps: automaticNaps)
            companionOrder.append(id); selectedID = id
            tracker.pin(target)
        }
        paused = false
        tracker.setEnabled(!systemSleeping)
        tracker.refresh()
        updateTimer()
        announce(tr(.placed))
        updateUI()
    }

    private func accept(_ states: [WindowState]) {
        for state in states {
            if state.closed { remove(state.target.identity) }
            else { companions[state.target.identity]?.setRect(state.rect) }
        }
        updateTimer()
        drawWorlds()
        updateUI()
    }

    private func updateTimer() {
        let live = companions.values.filter { $0.rect != nil }
        guard !paused, !systemSleeping, !live.isEmpty else {
            timer?.invalidate(); timer = nil; timerInterval = 0
            for companion in companions.values { companion.hide() }
            return
        }
        let interval: TimeInterval = live.allSatisfy { $0.world.action == .sleeping } ? 1 : 1.0 / 30
        guard timer == nil || interval != timerInterval else { return }
        timer?.invalidate(); timerInterval = interval
        previousTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = interval == 1 ? 0.15 : 0.003
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }

    private var featherPoint: CGPoint { CGPoint(x: NSEvent.mouseLocation.x - 10, y: NSEvent.mouseLocation.y - 35) }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        tracker.sampleDrag(at: now)
        guard !paused, !systemSleeping else { return }
        let elapsed = now - previousTick; previousTick = now
        let pointer = featherPoint
        for cat in companions.values where cat.rect != nil { cat.world.tick(elapsed, pointer: cat.world.mode == .wand ? pointer : nil) }
        drawWorlds(); updateTimer()
        if now - previousUIUpdate > 1 { previousUIUpdate = now; updateUI() }
    }
    private func drawWorlds() {
        guard !paused, !systemSleeping else { return }
        let pointer = featherPoint
        for cat in companions.values { cat.draw(tracker: tracker, pointer: pointer) }
    }
    private func selectMode(_ mode: CatMode) {
        guard let selected else { return }
        // There is one mouse; only the selected cat gets the teaser.
        if mode == .wand {
            for cat in companions.values where cat !== selected && cat.world.mode == .wand { cat.world.choose(.roam) }
        }
        selected.world.choose(mode)
        if paused { paused = false; tracker.setEnabled(!systemSleeping) }
        updateTimer(); drawWorlds(); updateUI()
    }

    private func remove(_ id: WindowIdentity) {
        companions[id]?.hide(); companions.removeValue(forKey: id)
        companionOrder.removeAll { $0 == id }; tracker.unpin(id)
        if selectedID == id { selectedID = companionOrder.last }
    }
    @objc private func removeSelected() {
        if let selectedID { remove(selectedID) }
        updateTimer(); updateUI()
    }
    @objc private func removeAll() {
        for id in companionOrder { remove(id) }
        updateTimer(); updateUI()
    }

    @objc private func showDemo() {
        let demo = DiagnosticWindow()
        demo.delegate = self
        if !demos.isEmpty { demo.setFrameOrigin(CGPoint(x: demo.frame.minX - CGFloat(demos.count * 45), y: demo.frame.minY - CGFloat(demos.count * 35))) }
        demos.append(demo)
        demo.orderFrontRegardless()
        tracker.registerLocal(demo)
        tracker.refresh()
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? DiagnosticWindow {
            tracker.removeLocal(window); demos.removeAll { $0 === window }
        }
    }

    private func changeLanguage(_ language: AppLanguage) {
        L10n.set(language)
        notice = nil
        for demo in demos { demo.updateLanguage() }
        buildMenu(); updateUI()
    }
    private func updateUI() {
        let items: [(WindowIdentity, String)] = companionOrder.compactMap { id in
            guard let cat = companions[id] else { return nil }
            let name = cat.target.localWindow != nil ? tr(.demoTitle) : cat.target.name
            return (id, "\(L10n.catName(cat.skin)) · \(name) · \(companionOrder.firstIndex(of: id)! + 1)")
        }
        let menuKey = items.map { "\($0.0)-\($0.1)" }.joined(separator: "|") + String(describing: selectedID)
        if companionMenuKey != menuKey {
            companionMenuKey = menuKey
            companionMenu?.removeAllItems()
            for (id, label) in items {
                let item = NSMenuItem(title: label, action: #selector(companionClicked(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = id
                item.state = selectedID == id ? .on : .off
                companionMenu?.addItem(item)
            }
            if items.isEmpty {
                let item = NSMenuItem(title: tr(.noCats), action: nil, keyEquivalent: "")
                item.isEnabled = false; companionMenu?.addItem(item)
            }
        }
        infoItem?.title = notice ?? "\(tr(.appName)) · \(companions.count)"
        pauseItem?.title = tr(paused ? .resume : .pause)
        permissionItem?.isHidden = tracker.trusted
        napItem?.state = automaticNaps ? .on : .off
        removeItem?.isEnabled = selected != nil
        for (mode, item) in modeItems { item.isEnabled = selected != nil; item.state = selected?.world.mode == mode ? .on : .off }
        for item in speedItems { item.state = CGFloat(item.tag) == speed ? .on : .off }
    }

    private func buildMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: 28)
            if let button = statusItem.button {
                statusDragView.frame = button.bounds
                statusDragView.autoresizingMask = [.width, .height]
                button.addSubview(statusDragView)
            }
        }
        statusDragView.skin = skin
        statusDragView.toolTip = tr(.dragHint)
        statusDragView.setAccessibilityLabel(tr(.appName) + ". " + tr(.dragHint))
        let menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
        modeItems.removeAll(); speedItems.removeAll()
        infoItem = NSMenuItem(title: tr(.appName), action: nil, keyEquivalent: ""); infoItem.isEnabled = false; menu.addItem(infoItem)
        let hint = NSMenuItem(title: tr(.dragHint), action: nil, keyEquivalent: "")
        hint.isEnabled = false; menu.addItem(hint)
        companionMenuKey = ""
        companionMenu = NSMenu(); companionMenu.autoenablesItems = false
        let companionItem = NSMenuItem(title: tr(.assigned), action: nil, keyEquivalent: "")
        companionItem.submenu = companionMenu; menu.addItem(companionItem)
        menu.addItem(.separator())
        for (mode, key) in [(CatMode.roam, TextKey.roam), (.ball, .ball), (.wand, .wand), (.nap, .nap)] {
            let item = add(key, #selector(modeClicked(_:)), menu); item.representedObject = mode.rawValue; modeItems[mode] = item
        }
        removeItem = add(.remove, #selector(removeSelected), menu)
        _ = add(.allHome, #selector(removeAll), menu)
        menu.addItem(.separator())
        pauseItem = add(.pause, #selector(togglePause), menu)
        napItem = add(.autoNaps, #selector(toggleNaps), menu)
        let speedMenu = NSMenu(); speedMenu.autoenablesItems = false
        for (key, value) in [(TextKey.slow, 42), (.normal, 68), (.fast, 105)] {
            let item = add(key, #selector(changeSpeed(_:)), speedMenu); item.tag = value; speedItems.append(item)
        }
        let speedParent = NSMenuItem(title: tr(.speed), action: nil, keyEquivalent: ""); speedParent.submenu = speedMenu; menu.addItem(speedParent)
        let languages = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.label, action: #selector(languageClicked(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = language.rawValue; item.state = L10n.language == language ? .on : .off
            languages.addItem(item)
        }
        let languageParent = NSMenuItem(title: tr(.language), action: nil, keyEquivalent: ""); languageParent.submenu = languages; menu.addItem(languageParent)
        permissionItem = add(.permissionEnable, #selector(requestPermission), menu)
        menu.addItem(.separator())
        _ = add(.quit, #selector(quitApp), menu)
        catMenu = menu
        let main = NSMenu(), app = NSMenu(), parent = NSMenuItem()
        let quit = add(.quit, #selector(quitApp), app); quit.keyEquivalent = "q"
        parent.submenu = app; main.addItem(parent); NSApp.mainMenu = main
    }
    private func add(_ key: TextKey, _ action: Selector, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: tr(key), action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
    }
    func menuWillOpen(_ menu: NSMenu) { updateUI() }
    @objc private func modeClicked(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = CatMode(rawValue: raw) { selectMode(mode) }
    }
    @objc private func languageClicked(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) { changeLanguage(language) }
    }
    @objc private func togglePause() {
        paused.toggle(); tracker.setEnabled(!paused && !systemSleeping); updateTimer(); drawWorlds(); updateUI()
    }
    @objc private func toggleNaps() {
        automaticNaps.toggle(); UserDefaults.standard.set(automaticNaps, forKey: "automaticNaps")
        for cat in companions.values { cat.world.automaticNaps = automaticNaps }; updateUI()
    }
    @objc private func changeSpeed(_ sender: NSMenuItem) {
        speed = CGFloat(sender.tag); UserDefaults.standard.set(sender.tag, forKey: "walkingSpeed")
        for cat in companions.values { cat.world.speed = speed }; updateUI()
    }
    @objc private func companionClicked(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? WindowIdentity { selectedID = id; notice = nil; updateUI() }
    }
    @objc private func requestPermission() { tracker.requestPermission() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func observeSystem() {
        let center = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            tokens.append((center, center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in self?.setSleeping(true) }))
        }
        for event in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            tokens.append((center, center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in self?.setSleeping(false) }))
        }
        let center2 = NotificationCenter.default
        tokens.append((center2, center2.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.tracker.refresh() }))
    }
    private func setSleeping(_ value: Bool) {
        systemSleeping = value; tracker.setEnabled(!paused && !value); updateTimer(); drawWorlds()
    }
    func applicationWillTerminate(_ notification: Notification) {
        cancelDrag(); timer?.invalidate(); tracker.setEnabled(false)
        for cat in companions.values { cat.hide() }
        for (center, token) in tokens { center.removeObserver(token) }
    }

    @MainActor private func runDiagnostics(directory: String) async {
        var results: [String: Any] = [:]
        if demos.isEmpty { showDemo() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard let demo = demos.first else { return }
        let point = CGPoint(x: demo.frame.midX, y: demo.frame.midY)
        beginDrag(skin: 1, point: point); finishDrag(point)
        results["dropCreatesCompanion"] = companions.count == 1
        let originalID = selectedID
        beginDrag(skin: 1, point: point); finishDrag(point)
        results["sameWindowDoesNotDuplicateCat"] = companions.count == 1 && selected?.skin == 1 && selectedID == originalID
        let originalX = selected?.world.path.rect.minX ?? 0
        demo.setFrameOrigin(CGPoint(x: demo.frame.minX - 45, y: demo.frame.minY))
        tracker.refresh()
        results["followsBoundWindowMove"] = abs((selected?.world.path.rect.minX ?? 0) - originalX + 45) < 1
        let originalWidth = selected?.world.path.rect.width ?? 0
        demo.setContentSize(NSSize(width: demo.contentView!.bounds.width + 24, height: demo.contentView!.bounds.height + 12))
        tracker.refresh()
        results["followsBoundWindowResize"] = abs((selected?.world.path.rect.width ?? 0) - originalWidth - 24) < 1
        selectMode(.ball)
        results["toyOnSelectedCompanion"] = selected?.world.mode == .ball
        showDemo()
        // Let AppKit commit the new window's ordering to WindowServer before hit testing.
        try? await Task.sleep(nanoseconds: 200_000_000)
        if let second = demos.last {
            let secondPoint = CGPoint(x: second.frame.midX, y: second.frame.midY)
            results["secondWindowNumber"] = second.windowNumber
            results["secondDropCandidate"] = tracker.candidate(at: secondPoint)?.identity.number
            beginDrag(skin: 1, point: secondPoint); finishDrag(secondPoint)
            results["secondWindowHasIndependentCat"] = companions.count == 2 && selectedID != originalID && selected?.target.localWindow === second
            let secondID = selectedID
            selectMode(.wand)
            results["toysAreIndependent"] = originalID.flatMap { companions[$0]?.world.mode } == .ball && selected?.world.mode == .wand
            demo.makeKeyAndOrderFront(nil)
            try? await Task.sleep(nanoseconds: 200_000_000)
            tracker.refresh()
            results["focusDoesNotRetargetCats"] = companions.count == 2 && selectedID == secondID &&
                originalID.flatMap { companions[$0]?.target.localWindow } === demo && selected?.target.localWindow === second
            second.close()
            tracker.refresh()
            results["closingWindowRemovesItsCat"] = companions.count == 1 && selectedID == originalID
        }
        beginDrag(skin: 1, point: CGPoint(x: -99999, y: -99999))
        finishDrag(CGPoint(x: -99999, y: -99999))
        results["invalidDropDoesNotCreateCat"] = companions.count == 1 && dragSkin == nil && !outline.isVisible
        togglePause(); results["pauseStopsTimer"] = timer == nil; togglePause()
        results["resumeStartsTimer"] = timer != nil
        results["mousePassthrough"] = selected?.panel.ignoresMouseEvents == true
        results["doesNotStealFocus"] = selected?.panel.canBecomeKey == false
        selectMode(.nap)
        for _ in 0..<600 { selected?.world.tick(0.1) }
        updateTimer()
        results["sleepUsesOneHertz"] = selected?.world.action == .sleeping && timerInterval == 1
        removeAll()
        results["removeAllStopsAnimation"] = companions.isEmpty && timer == nil
        results["accessibilityGranted"] = tracker.trusted
        results["language"] = L10n.language.rawValue
        var spriteFrames = 0
        for skin in 1...1 {
            for animation in ["Idle", "Idle2", "Groom", "Groom2", "Walk", "Run", "Sleep", "Paw", "Jump", "Scared"] {
                spriteFrames += CatSprites.load(skin: skin, animation: animation).count
            }
        }
        results["loadedSpriteFrames"] = spriteFrames
        results["localizedKeys"] = TextKey.allCases.count
        do {
            let root = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("diagnostics.json"))
            try exportGallery(to: root.appendingPathComponent("cats-preview.png"))
        } catch { fputs("Diagnostics failed: \(error)\n", stderr) }
    }

    @MainActor private func runExternalDiagnostics(path: String) async {
        var report: [String: Any] = ["accessibilityGranted": tracker.trusted, "startupHasNoWindows": demos.isEmpty && companions.isEmpty]
        if let target = tracker.frontmostExternalTarget() {
            report["targetApp"] = target.name
            let point = CGPoint(x: target.initialRect.midX, y: target.initialRect.midY)
            beginDrag(skin: 1, point: point)
            report["dragPreviewVisible"] = dragPanel.isVisible
            report["targetOutlineVisible"] = outline.isVisible
            finishDrag(point)
            try? await Task.sleep(nanoseconds: 800_000_000)
            tracker.refresh(); drawWorlds()
            report["externalWindowBound"] = selected?.target.identity == target.identity
            report["catPanelVisible"] = selected?.panel.isVisible == true
            if let cat = selected {
                report["trackRect"] = String(describing: cat.rect)
                report["targetRect"] = String(describing: target.initialRect)
                let pose = cat.world.pose
                let center = CGPoint(x: pose.point.x - sin(pose.angle) * 24, y: pose.point.y + cos(pose.angle) * 24)
                let area = CGRect(x: center.x - 28, y: center.y - 20, width: 56, height: 40)
                report["catArea"] = String(describing: area)
                report["intersections"] = tracker.windows.filter { !$0.rect.intersection(area).isNull }.map {
                    ["app": NSRunningApplication(processIdentifier: $0.identity.owner)?.localizedName ?? "system",
                     "id": String($0.identity.number), "layer": String($0.layer), "rect": String(describing: $0.rect)]
                }
            }
            report["animationAdvances"] = (selected?.world.time ?? 0) > 0
            report["statusIconHasSize"] = statusDragView.bounds.width > 0 && statusDragView.bounds.height > 0
            if let view = selected?.view, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                var opaquePixels = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { opaquePixels += 1 }
                    }
                }
                report["renderedCatPixels"] = opaquePixels
                try? exportGallery(to: URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent("elthen-preview.png"))
            }
        } else { report["error"] = "No ordinary external window is visible" }
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
        } catch { fputs("Diagnostics failed: \(error)\n", stderr) }
    }

    private func exportGallery(to url: URL) throws {
        let image = NSImage(size: NSSize(width: 560, height: 150), flipped: false) { bounds in
            NSColor(srgbRed: 0.96, green: 0.95, blue: 0.92, alpha: 1).setFill(); bounds.fill()
            let text: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black]
            ("windowcat · Elthen" as NSString).draw(at: CGPoint(x: 20, y: 120), withAttributes: text)
            NSGraphicsContext.current?.imageInterpolation = .none
            for (i, name) in ["Idle", "Walk", "Run", "Sleep", "Paw"].enumerated() {
                let x = CGFloat(i) * 108 + 34
                CatSprites.load(skin: 1, animation: name)[0].draw(in: NSRect(x: x, y: 48, width: 60, height: 54))
                (name as NSString).draw(at: CGPoint(x: x + 10, y: 24), withAttributes: text)
            }
            return true
        }
        if let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data),
           let png = bitmap.representation(using: .png, properties: [:]) { try png.write(to: url) }
    }
}
