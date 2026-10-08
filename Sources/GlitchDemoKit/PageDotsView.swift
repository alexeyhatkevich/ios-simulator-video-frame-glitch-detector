import UIKit

/// Page indicator. Idle dots are solid green, the selected dot is solid red: flat colours
/// make the dots trivial to find in a video frame.
public final class PageDotsView: UIView {
    public static let idleColor = UIColor(red: 0, green: 1, blue: 0, alpha: 1)
    public static let selectedColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)

    public var mode: GlitchMode = .naive
    public let count: Int
    public private(set) var selectedDot: DotView?
    public private(set) var selectedIndex = 0
    private let spacing: CGFloat = 16

    public init(count: Int = 5) {
        self.count = count
        super.init(frame: .zero)
        for i in 0..<count {
            let dot = DotView(color: Self.idleColor)
            dot.frame = dotFrame(at: i)
            addSubview(dot)
        }
        place(DotView(color: Self.selectedColor), at: 0)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: CGFloat(count) * DotView.diameter + CGFloat(count - 1) * spacing,
               height: DotView.diameter)
    }

    private func dotFrame(at index: Int) -> CGRect {
        CGRect(x: CGFloat(index) * (DotView.diameter + spacing), y: 0,
               width: DotView.diameter, height: DotView.diameter)
    }

    private func place(_ dot: DotView, at index: Int) {
        selectedDot?.removeFromSuperview()
        dot.frame = dotFrame(at: index)
        addSubview(dot)
        selectedDot = dot
        selectedIndex = index
    }

    public func select(_ index: Int) {
        switch mode {
        case .naive:
            // BUG: the dot is created inside the animation block, so it inherits the
            // block's duration and animates from its initial state (square, zero frame).
            UIView.animate(withDuration: 0.4) {
                self.place(DotView(color: Self.selectedColor), at: index)
            }
        case .fixed:
            // Build and configure outside the block; animate only the fade-in.
            let dot = DotView(color: Self.selectedColor)
            dot.alpha = 0
            place(dot, at: index)
            UIView.animate(withDuration: 0.4) { dot.alpha = 1 }
        }
    }
}
