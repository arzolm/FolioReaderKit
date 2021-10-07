//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import MenuItemKit
import WebKit

/// Protocol which is used from `FolioReaderPage`s.
@objc public protocol FolioReaderPageDelegate: class {

    /**
     Notify that the page will be loaded. Note: The webview content itself is already loaded at this moment. But some java script operations like the adding of class based on click listeners will happen right after this method. If you want to perform custom java script before this happens this method is the right choice. If you want to modify the html content (and not run java script) you have to use `htmlContentForPage()` from the `FolioReaderCenterDelegate`.

     - parameter page: The loaded page
     */
    @objc optional func pageWillLoad(_ page: FolioReaderPage)

    /**
     Notifies that page did load. A page load doesn't mean that this page is displayed right away, use `pageDidAppear` to get informed about the appearance of a page.

     - parameter page: The loaded page
     */
    @objc optional func pageDidLoad(_ page: FolioReaderPage)
    
    /**
     Notifies that page receive tap gesture.
     
     - parameter recognizer: The tap recognizer
     */
    @objc optional func pageTap(_ recognizer: UITapGestureRecognizer)
}










open class FolioReaderPage: UICollectionViewCell {
    
    //MARK: - Internal properties
    weak var delegate: FolioReaderPageDelegate?
    weak var readerContainer: FolioReaderContainer?
    
    //MARK: - Public property
    /// The index of the current page. Note: The index start at 1!
    open var pageNumber: Int!
    open var webView: FolioReaderWKWebView?
    
    //MARK: - Private property
    fileprivate var colorView: UIView!
    fileprivate var shouldShowBar = true
    fileprivate var menuIsVisible = false
    
