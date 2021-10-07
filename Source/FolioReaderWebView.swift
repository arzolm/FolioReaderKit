//
//  FolioReaderWebView.swift
//  FolioReaderKit
//
//  Created by Hans Seiffert on 21.09.16.
//  Copyright (c) 2016 Folio Reader. All rights reserved.
//

import UIKit
import WebKit

/// The custom WebView used in each page
open class FolioReaderWKWebView: WKWebView {
    
    enum MenuOptions: Equatable {
        
        case colorsMenu,
             highlightMenu,
             cleanText(isOneWord: Bool = false)
    }
    
    //MARK: - Private property
    private weak var readerContainer: FolioReaderContainer?
    private var currentMenuOption: MenuOptions?
    private var readerConfig: FolioReaderConfig {
        
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        
        return readerContainer.readerConfig
    }
    
    private var book: FRBook {
        
        guard let readerContainer = readerContainer else { return FRBook() }
        
        return readerContainer.book
    }
    
    private var folioReader: FolioReader {
        
        guard let readerContainer = readerContainer else { return FolioReader() }
        
        return readerContainer.folioReader
    }
    
    //MARK: - Lifecycle
    init(frame: CGRect, readerContainer: FolioReaderContainer) {
        
        self.readerContainer = readerContainer

        super.init(frame: frame, configuration: WKWebViewConfiguration())
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        fatalError("use init(frame:readerConfig:book:) instead.")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIMenuController
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        guard readerConfig.useReaderMenuController else {
            
            return super.canPerformAction(action, withSender: sender)
        }
        
        if action == #selector(highlight)
            || action == #selector(highlightWithNote)
            || action == #selector(updateHighlightNote)
            || action == #selector(copy(_:)) && currentMenuOption != MenuOptions.colorsMenu && currentMenuOption != MenuOptions.highlightMenu {
            
            //|| action == #selector(define)
            //|| action == #selector(play) && (book.hasAudio || readerConfig.enableTTS)
            //|| action == #selector(share) && readerConfig.allowSharing
            //|| action == #selector(copy(_:)) && readerConfig.allowSharing
            return true
        }
        return false
    }
    
    // MARK: - UIMenuController - Actions
