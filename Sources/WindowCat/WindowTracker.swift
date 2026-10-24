import AppKit
import ApplicationServices
import CatCore

final class WindowTarget {
    let identity: WindowIdentity
    let name: String
    let element: AXUIElement?
    var initialRect: CGRect
    weak var localWindow: NSWindow?
    private var observer: AXObserver?
    private var registrations: [String] = []
    var onChange: (() -> Void)?
    var wasDestroyed = false

    init(identity: WindowIdentity, name: String, rect: CGRect, element: AXUIElement? = nil, localWindow: NSWindow? = nil) {
        self.identity = identity; self.name = name; self.element = element; self.localWindow = localWindow
        initialRect = rect
    }

    func observe() {
        guard observer == nil, let element else { return }
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, context in
            guard let context else { return }
            let target = Unmanaged<WindowTarget>.fromOpaque(context).takeUnretainedValue()
            if notification as String == kAXUIElementDestroyedNotification { target.wasDestroyed = true }
            target.onChange?()
        }
        guard AXObserverCreate(identity.owner, callback, &created) == .success, let created else { return }
        observer = created
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        for name in [kAXMovedNotification, kAXResizedNotification, kAXWindowMiniaturizedNotification,
                     kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification] {
            if AXObserverAddNotification(created, element, name as CFString,
                                          Unmanaged.passUnretained(self).toOpaque()) == .success { registrations.append(name) }
        }
    }

    deinit {
        if let observer, let element {
            for name in registrations { AXObserverRemoveNotification(observer, element, name as CFString) }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }
}

struct WindowState {
    let target: WindowTarget
    let rect: CGRect?
    let closed: Bool
}

