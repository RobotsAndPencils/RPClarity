//
//  UIImageViewExtension.swift
//  RPClarity
//
//  Created by David Anderson on 2015-07-23.
//
//  Copyright (c) 2015 Robots and Pencils, Inc. All rights reserved.
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  "RPClarity" is a trademark of Robots and Pencils, Inc. and may not be used to endorse or promote products derived from this software without specific prior written permission.
//
//  Neither the name of the Robots and Pencils, Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit
import Accelerate

public extension UIImageView {
    
    // creates a buffer of the appropriate size for this image
    private func createEffectBuffer(context: CGContext) -> vImage_Buffer {
        let data = CGBitmapContextGetData(context)
        let width = UInt(CGBitmapContextGetWidth(context))
        let height = UInt(CGBitmapContextGetHeight(context))
        let rowBytes = CGBitmapContextGetBytesPerRow(context)
        
        return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
    }
    
    public func blurImageBelowLabels(labels: [UILabel]) {
        self.blurImageBelowLabels(labels, featherEdges: true, featherBlurRadius: 20)
    }
    
    // adapted from Swift translation of Apple UIImage+ImageEffects.m sample code
    public func blurImageBelowLabels(labels: [UILabel], featherEdges: Bool = true, featherBlurRadius: CGFloat = 20) {
        
        let size = self.frame.size
        let screenScale = UIScreen.mainScreen().scale
        let imageRect = CGRect(origin: CGPointZero, size: size)
        
        // Begin by creating the masking image the size of the original image
        // Fill with black and then fill the area where the glyphs of the label exist with white.
        // The white area will be blurred.
        
        UIGraphicsBeginImageContextWithOptions(size, true, screenScale)
        let outputContext = UIGraphicsGetCurrentContext()
        
        // Fill with black
        CGContextSetFillColorWithColor(outputContext, UIColor.blackColor().CGColor);
        CGContextFillRect(outputContext, imageRect);
        
        // Prepare to fill with white
        CGContextSetFillColorWithColor(outputContext, UIColor.whiteColor().CGColor);
        
        for label in labels {
            
            if label.hidden || label.alpha == 0 {
                continue
            }
            
            // Use GlyphLineLayoutViewProtocol (and underlying associated object) of the label to get areas (views) where the glyphs of the label exist
            label.calculateGlyphLineLayoutViews()
            for lineView in label.glyphLineLayoutViews {
                
                // TEMP: This is used for visualizing the frames during development
                // lineView.frame
                
                let integralRect = CGRectIntegral(lineView.frame)
                let convertedRect = label.convertRect(integralRect, toView: self)
                CGContextFillRect(outputContext, convertedRect)
            }
        }
        
        // TEMP: This is used for visualizing the masking image during development
        // let tempMaskImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // Apply a blur to the masking image to feather the edges of the blurred area
        // this logic dis/enables the feathering of the masked image edges
        if featherEdges {
            
            // Note: the effectInBuffer and effectOutBuffer get used for multiple passes of `vImageBoxConvolve_ARGB8888` where the output of the first pass is the input of the second pass.
            var effectInBuffer = createEffectBuffer(outputContext)
            UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
            let effectOutContext = UIGraphicsGetCurrentContext()
            var effectOutBuffer = createEffectBuffer(effectOutContext)
            
            // A description of how to compute the box kernel width from the Gaussian
            // radius (aka standard deviation) appears in the SVG spec:
            // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
            //
            // For larger values of 's' (s >= 2.0), an approximation can be used: Three
            // successive box-blurs build a piece-wise quadratic convolution kernel, which
            // approximates the Gaussian kernel to within roughly 3%.
            //
            // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
            //
            // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
            //
            
            let inputRadius = featherBlurRadius * screenScale
            var radius = UInt32(floor(inputRadius * 3.0 * CGFloat(sqrt(2 * M_PI)) / 4 + 0.5))
            if radius % 2 != 1 {
                radius += 1 // force radius to be odd so that the three box-blur methodology works.
            }
            
            let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
            
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            
            UIGraphicsEndImageContext()
        }
        
        // generating an image from the context to be used for masking the imageView's image (which will be blurred before masking)
        let dynamicMaskImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // get the image from ourself, blur and mask it, composite this sub-image on the original and tint the whole thing
        // light tint: UIColor(white: 1.0, alpha: 0.3)
        // extra light tint: UIColor(white: 0.97, alpha: 0.82)
        // dark tint: UIColor(white: 0.11, alpha: 0.73)
        
        if let image = self.image, blurredImage = image.applyCustomBlurWithRadius(20,
            tintColor: UIColor.clearColor(), // tints the whole image
            saturationDeltaFactor: 1.5,
            maskImage: dynamicMaskImage,
            maskedAreaTintColor: UIColor(white: 0.5, alpha: 0.3)) {
                
                self.image = blurredImage
        }
    }
}
