import SwiftUI

public struct VirtualKeyboardView: View {
    @ObservedObject public var session: AirPulseSession

    @State private var isCtrlActive: Bool = false
    @State private var isAltActive: Bool = false
    @State private var isWinActive: Bool = false
    @State private var isShiftActive: Bool = false
    @State private var textInputBuffer: String = ""
    @FocusState private var isTextFieldFocused: Bool

    public init(session: AirPulseSession) {
        self.session = session
    }

    private var activeModifiers: [UInt32] {
        var mods: [UInt32] = []
        if isCtrlActive { mods.append(WindowsVK.ctrl.rawValue) }
        if isAltActive { mods.append(WindowsVK.alt.rawValue) }
        if isWinActive { mods.append(WindowsVK.win.rawValue) }
        if isShiftActive { mods.append(WindowsVK.shift.rawValue) }
        return mods
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Function Key row (F1 - F12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Group {
                        keyButton("F1", vk: .f1)
                        keyButton("F2", vk: .f2)
                        keyButton("F3", vk: .f3)
                        keyButton("F4", vk: .f4)
                        keyButton("F5", vk: .f5)
                        keyButton("F6", vk: .f6)
                        keyButton("F7", vk: .f7)
                        keyButton("F8", vk: .f8)
                        keyButton("F9", vk: .f9)
                        keyButton("F10", vk: .f10)
                        keyButton("F11", vk: .f11)
                        keyButton("F12", vk: .f12)
                    }
                    Divider().frame(height: 24).background(Color.white.opacity(0.3))
                    keyButton("PrtScn", vk: .printScreen)
                    keyButton("Home", vk: .home)
                    keyButton("End", vk: .end)
                    keyButton("PgUp", vk: .pageUp)
                    keyButton("PgDn", vk: .pageDown)
                }
                .padding(.horizontal, 10)
            }

            // Quick shortcuts row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    comboButton("Ctrl+C") {
                        sendCombo([WindowsVK.ctrl.rawValue], key: 0x43) // 'C'
                    }
                    comboButton("Ctrl+V") {
                        sendCombo([WindowsVK.ctrl.rawValue], key: 0x56) // 'V'
                    }
                    comboButton("Alt+Tab") {
                        sendCombo([WindowsVK.alt.rawValue], key: WindowsVK.tab.rawValue)
                    }
                    comboButton("Win+D") {
                        sendCombo([WindowsVK.win.rawValue], key: 0x44) // 'D'
                    }
                    comboButton("Ctrl+Z") {
                        sendCombo([WindowsVK.ctrl.rawValue], key: 0x5A) // 'Z'
                    }
                    comboButton("Enter", vk: .enter)
                    comboButton("Esc", vk: .escape)
                    comboButton("Tab", vk: .tab)
                    comboButton("Del", vk: .delete)
                    comboButton("Backspace", vk: .backspace)
                }
                .padding(.horizontal, 10)
            }

            // Main Bar: Modifiers + Arrow keys + Keyboard invoke
            HStack(spacing: 8) {
                // Modifiers
                modifierToggle("Ctrl", isActive: $isCtrlActive, vk: .ctrl)
                modifierToggle("Alt", isActive: $isAltActive, vk: .alt)
                modifierToggle("Win", isActive: $isWinActive, vk: .win)
                modifierToggle("Shift", isActive: $isShiftActive, vk: .shift)

                Spacer()

                // Arrows
                HStack(spacing: 4) {
                    keyButton("←", vk: .left)
                    VStack(spacing: 4) {
                        keyButton("↑", vk: .up)
                        keyButton("↓", vk: .down)
                    }
                    keyButton("→", vk: .right)
                }

                // Keyboard input trigger
                Button(action: {
                    isTextFieldFocused = true
                }) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 38)
                        .background(Color.blue.opacity(0.85))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 10)

            // Hidden text field for system keyboard
            ZStack {
                TextField("", text: $textInputBuffer)
                    .focused($isTextFieldFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .onChange(of: textInputBuffer) { newValue in
                        if !newValue.isEmpty {
                            session.sendTextInput(newValue)
                            textInputBuffer = ""
                        }
                    }
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.6))
        .cornerRadius(14)
        .padding(.horizontal, 8)
    }

    private func keyButton(_ title: String, vk: WindowsVK) -> some View {
        Button(action: {
            session.sendKeyPress(vkCode: vk.rawValue, modifiers: activeModifiers)
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color.white.opacity(0.15))
                .cornerRadius(6)
        }
    }

    private func comboButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Color.cyan.opacity(0.18))
                .cornerRadius(6)
        }
    }

    private func comboButton(_ title: String, vk: WindowsVK) -> some View {
        Button(action: {
            session.sendKeyPress(vkCode: vk.rawValue, modifiers: activeModifiers)
        }) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
        }
    }

    private func modifierToggle(_ title: String, isActive: Binding<Bool>, vk: WindowsVK) -> some View {
        Button(action: {
            isActive.wrappedValue.toggle()
            session.sendKeyEvent(vkCode: vk.rawValue, keyDown: isActive.wrappedValue)
        }) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isActive.wrappedValue ? .white : .white.opacity(0.7))
                .frame(width: 44, height: 38)
                .background(isActive.wrappedValue ? Color.blue : Color.white.opacity(0.15))
                .cornerRadius(8)
        }
    }

    private func sendCombo(_ modKeys: [UInt32], key: UInt32) {
        for m in modKeys { session.sendKeyEvent(vkCode: m, keyDown: true) }
        session.sendKeyPress(vkCode: key, modifiers: modKeys)
        for m in modKeys { session.sendKeyEvent(vkCode: m, keyDown: false) }
    }
}