final class WindowTracker {
    var onChange: (([WindowState]) -> Void)?
    var onPermissionChange: ((Bool) -> Void)?
    private(set) var trusted = AXIsProcessTrusted()
    private(set) var windows: [WindowGeometry] = []
    private var targets: [WindowIdentity: WindowTarget] = [:]
    private var localWindows: [UInt32: NSWindow] = [:]
    private var fallbackTimer: Timer?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var lastDragSample: TimeInterval = 0
    private var refreshQueued = false
    private var enabled = true
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.scheduleRefresh() }))
        }
        let local = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification, NSWindow.didChangeOcclusionStateNotification] {
            tokens.append((local, local.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let window = note.object as? NSWindow,
                      let number = UInt32(exactly: window.windowNumber), number > 0,
                      self.localWindows[number] != nil else { return }
                self.scheduleRefresh()
            }))
        }
        setEnabled(true)
    }

    func registerLocal(_ window: NSWindow) {
        guard let number = UInt32(exactly: window.windowNumber), number > 0 else { return }
        localWindows[number] = window
    }
    func removeLocal(_ window: NSWindow) {
        guard let number = UInt32(exactly: window.windowNumber), number > 0 else { return }
        let id = WindowIdentity(owner: ownPID, number: number)
        targets[id]?.wasDestroyed = true
        localWindows.removeValue(forKey: id.number)
        refresh()
    }
    func pin(_ target: WindowTarget) {
        targets[target.identity] = target
        target.onChange = { [weak self] in self?.scheduleRefresh() }
        target.observe()
        refresh()
    }
    func unpin(_ id: WindowIdentity) { targets.removeValue(forKey: id) }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        fallbackTimer?.invalidate(); fallbackTimer = nil
        if enabled {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            fallbackTimer = timer
            refresh()
        }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func frontmostExternalTarget() -> WindowTarget? {
        let candidates = readWindows().filter { $0.identity.owner != ownPID && $0.layer == 0 && $0.rect.width > 200 && $0.rect.height > 150 }
        for window in candidates {
            if let target = candidate(at: CGPoint(x: window.rect.midX, y: window.rect.midY)), target.identity == window.identity { return target }
        }
        return nil
    }

    func candidate(at point: CGPoint) -> WindowTarget? {
        windows = readWindows()
        guard let geometry = WindowSelection.target(at: point, windows: windows, excluding: []) else { return nil }
        let id = geometry.identity
        if let local = localWindows[id.number], id.owner == ownPID {
            return WindowTarget(identity: id, name: tr(.demoTitle), rect: geometry.rect, localWindow: local)
        }
        guard id.owner != ownPID else { return nil }
        if let existing = targets[id] { existing.initialRect = geometry.rect; return existing }
        let fallback = WindowTarget(identity: id,
            name: NSRunningApplication(processIdentifier: id.owner)?.localizedName ?? "App", rect: geometry.rect)
        // Public WindowServer geometry is available without Accessibility permission.
        // AX adds notifications, but is never a prerequisite for displaying a cat.
        guard trusted else { return fallback }
        let app = AXUIElementCreateApplication(id.owner)
        AXUIElementSetMessagingTimeout(app, 0.08)
        // Hit-test this application, so overlapping windows with identical frames
        // are distinguished without letting our drag preview intercept the hit.
        if let primary = NSScreen.screens.first {
            var hit: AXUIElement?
            if AXUIElementCopyElementAtPosition(app, Float(point.x), Float(primary.frame.maxY - point.y), &hit) == .success,
               let hit {
                let window: AXUIElement?
                if attribute(hit, kAXRoleAttribute) as? String == kAXWindowRole { window = hit }
                else if let value = attribute(hit, kAXWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() {
                    window = (value as! AXUIElement)
                } else { window = nil }
                if let window, let target = matchedTarget(window, geometry: geometry) { return target }
            }
        }
        // Some apps do not expose point hit-testing. Use geometry only when unambiguous.
        guard let elements = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return fallback }
        let matches = elements.compactMap { matchedTarget($0, geometry: geometry) }
        return matches.count == 1 ? matches[0] : fallback
    }

    private func matchedTarget(_ element: AXUIElement, geometry: WindowGeometry) -> WindowTarget? {
        AXUIElementSetMessagingTimeout(element, 0.08)
        guard let rect = bounds(element), close(rect, geometry.rect),
              !(attribute(element, kAXMinimizedAttribute) as? Bool ?? false),
              !(attribute(element, "AXFullScreen") as? Bool ?? false) else { return nil }
        let name = NSRunningApplication(processIdentifier: geometry.identity.owner)?.localizedName ?? "App"
        return WindowTarget(identity: geometry.identity, name: name, rect: rect, element: element)
    }

    func sampleDrag(at time: TimeInterval) {
        guard enabled, !targets.isEmpty, NSEvent.pressedMouseButtons & 1 != 0,
              time - lastDragSample >= 1.0 / 15 else { return }
        lastDragSample = time
        refresh()
    }

    func exposed(_ area: CGRect, target: WindowIdentity) -> Bool {
        WindowSelection.isExposed(area, target: target, windows: windows, ownPID: ownPID)
    }

    private func scheduleRefresh() {
        guard enabled, !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshQueued = false
            self?.refresh()
        }
    }

    func refresh() {
        guard enabled else { return }
        let permission = AXIsProcessTrusted()
        if permission != trusted { trusted = permission; onPermissionChange?(permission) }
        guard !targets.isEmpty else { onChange?([]); return }
        windows = readWindows()
        let visible = Set(windows.map(\.identity))
        let allIDs = Set(readWindows(onScreenOnly: false).map(\.identity))
        let states = targets.values.map { target -> WindowState in
            if target.wasDestroyed { return WindowState(target: target, rect: nil, closed: true) }
            if target.identity.owner == ownPID {
                guard let window = target.localWindow else { return WindowState(target: target, rect: nil, closed: true) }
                let show = window.isVisible && !window.isMiniaturized && !window.styleMask.contains(.fullScreen) && visible.contains(target.identity)
                return WindowState(target: target, rect: show ? window.frame : nil, closed: false)
            }
            guard let app = NSRunningApplication(processIdentifier: target.identity.owner), !app.isTerminated else {
                return WindowState(target: target, rect: nil, closed: true)
            }
            if !allIDs.contains(target.identity) {
                return WindowState(target: target, rect: nil, closed: true)
            }
            if !trusted || target.element == nil {
                let rect = windows.first { $0.identity == target.identity }?.rect
                let fullscreen = rect.map { rect in NSScreen.screens.contains { close($0.frame, rect) } } ?? false
                return WindowState(target: target, rect: app.isHidden || fullscreen ? nil : rect, closed: false)
            }
            if trusted, let element = target.element, !visible.contains(target.identity) {
                var role: CFTypeRef?
                // A destroyed AX element is different from an off-screen/minimized window.
                if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .invalidUIElement {
                    return WindowState(target: target, rect: nil, closed: true)
                }
            }
            guard trusted, let element = target.element, !app.isHidden, visible.contains(target.identity),
                  !(attribute(element, kAXMinimizedAttribute) as? Bool ?? false),
                  !(attribute(element, "AXFullScreen") as? Bool ?? false), let rect = bounds(element) else {
                return WindowState(target: target, rect: nil, closed: false)
            }
            let fullscreen = NSScreen.screens.contains { close($0.frame, rect) }
            return WindowState(target: target, rect: fullscreen ? nil : rect, closed: false)
        }
        onChange?(states)
    }

    private func readWindows(onScreenOnly: Bool = true) -> [WindowGeometry] {
        guard let primary = NSScreen.screens.first,
              let list = CGWindowListCopyWindowInfo(onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? Int32,
                  let number = entry[kCGWindowNumber as String] as? UInt32,
                  let raw = entry[kCGWindowBounds as String] as? [String: Double],
                  let x = raw["X"], let y = raw["Y"], let width = raw["Width"], let height = raw["Height"] else { return nil }
            let rect = DesktopCoordinates.appKitRect(position: CGPoint(x: x, y: y), size: CGSize(width: width, height: height), primaryTop: primary.frame.maxY)
            return WindowGeometry(identity: WindowIdentity(owner: pid, number: number), rect: rect,
                                  layer: entry[kCGWindowLayer as String] as? Int ?? 0,
                                  alpha: entry[kCGWindowAlpha as String] as? Double ?? 1)
        }
    }

    private func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 3 && abs(a.minY - b.minY) < 3 && abs(a.width - b.width) < 3 && abs(a.height - b.height) < 3
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func bounds(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID(), let screen = NSScreen.screens.first else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return DesktopCoordinates.appKitRect(position: point, size: size, primaryTop: screen.frame.maxY)
    }
    deinit {
        fallbackTimer?.invalidate()
        for (center, token) in tokens { center.removeObserver(token) }
    }
}
