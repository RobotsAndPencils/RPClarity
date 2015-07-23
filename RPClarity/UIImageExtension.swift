//
//  UIImageExtension.swift
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

public extension UIImage {
    
    // creates a buffer of the appropriate size for this image
    private func createEffectBuffer(context: CGContext) -> vImage_Buffer {
        let data = CGBitmapContextGetData(context)
        let width = UInt(CGBitmapContextGetWidth(context))
        let height = UInt(CGBitmapContextGetHeight(context))
        let rowBytes = CGBitmapContextGetBytesPerRow(context)
        
        return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
    }
    
    // adapted from Swift translation of Apple UIImage+ImageEffects.m sample code
    public func applyCustomBlurWithRadius(blurRadius: CGFloat, tintColor: UIColor?, saturationDeltaFactor: CGFloat, maskImage: UIImage? = nil, maskedAreaTintColor blurTintColor: UIColor? = nil) -> UIImage? {
        
        // Check pre-conditions.
        if (size.width < 1 || size.height < 1) {
            println("*** error: invalid size: \(size.width) x \(size.height). Both dimensions must be >= 1: \(self)")
            return nil
        }
        if self.CGImage == nil {
            println("*** error: image must be backed by a CGImage: \(self)")
            return nil
        }
        if maskImage != nil && maskImage!.CGImage == nil {
            println("*** error: maskImage must be backed by a CGImage: \(maskImage)")
            return nil
        }
        
        let __FLT_EPSILON__ = CGFloat(FLT_EPSILON)
        let screenScale = UIScreen.mainScreen().scale
        let imageRect = CGRect(origin: CGPointZero, size: size)
        var effectImage = self
        
        // check if we are applying a blur or changing saturation
        let hasBlur = blurRadius > __FLT_EPSILON__
        let hasSaturationChange = fabs(saturationDeltaFactor - 1.0) > __FLT_EPSILON__
        
        if hasBlur || hasSaturationChange {
            
            // put our source image into the context
            UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
            let effectInContext = UIGraphicsGetCurrentContext()
            
            CGContextScaleCTM(effectInContext, 1.0, -1.0)
            CGContextTranslateCTM(effectInContext, 0, -size.height)
            CGContextDrawImage(effectInContext, imageRect, self.CGImage)
            
            // Note: the effectInBuffer and effectOutBuffer get used for multiple passes of `vImageBoxConvolve_ARGB8888` where the output of the first pass is the input of the second pass.
            var effectInBuffer = createEffectBuffer(effectInContext)
            UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
            let effectOutContext = UIGraphicsGetCurrentContext()
            var effectOutBuffer = createEffectBuffer(effectOutContext)
            
            if hasBlur {
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
                
                let inputRadius = blurRadius * screenScale
                var radius = UInt32(floor(inputRadius * 3.0 * CGFloat(sqrt(2 * M_PI)) / 4 + 0.5))
                if radius % 2 != 1 {
                    radius += 1 // force radius to be odd so that the three box-blur methodology works.
                }
                
                let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
                
                vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            }
            
            // the combination of `hasSaturationChange` and `hasBlur` along with buffer reuse can vary where our final output is
            // `effectImageBuffersAreSwapped` is used to track whether the `effectInBuffer` is where our final output is found or if it is in `effectOutBuffer`
            var effectImageBuffersAreSwapped = false
            
            // apply saturation change
            if hasSaturationChange {
                let s: CGFloat = saturationDeltaFactor
                let floatingPointSaturationMatrix: [CGFloat] = [
                    0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                    0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                    0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                    0,                    0,                    0,  1
                ]
                
                let divisor: CGFloat = 256
                let matrixSize = floatingPointSaturationMatrix.count
                var saturationMatrix = [Int16](count: matrixSize, repeatedValue: 0)
                
                for var i: Int = 0; i < matrixSize; ++i {
                    saturationMatrix[i] = Int16(round(floatingPointSaturationMatrix[i] * divisor))
                }
                
                // if we have already blurred, our `effectOutBuffer` is the input buffer for the saturation change
                if hasBlur {
                    vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                    effectImageBuffersAreSwapped = true
                } else {
                    // haven't already blurred, so our `effectInBuffer` is the input buffer for the saturation change
                    vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                }
            }
            
            if !effectImageBuffersAreSwapped {
                
                // Add in color tint just to the effect image
                if let color = blurTintColor {
                    print("effectOutContext")
                    CGContextSaveGState(effectOutContext)
                    CGContextSetFillColorWithColor(effectOutContext, color.CGColor)
                    CGContextFillRect(effectOutContext, imageRect)
                    CGContextRestoreGState(effectOutContext)
                }
                
                effectImage = UIGraphicsGetImageFromCurrentImageContext()
            }
            
            UIGraphicsEndImageContext()
            
            if effectImageBuffersAreSwapped {
                
                
                let tempEffectImage = UIGraphicsGetImageFromCurrentImageContext()
                
                // Add in color tint just to the effect image (which will be masked)
                if let color = blurTintColor {
                    print("effectInContext")
                    CGContextSaveGState(effectInContext)
                    CGContextSetFillColorWithColor(effectInContext, color.CGColor)
                    CGContextFillRect(effectInContext, imageRect)
                    CGContextRestoreGState(effectInContext)
                }
                
                effectImage = UIGraphicsGetImageFromCurrentImageContext()
            }
            
            UIGraphicsEndImageContext()
        }
        
        // Set up output context.
        UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
        let outputContext = UIGraphicsGetCurrentContext()
        CGContextScaleCTM(outputContext, 1.0, -1.0)
        CGContextTranslateCTM(outputContext, 0, -size.height)
        
        // Draw base image into the outputContext
        CGContextDrawImage(outputContext, imageRect, self.CGImage)
        
        // Draw effect image after applying mask
        if hasBlur {
            CGContextSaveGState(outputContext)
            if let image = maskImage {
                // TEMP: This is used for visualizing the masking image during development
                // image
                
                
                CGContextClipToMask(outputContext, imageRect, image.CGImage)
            }
            CGContextDrawImage(outputContext, imageRect, effectImage.CGImage) // draws the effect image, within the box defined by imageRect into the outputContext
            
            // TEMP: This is used for visualizing the image during development
            // let tempImage = UIGraphicsGetImageFromCurrentImageContext()
            
            CGContextRestoreGState(outputContext)
        }
        
        // Add in color tint for the entire image
        if let color = tintColor {
            CGContextSaveGState(outputContext)
            CGContextSetFillColorWithColor(outputContext, color.CGColor)
            CGContextFillRect(outputContext, imageRect)
            CGContextRestoreGState(outputContext)
        }
        
        // Output image is ready.
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return outputImage
    }
}
