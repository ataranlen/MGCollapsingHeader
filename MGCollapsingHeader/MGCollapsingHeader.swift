//
//  MGCollapsingHeader.swift
//  Pods
//
//  Created by Nathan Stoltenberg on 10/13/16.
//


//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Matthew Gardner
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Foundation


public protocol MGCollapsingHeaderDelegate {
    func headerDidCollapseToOffset(_ offset: CGFloat)
    func headerDidFinishCollapsing()
    func headerDidExpandToOffset(_ offset: CGFloat)
    func headerDidFinishExpanding()
}

public enum MGTransformCurve: Int {
    case MGTransformCurveLinear = 0
    case MGTransformCurveEaseIn
    case MGTransformCurveEaseOut
    case MGTransformCurveEaseInOut
}


public enum MGAttribute: Int {
    case MGAttributeX = 1
    case MGAttributeY
    case MGAttributeWidth
    case MGAttributeHeight
    case MGAttributeAlpha
    case MGAttributeCornerRadius
    case MGAttributeShadowRadius
    case MGAttributeShadowOpacity
    case MGAttributeFontSize
}

public struct MGTransform {
    var attribute: MGAttribute?
    var curve: MGTransformCurve?
    var value: CGFloat = 0.0
    var origValue: CGFloat = 0.0
    
    public func transformAttribute(_ attr: MGAttribute, byValue val: CGFloat) -> MGTransform{
        var transform = MGTransform()
        transform.attribute = attr
        transform.value = val
        transform.curve = .MGTransformCurveLinear;
        return transform;
        
    }
}

open class MGCollapsingHeaderView: UIView {
    var hdrConstrs = [NSLayoutConstraint]()
    var hdrConstrVals = [CGFloat]()
    var transfViews = [UIView]()
    var fadeViews = [UIView]()
    var constrs = [UIView:[NSLayoutAttribute:NSLayoutConstraint]]()
    var constrVals = [UIView:[NSLayoutAttribute:CGFloat]]()
    var transfAttrs = [UIView:[MGTransform]]()
    var alphaRatios = [UIView:CGFloat]()
    var vertContraints: [NSLayoutAttribute:Bool] = [.top: true, .topMargin: true, .bottom: true, .bottomMargin: true]
    var lastOffset: CGFloat = 0.0
    var header_ht: CGFloat = 0.0
    var scroll_ht: CGFloat = 0.0
    var offset_max: CGFloat = 0.0
    var font: UIFont?
    var min_height: CGFloat = 0
    
