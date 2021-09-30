//
//  FolioReaderPageIndicator.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/09/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

class FolioReaderPageIndicator: UIView {
    
    //MARK: - Internal properties
    var pagesLabel: UILabel!
//    var minutesLabel: UILabel!
//    var totalMinutes: Int!
    
    var totalPages = 0
    var currentPage: Int = 1 {
        didSet {
            reloadViewWithPage(currentPage)
        }
    }

    //MARK: - Fileprivate properties
    fileprivate var progressLine: UIProgressView!
    fileprivate var pagesLeftLabel: UILabel!
    fileprivate var readerConfig: FolioReaderConfig
    fileprivate var folioReader: FolioReader

    //MARK: - Lifecycle
    init(frame: CGRect, readerConfig: FolioReaderConfig, folioReader: FolioReader) {
        
        self.readerConfig = readerConfig
        self.folioReader = folioReader

        super.init(frame: frame)

        backgroundColor = folioReader.isNight(readerConfig.nightModeBackground, .white)
//        layer.shadowColor = color.cgColor
//        layer.shadowOffset = CGSize(width: 0, height: -6)
//        layer.shadowOpacity = 1
//        layer.shadowRadius = 4
//        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
//        layer.rasterizationScale = UIScreen.main.scale
//        layer.shouldRasterize = true

        pagesLabel = UILabel()
        pagesLabel.font = UIFont(name: "Avenir-Light", size: 13)!
        pagesLabel.textAlignment = .center
        addSubview(pagesLabel)
        
        pagesLeftLabel = UILabel()
        pagesLeftLabel.font = UIFont(name: "Avenir-Light", size: 13)!
        pagesLeftLabel.textAlignment = .right
        addSubview(pagesLeftLabel)
        
        progressLine = UIProgressView()
        progressLine.isHidden = true
        addSubview(progressLine)

//        minutesLabel = UILabel(frame: CGRect.zero)
//        minutesLabel.font = UIFont(name: "Avenir-Light", size: 10)!
//        minutesLabel.textAlignment = NSTextAlignment.right
//        minutesLabel.alpha = 0
//        addSubview(minutesLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }

    func reloadView(updateShadow: Bool) {
//        minutesLabel.sizeToFit()
        

//        let fullW = pagesLabel.frame.width + minutesLabel.frame.width
//        minutesLabel.frame.origin = CGPoint(x: frame.width/2-fullW/2, y: 2)
        //minutesLabel.frame.origin.x+minutesLabel.frame.width
        pagesLabel.frame.origin = CGPoint(x: (frame.width-pagesLabel.frame.width)/2,
                                          y: (46-pagesLabel.frame.height)/2)
        
        pagesLeftLabel.frame.origin = CGPoint(x: frame.width-pagesLeftLabel.frame.width-16,
                                          y: (46-pagesLeftLabel.frame.height)/2)
        
        let size = CGSize(width: frame.width-32, height: 1)
        let origin = CGPoint(x: (frame.width-size.width)/2, y: 2)
        progressLine.frame = CGRect(origin: origin, size: size)
        
        if updateShadow {
//            layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            reloadColors()
        }
    }

    func reloadColors() {
        
        backgroundColor = folioReader.isNight(readerConfig.nightModeBackground, .white)

        // Animate the shadow color change
//        let animation = CABasicAnimation(keyPath: "shadowColor")
//        let currentColor = UIColor(cgColor: layer.shadowColor!)
//        animation.fromValue = currentColor.cgColor
//        animation.toValue = color.cgColor
//        animation.fillMode = CAMediaTimingFillMode.forwards
//        animation.isRemovedOnCompletion = false
//        animation.duration = 0.6
//        animation.delegate = self
//        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
//        layer.add(animation, forKey: "shadowColor")

//        minutesLabel.textColor = self.folioReader.isNight(UIColor(white: 1, alpha: 0.3), UIColor(white: 0, alpha: 0.6))
        
        pagesLabel.textColor = folioReader.isNight(.white, readerConfig.nightModeBackground)
        
        pagesLeftLabel.textColor = folioReader.isNight(.white, readerConfig.nightModeBackground)
        
        progressLine.trackTintColor = folioReader.isNight(.black, .lightGray)
        progressLine.progressTintColor = folioReader.isNight(.white, .black)
        progressLine.progressViewStyle = .default
    }
    
    func setProgress(by scrollView: UIScrollView, pageSize size: CGFloat, configuration: FolioReaderConfig, animated: Bool = false) {
        
        if let webView = scrollView.superview as? FolioReaderWKWebView {
            
            let superviewTopInset = superview?.safeInsets.top ?? 0
            let sizeWithoutSafeInsets = size - superviewTopInset - (superview?.safeInsets.bottom ?? 0) - 46
            let offset = max(0, webView.scrollView.contentOffset.forDirection(withConfiguration: configuration) + superviewTopInset)
            let contentSize = webView.scrollView.contentSize.forDirection(withConfiguration: configuration)-sizeWithoutSafeInsets
            let progress = Float(offset / contentSize)
            
            progressLine.setProgress(progress, animated: animated)
        }
    }
    
    //MARK: - Private methods
    private func reloadViewWithPage(_ page: Int) {
        
        let pagesRemaining = totalPages > 0 ? folioReader.needsRTLChange ? totalPages-(totalPages-page+1) : totalPages-page : 0
        
        pagesLabel.text = "\(totalPages - pagesRemaining) of \(totalPages)"
        pagesLabel.sizeToFit()
        
        pagesLeftLabel.text = pagesRemaining == 1 ?
        " " + readerConfig.localizedReaderOnePageLeft :
        "\(pagesRemaining) " + readerConfig.localizedReaderManyPagesLeft
        pagesLeftLabel.sizeToFit()
        
        progressLine.isHidden = false
        
        reloadView(updateShadow: false)
        
        
//        let minutesRemaining = Int(ceil(CGFloat((pagesRemaining * totalMinutes)/totalPages)))
//        if minutesRemaining > 1 {
//            minutesLabel.text = "\(minutesRemaining) " + self.readerConfig.localizedReaderManyMinutes+" ·"
//        } else if minutesRemaining == 1 {
//            minutesLabel.text = self.readerConfig.localizedReaderOneMinute+" ·"
//        } else {
//            minutesLabel.text = self.readerConfig.localizedReaderLessThanOneMinute+" ·"
//        }
        
        
    }
}

//extension FolioReaderPageIndicator: CAAnimationDelegate {
//
//    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//
//        // Set the shadow color to the final value of the animation is done
//        if let keyPath = anim.value(forKeyPath: "keyPath") as? String, keyPath == "shadowColor" {
//            let color = self.folioReader.isNight(self.readerConfig.nightModeBackground, UIColor.white)
//            layer.shadowColor = color.cgColor
//        }
//    }
//}
