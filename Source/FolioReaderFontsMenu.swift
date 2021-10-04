//
//  FolioReaderFontsMenu.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 27/08/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

public enum FolioReaderFont: Int {
    
    case andada = 0
    case lato
    case lora
    case raleway

    public var cssIdentifier: String {
        
        switch self {
                
            case .andada: return "andada"
            case .lato: return "lato"
            case .lora: return "lora"
            case .raleway: return "raleway"
        }
    }
}

public enum FolioReaderFontSize: Int {
    
    case xs = 0
    case s
    case m
    case l
    case xl
    
    public var cssIdentifier: String {
        
        switch self {
                
            case .xs: return "textSizeOne"
            case .s: return "textSizeTwo"
            case .m: return "textSizeThree"
            case .l: return "textSizeFour"
            case .xl: return "textSizeFive"
        }
    }
}


class FolioReaderFontsMenu: UIViewController {
    
    //MARK: - Private property
    private var menuView: UIView!
    private var dayNightSegmentContainerView: SMSegmentView!
    private var fontsNameSegmentContainerView: SMSegmentView!
    private var slider: HADiscreteSlider!
    private var fontSmallImageView: UIImageView!
    private var fontBigImageView: UIImageView!
    private var separator1: UIView!
    private var separator2: UIView!
    private var separator3: UIView!
    private var layoutDirectionSegmentContainerView: SMSegmentView!
    
    fileprivate var readerConfig: FolioReaderConfig
    fileprivate var folioReader: FolioReader

    //MARK: - Init
    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        
        self.readerConfig = readerConfig
        self.folioReader = folioReader

        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Status Bar
    override var prefersStatusBarHidden: Bool {
        
        readerConfig.shouldHideNavigationOnTap
    }
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = .clear

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGesture))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        // Menu view
        menuView = UIView()
        menuView.backgroundColor = folioReader.isNight(readerConfig.nightModeMenuBackground, .white)
        menuView.autoresizingMask = .flexibleWidth
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 6
        menuView.layer.shadowPath = UIBezierPath(rect: menuView.bounds).cgPath
        menuView.layer.rasterizationScale = UIScreen.main.scale
        menuView.layer.shouldRasterize = true
        view.addSubview(menuView)

        let normalColor = UIColor(white: 0.5, alpha: 0.7)
        let selectedColor = readerConfig.tintColor
        let sun = UIImage(readerImageNamed: "icon-sun")
        let moon = UIImage(readerImageNamed: "icon-moon")
        let fontSmall = UIImage(readerImageNamed: "icon-font-small")
        let fontBig = UIImage(readerImageNamed: "icon-font-big")

        let sunNormal = sun?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let moonNormal = moon?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let fontSmallNormal = fontSmall?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let fontBigNormal = fontBig?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)

        let sunSelected = sun?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
        let moonSelected = moon?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)

        // Day night mode
        dayNightSegmentContainerView = SMSegmentView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 55),
                                                     separatorColour: readerConfig.nightModeSeparatorColor,
                                                     separatorWidth: 1,
                                                     segmentProperties:  [
                                                        keySegmentTitleFont: UIFont(name: "Avenir-Light", size: 17)!,
                                                        keySegmentOnSelectionColour: UIColor.clear,
                                                        keySegmentOffSelectionColour: UIColor.clear,
                                                        keySegmentOnSelectionTextColour: selectedColor,
                                                        keySegmentOffSelectionTextColour: normalColor,
                                                        keyContentVerticalMargin: 17 as AnyObject
            ])
        dayNightSegmentContainerView.delegate = self
        dayNightSegmentContainerView.tag = 1
        dayNightSegmentContainerView.addSegmentWithTitle(readerConfig.localizedFontMenuDay, onSelectionImage: sunSelected, offSelectionImage: sunNormal)
        dayNightSegmentContainerView.addSegmentWithTitle(readerConfig.localizedFontMenuNight, onSelectionImage: moonSelected, offSelectionImage: moonNormal)
        dayNightSegmentContainerView.selectSegmentAtIndex(folioReader.nightMode ? 1 : 0)
