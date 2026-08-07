import UIKit

protocol ToolCategoryBarDelegate: AnyObject {
    func toolCategoryBar(_ bar: ToolCategoryBar, didSelect tool: EditorTool)
}

/// 底部主分类栏：图标 + 文案，选中为柠檬绿 + 下划线。
final class ToolCategoryBar: UIView {
    weak var delegate: ToolCategoryBarDelegate?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons: [EditorTool: ToolCategoryButton] = [:]
    private(set) var selectedTool: EditorTool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = EditorTheme.panel
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 4

        addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(tools: [EditorTool]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        for tool in tools {
            let button = ToolCategoryButton(tool: tool)
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons[tool] = button
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: 64)
            ])
        }
    }

    func select(_ tool: EditorTool?) {
        selectedTool = tool
        for (key, button) in buttons {
            button.setSelected(key == tool)
        }
        if let tool, let button = buttons[tool] {
            scrollView.scrollRectToVisible(button.frame.insetBy(dx: -24, dy: 0), animated: true)
        }
    }

    @objc private func tapped(_ sender: ToolCategoryButton) {
        delegate?.toolCategoryBar(self, didSelect: sender.tool)
    }
}

final class ToolCategoryButton: UIControl {
    let tool: EditorTool
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let underline = UIView()

    init(tool: EditorTool) {
        self.tool = tool
        super.init(frame: .zero)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = EditorTheme.primaryText
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        iconView.image = UIImage(systemName: tool.systemImageName, withConfiguration: config)

        titleLabel.text = tool.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.textColor = EditorTheme.primaryText

        underline.backgroundColor = EditorTheme.accent
        underline.layer.cornerRadius = 1
        underline.isHidden = true

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false

        addSubview(stack)
        addSubview(underline)
        stack.translatesAutoresizingMaskIntoConstraints = false
        underline.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            underline.heightAnchor.constraint(equalToConstant: 2),
            underline.widthAnchor.constraint(equalToConstant: 18),
            underline.centerXAnchor.constraint(equalTo: centerXAnchor),
            underline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        let color: UIColor = selected ? EditorTheme.accent : EditorTheme.primaryText
        iconView.tintColor = color
        titleLabel.textColor = color
        underline.isHidden = !selected
    }
}
