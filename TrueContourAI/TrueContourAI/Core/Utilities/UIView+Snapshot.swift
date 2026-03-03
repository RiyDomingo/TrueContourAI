import UIKit

extension UIView {
    func snapshotImage(preferDrawHierarchy: Bool, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)

        if preferDrawHierarchy {
            return renderer.image { _ in
                self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
            }
        } else {
            return renderer.image { ctx in
                self.layer.render(in: ctx.cgContext)
            }
        }
    }
}