    private var lastTapLocation: CGPoint?
//    private var tapGesture: UITapGestureRecognizer?
    
    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }
    
    fileprivate var book: FRBook {
        guard let readerContainer = readerContainer else { return FRBook() }
        return readerContainer.book
    }
    
    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }
    
    //MARK: - Lifecycle
    public override init(frame: CGRect) {
        // Init explicit attributes with a default value. The `setup` function MUST be called to configure the current object with valid attributes.

        super.init(frame: frame)
        
        backgroundColor = .clear
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(refreshPageMode),
//                                               name: NSNotification.Name(rawValue: "needRefreshPageMode"),
//                                               object: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        webView?.setupScrollDirection()
        webView?.frame = bounds//webViewFrame()
        webView?.scrollView.contentInset = webViewContentInset()
    }
    
    // MARK: - UIMenu visibility
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        guard let webView = webView else { return false }

        webView.js("getSelectedText()"){selectedText in

            guard let selectedText = selectedText, selectedText.isNotEmpty else { return }

            let isOneWord = selectedText.components(separatedBy: " ").count == 1
            webView.createMenu(options: .cleanText(isOneWord: isOneWord))
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    // MARK: - Actions + ColorView fix for horizontal layout
//    @objc
//    func refreshPageMode() {
//
//        guard let webView = webView else { return }
//
//        if folioReader.nightMode {
//
//            // omit create webView and colorView
//            let script = "document.documentElement.offsetHeight"
//
//            webView.js(script) {[unowned self] contentHeight in
//
//                if let contentHeight = contentHeight {
//
////                    //FIXME: invalid page count (2)
//                    let frameHeight = webView.frame.height
//                    let lastPageHeight = frameHeight * CGFloat(2) - CGFloat(Double(contentHeight)!)
//
//                    colorView.frame = CGRect(x: webView.frame.width * CGFloat(2-1),
//                                             y: webView.frame.height - lastPageHeight,
//                                             width: webView.frame.width,
//                                             height: lastPageHeight)
//                }
//            }
//
//        } else {
//
//            colorView.frame = .zero
//        }
//    }
    
    
    
    //MARK: - Actions + UITapGestureRecognizer
    @objc
    private func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        
        delegate?.pageTap?(recognizer)
        webView?.setMenuVisible(false)
        lastTapLocation = recognizer.location(in: self)
        
//        if let navigation = folioReader.readerCenter?.navigationController, navigation.isNavigationBarHidden {
//
//            webView?.js("getSelectedText()"){[unowned self] selectedText in
//
//                guard selectedText == nil || selectedText!.isEmpty else { return }
//
//                DispatchQueue.main.async {[unowned self] in
//
//                    if shouldShowBar && !menuIsVisible {
//
//                        folioReader.readerCenter?.toggleBars()
//                    }
//                }
//            }
//
//        } else if readerConfig.shouldHideNavigationOnTap {
//
//            folioReader.readerCenter?.hideBars()
//            menuIsVisible = false
//        }
    }
    
    //MARK: - Public method
    func setup(withReaderContainer readerContainer: FolioReaderContainer) {
        
        self.readerContainer = readerContainer
        
        if webView == nil {
            
            webView = FolioReaderWKWebView(frame: bounds, readerContainer: readerContainer)//webViewFrame()
            webView!.scrollView.showsVerticalScrollIndicator = false
            webView!.scrollView.showsHorizontalScrollIndicator = false
            webView!.backgroundColor = .clear
            webView!.alpha = 0
            webView!.scrollView.backgroundColor = .clear
            
            if #available(iOS 11, *) {
                        
                webView!.scrollView.contentInsetAdjustmentBehavior = .never
            }
            contentView.addSubview(webView!)
        }
        webView!.setupScrollDirection()
        webView!.navigationDelegate = self
        
        // Remove all gestures before adding new one
        webView!.gestureRecognizers?.forEach { webView!.removeGestureRecognizer($0) }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_ :)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        
        webView!.addGestureRecognizer(tap)
    }
    
    //MARK: - Configure UI Cell
    func configureUI(resource: FRResource, baseURL: URL?) {
        
        guard let webView = webView,
                var html = try? String(contentsOfFile: resource.fullHref, encoding: .utf8) else { return }
        
        
        // epub with with incorrect <title/> field
        html = html.replacingOccurrences(of: "<title/>", with: "")
        
        let mediaOverlayStyleColors = "\"\(readerConfig.mediaOverlayColor.hexString(false))\", \"\(readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""

        // Inject CSS
        let jsFilePath = Bundle.frameworkBundle().path(forResource: "Bridge", ofType: "js")
        let cssFilePath = Bundle.frameworkBundle().path(forResource: "Style", ofType: "css")

        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        let jsTag = "<script type=\"application/javascript\" src=\"\(jsFilePath!)\"></script>" +
        "<script type=\"application/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>"

        let toInject = "\n\(cssTag)\n\(jsTag)\n</head>"
        html = html.replacingOccurrences(of: "</head>", with: toInject)

        // Font class name
        var classes = folioReader.currentFont.cssIdentifier
        classes += " " + folioReader.currentMediaOverlayStyle.className()

        // Night mode
        if folioReader.nightMode {

            classes += " nightMode"
        }

        // Font Size
        classes += " \(folioReader.currentFontSize.cssIdentifier)"

        html = html.replacingOccurrences(of: "<html ", with: "<html class=\"\(classes)\"")

        // Let the delegate adjust the html string
        if let modifiedHtmlContent = readerContainer?.centerViewController?.delegate?.htmlContentForPage?(self, htmlContent: html) {
            html = modifiedHtmlContent
        }
        
        if !webView.isLoading {
                    
            load(html: html, baseURL: baseURL)
        }
    }
    
    //MARK: - WebView Content Inset
    private func webViewContentInset() -> UIEdgeInsets {
        
        let topSafeAreaInset = readerContainer?.view.safeInsets.top ?? 0
        let bottomSafeAreaInset = readerContainer?.view.safeInsets.bottom ?? 0
        
        guard !readerConfig.hideBars else {
            
            return UIEdgeInsets(top: topSafeAreaInset, left: 1, bottom: bottomSafeAreaInset, right: 1)
        }
        
        let navBarHeight = folioReader.readerCenter?.navigationController?.navigationBar.frame.size.height ?? 0
        let topInset = readerConfig.shouldHideNavigationOnTap ? topSafeAreaInset : navBarHeight + topSafeAreaInset
        let bottomInset: CGFloat = 46 + bottomSafeAreaInset // height of page indicator+bottom inset
        
        return UIEdgeInsets(top: topInset, left: 1, bottom: bottomInset, right: 1)
         
    }
    
    //MARK: - Deinit
    deinit {
        
        webView?.scrollView.delegate = nil
        NotificationCenter.default.removeObserver(self)
    }
}

//MARK: - WKNavigationDelegate
extension FolioReaderPage: WKNavigationDelegate {
    
    /**
     Scheme type for correct behavior func
     'webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)'
     */
    private enum URLSchemeType: String {
        
