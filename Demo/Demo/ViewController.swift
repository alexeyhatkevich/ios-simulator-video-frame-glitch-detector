import UIKit
import GlitchDemoKit

/// One screen with two scenarios:
///  - Flash: switch to the "Settings" tab; the title may be blank for ~0.6 s (naive).
///  - Dots:  step the page indicator; the new red dot may animate in as a square (naive).
/// Launch arguments `-mode naive|fixed -scenario flash|dots -autorun 1` drive it unattended
/// (this is what tools/record.sh uses).
final class ViewController: UIViewController {
    private let modeControl = UISegmentedControl(items: ["Naive", "Fixed"])
    private let scenarioControl = UISegmentedControl(items: ["Flash", "Dots"])
    private let runButton = UIButton(type: .system)
    private let hint = UILabel()
    private let header = TitleHeaderView(frame: .zero)
    private let dots = PageDotsView(count: 5)
    private let homeTab = UIButton(type: .system)
    private let settingsTab = UIButton(type: .system)

    // Flat, unique colour: the "we are on the target screen" signature for the analyzer.
    static let selectedTabColor = UIColor(red: 0.42, green: 0.24, blue: 0.94, alpha: 1)
    static let idleTabColor = UIColor(white: 0.85, alpha: 1)

    private var mode: GlitchMode { modeControl.selectedSegmentIndex == 0 ? .naive : .fixed }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let defaults = UserDefaults.standard
        modeControl.selectedSegmentIndex = defaults.string(forKey: "mode") == "fixed" ? 1 : 0
        scenarioControl.selectedSegmentIndex = defaults.string(forKey: "scenario") == "dots" ? 1 : 0

        for control in [modeControl, scenarioControl] {
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(control)
        }
        runButton.setTitle("Run scenario", for: .normal)
        runButton.addAction(UIAction { [weak self] _ in self?.run() }, for: .touchUpInside)
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .darkGray
        hint.numberOfLines = 0
        hint.text = "Flash: title must be visible the instant Settings is selected.\nDots: the red dot must stay a circle."
        for v in [runButton, hint, header, dots] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let tabs = UIStackView(arrangedSubviews: [homeTab, settingsTab])
        tabs.distribution = .fillEqually
        tabs.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabs)
        homeTab.setTitle("Home", for: .normal)
        settingsTab.setTitle("Settings", for: .normal)
        homeTab.addAction(UIAction { [weak self] _ in self?.selectTab(settings: false) }, for: .touchUpInside)
        settingsTab.addAction(UIAction { [weak self] _ in self?.selectTab(settings: true) }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 240),
            scenarioControl.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12),
            scenarioControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scenarioControl.widthAnchor.constraint(equalToConstant: 240),
            runButton.topAnchor.constraint(equalTo: scenarioControl.bottomAnchor, constant: 12),
            runButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.topAnchor.constraint(equalTo: runButton.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            // Title band: y = 270...330 (in a 402x874 frame)
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 270),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 60),
            // Dots band: y = 450...470
            dots.topAnchor.constraint(equalTo: view.topAnchor, constant: 450),
            dots.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tabs.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabs.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabs.heightAnchor.constraint(equalToConstant: 83),
        ])
        selectTab(settings: false)
        if defaults.bool(forKey: "autorun") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                run()
            }
        }
    }

    private func selectTab(settings: Bool) {
        homeTab.backgroundColor = settings ? Self.idleTabColor : Self.selectedTabColor
        settingsTab.backgroundColor = settings ? Self.selectedTabColor : Self.idleTabColor
        homeTab.setTitleColor(settings ? .black : .white, for: .normal)
        settingsTab.setTitleColor(settings ? .white : .black, for: .normal)
        header.mode = mode
        header.isHidden = !settings
        if settings { header.show(title: "Settings") }
    }

    private func run() {
        dots.mode = mode
        let flash = scenarioControl.selectedSegmentIndex == 0
        Task { @MainActor in
            if flash {
                for _ in 0..<4 {
                    selectTab(settings: false)
                    try? await Task.sleep(for: .seconds(1.2))
                    selectTab(settings: true)
                    try? await Task.sleep(for: .seconds(1.5))
                }
            } else {
                for index in [1, 2, 3, 4, 0, 1, 2] {
                    dots.select(index)
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }
}
