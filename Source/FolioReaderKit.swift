//
//  FolioReaderKit.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Internal constants

internal let kApplicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
internal let kCurrentFontFamily = "com.folioreader.kCurrentFontFamily"
internal let kCurrentFontSize = "com.folioreader.kCurrentFontSize"
internal let kCurrentAudioRate = "com.folioreader.kCurrentAudioRate"
internal let kCurrentHighlightStyle = "com.folioreader.kCurrentHighlightStyle"
internal let kCurrentMediaOverlayStyle = "com.folioreader.kMediaOverlayStyle"
internal let kCurrentScrollDirection = "com.folioreader.kCurrentScrollDirection"
internal let kNightMode = "com.folioreader.kNightMode"
internal let kCurrentTOCMenu = "com.folioreader.kCurrentTOCMenu"
internal let kHighlightRange = 30
internal let kReuseCellIdentifier = "com.folioreader.Cell.ReuseIdentifier"

public enum FolioReaderError: Error, LocalizedError {
    case bookNotAvailable
    case errorInContainer
    case errorInOpf
    case authorNameNotAvailable
    case coverNotAvailable
    case invalidImage(path: String)
    case titleNotAvailable
    case fullPathEmpty

    public var errorDescription: String? {
        switch self {
        case .bookNotAvailable:
            return "Book not found"
        case .errorInContainer, .errorInOpf:
            return "Invalid book format"
        case .authorNameNotAvailable:
            return "Author name not available"
        case .coverNotAvailable:
            return "Cover image not available"
        case let .invalidImage(path):
            return "Invalid image at path: " + path
        case .titleNotAvailable:
            return "Book title not available"
        case .fullPathEmpty:
            return "Book corrupted"
        }
    }
}

/// Defines the media overlay and TTS selection
///
/// - `default`: The background is colored
/// - underline: The underlined is colored
/// - textColor: The text is colored
public enum MediaOverlayStyle: Int {
    case `default`
    case underline
    case textColor

    init() {
        self = .default
    }

    func className() -> String {
        
        "mediaOverlayStyle\(self.rawValue)"
    }
}

/// FolioReader actions delegate
@objc public protocol FolioReaderDelegate: class {
    
    /// Did finished loading book.
    ///
    /// - Parameters:
    ///   - folioReader: The FolioReader instance
    ///   - book: The Book instance
    @objc optional func folioReader(_ folioReader: FolioReader, didFinishedLoading book: FRBook)
    
    /// Called when reader did closed.
    ///
    /// - Parameter folioReader: The FolioReader instance
    @objc optional func folioReaderDidClose(_ folioReader: FolioReader)
    
    /// Called when reader did closed.
    @available(*, deprecated, message: "Use 'folioReaderDidClose(_ folioReader: FolioReader)' instead.")
    @objc optional func folioReaderDidClosed()
}

/// Main Library class with some useful constants and methods
open class FolioReader: NSObject {

    public override init() { }

    deinit {
        removeObservers()
    }

    /// Custom unzip path
    open var unzipPath: String?

    /// FolioReaderDelegate
    open weak var delegate: FolioReaderDelegate?
    
    open weak var readerContainer: FolioReaderContainer?
    open weak var readerAudioPlayer: FolioReaderAudioPlayer?
    open weak var readerCenter: FolioReaderCenter? {
        
        readerContainer?.centerViewController
    }

    /// Check if reader is open
    var isReaderOpen = false

    /// Check if reader is open and ready
    var isReaderReady = false

    /// Check if layout needs to change to fit Right To Left
    var needsRTLChange: Bool {
        
        readerContainer?.book.spine.isRtl == true && readerContainer?.readerConfig.scrollDirection == .horizontal
    }

    func isNight<T>(_ f: T, _ l: T) -> T {
        
        nightMode ? f : l
    }

    /// UserDefault for the current ePub file.
    fileprivate var defaults: FolioReaderUserDefaults {
        
        FolioReaderUserDefaults(withIdentifier: readerContainer?.readerConfig.identifier)
    }

    // Add necessary observers
    fileprivate func addObservers() {
        removeObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(saveReaderState), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveReaderState), name: UIApplication.willTerminateNotification, object: nil)
    }

    /// Remove necessary observers
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
    }
}

// MARK: - Present FolioReader

extension FolioReader {

    /// Present a Folio Reader Container modally on a Parent View Controller.
    ///
    /// - Parameters:
    ///   - parentViewController: View Controller that will present the reader container.
    ///   - epubPath: String representing the path on the disk of the ePub file. Must not be nil nor empty string.
    ///   - unzipPath: Path to unzip the compressed epub.
    ///   - config: FolioReader configuration.
    ///   - shouldRemoveEpub: Boolean to remove the epub or not. Default true.
    ///   - animated: Pass true to animate the presentation; otherwise, pass false.
    open func presentReader(parentViewController: UIViewController, withEpubPath epubPath: String, unzipPath: String? = nil, andConfig config: FolioReaderConfig, shouldRemoveEpub: Bool = true, animated:
        Bool = true) {
        
        let readerContainer = FolioReaderContainer(withConfig: config,
                                                   folioReader: self,
                                                   epubPath: epubPath,
                                                   unzipPath: unzipPath,
                                                   removeEpub: shouldRemoveEpub)
        self.readerContainer = readerContainer
        parentViewController.present(readerContainer, animated: animated, completion: nil)
        addObservers()
    }
}

// MARK: -  Getters and setters for stored values

extension FolioReader {

    public func register(defaults: [String: Any]) {
        
        self.defaults.register(defaults: defaults)
    }