        case highlight, highlightWithNote = "highlight-with-note"
        case playAudio = "play-audio"
        case file
        case mailto
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        guard let _ = webView as? FolioReaderWKWebView else { return }
        
        delegate?.pageWillLoad?(self)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        guard let webView = webView as? FolioReaderWKWebView else { return }
        
        // Add the custom class based onClick listener
        setupClassBasedOnClickListeners()
//        refreshPageMode()
        
        if readerConfig.enableTTS && !book.hasAudio {
            
            webView.js("wrappingSentencesWithinPTags()")
            
            if let audioPlayer = folioReader.readerAudioPlayer, audioPlayer.isPlaying() {
                
                audioPlayer.readCurrentSentence()
            }
        }
        
        let direction: ScrollDirection = folioReader.needsRTLChange ? .positive(withConfiguration: readerConfig) : .negative(withConfiguration: readerConfig)
        
        if folioReader.readerCenter?.pageScrollDirection == direction &&
            folioReader.readerCenter?.isScrolling == true &&
            readerConfig.scrollDirection != .horizontalWithVerticalContent {
            
            scrollPageToBottom()
        }
        
        UIView.animate(withDuration: 0.2, animations: {
            
            webView.alpha = 1
            
        }, completion: {[unowned self] _ in
        
            delegate?.pageDidLoad?(self)
        })
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let webView = webView as? FolioReaderWKWebView,
              let scheme = navigationAction.request.url?.scheme else {
            
            decisionHandler(.allow)
            return
        }
        
        let url = navigationAction.request.url!
        let schemeType = URLSchemeType(rawValue: scheme)
        
        if schemeType == .highlight || schemeType == .highlightWithNote {
            
            shouldShowBar = false
            
            guard let decoded = url.absoluteString.removingPercentEncoding else {
                
                decisionHandler(.cancel)
                return
            }
            let index = decoded.index(decoded.startIndex, offsetBy: 12)
            var rect = NSCoder.cgRect(for: String(decoded[index...]))
            
            if let origin = lastTapLocation {
                
                rect.origin = origin
                rect.size = CGSize(width: 1, height: 1)
            }
            
            webView.createMenu(options: .highlightMenu)
            webView.setMenuVisible(true, andRect: rect)
            
            menuIsVisible = true
            lastTapLocation = nil
            
            decisionHandler(.cancel)
            return
            
        } else if schemeType == .playAudio {
            
            guard let decoded = url.absoluteString.removingPercentEncoding else {
                
                decisionHandler(.cancel)
                return
            }
            
            let index = decoded.index(decoded.startIndex, offsetBy: 13)
            let playID = String(decoded[index...])
            let chapter = folioReader.readerCenter?.getCurrentChapter()
            let href = chapter?.href ?? ""
            
            folioReader.readerAudioPlayer?.playAudio(href, fragmentID: playID)
            
            decisionHandler(.cancel)
            return
            
        } else if schemeType == .file {
            
            let anchorFromURL = url.fragment
            
            // Handle internal url
            if !url.pathExtension.isEmpty {
                
                let pathComponent = book.opfResource.href?.deletingLastPathComponent
                
                guard let base = pathComponent == nil || pathComponent!.isEmpty ? book.name : pathComponent else {
                    
                    decisionHandler(.allow)
                    return
                }
                
                let path = url.path
                let splitedPath = path.components(separatedBy: base)
                
                // Return to avoid crash
                if splitedPath.count <= 1 || splitedPath[1].isEmpty {
                    
                    decisionHandler(.allow)
                    return
                }
                
                let href = splitedPath[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let hrefPage = (folioReader.readerCenter?.findPageByHref(href) ?? 0) + 1
                
                if hrefPage == pageNumber {
                    
                    // Handle internal #anchor
                    if anchorFromURL != nil {
                        
                        handleAnchor(anchorFromURL!, avoidBeginningAnchors: false)
                        decisionHandler(.cancel)
                        return
                    }
                    
                } else {
                    
                    folioReader.readerCenter?.changePageWith(href: href, animated: true)
                }
                decisionHandler(.cancel)
                return
            }
            
            // Handle internal #anchor
            if anchorFromURL != nil {
                
                handleAnchor(anchorFromURL!, avoidBeginningAnchors: false)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
            
        } else if schemeType == .mailto  {
            
            print("Email")
            decisionHandler(.allow)
            return
            
        } else if url.absoluteString != "about:blank" &&
                    scheme.contains("http") &&
                    navigationAction.navigationType == .linkActivated {
            
            let safariVC = SFSafariViewController(url: navigationAction.request.url!)
            safariVC.view.tintColor = readerConfig.tintColor
            
            folioReader.readerCenter?.present(safariVC, animated: true)
            
            decisionHandler(.cancel)
            return
            
        } else {
            
            // Check if the url is a custom class based onClick listerner
            var isClassBasedOnClickListenerScheme = false
            
            for listener in readerConfig.classBasedOnClickListeners {
                
                if scheme == listener.schemeName,
                   let absoluteURLString = navigationAction.request.url?.absoluteString,
                   let range = absoluteURLString.range(of: "/clientX=") {
                    
                    let baseURL = String(absoluteURLString[..<range.lowerBound])
                    let positionString = String(absoluteURLString[range.lowerBound...])
                    
                    if let point = getEventTouchPoint(fromPositionParameterString: positionString) {
                        
                        let attributeContentString = (baseURL.replacingOccurrences(of: "\(scheme)://", with: "").removingPercentEncoding)
                        // Call the on click action block
                        listener.onClickAction(attributeContentString, point)
                        // Mark the scheme as class based click listener scheme
                        isClassBasedOnClickListenerScheme = true
                    }
                }
            }
            
            if isClassBasedOnClickListenerScheme == false {
                // Try to open the url with the system if it wasn't a custom class based click listener
                if UIApplication.shared.canOpenURL(url) {
                    
                    UIApplication.shared.openURL(url)
                    decisionHandler(.cancel)
                    return
                }
                
            } else {
                
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
        return
    }
}
//MARK: - UIGestureRecognizerDelegate
extension FolioReaderPage: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        true
    }
}

// MARK: - Internal Helpers
extension FolioReaderPage {
    
