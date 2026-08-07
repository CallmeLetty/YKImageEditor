import UIKit
import YKImageEditorCore

protocol LiquifyToolPanelDelegate: AnyObject {
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didUpdatePreview image: UIImage?)
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didApply image: UIImage)
    func liquifyToolPanelDidCancel(_ panel: LiquifyToolPanel)
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didChangeMode mode: LiquifyMode, radiusRatio: CGFloat, strength: CGFloat)
}

/// 液化工具面板：推移塑形（二级工具条样式）。
final class LiquifyToolPanel: UIView {
    weak var delegate: LiquifyToolPanelDelegate?

    private(set) var mode: LiquifyMode = .push
    private(set) var radiusRatio: CGFloat = 0.12
    private(set) var strength: CGFloat = 0.5

    private var sourceImage: UIImage?
    private let deformer = LiquifyDeformer(columns: 56, rows: 56)
    private var renderGeneration = 0
    private var isRendering = false
    private var needsRender = false

    private let radiusSlider = UISlider()
    private let strengthSlider = UISlider()
    private let radiusLabel = UILabel()
    private let strengthLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)
    private let hintLabel = UILabel()

    private let previewMaxDimension: CGFloat = 560

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = EditorTheme.panel
        isHidden = true

        configureSlider(radiusSlider, value: Float((radiusRatio - 0.04) / 0.24), action: #selector(radiusChanged))
        configureSlider(strengthSlider, value: Float(strength), action: #selector(strengthChanged))
        configureLabel(radiusLabel)
        configureLabel(strengthLabel)

        hintLabel.text = "手指滑动推移画面"
        hintLabel.textColor = EditorTheme.secondaryText
        hintLabel.font = .systemFont(ofSize: 12, weight: .medium)

        cancelButton.setImage(
            UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)),
            for: .normal
        )
        cancelButton.tintColor = EditorTheme.primaryText
        cancelButton.backgroundColor = EditorTheme.chip
        cancelButton.layer.cornerRadius = 16
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        resetButton.setTitle("重置", for: .normal)
        resetButton.setTitleColor(EditorTheme.primaryText, for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetButton.backgroundColor = EditorTheme.chip
        resetButton.layer.cornerRadius = 14
        resetButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

        applyButton.setImage(
            UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)),
            for: .normal
        )
        applyButton.tintColor = EditorTheme.accentText
        applyButton.backgroundColor = EditorTheme.accent
        applyButton.layer.cornerRadius = 16
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        activity.color = .white
        activity.hidesWhenStopped = true

        let radiusRow = row(label: radiusLabel, slider: radiusSlider)
        let strengthRow = row(label: strengthLabel, slider: strengthSlider)

        let topRow = UIStackView(arrangedSubviews: [cancelButton, hintLabel, UIView(), resetButton, applyButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [topRow, radiusRow, strengthRow])
        stack.axis = .vertical
        stack.spacing = 10
        addSubview(stack)
        addSubview(activity)
        stack.translatesAutoresizingMaskIntoConstraints = false
        activity.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cancelButton.widthAnchor.constraint(equalToConstant: 32),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),
            applyButton.widthAnchor.constraint(equalToConstant: 32),
            applyButton.heightAnchor.constraint(equalToConstant: 32),
            activity.centerXAnchor.constraint(equalTo: centerXAnchor),
            activity.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])

        updateLabels()
        publishBrushSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(with image: UIImage) {
        sourceImage = image
        deformer.reset()
        isHidden = false
        publishBrushSettings()
        delegate?.liquifyToolPanel(self, didUpdatePreview: nil)
    }

    func dismissPanel() {
        renderGeneration += 1
        isHidden = true
        sourceImage = nil
        deformer.reset()
        activity.stopAnimating()
        delegate?.liquifyToolPanel(self, didUpdatePreview: nil)
    }

    func applyStroke(
        mode: LiquifyMode,
        at point: CGPoint,
        delta: CGPoint,
        radius: CGFloat,
        strength: CGFloat,
        aspectRatio: CGFloat
    ) {
        deformer.apply(
            mode: .push,
            at: point,
            delta: delta,
            radius: radius,
            strength: strength,
            aspectRatio: aspectRatio
        )
        schedulePreviewRender()
    }

    func endStroke() {
        schedulePreviewRender(force: true)
    }

    private func schedulePreviewRender(force: Bool = false) {
        needsRender = true
        guard !isRendering || force else { return }
        flushPreviewRender()
    }

    private func flushPreviewRender() {
        guard needsRender, let source = sourceImage else { return }
        needsRender = false
        isRendering = true
        renderGeneration += 1
        let generation = renderGeneration
        let deformerSnapshot = deformer.snapshot()
        let previewMax = previewMaxDimension

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let preview = LiquifyProcessor.render(
                image: source,
                deformer: deformerSnapshot,
                maxDimension: previewMax
            )
            DispatchQueue.main.async {
                guard let self, generation == self.renderGeneration else { return }
                self.delegate?.liquifyToolPanel(self, didUpdatePreview: preview)
                self.isRendering = false
                if self.needsRender {
                    self.flushPreviewRender()
                }
            }
        }
    }

    @objc private func radiusChanged() {
        radiusRatio = 0.04 + CGFloat(radiusSlider.value) * 0.24
        updateLabels()
        publishBrushSettings()
    }

    @objc private func strengthChanged() {
        strength = CGFloat(strengthSlider.value)
        updateLabels()
        publishBrushSettings()
    }

    @objc private func resetTapped() {
        deformer.reset()
        delegate?.liquifyToolPanel(self, didUpdatePreview: nil)
    }

    @objc private func applyTapped() {
        guard let source = sourceImage else { return }
        guard deformer.hasDeformation else {
            delegate?.liquifyToolPanelDidCancel(self)
            dismissPanel()
            return
        }
        activity.startAnimating()
        applyButton.isEnabled = false
        let deformerRef = deformer.snapshot()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LiquifyProcessor.render(image: source, deformer: deformerRef, maxDimension: 0)
            DispatchQueue.main.async {
                guard let self else { return }
                self.activity.stopAnimating()
                self.applyButton.isEnabled = true
                self.delegate?.liquifyToolPanel(self, didApply: result)
                self.dismissPanel()
            }
        }
    }

    @objc private func cancelTapped() {
        delegate?.liquifyToolPanelDidCancel(self)
        dismissPanel()
    }

    private func publishBrushSettings() {
        delegate?.liquifyToolPanel(self, didChangeMode: .push, radiusRatio: radiusRatio, strength: strength)
    }

    private func updateLabels() {
        radiusLabel.text = String(format: "半径%.0f%%", radiusRatio * 100)
        strengthLabel.text = String(format: "力度%.0f%%", strength * 100)
    }

    private func configureSlider(_ slider: UISlider, value: Float, action: Selector) {
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = value
        slider.minimumTrackTintColor = EditorTheme.accent
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
        slider.addTarget(self, action: action, for: .valueChanged)
    }

    private func configureLabel(_ label: UILabel) {
        label.textColor = EditorTheme.secondaryText
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 72).isActive = true
    }

    private func row(label: UILabel, slider: UISlider) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [label, slider])
        stack.axis = .horizontal
        stack.spacing = 8
        return stack
    }
}
