import UIKit
import YKImageEditorCore

protocol BlendToolPanelDelegate: AnyObject {
    /// `effect` 为强度 100% 的混合结果；`intensity` 由预览层透明度表现。`effect == nil` 表示清除预览。
    func blendToolPanel(_ panel: BlendToolPanel, didUpdatePreview effect: UIImage?, intensity: CGFloat)
    func blendToolPanel(_ panel: BlendToolPanel, didApply image: UIImage)
    func blendToolPanelDidCancel(_ panel: BlendToolPanel)
}

/// 混合修图面板：预设 + 强度滑杆 + 实时预览。
///
/// 性能策略：
/// - 滑杆只改预览层 `alpha`，不重算像素
/// - 切换预设时在缩略图尺寸上异步生成 100% 效果图
/// - 点「应用」时才在原图尺寸上算一次最终结果
final class BlendToolPanel: UIView {
    weak var delegate: BlendToolPanelDelegate?

    private var baseImage: UIImage?
    private var previewBase: UIImage?
    private var selectedPreset: BlendPreset = .warmColorBurn
    private var intensity: CGFloat = 0.45
    /// 当前预设在预览尺寸上的 100% 混合结果。
    private var cachedFullEffect: UIImage?
    private var renderGeneration = 0

    private let presetScroll = UIScrollView()
    private let presetStack = UIStackView()
    private let intensitySlider = UISlider()
    private let intensityLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)
    private var presetButtons: [UIButton] = []

    /// 预览最长边，保证滑动跟手。
    private let previewMaxDimension: CGFloat = 1080

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.92)
        isHidden = true

        presetScroll.showsHorizontalScrollIndicator = false
        presetStack.axis = .horizontal
        presetStack.spacing = 8
        presetStack.alignment = .center

        for preset in BlendPreset.allCases {
            let button = UIButton(type: .system)
            button.setTitle(preset.displayName, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            button.layer.cornerRadius = 14
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            button.tag = BlendPreset.allCases.firstIndex(of: preset) ?? 0
            button.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            presetStack.addArrangedSubview(button)
            presetButtons.append(button)
        }

        intensitySlider.minimumValue = 0
        intensitySlider.maximumValue = 1
        intensitySlider.value = Float(intensity)
        intensitySlider.tintColor = .systemGreen
        intensitySlider.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)

        intensityLabel.textColor = .white
        intensityLabel.font = .systemFont(ofSize: 12)
        intensityLabel.textAlignment = .center
        intensityLabel.adjustsFontSizeToFitWidth = true

        activity.color = .white
        activity.hidesWhenStopped = true

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        applyButton.setTitle("应用混合", for: .normal)
        applyButton.setTitleColor(.systemGreen, for: .normal)
        applyButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        presetScroll.addSubview(presetStack)
        addSubview(presetScroll)
        addSubview(intensitySlider)
        addSubview(intensityLabel)
        addSubview(cancelButton)
        addSubview(applyButton)
        addSubview(activity)

        [presetScroll, presetStack, intensitySlider, intensityLabel, cancelButton, applyButton, activity].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            presetScroll.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            presetScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            presetScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            presetScroll.heightAnchor.constraint(equalToConstant: 36),

            presetStack.topAnchor.constraint(equalTo: presetScroll.topAnchor),
            presetStack.bottomAnchor.constraint(equalTo: presetScroll.bottomAnchor),
            presetStack.leadingAnchor.constraint(equalTo: presetScroll.leadingAnchor),
            presetStack.trailingAnchor.constraint(equalTo: presetScroll.trailingAnchor),
            presetStack.heightAnchor.constraint(equalTo: presetScroll.heightAnchor),

            intensityLabel.topAnchor.constraint(equalTo: presetScroll.bottomAnchor, constant: 8),
            intensityLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            intensityLabel.widthAnchor.constraint(equalToConstant: 64),

            intensitySlider.centerYAnchor.constraint(equalTo: intensityLabel.centerYAnchor),
            intensitySlider.leadingAnchor.constraint(equalTo: intensityLabel.trailingAnchor, constant: 8),
            intensitySlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),

            applyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            applyButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),

            activity.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            activity.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -12)
        ])

        refreshPresetSelection()
        updateIntensityLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(with baseImage: UIImage) {
        self.baseImage = baseImage
        previewBase = ImageGeometry.downsample(baseImage, maxDimension: previewMaxDimension)
        cachedFullEffect = nil
        isHidden = false
        publishIntensityOnly()
        rebuildPreviewEffectAsync()
    }

    func dismissPanel() {
        renderGeneration += 1
        isHidden = true
        baseImage = nil
        previewBase = nil
        cachedFullEffect = nil
        activity.stopAnimating()
        applyButton.isEnabled = true
        delegate?.blendToolPanel(self, didUpdatePreview: nil, intensity: 0)
    }

    @objc private func presetTapped(_ sender: UIButton) {
        let presets = BlendPreset.allCases
        guard sender.tag >= 0, sender.tag < presets.count else { return }
        let preset = presets[sender.tag]
        guard preset != selectedPreset || cachedFullEffect == nil else { return }
        selectedPreset = preset
        cachedFullEffect = nil
        refreshPresetSelection()
        rebuildPreviewEffectAsync()
    }

    @objc private func intensityChanged() {
        intensity = CGFloat(intensitySlider.value)
        updateIntensityLabel()
        // 只改透明度，不重绘
        publishIntensityOnly()
    }

    @objc private func applyTapped() {
        guard let base = baseImage else { return }
        applyButton.isEnabled = false
        activity.startAnimating()
        let preset = selectedPreset
        let strength = intensity
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ImageBlender.blend(base: base, preset: preset, intensity: strength)
            DispatchQueue.main.async {
                guard let self else { return }
                self.activity.stopAnimating()
                self.applyButton.isEnabled = true
                self.delegate?.blendToolPanel(self, didApply: result)
                self.dismissPanel()
            }
        }
    }

    @objc private func cancelTapped() {
        delegate?.blendToolPanelDidCancel(self)
        dismissPanel()
    }

    private func rebuildPreviewEffectAsync() {
        guard let previewBase else { return }
        renderGeneration += 1
        let generation = renderGeneration
        let preset = selectedPreset
        activity.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let overlay = preset.makeOverlayImage(size: previewBase.size, scale: previewBase.scale)
            let effect = ImageBlender.blendFully(
                base: previewBase,
                overlay: overlay,
                mode: preset.mode
            )
            DispatchQueue.main.async {
                guard let self, generation == self.renderGeneration else { return }
                self.cachedFullEffect = effect
                self.activity.stopAnimating()
                self.delegate?.blendToolPanel(self, didUpdatePreview: effect, intensity: self.intensity)
            }
        }
    }

    private func publishIntensityOnly() {
        delegate?.blendToolPanel(self, didUpdatePreview: cachedFullEffect, intensity: intensity)
    }

    private func refreshPresetSelection() {
        let presets = BlendPreset.allCases
        for button in presetButtons {
            let selected = presets.indices.contains(button.tag) && presets[button.tag] == selectedPreset
            button.backgroundColor = selected
                ? UIColor.systemGreen.withAlphaComponent(0.35)
                : UIColor.white.withAlphaComponent(0.12)
            button.setTitleColor(selected ? .systemGreen : .white, for: .normal)
        }
    }

    private func updateIntensityLabel() {
        intensityLabel.text = "强度\(Int(intensity * 100))%"
    }
}
