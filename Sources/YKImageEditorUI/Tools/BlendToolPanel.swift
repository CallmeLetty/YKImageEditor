import UIKit
import YKImageEditorCore

protocol BlendToolPanelDelegate: AnyObject {
    /// `effect` 为强度 100% 的滤镜结果；`intensity` 由预览层透明度表现。`effect == nil` 表示清除预览。
    func blendToolPanel(_ panel: BlendToolPanel, didUpdatePreview effect: UIImage?, intensity: CGFloat)
    func blendToolPanel(_ panel: BlendToolPanel, didApply image: UIImage)
    func blendToolPanelDidCancel(_ panel: BlendToolPanel)
}

/// 滤镜面板：缩略图预设 + 强度滑杆（醒图式横向预览条）。
final class BlendToolPanel: UIView {
    weak var delegate: BlendToolPanelDelegate?

    private var baseImage: UIImage?
    private var previewBase: UIImage?
    private var selectedPreset: BlendPreset = .warmColorBurn
    private var intensity: CGFloat = 0.45
    private var cachedFullEffect: UIImage?
    private var renderGeneration = 0
    private var thumbnailGeneration = 0

    private let thumbnailScroll = UIScrollView()
    private let thumbnailStack = UIStackView()
    private let intensitySlider = UISlider()
    private let intensityLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)
    private var cells: [FilterPresetCell] = []

    private let previewMaxDimension: CGFloat = 1080
    private let thumbSize = CGSize(width: 72, height: 72)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = EditorTheme.panel
        isHidden = true

        thumbnailScroll.showsHorizontalScrollIndicator = false
        thumbnailStack.axis = .horizontal
        thumbnailStack.spacing = 10
        thumbnailStack.alignment = .top

        for preset in BlendPreset.allCases {
            let cell = FilterPresetCell(preset: preset, size: thumbSize)
            cell.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            thumbnailStack.addArrangedSubview(cell)
            cells.append(cell)
        }

        intensitySlider.minimumValue = 0
        intensitySlider.maximumValue = 1
        intensitySlider.value = Float(intensity)
        intensitySlider.minimumTrackTintColor = EditorTheme.accent
        intensitySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
        intensitySlider.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)

        intensityLabel.textColor = EditorTheme.secondaryText
        intensityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        intensityLabel.textAlignment = .center

        activity.color = .white
        activity.hidesWhenStopped = true

        cancelButton.setImage(
            UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)),
            for: .normal
        )
        cancelButton.tintColor = EditorTheme.primaryText
        cancelButton.backgroundColor = EditorTheme.chip
        cancelButton.layer.cornerRadius = 16
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        applyButton.setImage(
            UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)),
            for: .normal
        )
        applyButton.tintColor = EditorTheme.accentText
        applyButton.backgroundColor = EditorTheme.accent
        applyButton.layer.cornerRadius = 16
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        thumbnailScroll.addSubview(thumbnailStack)
        addSubview(thumbnailScroll)
        addSubview(intensitySlider)
        addSubview(intensityLabel)
        addSubview(cancelButton)
        addSubview(applyButton)
        addSubview(activity)

        [thumbnailScroll, thumbnailStack, intensitySlider, intensityLabel, cancelButton, applyButton, activity].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            cancelButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cancelButton.widthAnchor.constraint(equalToConstant: 32),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),

            applyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            applyButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            applyButton.widthAnchor.constraint(equalToConstant: 32),
            applyButton.heightAnchor.constraint(equalToConstant: 32),

            intensityLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            intensityLabel.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 10),
            intensityLabel.widthAnchor.constraint(equalToConstant: 52),

            intensitySlider.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            intensitySlider.leadingAnchor.constraint(equalTo: intensityLabel.trailingAnchor, constant: 6),
            intensitySlider.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -10),

            activity.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            activity.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -6),

            thumbnailScroll.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
            thumbnailScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnailScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            thumbnailScroll.heightAnchor.constraint(equalToConstant: 96),

            thumbnailStack.topAnchor.constraint(equalTo: thumbnailScroll.topAnchor),
            thumbnailStack.bottomAnchor.constraint(equalTo: thumbnailScroll.bottomAnchor),
            thumbnailStack.leadingAnchor.constraint(equalTo: thumbnailScroll.leadingAnchor, constant: 14),
            thumbnailStack.trailingAnchor.constraint(equalTo: thumbnailScroll.trailingAnchor, constant: -14),
            thumbnailStack.heightAnchor.constraint(equalTo: thumbnailScroll.heightAnchor)
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
        rebuildThumbnailsAsync()
        rebuildPreviewEffectAsync()
    }

    func dismissPanel() {
        renderGeneration += 1
        thumbnailGeneration += 1
        isHidden = true
        baseImage = nil
        previewBase = nil
        cachedFullEffect = nil
        activity.stopAnimating()
        applyButton.isEnabled = true
        delegate?.blendToolPanel(self, didUpdatePreview: nil, intensity: 0)
    }

    @objc private func presetTapped(_ sender: FilterPresetCell) {
        guard sender.preset != selectedPreset || cachedFullEffect == nil else { return }
        selectedPreset = sender.preset
        cachedFullEffect = nil
        refreshPresetSelection()
        rebuildPreviewEffectAsync()
    }

    @objc private func intensityChanged() {
        intensity = CGFloat(intensitySlider.value)
        updateIntensityLabel()
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

    private func rebuildThumbnailsAsync() {
        guard let previewBase else { return }
        thumbnailGeneration += 1
        let generation = thumbnailGeneration
        let source = ImageGeometry.downsample(previewBase, maxDimension: 160)
        let presets = BlendPreset.allCases

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var images: [BlendPreset: UIImage] = [:]
            for preset in presets {
                let overlay = preset.makeOverlayImage(size: source.size, scale: source.scale)
                images[preset] = ImageBlender.blend(
                    base: source,
                    overlay: overlay,
                    mode: preset.mode,
                    opacity: 0.7
                )
            }
            DispatchQueue.main.async {
                guard let self, generation == self.thumbnailGeneration else { return }
                for cell in self.cells {
                    cell.setThumbnail(images[cell.preset])
                }
            }
        }
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
        for cell in cells {
            cell.setSelected(cell.preset == selectedPreset)
        }
    }

    private func updateIntensityLabel() {
        intensityLabel.text = "\(Int(intensity * 100))%"
    }
}

/// 滤镜预设缩略图单元。
private final class FilterPresetCell: UIControl {
    let preset: BlendPreset
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let dim = UIView()

    init(preset: BlendPreset, size: CGSize) {
        self.preset = preset
        super.init(frame: .zero)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = EditorTheme.chip
        imageView.layer.borderWidth = 0
        imageView.layer.borderColor = EditorTheme.accent.cgColor

        dim.backgroundColor = EditorTheme.chipSelected.withAlphaComponent(0.75)
        dim.alpha = 0.55
        dim.isUserInteractionEnabled = false

        titleLabel.text = preset.displayName
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        addSubview(imageView)
        imageView.addSubview(dim)
        imageView.addSubview(titleLabel)
        [imageView, dim, titleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height + 4),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: size.height),

            dim.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            dim.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -2),
            titleLabel.centerYAnchor.constraint(equalTo: dim.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setThumbnail(_ image: UIImage?) {
        imageView.image = image
    }

    func setSelected(_ selected: Bool) {
        imageView.layer.borderWidth = selected ? 2 : 0
        dim.alpha = selected ? 1 : 0.55
        if imageView.image == nil {
            dim.alpha = selected ? 1 : 0
        }
    }
}
