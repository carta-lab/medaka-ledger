import SwiftUI

// 複数の画面で使う部品。

/// 利用者向けのエラー表示（CLAUDE.md：失敗は利用者向けの文言で Alert に出す）。
struct UserFacingError: Identifiable {
    let id = UUID()
    var title: String
    var message: String

    init(title: String = String(localized: "保存できませんでした"), message: String) {
        self.title = title
        self.message = message
    }

    init(_ error: any Error, title: String = String(localized: "保存できませんでした")) {
        self.title = title
        self.message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

extension View {
    func errorAlert(_ error: Binding<UserFacingError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

private struct ErrorAlertModifier: ViewModifier {
    @Binding var error: UserFacingError?
    @State private var isPresented = false

    init(error: Binding<UserFacingError?>) {
        _error = error
    }

    func body(content: Content) -> some View {
        content
            .alert(error?.title ?? "", isPresented: $isPresented, presenting: error) { _ in
                Button("OK") {}
            } message: { error in
                Text(verbatim: error.message)
            }
            .onChange(of: error?.id, initial: true) { _, id in
                isPresented = id != nil
            }
            .onChange(of: isPresented) { _, shown in
                if !shown { error = nil }
            }
    }
}

/// 画面の下に大きく置く「保存」ボタン（CLAUDE.md：主要なボタンは高さ48pt以上、片手で届く下側）。
struct BottomSaveBar: ViewModifier {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let identifier: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            Button(action: action) {
                Text(title)
            }
            .buttonStyle(LargeButtonStyle())
            .disabled(!isEnabled)
            .accessibilityIdentifier(identifier)
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}

extension View {
    func bottomSaveBar(
        _ title: LocalizedStringKey = "保存",
        isEnabled: Bool = true,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(BottomSaveBar(title: title, isEnabled: isEnabled, identifier: identifier, action: action))
    }
}

/// 整数の入力欄。空欄は nil（未入力）。全角の数字も受け付ける。
struct IntField: View {
    private let title: LocalizedStringKey
    @Binding private var value: Int?
    @State private var text: String

    init(_ title: LocalizedStringKey, value: Binding<Int?>) {
        self.title = title
        self._value = value
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.numberPad)
            .onChange(of: text) { _, newText in
                let normalized = (newText.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? newText)
                    .filter { $0.isASCII && $0.isNumber }
                if normalized != newText {
                    text = normalized
                }
                value = Int(normalized)
            }
            .onChange(of: value) { _, newValue in
                let current = Int(text)
                if current != newValue {
                    text = newValue.map(String.init) ?? ""
                }
            }
    }
}

/// 小数の入力欄（容量など）を文字列で受けて Double にする。
enum NumberParsing {
    static func double(from text: String) -> Double? {
        let normalized = (text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(normalized)
    }

    /// 空欄は未入力として正しい。何か入れてあるのに数字として読めないときは false。
    static func isValidOptional(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || double(from: text) != nil
    }

    static func text(from value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.grouping(.never))
    }
}

/// 候補を横に並べたボタン。押すと onSelect に渡す。
struct SuggestionChips: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            Text(verbatim: suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.fill.tertiary, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// 一覧の行に出すラベルと値。
struct InfoRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(verbatim: value)
        }
    }
}