    // MARK: - Mark ID
    
    /**
     Audio Mark ID - marks an element with an ID with the given class and scrolls to it
     
     - parameter identifier: The identifier
     */
    func audioMarkID(_ identifier: String) {
        
        guard let currentPage = folioReader.readerCenter?.currentPage else { return }
        
        let script = "audioMarkID('\(book.playbackActiveClass)','\(identifier)')"
        currentPage.webView?.js(script)
    }
}

// MARK: - Public Helpers
public extension FolioReaderPage {
    
    // MARK: - Public scroll postion setter
    /**
     Scrolls the page to a given offset
     
     - parameter offset:   The offset to scroll
     - parameter animated: Enable or not scrolling animation
     */
    func scrollPageToOffset(_ offset: CGFloat, animated: Bool) {
        
        let pageOffsetPoint = readerConfig.isDirection(CGPoint(x: 0, y: offset),
                                                       CGPoint(x: offset, y: 0),
                                                       CGPoint(x: 0, y: offset))
        webView?.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
    }
    
    /**
     Scrolls the page to bottom
     */
    func scrollPageToBottom() {
        
        guard let webView = webView else { return }
        
        let bottomOffset = readerConfig.isDirection(
            CGPoint(x: 0, y: webView.scrollView.contentSize.height - webView.scrollView.frame.height),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.frame.width, y: 0),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.frame.width, y: 0)
        )
        
        if bottomOffset.forDirection(withConfiguration: readerConfig) >= 0 {
            
            webView.scrollView.setContentOffset(bottomOffset, animated: false)
        }
    }
    
    /**
     Handdle #anchors in html, get the offset and scroll to it
     
     - parameter anchor:                The #anchor
     - parameter avoidBeginningAnchors: Sometimes the anchor is on the beggining of the text, there is not need to scroll
     - parameter animated:              Enable or not scrolling animation
     */
    func handleAnchor(_ anchor: String, avoidBeginningAnchors: Bool, animated: Bool = true) {
        
        if anchor.isNotEmpty {
            
            let offset = getAnchorOffset(anchor)
            
            switch readerConfig.scrollDirection {
                
                case .vertical, .defaultVertical:
                    
                    let isBeginning = (offset < frame.forDirection(withConfiguration: readerConfig) * 0.5)
                    
                    if !avoidBeginningAnchors {
                        
                        scrollPageToOffset(offset, animated: animated)
                        
                    } else if avoidBeginningAnchors && !isBeginning {
                        
                        scrollPageToOffset(offset, animated: animated)
                    }
                    
                case .horizontal, .horizontalWithVerticalContent:
                    
                    scrollPageToOffset(offset, animated: animated)
            }
        }
    }
}
// MARK: - Private Helpers
private extension FolioReaderPage {
    
