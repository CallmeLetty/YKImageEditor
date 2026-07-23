import UIKit
import YKImageEditorCore
import YKImageEditorUI

final class DemoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let preview = UIImageView()
    private let resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "YKImageEditor Example"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "选图",
            style: .plain,
            target: self,
            action: #selector(pickImage)
        )

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .secondarySystemBackground
        preview.layer.cornerRadius = 12
        preview.clipsToBounds = true

        resultLabel.textAlignment = .center
        resultLabel.textColor = .secondaryLabel
        resultLabel.numberOfLines = 0
        resultLabel.text = "选择一张图片开始编辑"

        let editAll = makeButton("编辑（全部功能）", action: #selector(editAll))
        let editCropText = makeButton("编辑（仅裁剪+文字）", action: #selector(editCropText))
        let editExclude = makeButton("编辑（排除马赛克）", action: #selector(editExcludeMosaic))

        let stack = UIStackView(arrangedSubviews: [
            preview, resultLabel, editAll, editCropText, editExclude
        ])
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        preview.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            preview.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35)
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func pickImage() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func editAll() {
        openEditor(config: .all)
    }

    @objc private func editCropText() {
        openEditor(config: .including([.crop, .text]))
    }

    @objc private func editExcludeMosaic() {
        openEditor(config: .excluding([.mosaic]))
    }

    private func openEditor(config: EditorConfig) {
        let sample = preview.image ?? makeSampleImage()
        let stickers = ClosureStickerProvider {
            [
                UIImage(systemName: "star.fill"),
                UIImage(systemName: "heart.fill"),
                UIImage(systemName: "flame.fill")
            ].compactMap { $0?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal) }
        }
        yk_presentImageEditor(
            image: sample,
            config: config,
            stickerProvider: stickers
        ) { [weak self] result in
            switch result {
            case .finished(let edited):
                self?.preview.image = edited
                self?.resultLabel.text = "编辑完成 \(Int(edited.size.width))×\(Int(edited.size.height))"
            case .cancelled:
                self?.resultLabel.text = "已取消"
            }
        }
    }

    private func makeSampleImage() -> UIImage {
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let text = "YKImageEditor\nSample"
            text.draw(in: CGRect(x: 0, y: size.height / 2 - 60, width: size.width, height: 120), withAttributes: attrs)
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        preview.image = info[.originalImage] as? UIImage
        resultLabel.text = "已选图，点击下方按钮编辑"
    }
}
