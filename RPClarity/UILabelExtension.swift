//
//  UILabelExtension.swift
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
import QuartzCore
import CoreText
import ObjectiveC

public protocol GlyphLineLayoutViewProtocol {
    var glyphLineLayoutViews: [UIView] { get }
    
    func calculateGlyphLineLayoutViews()
}

extension UILabel: GlyphLineLayoutViewProtocol {
    
    private struct AssociatedKey {
        static var glyphLineLayoutViewsExtension = "glyphLineLayoutViewsExtension"
    }
    
    public var glyphLineLayoutViews: [UIView] {
        if let lineLayoutViews = objc_getAssociatedObject(self, &AssociatedKey.glyphLineLayoutViewsExtension) as? [UIView] {
            return lineLayoutViews
        } else {
            return [UIView] ()
        }
    }
    
    public func calculateGlyphLineLayoutViews() {
        
        let labelRect = self.frame
        let integralLabelRect = labelRect // CGRectIntegral(labelRect) // in case we need/want to make this rect integral
        
        // first create textStorage, layoutManager and textContainer that will mimic the label
        let textStorage = NSTextStorage(attributedString: self.attributedText)
        let layoutManager = NSLayoutManager() // not sure how expensive a call this is, might want to cache it
        let textContainer = NSTextContainer(size: integralLabelRect.size) // not sure how expensive a call this is, might want to cache it
        textContainer.widthTracksTextView = false // may not be necessary
        textContainer.maximumNumberOfLines = self.numberOfLines
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.lineFragmentPadding = 0 // needed so the left and right inset matches that of UILabel
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // now use the textContainer (which is associated with the layout manager and text storage)
        // to create a UITextView which will be used to calculate our glyph layout
        let textView = UITextView(frame: integralLabelRect, textContainer: textContainer)
        
        // Measure the text with the new state
        var textBounds = CGRectZero
        let glyphRange = layoutManager.glyphRangeForTextContainer(textContainer)
        textBounds = layoutManager.boundingRectForGlyphRange(glyphRange, inTextContainer: textContainer)
        
        // Get the layout of the glyphs
        let attributedString = textStorage // NSTextStorage is a subclass of NSMutableAttributedString
        // Create a mutable path for the paths of all the glyphs.
        let lettersPath = CGPathCreateMutable()
        // Create a core text line from the attributed string and get glyph runs from that line
        let line = CTLineCreateWithAttributedString(attributedString)
        let textRange = layoutManager.glyphRangeForTextContainer(textContainer)
        let glyphsToShow = layoutManager.glyphRangeForCharacterRange(textRange, actualCharacterRange: nil)
        
        var lineRects = [CGRect]()
        
        // enumerate our line fragements and determine the rectangle that encompasses the glyphs in a line (excluding trailing whitespace)
        layoutManager.enumerateLineFragmentsForGlyphRange(glyphsToShow, usingBlock: { (rect: CGRect, usedRect: CGRect, textContainer: NSTextContainer!, glyphRange: NSRange, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            var finalLineRect = CGRectZero
            var previousGlyphRect = CGRectZero
            var previousSubstring = ""
            // enumerate the glyphs in this line and build the final rect for the line
            (attributedString.string as NSString).enumerateSubstringsInRange(glyphRange, options: NSStringEnumerationOptions.ByComposedCharacterSequences, usingBlock: { (substring: String!, substringRange: NSRange, enclosingRange: NSRange, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                
                // TEMP: This is used for visualizing the characters during development
                // print(substring)
                
                // the range that defines a single glyph
                let singleGlyphRange = layoutManager.glyphRangeForCharacterRange(substringRange, actualCharacterRange: nil)
                // the rect for this glyph
                let glyphRect = layoutManager.boundingRectForGlyphRange(singleGlyphRange, inTextContainer: textContainer)
                // check if this is the first glyph of the the line or not
                if CGRectEqualToRect(finalLineRect, CGRectZero) {
                    finalLineRect = glyphRect
                } else {
                    finalLineRect.size.width += glyphRect.size.width
                    previousSubstring = substring
                    previousGlyphRect = glyphRect
                }
            })
            
            // remove trailing whitespace from this line, subtract the width of our last glyph
            let whitespaceCharacters = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            let trailingCharacters = NSCharacterSet(charactersInString: previousSubstring)
            if whitespaceCharacters.isSupersetOfSet(trailingCharacters) {
                finalLineRect.size.width -= previousGlyphRect.size.width
            }
            
            // have the rectangle for this line, store it for later use
            lineRects.append(finalLineRect)
            
            // TEMP: This is used for visualizing the frames during development
            // finalLineRect
        })
        
        var lineLayoutViews = [UIView]()
        for rect in lineRects {
            
            let convertedRect = rect //titleLabel.convertRect(rect, toView: self.view)
            
            let labelLineView = UIView(frame: convertedRect)
            // labelLineView.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.5)
            lineLayoutViews.append(labelLineView)
        }
        
        // store the views where our glyph lines exist
        objc_setAssociatedObject(self, &AssociatedKey.glyphLineLayoutViewsExtension, lineLayoutViews, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
    }
}
