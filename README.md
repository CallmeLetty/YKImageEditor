# YKImageEditor

轻量级 iOS 图片编辑 Swift Package（微信风格会话编辑器）。

## Modules

- `YKImageEditorCore`：几何变换、马赛克、混合模式叠色、液化塑形、导出、会话状态
- `YKImageEditorUI`：UIKit 编辑器界面（含混合预设、液化推移）

## Requirements

- iOS 15+
- Swift 5.9+
- 零第三方依赖

## Usage

```swift
import YKImageEditorCore
import YKImageEditorUI

// 全部功能
presenting.yk_presentImageEditor(image: image) { result in
    switch result {
    case .finished(let edited): break
    case .cancelled: break
    }
}

// 只开裁剪和文字
let config = EditorConfig.including([.crop, .text])

// 去掉马赛克
let config2 = EditorConfig.excluding([.mosaic])

// 只要裁剪 + 混合调色
let config3 = EditorConfig.including([.crop, .blend])

// 程序化混合（无需 UI）
let toned = ImageBlender.blend(base: image, preset: .warmColorBurn, intensity: 0.7)
let multiplied = ImageBlender.blend(base: image, color: .orange, mode: .multiply, opacity: 0.5)

// 贴纸需注入
let stickers = ClosureStickerProvider { [UIImage(systemName: "star.fill")!] }
presenting.yk_presentImageEditor(
    image: image,
    config: .all,
    stickerProvider: stickers
) { _ in }
```

也可直接使用 `ImageEditorViewController` 自行 `present` / `push`。

## Example

```bash
cd Example
xcodegen generate
open YKImageEditorExample.xcodeproj
```

## Test

```bash
xcodebuild -scheme YKImageEditor-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
