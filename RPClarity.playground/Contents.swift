//
//  RPClarity.playground
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
import XCPlayground

func addImageView(imageName: String, toParentView parentView: UIView) -> UIImageView {
    
    var image = UIImage(named: imageName)
    var imageView = UIImageView(image: image)
    imageView.setTranslatesAutoresizingMaskIntoConstraints(false)
    imageView.contentMode = .ScaleAspectFit
    parentView.addSubview(imageView)
    
    let horizontalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("H:|[imageView]|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["imageView": imageView])
    parentView.addConstraints(horizontalConstraints)
    let verticalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("V:|[imageView]|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["imageView": imageView])
    parentView.addConstraints(verticalConstraints)
    return imageView
}

func whiteLabel(text: String, #fontSize: CGFloat) -> UILabel {
    let label = UILabel(frame: CGRectZero)
    label.numberOfLines = 0
    label.lineBreakMode = .ByWordWrapping
    label.setTranslatesAutoresizingMaskIntoConstraints(false)
    label.text = text
    label.font = UIFont(name: label.font.fontName, size: fontSize)
    label.textColor = UIColor.whiteColor()
    // label.backgroundColor = UIColor.blueColor().colorWithAlphaComponent(0.5)
    return label
}

func addFirstLabel(text: String, #fontSize: CGFloat, toParentView parentView: UIView) -> UILabel {
    
    let label = whiteLabel(text, fontSize: fontSize)
    label.textAlignment = .Center
    parentView.addSubview(label)
    
    let horizontalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("H:|-100-[label]->=600-|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["label": label])
    parentView.addConstraints(horizontalConstraints)

    let verticalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("V:|-32-[label]", options: NSLayoutFormatOptions(0), metrics: nil, views: ["label": label])
    parentView.addConstraints(verticalConstraints)
    return label
}

func addSecondLabel(text: String, #fontSize: CGFloat, toParentView parentView: UIView) -> UILabel {
    
    let label = whiteLabel(text, fontSize: fontSize)
    label.textAlignment = .Right
    parentView.addSubview(label)
    
    let horizontalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("H:|->=800-[label]-10-|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["label": label])
    parentView.addConstraints(horizontalConstraints)
    
    let verticalConstraints:[AnyObject] = NSLayoutConstraint.constraintsWithVisualFormat("V:[label]-150-|", options: NSLayoutFormatOptions(0), metrics: nil, views: ["label": label])
    parentView.addConstraints(verticalConstraints)
    return label
}


let rect = CGRect(x: 0, y: 0, width: 1280, height: 852)
var view = UIView(frame: rect)
view.backgroundColor = UIColor.blackColor()
let imageView = addImageView("18958602415_29edf164fe_k.jpg", toParentView: view)
let labelOne = addFirstLabel("Hello, World! I am late for my bike ride :(", fontSize: 80, toParentView: view)
let labelTwo = addSecondLabel("But this is where I ride :)", fontSize: 50, toParentView: view)

view.layoutIfNeeded()

imageView.blurImageBelowLabels([labelOne, labelTwo], featherEdges: false)

view


