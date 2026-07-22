import SwiftUI

// Real iOS 26 Liquid Glass surfaces.
//
// Before this existed, every card imitated glass by stacking
// `.ultraThinMaterial` + tint fills + gradient strokes. System Liquid Glass
// replaces all of that with one modifier: it refracts the content behind it,
// supplies its own edge lighting, and adapts to light/dark and reduced
// transparency automatically — so converted call sites should NOT keep
// their own stroke/highlight overlays.

extension View {
    /// Standard card surface: system Liquid Glass in a rounded rectangle.
    func glassCard(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            Self.glass(tint: tint, interactive: interactive),
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    /// Pill/capsule surface — buttons, chips, floating bars.
    func glassPill(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            Self.glass(tint: tint, interactive: interactive),
            in: .capsule
        )
    }

    /// Circular surface — icon buttons, avatars.
    func glassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            Self.glass(tint: tint, interactive: interactive),
            in: .circle
        )
    }

    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}
