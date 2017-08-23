//
//  BrokenGlassTransitionAnimator.swift
//  BrokenGlassEffect
//
//  Created by wang yang on 2017/8/22.
//  Copyright © 2017年 ocean. All rights reserved.
//

import Foundation
import UIKit

class BrokenGlassTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 1.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
            let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else {
                return
        }
        let snapshotImage = createImage(layer: fromVC.view.layer)
        let brokenGlassView = BrokenGlassEffectView.init(frame: fromVC.view.bounds)
        fromVC.view.removeFromSuperview()
        containerView.addSubview(toVC.view)
        containerView.addSubview(brokenGlassView)
        brokenGlassView.setImageForBroke(image: snapshotImage)
        brokenGlassView.beginBroke()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak brokenGlassView] in
            brokenGlassView?.removeFromSuperview()
            brokenGlassView?.destroy()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    func createImage(layer: CALayer) -> UIImage {
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let width:Int = Int(layer.bounds.size.width)
        let height:Int = Int(layer.bounds.size.height)
        let imageData = UnsafeMutableRawPointer.allocate(bytes: Int(width * height * bytesPerPixel), alignedTo: 8)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let imageContext = CGContext.init(data: imageData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: width * bytesPerPixel, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue )
        layer.render(in: imageContext!)
        
        let cgImage = imageContext?.makeImage()
        let image = UIImage.init(cgImage: cgImage!)
        return image
    }
}
