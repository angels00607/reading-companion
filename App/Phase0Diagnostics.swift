#if DEBUG
import UIKit

/// Opt-in observation only. Does not change fonts, traits, layout or audit results.
@MainActor
final class Phase0Diagnostics: NSObject {
    static let shared = Phase0Diagnostics()
    private var timer: Timer?
    private var started = false

    func start() {
        guard !started, ProcessInfo.processInfo.arguments.contains("-phase0-diagnostics") else { return }
        started = true
        NotificationCenter.default.addObserver(self, selector: #selector(categoryChanged),
            name: UIContentSizeCategory.didChangeNotification, object: nil)
        sample(reason: "launch")
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in Phase0Diagnostics.shared.sample(reason: "timer") }
        }
    }

    @objc private func categoryChanged(_ notification: Notification) {
        sample(reason: "categoryChanged")
    }

    private func sample(reason: String) {
        var rows: [[String: Any]] = []
        func walk(_ view: UIView, path: String) {
            var row: [String: Any] = ["path": path, "class": String(describing: type(of: view)),
                "identifier": view.accessibilityIdentifier ?? "", "label": view.accessibilityLabel ?? "",
                "frameInWindow": String(describing: view.convert(view.bounds, to: nil)),
                "isAccessibilityElement": view.isAccessibilityElement,
                "hidden": view.isHidden, "alpha": view.alpha,
                "category": view.traitCollection.preferredContentSizeCategory.rawValue]
            let font: UIFont?
            if let label = view as? UILabel {
                font = label.font
                row["text"] = label.text ?? ""
                row["adjustsFontForContentSizeCategory"] = label.adjustsFontForContentSizeCategory
            } else if let text = view as? UITextView {
                font = text.font
                row["text"] = text.text ?? ""
                row["adjustsFontForContentSizeCategory"] = text.adjustsFontForContentSizeCategory
            } else { font = nil }
            if let font {
                row["fontName"] = font.fontName
                row["pointSize"] = font.pointSize
                row["fontDescriptor"] = String(describing: font.fontDescriptor.fontAttributes)
            } else { row["fontExposure"] = "No public UIKit text font on this view" }
            rows.append(row)
            for (index, child) in view.subviews.enumerated() {
                walk(child, path: path + "/" + String(index))
            }
            for (index, object) in (view.accessibilityElements ?? []).enumerated() {
                if let element = object as? UIAccessibilityElement {
                    rows.append(["path": path + "/ax/" + String(index),
                        "class": String(describing: type(of: element)),
                        "identifier": element.accessibilityIdentifier ?? "",
                        "label": element.accessibilityLabel ?? "",
                        "accessibilityFrame": String(describing: element.accessibilityFrame),
                        "traits": element.accessibilityTraits.rawValue,
                        "fontExposure": "UIAccessibilityElement exposes no UIFont"])
                }
            }
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for (sceneIndex, scene) in scenes.enumerated() {
            for (windowIndex, window) in scene.windows.enumerated() {
                walk(window, path: "scene/\(sceneIndex)/window/\(windowIndex)")
                rows.append(["sceneOrientation": scene.interfaceOrientation.rawValue,
                    "screenBounds": String(describing: scene.screen.bounds)])
            }
        }
        let record: [String: Any] = ["time": Date().timeIntervalSince1970, "reason": reason,
            "process": ProcessInfo.processInfo.processIdentifier,
            "category": UIApplication.shared.preferredContentSizeCategory.rawValue,
            "views": rows]
        do {
            var data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            data.append(10)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("phase0-diagnostics.jsonl")
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch { print("PHASE0 DIAGNOSTIC WRITE FAILED: \(error)") }
    }
}
#endif
