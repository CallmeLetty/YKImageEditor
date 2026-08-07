import UIKit
import YKImageEditorCore
import YKImageEditorUI

final class DemoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let preview = UIImageView()
    private let resultLabel = UILabel()
    private let pickButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "YKImageEditor Example"
        view.backgroundColor = .systemBackground

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .secondarySystemBackground
        preview.layer.cornerRadius = 12
        preview.clipsToBounds = true

        resultLabel.textAlignment = .center
        resultLabel.textColor = .secondaryLabel
        resultLabel.numberOfLines = 0
        resultLabel.text = "请先选择一张图片"

        configureButton(pickButton, title: "选择图片", action: #selector(pickImage))
        configureButton(editButton, title: "开始编辑", action: #selector(editTapped))
        editButton.isEnabled = false
        editButton.alpha = 0.4

        let stack = UIStackView(arrangedSubviews: [
            preview, resultLabel, pickButton, editButton
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
            preview.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])
    }

    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func pickImage() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func editTapped() {
        guard let image = preview.image else {
            resultLabel.text = "请先选择一张图片"
            return
        }
        let stickers = ClosureStickerProvider {
            [
                UIImage(systemName: "star.fill"),
                UIImage(systemName: "heart.fill"),
                UIImage(systemName: "flame.fill")
            ].compactMap { $0?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal) }
        }
        yk_presentImageEditor(
            image: image,
            config: .all,
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

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            resultLabel.text = "选图失败，请重试"
            return
        }
        preview.image = image
        editButton.isEnabled = true
        editButton.alpha = 1
        resultLabel.text = "已选图，可开始编辑"
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
