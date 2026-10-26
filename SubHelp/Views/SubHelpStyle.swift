import SwiftUI

// MARK: - Theme tokens

/// Shared design tokens. Surfaces use Liquid Glass on iOS 26+ and fall back to
/// materials / solid fills on iOS 18–25 so the look degrades gracefully.
enum SubHelpTheme {
    static let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)
    static let savingsGold = Color(red: 1.0, green: 0.84, blue: 0.0)

    /// Large hero surfaces (summary panel, plan cards).
    static let panelRadius: CGFloat = 30
    /// Subscription cards.
    static let cardRadius: CGFloat = 26
    /// Smaller rows and inset surfaces.
    static let rowRadius: CGFloat = 20

    /// Default spring used for state changes across the app.
    static let smooth: Animation = .smooth(duration: 0.35)
    static let snappy: Animation = .snappy(duration: 0.28)
    static let bouncy: Animation = .bouncy(duration: 0.45, extraBounce: 0.1)
}

// MARK: - Glass surfaces

extension View {
    /// Liquid Glass surface (iOS 26+) with a material fallback.
    @ViewBuilder
    func subHelpGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else if let tint {
            self.background(tint, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Rounded glass panel used for hero sections.
    func subHelpPanel(cornerRadius: CGFloat = SubHelpTheme.panelRadius, tint: Color? = nil) -> some View {
        subHelpGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }

    /// Coloured subscription card. Tinted Liquid Glass on iOS 26+, lit solid fill before that.
    func subHelpColorCard(
        _ color: Color,
        cornerRadius: CGFloat = SubHelpTheme.cardRadius,
        opacity: Double = 1
    ) -> some View {
        modifier(SubHelpColorCardModifier(color: color, cornerRadius: cornerRadius, opacity: opacity))
    }

    /// Soft grouped-background surface for rows (Help options, steps, etc.).
    func subHelpRow(cornerRadius: CGFloat = SubHelpTheme.rowRadius) -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct SubHelpColorCardModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(color.opacity(opacity)), in: shape)
        } else {
            content
                .background(color.opacity(opacity), in: shape)
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}

// MARK: - Backdrop

/// Grouped background with a faint brand glow so glass surfaces have something to refract.
struct SubHelpBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            GeometryReader { geo in
                Circle()
                    .fill(SubHelpTheme.brandGold.opacity(colorScheme == .dark ? 0.16 : 0.22))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 70)
                    .offset(x: -geo.size.width * 0.35, y: -geo.size.width * 0.45)
                Circle()
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.12))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.55)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Button styles

/// Capsule button in the iOS 26 idiom: tinted Liquid Glass when prominent, clear glass otherwise.
struct SubHelpButtonStyle: ButtonStyle {
    enum Kind { case prominent, glass }

    var kind: Kind = .prominent
    var tint: Color = .blue
    var compact = false
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(compact ? .subheadline : .body, design: .default, weight: .semibold))
            .foregroundStyle(kind == .prominent ? Color.white : tint)
            .padding(.horizontal, compact ? 14 : 22)
            .padding(.vertical, compact ? 8 : 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .contentShape(Capsule())

        if #available(iOS 26.0, *) {
            label
                .glassEffect(
                    kind == .prominent ? .regular.tint(tint).interactive() : .regular.interactive(),
                    in: Capsule()
                )
        } else {
            label
                .background(
                    kind == .prominent ? tint : Color(.secondarySystemBackground),
                    in: Capsule()
                )
                .opacity(configuration.isPressed ? 0.82 : 1)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(SubHelpTheme.snappy, value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == SubHelpButtonStyle {
    static func subHelp(
        _ kind: SubHelpButtonStyle.Kind = .prominent,
        tint: Color = .blue,
        compact: Bool = false,
        fullWidth: Bool = false
    ) -> SubHelpButtonStyle {
        SubHelpButtonStyle(kind: kind, tint: tint, compact: compact, fullWidth: fullWidth)
    }
}

/// Soft press feedback for custom tappable cards and rows (no chrome of its own).
struct SubHelpPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(SubHelpTheme.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SubHelpPressableStyle {
    static var subHelpPressable: SubHelpPressableStyle { SubHelpPressableStyle() }
}

// MARK: - Toolbar buttons

/// "Done" in a toolbar: checkmark confirm on iOS 26+, text button before that.
struct SubHelpDoneButton: View {
    var title: LocalizedStringKey = "Done"
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(title, role: .confirm, action: action)
        } else {
            Button(title, action: action)
                .fontWeight(.semibold)
        }
    }
}

/// "Cancel" in a toolbar: xmark close on iOS 26+, text button before that.
struct SubHelpCancelButton: View {
    var title: LocalizedStringKey = "Cancel"
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(title, role: .close, action: action)
        } else {
            Button(title, action: action)
        }
    }
}

// MARK: - Misc modifiers

extension View {
    /// Rounded numerals that tick when the value changes.
    func subHelpNumeric<V: Equatable>(value: V) -> some View {
        self
            .fontDesign(.rounded)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(SubHelpTheme.smooth, value: value)
    }

    /// Cards ease in/out as they approach the scroll edges.
    func subHelpScrollFade() -> some View {
        scrollTransition(axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.55)
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .blur(radius: phase.isIdentity ? 0 : 1.5)
        }
    }

    /// Tab bar collapses on scroll on iOS 26+.
    @ViewBuilder
    func subHelpTabBarBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