//        menuView.addSubview(dayNightSegmentContainerView)

        // Separator
        separator1 = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 1))//dayNightSegmentContainerView.frame.maxY
        separator1.backgroundColor = readerConfig.nightModeSeparatorColor
        menuView.addSubview(separator1)
        
        // Fonts adjust
        fontsNameSegmentContainerView = SMSegmentView(frame: CGRect(x: 15,
                                                                    y: separator1.frame.height+separator1.frame.origin.y,
                                                                    width: view.frame.width-30,
                                                                    height: readerConfig.canChangeFontStyle ? 55: 0),
                                                      separatorColour: UIColor.clear,
                                                      separatorWidth: 0,
                                                      segmentProperties:  [
                                                        keySegmentOnSelectionColour: UIColor.clear,
                                                        keySegmentOffSelectionColour: UIColor.clear,
                                                        keySegmentOnSelectionTextColour: selectedColor,
                                                        keySegmentOffSelectionTextColour: normalColor,
                                                        keyContentVerticalMargin: 17 as AnyObject])
        fontsNameSegmentContainerView.delegate = self
        fontsNameSegmentContainerView.tag = 2
        fontsNameSegmentContainerView.addSegmentWithTitle("Andada")
        fontsNameSegmentContainerView.addSegmentWithTitle("Lato")
        fontsNameSegmentContainerView.addSegmentWithTitle("Lora")
        fontsNameSegmentContainerView.addSegmentWithTitle("Raleway")
        fontsNameSegmentContainerView.selectSegmentAtIndex(folioReader.currentFont.rawValue)
        
        menuView.addSubview(fontsNameSegmentContainerView)

        // Separator 2
        separator2 = UIView(frame: CGRect(x: 0,
                                          y: fontsNameSegmentContainerView.frame.height+fontsNameSegmentContainerView.frame.origin.y,
                                          width: view.frame.width,
                                          height: 1))
        separator2.backgroundColor = readerConfig.nightModeSeparatorColor
        menuView.addSubview(separator2)

        // Font slider size
        slider = HADiscreteSlider(frame: CGRect(x: 60, y: separator2.frame.origin.y+2, width: view.frame.width-120, height: 55))
        slider.tickStyle = ComponentStyle.rounded
        slider.tickCount = 5
        slider.tickSize = CGSize(width: 8, height: 8)

        slider.thumbStyle = ComponentStyle.rounded
        slider.thumbSize = CGSize(width: 28, height: 28)
        slider.thumbShadowOffset = CGSize(width: 0, height: 2)
        slider.thumbShadowRadius = 3
        slider.thumbColor = selectedColor

        slider.backgroundColor = UIColor.clear
        slider.tintColor = readerConfig.nightModeSeparatorColor
        slider.minimumValue = 0
        slider.value = CGFloat(folioReader.currentFontSize.rawValue)
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        // Force remove fill color
        slider.layer.sublayers?.forEach { $0.backgroundColor = UIColor.clear.cgColor }

        menuView.addSubview(slider)

        // Font icons
        fontSmallImageView = UIImageView(frame: CGRect(x: 20, y: separator2.frame.origin.y+14, width: 30, height: 30))
        fontSmallImageView.image = fontSmallNormal
        fontSmallImageView.contentMode = UIView.ContentMode.center
        menuView.addSubview(fontSmallImageView)

        fontBigImageView = UIImageView(frame: CGRect(x: view.frame.width-50, y: separator2.frame.origin.y+14, width: 30, height: 30))
        fontBigImageView.image = fontBigNormal
        fontBigImageView.contentMode = UIView.ContentMode.center
        menuView.addSubview(fontBigImageView)

        // Only continues if user can change scroll direction
        guard readerConfig.canChangeScrollDirection else { return }

        // Separator 3
        separator3 = UIView(frame: CGRect(x: 0, y: separator2.frame.origin.y+56, width: view.frame.width, height: 1))
        separator3.backgroundColor = readerConfig.nightModeSeparatorColor
        menuView.addSubview(separator3)

        let vertical = UIImage(readerImageNamed: "icon-menu-vertical")
        let horizontal = UIImage(readerImageNamed: "icon-menu-horizontal")
        let verticalNormal = vertical?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let horizontalNormal = horizontal?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let verticalSelected = vertical?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
        let horizontalSelected = horizontal?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)

        // Layout direction
        layoutDirectionSegmentContainerView = SMSegmentView(frame: CGRect(x: 0, y: separator3.frame.origin.y, width: view.frame.width, height: 55),
                                            separatorColour: readerConfig.nightModeSeparatorColor,
                                            separatorWidth: 1,
                                            segmentProperties:  [
                                                keySegmentTitleFont: UIFont(name: "Avenir-Light", size: 17)!,
                                                keySegmentOnSelectionColour: UIColor.clear,
                                                keySegmentOffSelectionColour: UIColor.clear,
                                                keySegmentOnSelectionTextColour: selectedColor,
                                                keySegmentOffSelectionTextColour: normalColor,
                                                keyContentVerticalMargin: 17 as AnyObject
            ])
        layoutDirectionSegmentContainerView.delegate = self
        layoutDirectionSegmentContainerView.tag = 3
        layoutDirectionSegmentContainerView.addSegmentWithTitle(readerConfig.localizedLayoutVertical, onSelectionImage: verticalSelected, offSelectionImage: verticalNormal)
        layoutDirectionSegmentContainerView.addSegmentWithTitle(readerConfig.localizedLayoutHorizontal, onSelectionImage: horizontalSelected, offSelectionImage: horizontalNormal)

        var scrollDirection = FolioReaderScrollDirection(rawValue: folioReader.currentScrollDirection) ?? .vertical

        if scrollDirection == .defaultVertical && readerConfig.scrollDirection != .defaultVertical {
            
            scrollDirection = readerConfig.scrollDirection
        }

        switch scrollDirection {
                
        case .vertical, .defaultVertical:
                
            layoutDirectionSegmentContainerView.selectSegmentAtIndex(FolioReaderScrollDirection.vertical.rawValue)
                
        case .horizontal, .horizontalWithVerticalContent:
                
            layoutDirectionSegmentContainerView.selectSegmentAtIndex(FolioReaderScrollDirection.horizontalWithVerticalContent.rawValue)
        }
        menuView.addSubview(layoutDirectionSegmentContainerView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        layout()
    }

    
    //MARK: - Actions
    //MARK: - Font slider changed
    @objc private func sliderValueChanged(_ sender: HADiscreteSlider) {
        
        guard folioReader.readerCenter?.currentPage != nil,
              let fontSize = FolioReaderFontSize(rawValue: Int(sender.value)) else { return }
        
        folioReader.currentFontSize = fontSize
    }
    
    //MARK: - Gestures
    @objc private func tapGesture() {
        
        dismiss()
        
        if !readerConfig.shouldHideNavigationOnTap {
            
            folioReader.readerCenter?.showBars()
        }
    }
    
    private func layout() {
        
        let bottomInset = folioReader.readerCenter?.view.safeInsets.bottom ?? 0
        var visibleHeight: CGFloat = readerConfig.canChangeScrollDirection ? 200 : 115//170
        visibleHeight = readerConfig.canChangeFontStyle ? visibleHeight : visibleHeight - 55

        menuView.frame = CGRect(origin: CGPoint(x: 0, y: view.frame.height-visibleHeight-bottomInset),
                                size: view.frame.size)
        
//        dayNightSegmentContainerView.frame = CGRect(origin: .zero,
//                                                    size: CGSize(width: view.bounds.width, height: 55))
        
        separator1.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 1)
        //dayNightSegmentContainerView.frame.maxY
        
        fontsNameSegmentContainerView.frame = CGRect(x: 15, y: separator1.frame.height+separator1.frame.origin.y,
                                                     width: view.frame.width-30, height: readerConfig.canChangeFontStyle ? 55: 0)
        
        separator2.frame = CGRect(x: 0, y: fontsNameSegmentContainerView.frame.height+fontsNameSegmentContainerView.frame.origin.y,
                                  width: view.frame.width, height: 1)
        
        let safeAreaInsets = folioReader.readerContainer?.view.safeInsets ?? .zero
        let orintation = UIDevice.current.orientation
        let fontSmallImageViewOriginX = orintation == .landscapeLeft ? safeAreaInsets.top : 20
        let fontBigImageViewOriginX = (orintation == .landscapeRight ? safeAreaInsets.top : 20) + fontBigImageView.frame.width
        
        let sliderWidth = view.frame.width-(fontSmallImageViewOriginX+fontSmallImageView.frame.width+10+fontBigImageViewOriginX+10+(orintation == .landscapeRight || orintation == .landscapeLeft ? safeAreaInsets.top : 0))
        let sliderX = (view.frame.width-sliderWidth)/2
        
        slider.frame = CGRect(x: sliderX, y: separator2.frame.origin.y+2, width: sliderWidth, height: 55)
        slider.layout()
        
        fontSmallImageView.frame.origin.x = fontSmallImageViewOriginX
        
        fontBigImageView.frame.origin.x = view.frame.width-fontBigImageViewOriginX
        
        // Only continues if user can change scroll direction
        guard readerConfig.canChangeScrollDirection else { return }
        
        separator3.frame = CGRect(x: 0, y: separator2.frame.origin.y+56, width: view.frame.width, height: 1)
        
        layoutDirectionSegmentContainerView.frame = CGRect(x: 0, y: separator3.frame.origin.y, width: view.frame.width, height: 55)
    }
}

//MARK: - UIGestureRecognizerDelegate
extension FolioReaderFontsMenu: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        gestureRecognizer is UITapGestureRecognizer && touch.view == view
    }
}

//MARK: - SMSegmentViewDelegate
extension FolioReaderFontsMenu: SMSegmentViewDelegate {
    
    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {
        
        guard folioReader.readerCenter?.currentPage != nil else { return }
        
        if segmentView.tag == 1 {
            
            folioReader.nightMode = index == 1
            
            UIView.animate(withDuration: 0.6) {[unowned self] in
                
                menuView.backgroundColor = folioReader.nightMode ? readerConfig.nightModeBackground : readerConfig.daysModeNavBackground
            }
            
        } else if segmentView.tag == 2, let font = FolioReaderFont(rawValue: index) {
            
            folioReader.currentFont = font
            
        }  else if segmentView.tag == 3, folioReader.currentScrollDirection != index {
            
            folioReader.currentScrollDirection = index
        }
    }
}
