import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    static let showMacEverything = Notification.Name("MacEverything.ShowWindow")
    static let focusMacEverythingSearch = Notification.Name("MacEverything.FocusSearch")
}

final class GlobalHotKey: @unchecked Sendable {
    private struct Candidate {
        let keyCode: UInt32
        let modifiers: UInt32
        let label: String
    }

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let action: @Sendable () -> Void

    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }

    @discardableResult
    func registerFirstAvailable() -> String? {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            NSLog("MacEverything global hotkey pressed")
            hotKey.action()
            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            NSLog("MacEverything failed to install hotkey handler: %d", handlerStatus)
            return nil
        }

        let candidates = [
            Candidate(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey), label: "⌘⇧F"),
            Candidate(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥F"),
            Candidate(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(controlKey | shiftKey), label: "⌃⇧F")
        ]
        let signature = OSType(0x4D455652) // "MEVR"

        for (index, candidate) in candidates.enumerated() {
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(
                candidate.keyCode,
                candidate.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &reference
            )

            if status == noErr, let reference {
                hotKeyRef = reference
                NSLog("MacEverything registered global hotkey: %@", candidate.label)
                return candidate.label
            }
            NSLog("MacEverything could not register %@: %d", candidate.label, status)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        return nil
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