//    @objc
//    private func share(_ sender: UIMenuController) {
//
//        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
//
//        let shareImage = UIAlertAction(title: readerConfig.localizedShareImageQuote, style: .default, handler: {[unowned self] action in
//
//            let finished: (String?) -> Void = {[unowned self] textToShare in
//
//                if let textToShare = textToShare {
//
//                    folioReader.readerCenter?.presentQuoteShare(textToShare)
//                    !isShare ? clearTextSelection() : ()
//                }
//                setMenuVisible(false)
//            }
//
//            if isShare {
//
//                js("getHighlightContent()", finished: finished)
//
//            } else {
//
//                js("getSelectedText()", finished: finished)
//            }
//        })
//
//        let shareText = UIAlertAction(title: self.readerConfig.localizedShareTextQuote, style: .default) {[unowned self] (action) -> Void in
//
//            let finished: (String?) -> Void = {[unowned self] textToShare in
//
//                if let textToShare = textToShare {
//
//                    folioReader.readerCenter?.shareHighlight(textToShare, rect: sender.menuFrame)
//                }
//                setMenuVisible(false)
//            }
//
//            if isShare {
//
//                js("getHighlightContent()", finished: finished)
//
//            } else {
//
//                js("getSelectedText()", finished: finished)
//            }
//        }
//
//        let cancel = UIAlertAction(title: self.readerConfig.localizedCancel, style: .cancel)
//
//        alertController.addAction(shareImage)
//        alertController.addAction(shareText)
//        alertController.addAction(cancel)
//
//        if let alert = alertController.popoverPresentationController {
//
//            alert.sourceView = folioReader.readerCenter?.currentPage
//            alert.sourceRect = sender.menuFrame
//        }
//
//        folioReader.readerCenter?.present(alertController, animated: true, completion: nil)
//    }
    
    @objc
    private func highlight(_ sender: UIMenuController) {
        
        let script = "highlightString('\(HighlightStyle.classForStyle(folioReader.currentHighlightStyle))')"
        
        js(script){[unowned self] json in
            
            if let dictionary = parse(json: json) {
                
//                var rect = NSCoder.cgRect(for: dictionary["rect"]!)
//                rect = sender.menuFrame
//                rect.origin = CGPoint(x: 0, y: readerContainer?.view.safeInsets.top ?? 0)
                
                setMenuVisible(false)
                createMenu(options: .highlightMenu)
                setMenuVisible(true, andRect: sender.menuFrame)
                
                js("getHTML()"){[unowned self] html in
                    
                    let startOffset = dictionary["startOffset"]!
                    let endOffset = dictionary["endOffset"]!
                    let identifier = dictionary["id"]!
                    
                    // Persist
                    guard let html = html,
                          let bookId = (book.name as NSString?)?.deletingPathExtension else { return }
                    
                    let pageNumber = folioReader.readerCenter?.currentPageNumber ?? 0
                    let match = Highlight.MatchingHighlight(text: html,
                                                            id: identifier,
                                                            startOffset: startOffset,
                                                            endOffset: endOffset,
                                                            bookId: bookId,
                                                            currentPage: pageNumber)
                    
                    let highlight = Highlight.matchHighlight(match)
                    highlight?.persist(withConfiguration: readerConfig)
                }
                
            } else {
                
                print("Could not receive JSON")
            }
        }
    }
    
    @objc
    private func highlightWithNote(_ sender: UIMenuController?) {
        
        let script = "highlightStringWithNote('\(HighlightStyle.classForStyle(folioReader.currentHighlightStyle))')"
        
        js(script){[unowned self] json in
            
            if let dictionary = parse(json: json) {
                
                let startOffset = dictionary["startOffset"]!
                let endOffset = dictionary["endOffset"]!
                let identifier = dictionary["id"]!
                
                clearTextSelection()
                
                js("getHTML()"){[unowned self] html in
                    
                    guard let html = html,
                          let bookId = (book.name as NSString?)?.deletingPathExtension else { return }
                    
                    let pageNumber = folioReader.readerCenter?.currentPageNumber ?? 0
                    let match = Highlight.MatchingHighlight(text: html,
                                                            id: identifier,
                                                            startOffset: startOffset,
                                                            endOffset: endOffset,
                                                            bookId: bookId,
                                                            currentPage: pageNumber)
                    
                    if let highlight = Highlight.matchHighlight(match) {
                        
                        folioReader.readerCenter?.presentAddHighlightNote(highlight, edit: false)
                    }
                }
            }
        }
    }
    
    @objc
    private func updateHighlightNote(_ sender: UIMenuController?) {
        
        js("getHighlightId()"){[unowned self] highlightId in
            
            guard let highlightId = highlightId,
                  let highlightNote = Highlight.getById(withConfiguration: readerConfig, highlightId: highlightId) else { return }
            
            folioReader.readerCenter?.presentAddHighlightNote(highlightNote, edit: true)
        }
    }
    
    @objc
    private func define(_ sender: UIMenuController?) {
        
        guard let readerContainer = readerContainer else { return }
        
        js("getSelectedText()"){[unowned self] selectedText in
            
            guard let selectedText = selectedText else { return }
            
            setMenuVisible(false)
            clearTextSelection()
            
            let referenceLibraryViewController = UIReferenceLibraryViewController(term: selectedText)
            referenceLibraryViewController.view.tintColor = readerConfig.tintColor
            readerContainer.show(referenceLibraryViewController, sender: nil)
        }
    }
    
    @objc
    private func play(_ sender: UIMenuController?) {
        
        folioReader.readerAudioPlayer?.play()
        clearTextSelection()
    }
    
    // MARK: - Create menu
    func createMenu(options: MenuOptions) {
        
        guard readerConfig.useReaderMenuController else { return }
        
        let menuController = UIMenuController.shared
        menuController.menuItems = []
        
        switch options {
                
            case .colorsMenu:
                
                let yellow = UIImage(readerImageNamed: "yellow-marker")
                let green = UIImage(readerImageNamed: "green-marker")
                let blue = UIImage(readerImageNamed: "blue-marker")
                let pink = UIImage(readerImageNamed: "pink-marker")
                let underline = UIImage(readerImageNamed: "underline-marker")
                
                menuController.menuItems = [
                    
                    UIMenuItem(title: "Y", image: yellow) {[weak self] _ in self?.setYellow(menuController)},
                    UIMenuItem(title: "G", image: green) {[weak self] _ in self?.setGreen(menuController)},
                    UIMenuItem(title: "B", image: blue) {[weak self] _ in self?.setBlue(menuController)},
                    UIMenuItem(title: "P", image: pink) {[weak self] _ in self?.setPink(menuController)},
                    UIMenuItem(title: "U", image: underline) { [weak self] _ in self?.setUnderline(menuController)}
                ]
                
            case .highlightMenu:
                
                let colors = UIImage(readerImageNamed: "colors-marker")
                let remove = UIImage(readerImageNamed: "no-marker")
                
                menuController.menuItems = [
                    
                    UIMenuItem(title: "C", image: colors) {[weak self] _ in self?.colorsMenu(menuController) },
                    UIMenuItem(title: readerConfig.localizedHighlightNote, action: #selector(updateHighlightNote)),
                    UIMenuItem(title: "R", image: remove) {[weak self] _ in self?.removeHighlight(menuController) }
                    
                ]
                
            case .cleanText(_): //isOneWord
                
                let menuItems: [UIMenuItem] = [
                    
                    UIMenuItem(title: readerConfig.localizedHighlightMenu, action: #selector(highlight)),
                    UIMenuItem(title: readerConfig.localizedHighlightNote, action: #selector(highlightWithNote))
                ]
                
//                if isOneWord {
//
//                    menuItems.insert(UIMenuItem(title: readerConfig.localizedDefineMenu, action: #selector(define)), at: 1)
//                }
                menuController.menuItems = menuItems
                
        }
        currentMenuOption = options
    }
    
    //MARK: - Show Menu
    func setMenuVisible(_ isMenuVisible: Bool, animated: Bool = true, andRect rect: CGRect = .zero) {
        
        let menuController = UIMenuController.shared
        
        if #available(iOS 13, *) {
            
            if isMenuVisible && !rect.equalTo(.zero) {
                
                menuController.showMenu(from: self, rect: rect)
                
            } else {
                
                menuController.hideMenu(from: self)
            }
            
        } else {
            
            if isMenuVisible && !rect.equalTo(.zero) {
                
                menuController.setTargetRect(rect, in: self)
            }
            menuController.setMenuVisible(isMenuVisible, animated: animated)
        }
    }
    
    // MARK: - WebView
    func setupScrollDirection() {
        
        switch readerConfig.scrollDirection {
                
            case .vertical, .defaultVertical, .horizontalWithVerticalContent:
                
                scrollView.isPagingEnabled = false
                
            case .horizontal:
                
                scrollView.isPagingEnabled = true
        }
        scrollView.bounces = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
    }
    
    //MARK: - Private general methods
    private func clearTextSelection() {
        // Forces text selection clearing
        // @NOTE: this doesn't seem to always work
        
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        
//        js("window.getSelection().removeAllRanges();")
    }
    
    private func colorsMenu(_ sender: UIMenuController) {
        
        setMenuVisible(false)
        createMenu(options: .colorsMenu)
        setMenuVisible(true, andRect: sender.menuFrame)
    }
    
    private func removeHighlight(_ sender: UIMenuController?) {
        
        js("removeThisHighlight()"){[unowned self] result in
            
            if let removedId = result {
                
                Highlight.removeById(withConfiguration: self.readerConfig, highlightId: removedId)
            }
            setMenuVisible(false)
        }
    }
    
    private func setYellow(_ sender: UIMenuController?) {
        
        changeHighlightStyle(sender, style: .yellow)
    }
    
    private func setGreen(_ sender: UIMenuController?) {
        
        changeHighlightStyle(sender, style: .green)
    }
    
    private func setBlue(_ sender: UIMenuController?) {
        
        changeHighlightStyle(sender, style: .blue)
    }
    
    private func setPink(_ sender: UIMenuController?) {
        
        changeHighlightStyle(sender, style: .pink)
    }
    
    private func setUnderline(_ sender: UIMenuController?) {
        
        changeHighlightStyle(sender, style: .underline)
    }
    
    private func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        
        let script = "setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')"
        
        folioReader.currentHighlightStyle = style.rawValue
        js(script){[unowned self] updateId in
            
            if let updateId = updateId {
                
                Highlight.updateById(withConfiguration: readerConfig, highlightId: updateId, type: style)
            }
            //FIXME: https://github.com/FolioReader/FolioReaderKit/issues/316
            setMenuVisible(false)
        }
    }
}
//MARK: - Internal Helpers
extension FolioReaderWKWebView {
    
    // MARK: - Public Java Script injection
    
    /**
     Runs a JavaScript script and returns it result. The result of running the JavaScript script passed in the script parameter, or nil if the script fails.
     
     - completion: The result of running the JavaScript script passed in the script parameter, or nil if the script fails.
     */
    func js(_ script: String, finished: ((String?) -> Void)? = nil) {
        
        evaluate(script: script) { string, error in
            
            if let string = string as? String, string.isNotEmpty {
                
                finished?(string)
                
            } else {
                
                finished?(nil)
            }
        }
    }
}
//MARK: - Private Helpers
private extension FolioReaderWKWebView {
    
    /**
     Parse JSON from string with encoding format .utf8
     */
    func parse(json: String?) -> [String: String]? {
        
        if let string = json, string.isNotEmpty,
           let data = string.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let jsonDict = (jsonObject as? [[String: String]])?.first,
           let _ = jsonDict["rect"],
           let _ = jsonDict["id"],
           let _ = jsonDict["startOffset"],
           let _ = jsonDict["endOffset"] {
            
            return jsonDict
        }
        return nil
    }
}
