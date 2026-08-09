import CoreGraphics
import Foundation

/// 基于网格的液化形变场。
///
/// 每个网格点存储「反向位移」：输出坐标 `p` 从 `p + offset` 采样原图。
/// 坐标均为归一化 `0...1`（原点左上）。
public final class LiquifyDeformer {
    public let columns: Int
    public let rows: Int

    /// 水平反向位移（归一化）。
    private var offsetX: [Float]
    /// 垂直反向位移（归一化）。
    private var offsetY: [Float]

    /// - Parameters:
    ///   - columns: 网格列数（控制点比单元格多 1 时用 columns+1 个点）。
    ///   - rows: 网格行数。
    public init(columns: Int = 48, rows: Int = 48) {
        self.columns = max(8, columns)
        self.rows = max(8, rows)
        let count = (self.columns + 1) * (self.rows + 1)
        offsetX = [Float](repeating: 0, count: count)
        offsetY = [Float](repeating: 0, count: count)
    }

    /// 是否已有形变。
    public var hasDeformation: Bool {
        for v in offsetX where abs(v) > 1e-6 { return true }
        for v in offsetY where abs(v) > 1e-6 { return true }
        return false
    }

    /// 清空形变。
    public func reset() {
        for i in 0..<offsetX.count {
            offsetX[i] = 0
            offsetY[i] = 0
        }
    }

    /// 用另一个相同网格尺寸的形变场恢复当前状态。
    public func restore(from snapshot: LiquifyDeformer) {
        guard snapshot.columns == columns, snapshot.rows == rows else { return }
        offsetX = snapshot.offsetX
        offsetY = snapshot.offsetY
    }

    /// 复制当前形变场（供后台渲染，避免与主线程笔刷写入竞态）。
    public func snapshot() -> LiquifyDeformer {
        let copy = LiquifyDeformer(columns: columns, rows: rows)
        copy.offsetX = offsetX
        copy.offsetY = offsetY
        return copy
    }

    /// 按行返回 GPU 预览使用的反向位移网格。
    ///
    /// 数组布局与 ``sourcePoint(forNormalized:)`` 一致：每个元素对应一个
    /// `(x, y)` 控制点，先从左到右，再从上到下。
    public func displacementVectors() -> [SIMD2<Float>] {
        zip(offsetX, offsetY).map { SIMD2<Float>($0, $1) }
    }

    /// 应用一笔液化。
    ///
    /// - Parameters:
    ///   - mode: 笔刷模式。
    ///   - point: 笔刷中心（归一化，原点左上）。
    ///   - delta: 推移向量（归一化）。
    ///   - radius: 笔刷半径，相对于画面短边（与手指圈一致）。
    ///   - strength: 强度 `0...1`。
    ///   - aspectRatio: 画面宽/高，用于把圆形笔刷映射到归一化坐标。
    public func apply(
        mode: LiquifyMode = .push,
        at point: CGPoint,
        delta: CGPoint,
        radius: CGFloat,
        strength: CGFloat,
        aspectRatio: CGFloat = 1
    ) {
        guard mode == .push else { return }
        let r = max(Float(radius), 0.001)
        let s = Float(min(max(strength, 0), 1))
        guard s > 0 else { return }

        let aspect = max(Float(aspectRatio), 0.01)
        // 归一化位移 → 以短边为单位的屏幕距离
        let widthOverShort = max(aspect, 1)
        let heightOverShort = max(1 / aspect, 1)

        // 影响范围（归一化 AABB）
        let padX = CGFloat(r) / CGFloat(widthOverShort)
        let padY = CGFloat(r) / CGFloat(heightOverShort)
        let minX = max(0, Int(floor(Double((point.x - padX) * CGFloat(columns)))))
        let maxX = min(columns, Int(ceil(Double((point.x + padX) * CGFloat(columns)))))
        let minY = max(0, Int(floor(Double((point.y - padY) * CGFloat(rows)))))
        let maxY = min(rows, Int(ceil(Double((point.y + padY) * CGFloat(rows)))))

        let dxPush = Float(delta.x) * s
        let dyPush = Float(delta.y) * s
        guard abs(dxPush) > 1e-8 || abs(dyPush) > 1e-8 else { return }

        for gy in minY...maxY {
            for gx in minX...maxX {
                let nx = CGFloat(gx) / CGFloat(columns)
                let ny = CGFloat(gy) / CGFloat(rows)
                let ddx = Float(nx - point.x) * widthOverShort
                let ddy = Float(ny - point.y) * heightOverShort
                let dist = sqrt(ddx * ddx + ddy * ddy)
                guard dist < r else { continue }

                // 平滑衰减：中心强、边缘弱
                let t = dist / r
                let falloff = 0.5 * (1 + cos(Float.pi * t)) // 1 → 0
                let idx = gy * (columns + 1) + gx

                // 内容沿 delta 移动 ⇒ 反向位移取反
                offsetX[idx] -= dxPush * falloff
                offsetY[idx] -= dyPush * falloff
            }
        }
    }

    /// 双线性采样位移场，返回归一化源坐标。
    public func sourcePoint(forNormalized p: CGPoint) -> CGPoint {
        let fx = min(max(p.x, 0), 1) * CGFloat(columns)
        let fy = min(max(p.y, 0), 1) * CGFloat(rows)
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let x1 = min(x0 + 1, columns)
        let y1 = min(y0 + 1, rows)
        let tx = Float(fx - CGFloat(x0))
        let ty = Float(fy - CGFloat(y0))

        let i00 = y0 * (columns + 1) + x0
        let i10 = y0 * (columns + 1) + x1
        let i01 = y1 * (columns + 1) + x0
        let i11 = y1 * (columns + 1) + x1

        let ox =
            offsetX[i00] * (1 - tx) * (1 - ty) +
            offsetX[i10] * tx * (1 - ty) +
            offsetX[i01] * (1 - tx) * ty +
            offsetX[i11] * tx * ty
        let oy =
            offsetY[i00] * (1 - tx) * (1 - ty) +
            offsetY[i10] * tx * (1 - ty) +
            offsetY[i01] * (1 - tx) * ty +
            offsetY[i11] * tx * ty

        return CGPoint(
            x: min(max(p.x + CGFloat(ox), 0), 1),
            y: min(max(p.y + CGFloat(oy), 0), 1)
        )
    }
}
