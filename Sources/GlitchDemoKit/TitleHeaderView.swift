import UIKit

/// A big title label. In `.naive` mode the text is bound late (as if it came from an
/// asynchronous data source), so the band is blank for `bindingDelay` after every entry.
public final class TitleHeaderView: UIView {
    public let label = UILabel()
    public var mode: GlitchMode = .naive
    public var bindingDelay: TimeInterval = 0.6

    public override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 40, weight: .heavy)
        label.textColor = .black
        label.textAlignment = .center
        label.frame = bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// Called every time the screen is entered.
    public func show(title: String) {
        switch mode {
        case .naive:
            label.text = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + bindingDelay) { [weak self] in
                self?.label.text = title
            }
        case .fixed:
            label.text = title   // ready before the first frame is rendered
        }
    }
}
