import UIKit
import YKImageEditorCore

protocol LiquifyToolPanelDelegate: AnyObject {
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didUpdatePreview image: UIImage?)
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didApply image: UIImage)
    func liquifyToolPanelDidCancel(_ panel: LiquifyToolPanel)
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didChangeMode mode: LiquifyMode, radiusRatio: CGFloat, strength: CGFloat)
}

/// 液化工具面板：推移塑形。
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

    private let previewMaxDimension: CGFloat = 560

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.92)
        isHidden = true

        // radiusSlider 0...1 → 实际半径比例 0.04...0.28
        configureSlider(radiusSlider, value: Float((radiusRatio - 0.04) / 0.24), action: #selector(radiusChanged))
        configureSlider(strengthSlider, value: Float(strength), action: #selector(strengthChanged))
        configureLabel(radiusLabel)
        configureLabel(strengthLabel)

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        resetButton.setTitle("重置", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

        applyButton.setTitle("应用液化", for: .normal)
        applyButton.setTitleColor(.systemGreen, for: .normal)
        applyButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        activity.color = .white
        activity.hidesWhenStopped = true

        let radiusRow = row(label: radiusLabel, slider: radiusSlider)
        let strengthRow = row(label: strengthLabel, slider: strengthSlider)
        let actionRow = UIStackView(arrangedSubviews: [cancelButton, resetButton, applyButton])
        actionRow.axis = .horizontal
        actionRow.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [radiusRow, strengthRow, actionRow])
        stack.axis = .vertical
        stack.spacing = 10
        addSubview(stack)
        addSubview(activity)
        stack.translatesAutoresizingMaskIntoConstraints = false
        activity.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            activity.centerXAnchor.constraint(equalTo: centerXAnchor),
            activity.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -6)
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

    /// 由笔刷层回调：写入形变并刷新预览。
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
        slider.tintColor = .systemGreen
        slider.addTarget(self, action: action, for: .valueChanged)
    }

    private func configureLabel(_ label: UILabel) {
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
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
