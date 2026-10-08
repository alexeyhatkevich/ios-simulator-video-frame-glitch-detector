import UIKit

/// A round dot. Records the animation duration that was in effect when it was built.
public final class DotView: UIView {
    nonisolated(unsafe) public static var lastBuildInheritedDuration: TimeInterval = 0
    public static let diameter: CGFloat = 20

    public init(color: UIColor) {
        DotView.lastBuildInheritedDuration = UIView.inheritedAnimationDuration
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter))
        backgroundColor = color
        layer.cornerRadius = Self.diameter / 2
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }
}