    convenience init() {
        self.init()
        self.commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override open func didMoveToWindow() {
        
    }
    
    fileprivate func commonInit() {
        header_ht = self.frame.size.height
        scroll_ht = -1.0
        self.minimumHeaderHeight = 60.0
        self.alwaysCollapse = true
    }
    
    /**
     * @brief An implementation of the header delegate.
     */
    open var delegate: MGCollapsingHeaderDelegate?
    
    /**
     * @brief The minimum height of the header in it's collapsed state.
     */
    open var minimumHeaderHeight: CGFloat {
        get {
            return min_height
        }
        set(newValue) {
            min_height = newValue
            offset_max = header_ht - newValue
        }
    }
    
    /**
     * @brief Forces the header to always collapse, even if the scrollable content is less
     * than the offset to collapse the header.
     * @discussion If set to @p NO, then the header will only collapse if there is enough
     * content in the scroll view to collapse the header completely.
     */
    open var alwaysCollapse = false
    
    /**
     * - brief Adds a constraint whose constant is offset when @p collapseWithScroll is called.
     * - discussion Constraints are expected to have vertical alignment. Different behavior can
     * be achieved depending on the constraints added. For example, adding the header height
     * constraint will cause the header to change its frame size while automatically adjusting
     * constraints of views within it. Adding the top or bottom constraint will cause the
     * header to slide up.
     * - Parameter constraint Constraint to offset.
     */
    open func setCollapsing(for constraint: NSLayoutConstraint) {
        self.setCollapsingConstraints([constraint])
    }
    
    open func setCollapsingConstraints(_ cs: [NSLayoutConstraint]) {
        hdrConstrs = cs;
        var vals = [CGFloat]()
        
        for c in cs {
            vals.append(c.constant)
        }
        hdrConstrVals = vals
    }
    
    
    /*!
     * @discussion Adds a view that transforms as the user scrolls.
     * @param view The view to transform.
     * @param attrs An array of MGTransform that describe the view in it's condensed
     * form.
     * @return Boolean identifying if the transform was successfully added.
     */
    open func addTransforming(_ view: UIView, attributes attr: [MGTransform]) -> Bool {
        var constrDict = [NSLayoutAttribute:NSLayoutConstraint]()
        var constrValDict = [NSLayoutAttribute:CGFloat]()
        
        var v = view;
        var hasView = true
        var attrs = attr
        while (hasView) {
            for c in v.constraints {
                if c.firstItem as! NSObject == view {
                    constrDict[c.firstAttribute] = c
                    constrValDict[c.firstAttribute] = c.constant
                } else if c.secondItem as! NSObject == view {
                    constrDict[c.secondAttribute] = c
                    constrValDict[c.secondAttribute] = c.constant
                }
            }
            if let sv = v.superview {
                v = sv
            } else {
                hasView = false
            }
        }
        for i in (0 ..< attrs.count) {
            attrs[i].origValue = self.getViewAttribute(attrs[i].attribute!, view)
        }
        transfViews.append(view)
        transfAttrs[view] = attrs
        
        constrs[view] = constrDict
        constrVals[view] = constrValDict
        
        return true;
    }
    
    /*!
     * @discussion Adds a view that fades as the user scrolls.
     * @param view The view to fade away.
     * @param ratio The ratio of collapsing at which the subview will finish fading away.
     * @return Boolean identifying if the fading subview was successfully added.
     */
    open func addFading(_ view: UIView, fadeBy ratio: CGFloat) -> Bool{
        if (ratio < 0.0 || ratio > 1.0) {
            return false;
        }
        fadeViews.append(view)
        alphaRatios[view] = ratio
        
        return true;
    }
    /*!
     * @discussion Adds a view that fades as the user scrolls.
     * @param view The view to fade away.
     * @param ratio The ratio of collapsing at which the subview will finish fading away.
     * @return Boolean identifying if the fading subview was successfully added.
     */
    open func collapse(with scrollView: UIScrollView) {
        var dy = scrollView.contentOffset.y;
        if scroll_ht < 0.0 {
            scroll_ht = scrollView.frame.size.height;
        }
        var scrollableHeight = scrollView.contentSize.height - scroll_ht;
        
        if (scrollableHeight / 2.0 < offset_max) {
            if (self.alwaysCollapse) {
                var scrInset   = scrollView.contentInset;
                // scrInset.bottom         = 2. * offset_max - scrollableHeight;
                scrollView.contentInset = scrInset;
            } else {
                return;
            }
        }
        
        if (dy > 0.0) {
            if (header_ht - dy > self.minimumHeaderHeight) {
                self.scrollHeader(to: dy)
                if self.delegate != nil {
                    if dy > lastOffset {
                        self.delegate!.headerDidCollapseToOffset(dy)
                        
                    } else {
                        self.delegate!.headerDidExpandToOffset(dy)
                    }
                }
            } else if (header_ht - lastOffset > self.minimumHeaderHeight) {
                self.scrollHeader(to: offset_max)
                
                if self.delegate != nil {
                    self.delegate!.headerDidFinishExpanding()
                    
                }
            }
        } else if (lastOffset > 0.0) {
            self.scrollHeader(to: 0.0)
            if self.delegate != nil {
                if dy < 0 { // Report negative offset from bouncing at top of scroll
                    self.delegate!.headerDidExpandToOffset(dy)
                } else {
                    self.delegate!.headerDidFinishExpanding()
                }
            }
        }
        if let superview = self.superview {
            superview.setNeedsUpdateConstraints()
            superview.setNeedsLayout()
            superview.layoutIfNeeded()
        }
        
        lastOffset = dy;
    }
    
    
    
    func scrollHeader(to offset: CGFloat) {
        let ratio = offset / offset_max;
        
        for view in fadeViews {
            //            let alphaRatio = [[alphaRatios objectForKey:@(view.hash)] doubleValue];
            let alphaRatio = alphaRatios[view]
            view.alpha = -ratio / alphaRatio! + 1
        }
        
        for view in transfViews {
            let cs = constrs[view]
            let cvs = constrVals[view]
            let tas = transfAttrs[view]
            
            for a in tas! {
                self.setAttribute(a, view, ratio, constraints: cs!, constraintValues: cvs!)
            }
        }
        
        var hdrFrame   = self.frame
        hdrFrame.origin.y = -offset
        self.frame = hdrFrame
        
        for i in (0 ..< hdrConstrs.count) {
            hdrConstrs[i].constant = (hdrConstrVals[i] - offset)
        }
    }
    
    func getViewAttribute(_ attribute: MGAttribute, _ view: UIView) -> CGFloat
    {
        switch (attribute) {
        case .MGAttributeX:
            return view.frame.origin.x
        case .MGAttributeY:
            return view.frame.origin.y
        case .MGAttributeWidth:
            return view.frame.size.width
        case .MGAttributeHeight:
            return view.frame.size.height
        case .MGAttributeAlpha:
            return view.alpha
        case .MGAttributeCornerRadius:
            return view.layer.cornerRadius
        case .MGAttributeShadowOpacity:
            return CGFloat(view.layer.shadowOpacity)
        case .MGAttributeShadowRadius:
            return view.layer.shadowRadius;
        case .MGAttributeFontSize:
            if let labelView = view as? UILabel {
                return labelView.font.pointSize
            } else if let buttonView = view as? UIButton , buttonView.titleLabel != nil {
                return buttonView.titleLabel!.font.pointSize
            } else if let textView = view as? UITextView , textView.font != nil {
                return textView.font!.pointSize
            } else if let textField = view as? UITextField, textField.font != nil {
                return textField.font!.pointSize
            }
        }
        
        return 0.0
    }
    
    func setAttribute(_ attr: MGTransform, _ view: UIView, _ ratio: CGFloat, constraints cs: [NSLayoutAttribute:NSLayoutConstraint], constraintValues cvals: [NSLayoutAttribute:CGFloat]) {
        
        switch (attr.attribute!) {
        case .MGAttributeX:
            self.updateConstraint(cs[.leading], constrValue: cvals[.leading]!, transform: attr, ratio)
            self.updateConstraint(cs[.leadingMargin], constrValue: cvals[.leadingMargin]!, transform: attr, ratio)
            self.updateConstraint(cs[.trailing], constrValue: cvals[.trailing]!, transform: attr, ratio)
            self.updateConstraint(cs[.trailingMargin], constrValue: cvals[.trailingMargin]!, transform: attr, ratio)
            break;
        case .MGAttributeY:
            self.updateConstraint(cs[.top], constrValue: cvals[.top]!, transform: attr, ratio)
            self.updateConstraint(cs[.topMargin], constrValue: cvals[.topMargin]!, transform: attr, ratio)
            self.updateConstraint(cs[.bottom], constrValue: cvals[.bottom]!, transform: attr, ratio)
            self.updateConstraint(cs[.bottomMargin], constrValue: cvals[.bottomMargin]!, transform: attr, ratio)
            break;
        case .MGAttributeWidth:
            self.updateConstraint(cs[.width], constrValue: cvals[.width]!, transform: attr, ratio)
            
            break;
        case .MGAttributeHeight:
            self.updateConstraint(cs[.height], constrValue: cvals[.height]!, transform: attr, ratio)
            
            break;
        case .MGAttributeCornerRadius:
            view.layer.cornerRadius = attr.origValue + ratio * attr.value;
            break;
        case .MGAttributeAlpha:
            view.alpha = attr.origValue + ratio * attr.value;
            break;
        case .MGAttributeShadowRadius:
            view.layer.shadowRadius = attr.origValue + ratio * attr.value;
            break;
        case .MGAttributeShadowOpacity:
            var value = ratio * attr.value
            value = attr.origValue + value
            view.layer.shadowOpacity = Float(value)
            break;
        case .MGAttributeFontSize:
            if let labelView = view as? UILabel {
                font = UIFont(name: labelView.font.familyName, size: attr.origValue + ratio * attr.value)
                labelView.font = font
            } else if let buttonView = view as? UIButton , buttonView.titleLabel != nil {
                font = UIFont(name: buttonView.titleLabel!.font.familyName, size: attr.origValue + ratio * attr.value)
                buttonView.titleLabel!.font = font
            } else if let textView = view as? UITextView , textView.font != nil {
                font = UIFont(name: textView.font!.familyName, size: attr.origValue + ratio * attr.value)
                textView.font = font
            } else if let textField = view as? UITextField, textField.font != nil {
                font = UIFont(name: textField.font!.familyName, size: attr.origValue + ratio * attr.value)
                textField.font = font
            }
            break;
        }
        
    }
    
    func updateConstraint(_ constraint: NSLayoutConstraint?, constrValue cv: CGFloat, transform ta: MGTransform, _ ratio: CGFloat) {
        if let c = constraint {
            switch (constraint!.firstAttribute) {
            case .height:
                constraint!.constant = cv + ratio * ta.value;
                break
            case .trailingMargin: break
            constraint!.constant = cv - ratio * ta.value;
                break
            default:
                break
            }
        }
    }
    
}
