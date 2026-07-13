import simd

/// モデルを原点中心・最大辺 targetExtent に正規化する scale と translation を返す。
/// extents が 0 や非有限のとき (空シーン等) は scale 1 で中心移動のみ。
func framingTransform(
    center: SIMD3<Float>,
    extents: SIMD3<Float>,
    targetExtent: Float = 1.0
) -> (scale: Float, translation: SIMD3<Float>) {
    let maxExtent = max(extents.x, max(extents.y, extents.z))
    guard maxExtent > 0, maxExtent.isFinite else {
        return (1.0, -center)
    }
    let scale = targetExtent / maxExtent
    return (scale, -center * scale)
}
