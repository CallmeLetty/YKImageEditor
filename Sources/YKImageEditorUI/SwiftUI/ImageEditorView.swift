import SwiftUI
import UIKit
import YKImageEditorCore

/// 可直接嵌入 SwiftUI 页面层级的图片编辑器。
public struct ImageEditorView: View {
    @StateObject private var model: ImageEditorViewModel

    public init(
        image: UIImage,
        config: EditorConfig = .all,
        stickerProvider: StickerProviding? = nil,
        completion: @escaping (ImageEditorResult) -> Void
    ) {
        let model = ImageEditorViewModel(
            image: image,
            config: config,
            stickerProvider: stickerProvider
        )
        model.onFinish = completion
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        ImageEditorContentView(model: model)
    }
}

struct ImageEditorContentView: View {
    @ObservedObject var model: ImageEditorViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.selectedTool == .crop {
                CropEditorView(
                    image: model.currentImage,
                    onCancel: model.cancelCrop,
                    onComplete: model.completeCrop
                )
                .transition(.opacity)
            } else {
                editorContent
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .alert("添加文字", isPresented: $model.isTextEditorPresented) {
            TextField("输入文字", text: $model.textInput)
            Button("取消", role: .cancel) {
                model.textInput = ""
            }
            Button("添加") {
                model.addText()
            }
        }
        .alert("放弃编辑？", isPresented: $model.isDiscardConfirmationPresented) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃", role: .destructive) {
                model.discard()
            }
        } message: {
            Text("退出后将丢失当前修改")
        }
        .sheet(isPresented: $model.isStickerPickerPresented) {
            StickerPickerView(images: model.stickers, onSelect: model.addSticker)
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            topBar
            EditorCanvasRepresentable(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            secondaryPanel
            toolBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            toolbarIcon("xmark", action: model.requestClose)
                .accessibilityLabel("关闭")
            toolbarIcon("arrow.uturn.backward", action: model.undo)
                .disabled(!model.canUndo)
                .opacity(model.canUndo ? 1 : 0.35)
                .accessibilityLabel("撤销")
            toolbarIcon("arrow.uturn.forward", action: model.redo)
                .disabled(!model.canRedo)
                .opacity(model.canRedo ? 1 : 0.35)
                .accessibilityLabel("重做")
            Spacer(minLength: 12)
            Button(action: model.export) {
                Text("导出")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(themeColor(EditorTheme.accent))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: EditorTheme.topBarHeight)
        .background(Color.black)
    }

    @ViewBuilder
    private var secondaryPanel: some View {
        switch model.selectedTool {
        case .doodle, .text:
            ColorToolPanel(model: model)
                .frame(height: 58)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .blend:
            BlendToolView(model: model)
                .frame(height: 160)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .tone:
            ToneToolView(model: model)
                .frame(height: 148)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .liquify:
            LiquifyToolView(model: model)
                .frame(height: 138)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        default:
            EmptyView()
        }
    }

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(model.availableTools) { tool in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            model.selectTool(tool)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.systemImageName)
                                .font(.system(size: 18, weight: .regular))
                                .frame(width: 22, height: 22)
                            Text(tool.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Capsule()
                                .fill(model.selectedTool == tool ? themeColor(EditorTheme.accent) : .clear)
                                .frame(width: 18, height: 2)
                        }
                        .foregroundColor(model.selectedTool == tool ? themeColor(EditorTheme.accent) : .white)
                        .frame(width: 64, height: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 58)
        .background(Color.black)
    }

    private func toolbarIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EditorCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: ImageEditorViewModel

    func makeUIView(context: Context) -> EditorCanvasHostView {
        model.makeCanvasHost()
    }

    func updateUIView(_ uiView: EditorCanvasHostView, context: Context) {
        if uiView.canvas.displayedImage !== model.currentImage {
            uiView.canvas.setImage(model.currentImage)
        }
    }
}