    /// Check if current theme is Night mode
    open var nightMode: Bool {
        
        get { defaults.bool(forKey: kNightMode) }
        set (mode) {
            
            defaults.set(mode, forKey: kNightMode)

            if let readerCenter = readerCenter {
                
                UIView.animate(withDuration: 0.6, animations: {[unowned self] in
                    
                    readerCenter.currentPage?.webView?.js("nightMode(\(nightMode))")
                    readerCenter.pageIndicatorView?.reloadColors()
                    readerCenter.configureNavigationBar()
                    readerCenter.collectionView.backgroundColor = (nightMode ? readerContainer?.readerConfig.nightModeBackground : .white)
                    
                }, completion: { _ in
                    
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "needRefreshPageMode"), object: nil)
                })
            }
        }
    }

    /// Check current font name. Default .andada
    open var currentFont: FolioReaderFont {
        
        get {
            guard let rawValue = defaults.value(forKey: kCurrentFontFamily) as? Int,
                  let font = FolioReaderFont(rawValue: rawValue) else { return .andada }

            return font
        }
        set (font) {
            
            defaults.set(font.rawValue, forKey: kCurrentFontFamily)
            readerCenter?.currentPage?.webView?.js("setFontName('\(font.cssIdentifier)')")
        }
    }

    /// Check current font size. Default .m
    open var currentFontSize: FolioReaderFontSize {

        get {
            guard let rawValue = defaults.value(forKey: kCurrentFontSize) as? Int,
                  let size = FolioReaderFontSize(rawValue: rawValue) else { return .m }

            return size
        }
        set (size) {
            
            defaults.set(size.rawValue, forKey: kCurrentFontSize)

            guard let currentPage = readerCenter?.currentPage else { return }

            currentPage.webView?.js("setFontSize('\(currentFontSize.cssIdentifier)')")
        }
    }

    /// Check current audio rate, the speed of speech voice. Default 0
    open var currentAudioRate: Int {
        
        get { defaults.integer(forKey: kCurrentAudioRate) }
        set(rate) { defaults.set(rate, forKey: kCurrentAudioRate) }
    }

    /// Check the current highlight style.Default 0
    open var currentHighlightStyle: Int {
        
        get { defaults.integer(forKey: kCurrentHighlightStyle) }
        set (style) { defaults.set(style, forKey: kCurrentHighlightStyle) }
    }

    /// Check the current Media Overlay or TTS style
    open var currentMediaOverlayStyle: MediaOverlayStyle {
        
        get {
            guard let rawValue = defaults.value(forKey: kCurrentMediaOverlayStyle) as? Int,
                  let style = MediaOverlayStyle(rawValue: rawValue) else { return MediaOverlayStyle.default }
            
            return style
        }
        set (style) { defaults.set(style.rawValue, forKey: kCurrentMediaOverlayStyle) }
    }

    /// Check the current scroll direction. Default .defaultVertical
    open var currentScrollDirection: Int {
        
        get {
        
            guard let direction = defaults.value(forKey: kCurrentScrollDirection) as? Int else { return FolioReaderScrollDirection.defaultVertical.rawValue }
            return direction
        }
        set(direction) {
            
            defaults.set(direction, forKey: kCurrentScrollDirection)

            let direction = FolioReaderScrollDirection(rawValue: currentScrollDirection) ?? .defaultVertical
            readerCenter?.setScrollDirection(direction)
        }
    }

    open var currentMenuIndex: Int {
        
        get { defaults.integer(forKey: kCurrentTOCMenu) }
        set (index) { defaults.set(index, forKey: kCurrentTOCMenu) }
    }

    open var savedPositionForCurrentBook: [String: Any]? {
        
        get {
            guard let bookId = readerContainer?.book.name else { return nil }
            
            return defaults.value(forKey: bookId) as? [String : Any]
        }
        set {
            guard let bookId = readerContainer?.book.name else { return }
            
            defaults.set(newValue, forKey: bookId)
        }
    }
}

// MARK: - Metadata

extension FolioReader {

    // TODO QUESTION: The static `getCoverImage` function used the shared instance before and ignored the `unzipPath` parameter.
    // Should we properly implement the parameter (what has been done now) or should change the API to only use the current FolioReader instance?

    /**
     Read Cover Image and Return an `UIImage`
     */
    open class func getCoverImage(_ epubPath: String, unzipPath: String? = nil) throws -> UIImage {
        try FREpubParser().parseCoverImage(epubPath, unzipPath: unzipPath)
    }

    open class func getTitle(_ epubPath: String, unzipPath: String? = nil) throws -> String {
        try FREpubParser().parseTitle(epubPath, unzipPath: unzipPath)
    }

    open class func getAuthorName(_ epubPath: String, unzipPath: String? = nil) throws-> String {
        try FREpubParser().parseAuthorName(epubPath, unzipPath: unzipPath)
    }
}

// MARK: - Exit, save and close FolioReader

extension FolioReader {

    /// Save Reader state, book, page and scroll offset.
    @objc open func saveReaderState() {
        
        guard isReaderOpen,
              let currentPage = readerCenter?.currentPage,
              let webView = currentPage.webView else { return }

        let position = [
            "pageNumber": (self.readerCenter?.currentPageNumber ?? 0),
            "pageOffsetX": webView.scrollView.contentOffset.x,
            "pageOffsetY": webView.scrollView.contentOffset.y
            ] as [String : Any]

        savedPositionForCurrentBook = position
    }

    /// Closes and save the reader current instance.
    open func close() {
        
        saveReaderState()
        isReaderOpen = false
        isReaderReady = false
        readerAudioPlayer?.stop(immediate: true)
        defaults.set(0, forKey: kCurrentTOCMenu)
        delegate?.folioReaderDidClose?(self)
    }
}
