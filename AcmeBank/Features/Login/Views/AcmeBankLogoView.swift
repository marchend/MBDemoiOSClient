import SwiftUI

/// AcmeBank brand logo — hexagonal dark-navy shape with a white "A".
///
/// Rendered entirely in SwiftUI so there is no image asset dependency and
/// the shape scales cleanly at any size.
struct AcmeBankLogoView: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(Color.acmeNavy)
                .frame(width: size, height: size)

            Text("A")
                .font(.system(size: size * 0.45, weight: .bold, design: .default))
                .foregroundStyle(Color.white)
        }
        .accessibilityLabel("AcmeBank logo")
        .accessibilityHidden(true)
    }
}

// MARK: - Hexagon helper

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        // Flat-top hexagon: first vertex at 30°, step 60°.
        for i in 0 ..< 6 {
            let angleDeg = Double(60 * i) - 30
            let angleRad = angleDeg * .pi / 180
            let x = cx + CGFloat(cos(angleRad)) * r
            let y = cy + CGFloat(sin(angleRad)) * r
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    AcmeBankLogoView()
        .padding()
}