private struct ColorToolPanel: View {
    @ObservedObject var model: ImageEditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(model.doodleColors.indices, id: \.self) { index in
                Button {
                    model.selectDoodleColor(at: index)
                } label: {
                    Circle()
                        .fill(themeColor(model.doodleColors[index]))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Circle()
                                .stroke(
                                    index == model.selectedColorIndex ? themeColor(EditorTheme.accent) : Color.white.opacity(0.75),
                                    lineWidth: index == model.selectedColorIndex ? 3 : 1.5
                                )
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Button(action: model.applyOverlayLayers) {
                Label("应用", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(themeColor(EditorTheme.accent))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(Color.black)
    }
}

private struct BlendToolView: View {
    @ObservedObject var model: ImageEditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                PanelIconButton(systemName: "xmark", emphasized: false, action: model.cancelBlend)
                Text("\(Int(model.blendIntensity * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeColor(EditorTheme.secondaryText))
                    .frame(width: 44)
                Slider(
                    value: Binding(
                        get: { model.blendIntensity },
                        set: model.setBlendIntensity
                    ),
                    in: 0...1
                )
                .tint(themeColor(EditorTheme.accent))
                if model.isProcessing {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 24)
                }
                PanelIconButton(systemName: "checkmark", emphasized: true, action: model.applyBlend)
                    .disabled(model.isProcessing)
            }
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BlendPreset.allCases, id: \.self) { preset in
                        Button {
                            model.selectPreset(preset)
                        } label: {
                            ZStack(alignment: .bottom) {
                                Group {
                                    if let image = model.filterThumbnails[preset] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        themeColor(EditorTheme.panelElevated)
                                    }
                                }
                                .frame(width: 72, height: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Text(preset.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 68, height: 22)
                                    .background(Color.black.opacity(0.55))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        model.selectedPreset == preset ? themeColor(EditorTheme.accent) : .clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.top, 8)
        .background(Color.black)
    }
}

private struct ToneToolView: View {
    @ObservedObject var model: ImageEditorViewModel

    private var selectedParameter: ToneParameter { model.selectedToneParameter }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                PanelIconButton(systemName: "xmark", emphasized: false, action: model.cancelTone)
                Text("\(selectedParameter.title) \(formattedValue)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeColor(EditorTheme.secondaryText))
                    .frame(minWidth: 88, alignment: .leading)
                Spacer(minLength: 8)
                Button(action: model.resetTone) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(themeColor(EditorTheme.chip))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重置 Tone 滤镜")
                if model.isProcessing {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 24)
                }
                PanelIconButton(systemName: "checkmark", emphasized: true, action: model.applyTone)
                    .disabled(model.isProcessing)
            }
            .padding(.horizontal, 14)

            Slider(
                value: Binding(
                    get: { model.toneValue(for: selectedParameter) },
                    set: { model.setToneValue($0, for: selectedParameter) }
                ),
                in: selectedParameter.range,
                step: selectedParameter.step
            )
            .tint(themeColor(EditorTheme.accent))
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(ToneParameter.allCases) { parameter in
                        Button {
                            model.selectedToneParameter = parameter
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: parameter.systemImageName)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 20, height: 20)
                                Text(parameter.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                Capsule()
                                    .fill(
                                        selectedParameter == parameter
                                            ? themeColor(EditorTheme.accent)
                                            : .clear
                                    )
                                    .frame(width: 16, height: 2)
                            }
                            .foregroundColor(
                                selectedParameter == parameter
                                    ? themeColor(EditorTheme.accent)
                                    : .white
                            )
                            .frame(width: 54, height: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.top, 8)
        .background(Color.black)
    }

    private var formattedValue: String {
        let value = model.toneValue(for: selectedParameter)
        if selectedParameter == .exposure {
            return String(format: "%+.2f EV", value)
        }
        return String(format: "%+.0f", value * 100)
    }
}

private struct LiquifyToolView: View {
    @ObservedObject var model: ImageEditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                PanelIconButton(systemName: "xmark", emphasized: false, action: model.cancelLiquify)
                Text("手指滑动推移画面")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeColor(EditorTheme.secondaryText))
                Spacer()
                Button("重置", action: model.resetLiquify)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(themeColor(EditorTheme.chip))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .buttonStyle(.plain)
                if model.isProcessing {
                    ProgressView().tint(.white)
                }
                PanelIconButton(systemName: "checkmark", emphasized: true, action: model.applyLiquify)
                    .disabled(model.isProcessing)
            }
            sliderRow(
                title: "半径 \(Int(model.liquifyRadius * 100))%",
                value: $model.liquifyRadius,
                range: 0.04...0.28
            )
            sliderRow(
                title: "力度 \(Int(model.liquifyStrength * 100))%",
                value: $model.liquifyStrength,
                range: 0...1
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(Color.black)
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeColor(EditorTheme.secondaryText))
                .frame(width: 76, alignment: .leading)
            Slider(value: value, in: range)
                .tint(themeColor(EditorTheme.accent))
        }
    }
}

private struct PanelIconButton: View {
    let systemName: String
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(emphasized ? .black : .white)
                .frame(width: 32, height: 32)
                .background(emphasized ? themeColor(EditorTheme.accent) : themeColor(EditorTheme.chip))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StickerPickerView: View {
    let images: [UIImage]
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        Button {
                            onSelect(image)
                            dismiss()
                        } label: {
                            Image(uiImage: image)
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(themeColor(EditorTheme.panelElevated))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("选择贴纸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private func themeColor(_ color: UIColor) -> Color {
    Color(uiColor: color)
}