    /**
     Get the #anchor offset in the page
     
     - parameter anchor: The #anchor id
     - returns: The element offset ready to scroll
     */
    func getAnchorOffset(_ anchor: String) -> CGFloat {
        
        let isHorizontal = readerConfig.scrollDirection == .horizontal
        let script = "getAnchorOffset('\(anchor)', \(isHorizontal.description))"
        var offset: CGFloat = 0
        
        webView?.js(script){ offsetString in
            
            if let offsetString = offsetString {
                
                offset = CGFloat((offsetString as NSString).floatValue)
            }
        }
        return offset
    }
    
    /**
     Load html content
     
     - parameter content: HTML
     - parameter baseURL: url file
     */
    
    private func load(html content: String!, baseURL: URL!) {
        
        guard webView != nil else { return }
        // Insert the stored highlights to the HTML
        let html = htmlContentWithInsertHighlights(content)
        
        let source: String = "var meta = document.createElement('meta');" +
            "meta.name = 'viewport';" +
            "meta.content = 'maximum-scale=1.0, user-scalable=no';" + //initial-scale=1.0,  width=device-width,
            "var head = document.getElementsByTagName('head')[0];" +
            "head.appendChild(meta);"
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView!.configuration.userContentController.addUserScript(userScript)
        
        // Load the html into the webview
        webView!.loadFileURL(baseURL, allowingReadAccessTo: baseURL)
        webView!.loadHTMLString(html, baseURL: baseURL)
    }
    
    /**
     HTML content with highlights
     */
    
    private func htmlContentWithInsertHighlights(_ htmlContent: String) -> String {
        
        // Restore highlights
        guard let bookId = book.name?.deletingPathExtension else { return htmlContent }
        
        var tempHtmlContent = htmlContent as NSString
        let highlights = Highlight.allByBookId(withConfiguration: readerConfig,
                                               bookId: bookId,
                                               andPage: pageNumber as NSNumber?)
        
        if highlights.count > 0 {
            
            for highlight in highlights {
                
                let style = HighlightStyle.classForStyle(highlight.type)
                var tag = ""
                
                if let _ = highlight.noteForHighlight {
                    
                    tag = "<highlight id=\"\(highlight.highlightId!)\" onclick=\"callHighlightWithNoteURL(this);\" class=\"\(style)\">\(highlight.content!)</highlight>"
                    
                } else {
                    
                    tag = "<highlight id=\"\(highlight.highlightId!)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(highlight.content!)</highlight>"
                }
                
                var locator = highlight.contentPre + highlight.content
                locator += highlight.contentPost
                locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
                
                let range: NSRange = tempHtmlContent.range(of: locator, options: .literal)
                
                if range.location != NSNotFound {
                    
                    let newRange = NSRange(location: range.location + highlight.contentPre.count,
                                           length: highlight.content.count)
                    tempHtmlContent = tempHtmlContent.replacingCharacters(in: newRange, with: tag) as NSString
                    
                } else {
                    
                    print("highlight range not found")
                }
            }
        }
        return tempHtmlContent as String
    }
    
    /**
     Get Event Touch Point
     */
    
    private func getEventTouchPoint(fromPositionParameterString positionParameterString: String) -> CGPoint? {
        
        // Remove the parameter names: "/clientX=188&clientY=292" -> "188&292"
        var positionParameterString = positionParameterString.replacingOccurrences(of: "/clientX=", with: "")
        positionParameterString = positionParameterString.replacingOccurrences(of: "clientY=", with: "")
        // Separate both position values into an array: "188&292" -> [188],[292]
        let positionStringValues = positionParameterString.components(separatedBy: "&")
        // Multiply the raw positions with the screen scale and return them as CGPoint
        
        if positionStringValues.count == 2,
           let xPos = Int(positionStringValues[0]),
           let yPos = Int(positionStringValues[1]) {
            
            return CGPoint(x: xPos, y: yPos)
        }
        return nil
    }
    
    private func setupClassBasedOnClickListeners() {
        
        for listener in readerConfig.classBasedOnClickListeners {
            
            webView?.js("addClassBasedOnClickListener(\"\(listener.schemeName)\", \"\(listener.querySelector)\", \"\(listener.attributeName)\", \"\(listener.selectAll)\")")
        }
    }
}

