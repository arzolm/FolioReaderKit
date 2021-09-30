//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import ZFDragableModalTransition
import WebKit

/// Protocol which is used from `FolioReaderCenter`s.
@objc public protocol FolioReaderCenterDelegate: class {

    /// Notifies that a page appeared. This is triggered when a page is chosen and displayed.
    ///
    /// - Parameter page: The appeared page
    @objc optional func pageDidAppear(_ page: FolioReaderPage)

    /// Passes and returns the HTML content as `String`. Implement this method if you want to modify the HTML content of a `FolioReaderPage`.
    ///
    /// - Parameters:
    ///   - page: The `FolioReaderPage`.
    ///   - htmlContent: The current HTML content as `String`.
    /// - Returns: The adjusted HTML content as `String`. This is the content which will be loaded into the given `FolioReaderPage`.
    @objc optional func htmlContentForPage(_ page: FolioReaderPage, htmlContent: String) -> String
    
    /// Notifies that a page changed. This is triggered when collection view cell is changed.
    ///
    /// - Parameter pageNumber: The appeared page item
    @objc optional func pageItemChanged(_ pageNumber: Int)

}






/// The base reader class
open class FolioReaderCenter: UIViewController {

    //MARK: - Public property
    
    /// This delegate receives the events from the current `FolioReaderPage`s delegate.
    open weak var delegate: FolioReaderCenterDelegate?

    /// This delegate receives the events from current page
    open weak var pageDelegate: FolioReaderPageDelegate?

    /// The base reader container
    open weak var readerContainer: FolioReaderContainer?

    /// The current visible page on reader
    open private(set) var currentPage: FolioReaderPage?

    /// The collection view with pages
    open var collectionView: UICollectionView!
    
    //MARK: - Internal properties
    let collectionViewLayout = UICollectionViewFlowLayout()
    
    var loadingView: UIActivityIndicatorView!
    
    var tempFragment: String?
    
    var animator: ZFModalTransitionAnimator!
    
    var pageIndicatorView: FolioReaderPageIndicator?
    var pageIndicatorHeight: CGFloat = 46
    
    var recentlyScrolled = false
    var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
    var recentlyScrolledTimer: Timer!
    
//    var scrollScrubber: ScrollScrubber?
    
    var activityIndicator = UIActivityIndicatorView()
    
    var isScrolling = false
    
    var pageScrollDirection = ScrollDirection()
    
    var pages: [String]!
    var totalPages: Int = 0
    var nextPageNumber: Int = 0
    var previousPageNumber: Int = 0
    var currentPageNumber: Int = 0
    
    var pageWidth: CGFloat = 0
    var pageHeight: CGFloat = 0

    //MARK: - Private property
    fileprivate var screenBounds: CGRect{ UIScreen.main.bounds }
    fileprivate var pointNow = CGPoint.zero
    fileprivate var pageOffsetRate: CGFloat = 0
    fileprivate var tempReference: FRTocReference?
    fileprivate var isFirstLoad = true
    fileprivate var currentWebViewScrollPositions = [Int: CGPoint]()
    fileprivate var currentOrientation: UIDeviceOrientation?
    

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

    // MARK: - Init

    init(withContainer readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())

        self.initialization()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("This class doesn't support NSCoding.")
    }

    //MARK: - Lifecycle
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = folioReader.isNight(readerConfig.nightModeBackground, UIColor.white)
        
        extendedLayoutIncludesOpaqueBars = true

        // Layout
        collectionViewLayout.sectionInset = .zero
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .direction(withConfiguration: readerConfig)
        
        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: collectionViewLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = view.backgroundColor
        collectionView.decelerationRate = .fast
        collectionView?.register(FolioReaderPage.self, forCellWithReuseIdentifier: kReuseCellIdentifier) // Register cell classes
        enableScrollBetweenChapters(scrollEnabled: true)
        
        if #available(iOS 11, *) {
                    
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        
        if #available(iOS 10, *) {
            
            collectionView.isPrefetchingEnabled = false
        }
        view.addSubview(collectionView)
        
        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: screenBounds.size.width/2,
                                                                  y: screenBounds.size.height/2,
                                                                  width: 30,
                                                                  height: 30))
        activityIndicator.style = .gray
        activityIndicator.hidesWhenStopped = true
        activityIndicator.backgroundColor = UIColor.gray
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(activityIndicator)

        // Page indicator view
        if !readerConfig.hidePageIndicator {
            
            pageIndicatorView = FolioReaderPageIndicator(frame: frameForPageIndicatorView(),
                                                         readerConfig: readerConfig,
                                                         folioReader: folioReader)
            
            view.addSubview(pageIndicatorView!)
        }

//        if let readerContainer = readerContainer {
                    
//            scrollScrubber = ScrollScrubber(frame: frameForScrollScrubber(),
//                                            withReaderContainer: readerContainer)
//            scrollScrubber!.delegate = self
//
//            view.addSubview(scrollSc rubber!.slider)
//        }
        
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        //set center for loading view
        loadingView.center = view.center
        
        //update page indicator frame
        pageIndicatorView?.frame = frameForPageIndicatorView()
        
        //set page size 'height or width' it depends for
        setPageSize()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureNavigationBar()
        
        // Update count of pages
        pagesForCurrentPage(currentPage)
        
        //update page indicator colors
        pageIndicatorView?.reloadView(updateShadow: true)
    }
    
    // MARK: - Device rotation
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        //aka willRotate
        print("start",#function)
        guard folioReader.isReaderReady else { return }

        setPageSize()
        updateCurrentPage()

        if currentOrientation == nil || currentOrientation?.isPortrait != UIDevice.current.orientation.isPortrait {

            collectionView.collectionViewLayout.invalidateLayout()

            UIView.animate(withDuration: 0.1) {[unowned self] in
                
                // Adjust page indicator view
                pageIndicatorView?.reloadView(updateShadow: true)

                // Adjust collectionView
                collectionView.contentSize = readerConfig.isDirection( CGSize(width: pageWidth, height: pageHeight * CGFloat(totalPages)),
                                                                       CGSize(width: pageWidth * CGFloat(totalPages), height: pageHeight),
                                                                       CGSize(width: pageWidth * CGFloat(totalPages), height: pageHeight))
                collectionView.setContentOffset(frameForPage(currentPageNumber).origin, animated: false)
                collectionView.collectionViewLayout.invalidateLayout()

                // Adjust internal page offset
                updatePageOffsetRate()
            }
        }

        currentOrientation = UIDevice.current.orientation
        
        coordinator.animate {[unowned self] _ in
            
            //aka willAnimateRotation
            print("animation",#function)
            
            guard folioReader.isReaderReady else { return }
            
            collectionView.scrollToItem(at: IndexPath(row: currentPageNumber - 1, section: 0), at: UICollectionView.ScrollPosition(), animated: false)
            
            if currentPageNumber + 1 >= totalPages {
                
                collectionView.setContentOffset(frameForPage(currentPageNumber).origin, animated: false)
            }
            
        } completion: {[unowned self] _ in
            
            //ala didRotate
            print("finished",#function)
            
            guard folioReader.isReaderReady, let currentPage = currentPage else { return }
            
            // Update pages
            pagesForCurrentPage(currentPage)

            // After rotation fix internal page offset
            var pageOffset = (currentPage.webView?.scrollView.contentSize.forDirection(withConfiguration: readerConfig) ?? 0) * pageOffsetRate

            // Fix the offset for paged scroll
            if readerConfig.scrollDirection == .horizontal && pageWidth != 0 {
                
                let page = round(pageOffset / pageWidth)
                pageOffset = page * pageWidth
            }
            let pageOffsetPoint = readerConfig.isDirection(CGPoint(x: 0, y: pageOffset), CGPoint(x: pageOffset, y: 0), CGPoint(x: 0, y: pageOffset))
            currentPage.webView?.scrollView.setContentOffset(pageOffsetPoint, animated: true)
        }
    }
    
    //MARK: - Public method
    func configureNavigationBar() {
        
        let navBackground = folioReader.isNight(readerConfig.nightModeNavBackground, readerConfig.daysModeNavBackground)
        let tintColor = readerConfig.tintColor
        let navText = folioReader.isNight(UIColor.white, UIColor.black)
        let font = UIFont(name: "Avenir-Light", size: 17)!
        
        setTranslucentNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
    }

    func reloadData() {
        
        loadingView.stopAnimating()
        //This is all book pages
        totalPages = book.spine.spineReferences.count
        //---
        collectionView.reloadData()
        configureNavBarButtons()
        setCollectionViewProgressiveDirection()

        if readerConfig.loadSavedPositionForCurrentBook {
            
            guard let position = folioReader.savedPositionForCurrentBook,
                  let pageNumber = position["pageNumber"] as? Int,
                  pageNumber > 0 else {
                      
                      currentPageNumber = 1
                      return
                  }
            changePageWith(page: pageNumber)
            currentPageNumber = pageNumber
        }
    }
    
    func setScrollDirection(_ direction: FolioReaderScrollDirection) {
        
        guard let currentPage = currentPage,
              let webView = currentPage.webView else { return }
        
        
        
        // Get internal page offset before layout change
        updatePageOffsetRate()
        // Change layout
        readerConfig.scrollDirection = direction
        collectionViewLayout.scrollDirection = .direction(withConfiguration: readerConfig)
        currentPage.setNeedsLayout()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setContentOffset(frameForPage(currentPageNumber).origin, animated: false)

        // Page progressive direction
        setCollectionViewProgressiveDirection()
        delay(0.2) {[weak self] in self?.setPageProgressiveDirection(currentPage) }


        /**
         *  This delay is needed because the page will not be ready yet
         *  so the delay wait until layout finished the changes.
         */
        delay(0.1) {[weak self] in
            
            guard let self = self else { return }
            
            let pageScrollView = webView.scrollView
            var pageOffset = (pageScrollView.contentSize.forDirection(withConfiguration: self.readerConfig) * self.pageOffsetRate)

            // Fix the offset for paged scroll
            if self.readerConfig.scrollDirection == .horizontal && self.pageWidth > 0 {
                
                let page = round(pageOffset / self.pageWidth)
                pageOffset = (page * self.pageWidth)
            }

            let pageOffsetPoint = self.readerConfig.isDirection(CGPoint(x: 0, y: pageOffset),
                                                           CGPoint(x: pageOffset, y: 0),
                                                           CGPoint(x: 0, y: pageOffset))
            
            pageScrollView.setContentOffset(pageOffsetPoint, animated: true)
        }
    }
    
    // MARK: - Status bar and Navigation bar
    func hideBars() {
        
        guard readerConfig.shouldHideNavigationOnTap else { return }

        updateBarsStatus(true)
    }

    func showBars() {
        
        configureNavigationBar()
        updateBarsStatus(false)
    }

    func toggleBars() {
        
        guard readerConfig.shouldHideNavigationOnTap,
              let isNavigationBarHidden = navigationController?.isNavigationBarHidden else { return }
        
        if !isNavigationBarHidden {
            
            configureNavigationBar()
        }
        updateBarsStatus(isNavigationBarHidden)
    }

    // MARK: - Layout

    /**
     Enable or disable the scrolling between chapters (`FolioReaderPage`s). If this is enabled it's only possible to read the current chapter. If another chapter should be displayed is has to be triggered programmatically with `changePageWith`.

     - parameter scrollEnabled: `Bool` which enables or disables the scrolling between `FolioReaderPage`s.
     */
    open func enableScrollBetweenChapters(scrollEnabled: Bool) {
        
        collectionView.isScrollEnabled = scrollEnabled
    }
    
    //MARK: - Private methods
//    private func updateSubviewFrames() {
        
//        pageIndicatorView?.frame = frameForPageIndicatorView()
//        scrollScrubber?.frame = frameForScrollScrubber()
//    }

    private func frameForPageIndicatorView() -> CGRect {
        
        CGRect(x: 0,
               y: screenBounds.height-pageIndicatorHeight-view.safeInsets.bottom,
               width: screenBounds.width,
               height: pageIndicatorHeight+view.safeInsets.bottom) // view.safeAreaInsets.bottom for fill safe area
    }

    private func frameForScrollScrubber() -> CGRect {
        
        let statusBarHeight = UIApplication.shared.statusBarFrame.height == 0 ? 47 : UIApplication.shared.statusBarFrame.height
        let navigationBarHeight = navigationController?.navigationBar.frame.height ?? 0
        let topInset = statusBarHeight + navigationBarHeight + 5//5 is sugar
        let y = readerConfig.shouldHideNavigationOnTap || readerConfig.hideBars ? statusBarHeight : topInset
        
        return CGRect(x: screenBounds.width,
                      y: y,
                      width: 15,
                      height: (pageHeight - topInset - pageIndicatorHeight))
    }
    
    private func configureNavBarButtons() {
        
        // Navbar buttons
        let shareIcon = UIImage(readerImageNamed: "icon-navbar-share")?.ignoreSystemTint(withConfiguration: readerConfig)
        let audioIcon = UIImage(readerImageNamed: "icon-navbar-tts")?.ignoreSystemTint(withConfiguration: readerConfig) //man-speech-icon
        let closeIcon = UIImage(readerImageNamed: "icon-navbar-close")?.ignoreSystemTint(withConfiguration: readerConfig)
        let tocIcon = UIImage(readerImageNamed: "icon-navbar-toc")?.ignoreSystemTint(withConfiguration: readerConfig)
        let fontIcon = UIImage(readerImageNamed: "icon-navbar-font")?.ignoreSystemTint(withConfiguration: readerConfig)
        let space: CGFloat = 70

        let menu = UIBarButtonItem(image: closeIcon, style: .plain, target: self, action:#selector(closeReader(_:)))
        let toc = UIBarButtonItem(image: tocIcon, style: .plain, target: self, action:#selector(presentChapterList(_:)))

        navigationItem.leftBarButtonItems = [menu, toc]

        var rightBarIcons = [UIBarButtonItem]()

        if readerConfig.allowSharing {
            
            rightBarIcons.append(UIBarButtonItem(image: shareIcon, style: .plain, target: self, action: #selector(shareChapter(_:))))
        }

        if book.hasAudio || readerConfig.enableTTS {
            
            rightBarIcons.append(UIBarButtonItem(image: audioIcon, style: .plain, target: self, action:#selector(presentPlayerMenu(_:))))
        }

        let font = UIBarButtonItem(image: fontIcon, style: .plain, target: self, action: #selector(presentFontsMenu))
        font.width = space

        rightBarIcons.append(contentsOf: [font])
        navigationItem.rightBarButtonItems = rightBarIcons
        
        if readerConfig.displayTitle {
            
            navigationItem.title = book.title
        }
    }

    /**
     Common Initialization
     */
    private func initialization() {

        if readerConfig.hideBars {
            
            pageIndicatorHeight = 0
        }
        totalPages = book.spine.spineReferences.count

        // Loading indicator
        let style: UIActivityIndicatorView.Style = folioReader.isNight(.white, .gray)
        loadingView = UIActivityIndicatorView(style: style)
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        view.addSubview(loadingView)
    }

    // MARK: - Change page progressive direction
    private func transformViewForRTL(_ view: UIView?) {
        
        view?.transform = folioReader.needsRTLChange ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }

    private func setCollectionViewProgressiveDirection() {
        
        transformViewForRTL(collectionView)
    }

    private func setPageProgressiveDirection(_ page: FolioReaderPage) {
        
        transformViewForRTL(page)
    }

    // MARK: - Change layout orientation

    /// Get internal page offset before layout change
    private func updatePageOffsetRate() {
        
        guard let currentPage = currentPage,
              let webView = currentPage.webView else { return }
        
        let pageScrollView = webView.scrollView
        let contentSize = pageScrollView.contentSize.forDirection(withConfiguration: readerConfig)
        let contentOffset = pageScrollView.contentOffset.forDirection(withConfiguration: readerConfig)
        
        pageOffsetRate = contentSize > 0 ? (contentOffset / contentSize) : 0
    }

    private func updateBarsStatus(_ shouldHide: Bool, shouldShowIndicator: Bool = false) {
        
        guard let readerContainer = readerContainer else { return }
        
        readerContainer.shouldHideStatusBar = shouldHide

        UIView.animate(withDuration: 0.25, animations: {
            
            readerContainer.setNeedsStatusBarAppearanceUpdate()

            // Show minutes indicator
//            if (shouldShowIndicator == true) {
//                self.pageIndicatorView?.minutesLabel.alpha = shouldHide ? 0 : 1
//            }
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }

    // MARK: - Page
    private func setPageSize() {
        
        let orientation = UIDevice.current.orientation
        
        guard orientation.isPortrait else {
            
            if screenBounds.size.width > screenBounds.size.height {
                
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height
                
            } else {
                
                pageWidth = screenBounds.size.height
                pageHeight = screenBounds.size.width
            }
            return
        }

        if screenBounds.size.width < screenBounds.size.height {
            
            pageWidth = screenBounds.size.width
            pageHeight = screenBounds.size.height
            
        } else {
            
            pageWidth = screenBounds.size.height
            pageHeight = screenBounds.size.width
        }
    }
    
    /// Updating current page
    /// - Parameters:
    ///   - page: current visible cell 'FolioRederPage'
    ///   - completion: finished operations updating
    private func updateCurrentPage(_ page: FolioReaderPage? = nil, completion: (() -> Void)? = nil) {
        
        if let page = page {
            
            currentPage = page
            previousPageNumber = page.pageNumber-1
            currentPageNumber = page.pageNumber
            
        } else {
            
            
            let currentIndexPath = getCurrentIndexPath()
            
            currentPage = collectionView.cellForItem(at: currentIndexPath) as? FolioReaderPage
            previousPageNumber = currentIndexPath.row
            currentPageNumber = currentIndexPath.row+1
        }
        nextPageNumber = currentPageNumber + 1 <= totalPages ? currentPageNumber + 1 : currentPageNumber

        // Set pages
        if let currentPage = currentPage {
            
            pagesForCurrentPage(currentPage)
            delegate?.pageDidAppear?(currentPage)
            delegate?.pageItemChanged?(getCurrentPageItemNumber())
        }
        completion?()
    }

    private func pagesForCurrentPage(_ page: FolioReaderPage?) {
        
        guard let webView = page?.webView else { return }
        
        let pageSize = readerConfig.isDirection(pageHeight, pageWidth, pageHeight)
        let contentSize = webView.scrollView.contentSize.forDirection(withConfiguration: readerConfig)
        
        pageIndicatorView?.totalPages = pageSize > 0 && contentSize > 0 ? Int(round(contentSize / pageSize)) : 0

        let pageOffset = webView.scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
        let webViewPage = pageForOffset(pageOffset, pageHeight: pageSize)

        pageIndicatorView?.currentPage = webViewPage
    }

    private func pageForOffset(_ offset: CGFloat, pageHeight height: CGFloat) -> Int {
        
        guard height > 0 else { return 0 }

        let page = Int(round(offset / height))+1
        return page
    }

    private func getCurrentIndexPath() -> IndexPath {
        
        let indexPaths = collectionView.indexPathsForVisibleItems
        var indexPath = IndexPath()

        if indexPaths.count > 1 {
            
            let first = indexPaths.first!
            let last = indexPaths.last!

            switch pageScrollDirection {
                
            case .up, .left:
                
                if first.compare(last) == .orderedAscending {
                    
                    indexPath = last
                    
                } else {
                    
                    indexPath = first
                }
                
            default:
                
                if first.compare(last) == .orderedAscending {
                    
                    indexPath = first
                    
                } else {
                    
                    indexPath = last
                }
            }
        } else {
            
            indexPath = indexPaths.first ?? IndexPath(row: 0, section: 0)
        }

        return indexPath
    }

    private func frameForPage(_ page: Int) -> CGRect {
        
        readerConfig.isDirection(
            CGRect(x: 0, y: pageHeight * CGFloat(page-1), width: pageWidth, height: pageHeight),
            CGRect(x: pageWidth * CGFloat(page-1), y: 0, width: pageWidth, height: pageHeight),
            CGRect(x: pageWidth * CGFloat(page-1), y: 0, width: pageWidth, height: pageHeight)
        )
    }

    open func changePageWith(page: Int, andFragment fragment: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        if (self.currentPageNumber == page) {
            if let currentPage = currentPage , fragment != "" {
                currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animated: animated)
            }
            completion?()
        } else {
            tempFragment = fragment
            changePageWith(page: page, animated: animated, completion: { () -> Void in
                self.updateCurrentPage {
                    completion?()
                }
            })
        }
    }

    open func changePageWith(href: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        let item = findPageByHref(href)
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage {
                completion?()
            }
        })
    }

    open func changePageWith(href: String, andAudioMarkID markID: String) {
        if recentlyScrolled { return } // if user recently scrolled, do not change pages or scroll the webview
        guard let currentPage = currentPage else { return }

        let item = findPageByHref(href)
        let pageUpdateNeeded = item+1 != currentPage.pageNumber
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: true) { () -> Void in
            if pageUpdateNeeded {
                self.updateCurrentPage {
                    currentPage.audioMarkID(markID)
                }
            } else {
                currentPage.audioMarkID(markID)
            }
        }
    }

    open func changePageWith(indexPath: IndexPath, animated: Bool = false, completion: (() -> Void)? = nil) {
        guard indexPathIsValid(indexPath) else {
            print("ERROR: Attempt to scroll to invalid index path")
            completion?()
            return
        }

        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIView.AnimationOptions(), animations: { () -> Void in
            self.collectionView.scrollToItem(at: indexPath, at: .direction(withConfiguration: self.readerConfig), animated: false)
        }) { (finished: Bool) -> Void in
            completion?()
        }
    }
    
    open func changePageWith(href: String, pageItem: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        changePageWith(href: href, animated: animated) {
            self.changePageItem(to: pageItem)
        }
    }

    private func indexPathIsValid(_ indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        let lastSectionIndex = collectionView.numberOfSections - 1

        //Make sure the specified section exists
        if section > lastSectionIndex {
            return false
        }

        let rowCount = self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1
        return row <= rowCount
    }

    open func isLastPage() -> Bool{
        return (currentPageNumber == self.nextPageNumber)
    }

    public func changePageToNext(_ completion: (() -> Void)? = nil) {
        changePageWith(page: self.nextPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }

    public func changePageToPrevious(_ completion: (() -> Void)? = nil) {
        changePageWith(page: self.previousPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }
    
    public func changePageItemToNext(_ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentOffset = cell.webView?.scrollView.contentOffset,
            let contentOffsetXLimit = cell.webView?.scrollView.contentSize.width else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        let contentOffsetX = contentOffset.x + cellSize.width
        
        if contentOffsetX >= contentOffsetXLimit {
            changePageToNext(completion)
        } else {
            cell.scrollPageToOffset(contentOffsetX, animated: true)
        }
        
        completion?()
    }

    public func getCurrentPageItemNumber() -> Int {
        guard let page = currentPage, let webView = page.webView else { return 0 }
        
        let pageSize = readerConfig.isDirection(pageHeight, pageWidth, pageHeight)
        let pageOffSet = readerConfig.isDirection(webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.y)
        let webViewPage = pageForOffset(pageOffSet, pageHeight: pageSize)
        
        return webViewPage
    }
    
    public func getCurrentPageProgress() -> Float {
        guard let page = currentPage else { return 0 }
        
        let pageSize = self.readerConfig.isDirection(pageHeight, self.pageWidth, pageHeight)
        let contentSize = page.webView?.scrollView.contentSize.forDirection(withConfiguration: self.readerConfig) ?? 0
        let totalPages = ((pageSize != 0) ? Int(ceil(contentSize / pageSize)) : 0)
        let currentPageItem = getCurrentPageItemNumber()
        
        if totalPages > 0 {
            var progress = Float((currentPageItem * 100) / totalPages)
            
            if progress < 0 { progress = 0 }
            if progress > 100 { progress = 100 }
            
            return progress
        }
        
        return 0
    }

    public func changePageItemToPrevious(_ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentOffset = cell.webView?.scrollView.contentOffset else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        let contentOffsetX = contentOffset.x - cellSize.width
        
        if contentOffsetX < 0 {
            changePageToPrevious(completion)
        } else {
            cell.scrollPageToOffset(contentOffsetX, animated: true)
        }
        
        completion?()
    }

    public func changePageItemToLast(animated: Bool = true, _ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentSize = cell.webView?.scrollView.contentSize else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        var contentOffsetX: CGFloat = 0.0
        
        if contentSize.width > 0 && cellSize.width > 0 {
            contentOffsetX = (cellSize.width * (contentSize.width / cellSize.width)) - cellSize.width
        }
        
        if contentOffsetX < 0 {
            contentOffsetX = 0
        }
        
        cell.scrollPageToOffset(contentOffsetX, animated: animated)
        
        completion?()
    }

    public func changePageItem(to: Int, animated: Bool = true, completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentSize = cell.webView?.scrollView.contentSize else {
                delegate?.pageItemChanged?(getCurrentPageItemNumber())
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        var contentOffsetX: CGFloat = 0.0
        
        if contentSize.width > 0 && cellSize.width > 0 {
            contentOffsetX = (cellSize.width * CGFloat(to)) - cellSize.width
        }
        
        if contentOffsetX > contentSize.width {
            contentOffsetX = contentSize.width - cellSize.width
        }
        
        if contentOffsetX < 0 {
            contentOffsetX = 0
        }
        
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIView.AnimationOptions(), animations: { () -> Void in
            cell.scrollPageToOffset(contentOffsetX, animated: animated)
        }) { (finished: Bool) -> Void in
            self.updateCurrentPage {
                completion?()
            }
        }
    }

    /**
     Find a page by FRTocReference.
     */
    public func findPageByResource(_ reference: FRTocReference) -> Int {
        var count = 0
        for item in self.book.spine.spineReferences {
            if let resource = reference.resource, item.resource == resource {
                return count
            }
            count += 1
        }
        return count
    }

    /**
     Find a page by href.
     */
    public func findPageByHref(_ href: String) -> Int {
        var count = 0
        for item in self.book.spine.spineReferences {
            if item.resource.href == href {
                return count
            }
            count += 1
        }
        return count
    }

    /**
     Find and return the current chapter resource.
     */
    public func getCurrentChapter() -> FRResource? {
        var foundResource: FRResource?

        func search(_ items: [FRTocReference]) {
            for item in items {
                guard foundResource == nil else { break }

                if let reference = book.spine.spineReferences[safe: (currentPageNumber - 1)], let resource = item.resource, resource == reference.resource {
                    foundResource = resource
                    break
                } else if let children = item.children, children.isEmpty == false {
                    search(children)
                }
            }
        }
        search(book.flatTableOfContents)

        return foundResource
    }

    /**
     Return the current chapter progress based on current chapter and total of chapters.
     */
    public func getCurrentChapterProgress() -> CGFloat {
        let total = totalPages
        let current = currentPageNumber
        
        if total == 0 {
            return 0
        }
        
        return CGFloat((100 * current) / total)
    }

    /**
     Find and return the current chapter name.
     */
    public func getCurrentChapterName() -> String? {
        var foundChapterName: String?
        
        func search(_ items: [FRTocReference]) {
            for item in items {
                guard foundChapterName == nil else { break }
                
                if let reference = self.book.spine.spineReferences[safe: (self.currentPageNumber - 1)],
                    let resource = item.resource,
                    resource == reference.resource,
                    let title = item.title {
                    foundChapterName = title
                } else if let children = item.children, children.isEmpty == false {
                    search(children)
                }
            }
        }
        search(self.book.flatTableOfContents)
        
        return foundChapterName
    }

    // MARK: Public page methods

    /**
     Changes the current page of the reader.

     - parameter page: The target page index. Note: The page index starts at 1 (and not 0).
     - parameter animated: En-/Disables the animation of the page change.
     - parameter completion: A Closure which is called if the page change is completed.
     */
    public func changePageWith(page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        
        if page > 0 && page-1 < totalPages {
            let indexPath = IndexPath(row: page-1, section: 0)
            changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
                self.updateCurrentPage {
                    completion?()
                }
            })
        }
    }

    // MARK: - Audio Playing
    func audioMark(href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }

    // MARK: - Sharing

    /**
     Sharing chapter method.
     */
    @objc
    private func shareChapter(_ sender: UIBarButtonItem) {
        
        guard let currentPage = currentPage else { return }
        
        currentPage.webView?.js("getBodyText()"){[unowned self] chapterText in
            
            if let chapterText = chapterText {
                
                let htmlText = chapterText.replacingOccurrences(of: "[\\n\\r]+", with: "<br />", options: .regularExpression)
                var subject = readerConfig.localizedShareChapterSubject
                var html = ""
                var text = ""
                var bookTitle = ""
                var chapterName = ""
                var authorName = ""
                var shareItems = [AnyObject]()
                
                // Get book title
                if let title = book.title {
                    
                    bookTitle = title
                    subject += " “\(title)”"
                }
                
                // Get chapter name
                if let chapter = getCurrentChapterName() {
                    
                    chapterName = chapter
                }
                
                // Get author name
                if let author = book.metadata.creators.first {
                    
                    authorName = author.name
                }
                
                // Sharing html and text
                html = "<html><body>"
                html += "<br /><hr> <p>\(htmlText)</p> <hr><br />"
                html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
                html += "<b>\(bookTitle)</b><br />"
                html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
                
                if let bookShareLink = readerConfig.localizedShareWebLink {
                    
                    html += "<a href=\"\(bookShareLink.absoluteString)\">\(bookShareLink.absoluteString)</a>"
                    shareItems.append(bookShareLink as AnyObject)
                }
                
                html += "</center></body></html>"
                text = "\(chapterName)\n\n“\(chapterText)” \n\n\(bookTitle) \n\(readerConfig.localizedShareBy) \(authorName)"
                
                let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
                shareItems.insert(contentsOf: [act, "" as AnyObject], at: 0)
                
                let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
                activityViewController.excludedActivityTypes = [UIActivity.ActivityType.print, UIActivity.ActivityType.postToVimeo]
                
                // Pop style on iPad
                if let actv = activityViewController.popoverPresentationController {
                    
                    actv.barButtonItem = sender
                }
                present(activityViewController, animated: true)
            }
        }
    }

    /**
     Sharing highlight method.
     */
    func shareHighlight(_ string: String, rect: CGRect) {
        
        var subject = readerConfig.localizedShareHighlightSubject
        var html = ""
        var text = ""
        var bookTitle = ""
        var chapterName = ""
        var authorName = ""
        var shareItems = [AnyObject]()

        // Get book title
        if let title = book.title {
            bookTitle = title
            subject += " “\(title)”"
        }

        // Get chapter name
        if let chapter = getCurrentChapterName() {
            chapterName = chapter
        }

        // Get author name
        if let author = book.metadata.creators.first {
            authorName = author.name
        }

        // Sharing html and text
        html = "<html><body>"
        html += "<br /><hr> <p>\(chapterName)</p>"
        html += "<p>\(string)</p> <hr><br />"
        html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
        html += "<b>\(bookTitle)</b><br />"
        html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"

        if let bookShareLink = readerConfig.localizedShareWebLink {
            html += "<a href=\"\(bookShareLink.absoluteString)\">\(bookShareLink.absoluteString)</a>"
            shareItems.append(bookShareLink as AnyObject)
        }

        html += "</center></body></html>"
        text = "\(chapterName)\n\n“\(string)” \n\n\(bookTitle) \n\(readerConfig.localizedShareBy) \(authorName)"

        let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
        shareItems.insert(contentsOf: [act, "" as AnyObject], at: 0)

        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivity.ActivityType.print, UIActivity.ActivityType.postToVimeo]

        // Pop style on iPad
        if let actv = activityViewController.popoverPresentationController {
            actv.sourceView = currentPage
            actv.sourceRect = rect
        }

        present(activityViewController, animated: true, completion: nil)
    }

    private func updatePageScrollDirection(inScrollView scrollView: UIScrollView, forScrollType scrollType: ScrollType) {
        
        let contentOffset = scrollView.contentOffset.forDirection(withConfiguration: readerConfig, scrollType: scrollType)
        let pointNowForDirection = pointNow.forDirection(withConfiguration: readerConfig, scrollType: scrollType)
        // The movement is either positive or negative. This happens if the page change isn't completed. Toggle to the other scroll direction then.

        if contentOffset < pointNowForDirection {
            
            if pageScrollDirection != .negative(withConfiguration: readerConfig, scrollType: scrollType) {
                
                pageScrollDirection = .negative(withConfiguration: readerConfig, scrollType: scrollType)
            }
            
            
        } else if contentOffset > pointNowForDirection {
            
            if pageScrollDirection != .positive(withConfiguration: readerConfig, scrollType: scrollType) {
                
                pageScrollDirection = .positive(withConfiguration: readerConfig, scrollType: scrollType)
                
            }
            
        } else if pageScrollDirection == .left || pageScrollDirection == .up {
            
            if pageScrollDirection != .negative(withConfiguration: readerConfig, scrollType: scrollType) {
                
                pageScrollDirection = .negative(withConfiguration: readerConfig, scrollType: scrollType)
            }
            
        } else {
            
            if pageScrollDirection != .positive(withConfiguration: readerConfig, scrollType: scrollType) {
                
                pageScrollDirection = .positive(withConfiguration: readerConfig, scrollType: scrollType)
            }
        }
    }

    // MARK: - NavigationBar Actions

    @objc
    private func closeReader(_ sender: UIBarButtonItem) {
        dismiss()
        folioReader.close()
    }

    /**
     Present chapter list
     */
    @objc
    private func presentChapterList(_ sender: UIBarButtonItem) {
        
        folioReader.saveReaderState()

        let chapter = FolioReaderChapterList(folioReader: folioReader, readerConfig: readerConfig, book: book, delegate: self)
        let highlight = FolioReaderHighlightList(folioReader: folioReader, readerConfig: readerConfig)
        let pageController = PageViewController(folioReader: folioReader, readerConfig: readerConfig)

        pageController.viewControllerOne = chapter
        pageController.viewControllerTwo = highlight
        pageController.segmentedControlItems = [readerConfig.localizedContentsTitle, readerConfig.localizedHighlightsTitle]

        let nav = UINavigationController(rootViewController: pageController)
        
        present(nav, animated: true, completion: nil)
    }

    /**
     Present fonts and settings menu
     */
    @objc
    private func presentFontsMenu() {
        
        folioReader.saveReaderState()
        hideBars()

        let menu = FolioReaderFontsMenu(folioReader: folioReader, readerConfig: readerConfig)
        menu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = false
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = .bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true)
    }

    /**
     Present audio player menu
     */
    @objc
    private func presentPlayerMenu(_ sender: UIBarButtonItem) {
        
        folioReader.saveReaderState()
        hideBars()
        
        let menu = FolioReaderPlayerMenu(folioReader: folioReader, readerConfig: readerConfig)
        menu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = true
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true, completion: nil)
    }

    /**
     Present Quote Share
     */
    func presentQuoteShare(_ string: String) {
        
        let quoteShare = FolioReaderQuoteShare(initWithText: string,
                                               readerConfig: readerConfig,
                                               folioReader: folioReader, book: book)
        
        let navigation = UINavigationController(rootViewController: quoteShare)

        if UIDevice.current.userInterfaceIdiom == .pad {
            
            navigation.modalPresentationStyle = .formSheet
        }
        
        present(navigation, animated: true)
    }
    
    /**
     Present add highlight note
     */
    func presentAddHighlightNote(_ highlight: Highlight, edit: Bool) {
        
        let addHighlightView = FolioReaderAddHighlightNote(withHighlight: highlight,
                                                           folioReader: folioReader,
                                                           readerConfig: readerConfig)
        addHighlightView.isEditHighlight = edit
        
        
        let navigation = UINavigationController(rootViewController: addHighlightView)
        navigation.modalPresentationStyle = .formSheet
        
        present(navigation, animated: true)
    }
    
    @objc
    private func clearRecentlyScrolled() {
        
        if recentlyScrolledTimer != nil {
            
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }
}

// MARK: - FolioPageDelegate
extension FolioReaderCenter: FolioReaderPageDelegate {

    public func pageDidLoad(_ page: FolioReaderPage) {
        
        if readerConfig.loadSavedPositionForCurrentBook,
            let position = folioReader.savedPositionForCurrentBook {
            
            let pageNumber = position["pageNumber"] as? Int
            let offset = readerConfig.isDirection(position["pageOffsetY"], position["pageOffsetX"], position["pageOffsetY"]) as? CGFloat
            let pageOffset = offset

            if isFirstLoad {
                
                updateCurrentPage(page)
                isFirstLoad = false

                if currentPageNumber == pageNumber && pageOffset > 0 {
                    
                    page.scrollPageToOffset(pageOffset!, animated: false)
                }
            } else if !isScrolling && folioReader.needsRTLChange {
                
                page.scrollPageToBottom()
            }
            
        } else if isFirstLoad {
            
            updateCurrentPage(page)
            isFirstLoad = false
        }

        // Go to fragment if needed
        if let fragmentId = tempFragment,
           let currentPage = currentPage,
           fragmentId.isNotEmpty {
            
            currentPage.handleAnchor(fragmentId, avoidBeginningAnchors: true, animated: true)
            tempFragment = nil
        }
        
        if readerConfig.scrollDirection == .horizontalWithVerticalContent,
            let offsetPoint = currentWebViewScrollPositions[page.pageNumber - 1] {
            
            page.webView?.scrollView.setContentOffset(offsetPoint, animated: false)
        }
        
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageDidLoad?(page)
    }
    
    public func pageWillLoad(_ page: FolioReaderPage) {
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageWillLoad?(page)
    }
    
    public func pageTap(_ recognizer: UITapGestureRecognizer) {
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageTap?(recognizer)
    }
    
}

// MARK: - FolioReaderChapterListDelegate
extension FolioReaderCenter: FolioReaderChapterListDelegate {
    
    func chapterList(_ chapterList: FolioReaderChapterList, didSelectRowAtIndexPath indexPath: IndexPath, withTocReference reference: FRTocReference) {
        
        let item = findPageByResource(reference)
        
        if item < totalPages {
            
            let indexPath = IndexPath(row: item, section: 0)
            
            changePageWith(indexPath: indexPath, animated: false) {[unowned self] in
                self.updateCurrentPage()
            }
            tempReference = reference
            
        } else {
            
            print("Failed to load book because the requested resource is missing.")
        }
    }
    
    func chapterList(didDismissedChapterList chapterList: FolioReaderChapterList) {
        
        updateCurrentPage()
        
        // Move to #fragment
        if let reference = tempReference {
            
            if let fragmentID = reference.fragmentID,
                let currentPage = currentPage ,
                fragmentID != "" {
                
                currentPage.handleAnchor(reference.fragmentID!, avoidBeginningAnchors: true, animated: true)
            }
            tempReference = nil
        }
    }
}

//MARK: - UICollectionView+Delegate & DataSource
extension FolioReaderCenter: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
         totalPages
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kReuseCellIdentifier, for: indexPath) as? FolioReaderPage,
              let readerContainer = readerContainer else {
                  
                  return UICollectionViewCell()
              }

        cell.delegate = self
        cell.pageNumber = indexPath.row+1
        cell.setup(withReaderContainer: readerContainer)
        cell.webView?.scrollView.delegate = self
        setPageProgressiveDirection(cell)
        
        // Configure the cell
        let resource = book.spine.spineReferences[indexPath.row].resource
        
        cell.configureUI(resource: resource,
                         baseURL: URL(fileURLWithPath: resource.fullHref.deletingLastPathComponent))
        return cell
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        collectionView.bounds.size
    }
}

//MARK: - UIScrollViewDelegate
extension FolioReaderCenter: UIScrollViewDelegate {
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        isScrolling = true
        currentPage?.webView?.setMenuVisible(false)
        pointNow = scrollView.contentOffset
        
        let isCollectionView = scrollView is UICollectionView
        
        if !isCollectionView {

            collectionView.isScrollEnabled = false
        }
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let pageSize = readerConfig.isDirection(pageHeight, pageWidth, pageHeight)
        pageIndicatorView?.setProgress(by: scrollView, pageSize: pageSize, configuration: readerConfig)

        let isCollectionView = scrollView is UICollectionView
        let scrollType: ScrollType = isCollectionView ? .chapter : .page

        // Update current reading page
        if !isCollectionView, let page = currentPage, let webView = page.webView {

            let contentOffset = webView.scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
            let contentSize = webView.scrollView.contentSize.forDirection(withConfiguration: readerConfig)
            
            if (contentOffset + pageSize <= contentSize) {

                let webViewPage = pageForOffset(contentOffset, pageHeight: pageSize)
                
                if readerConfig.scrollDirection == .horizontalWithVerticalContent {

                    let currentIndexPathRow = (page.pageNumber - 1)

                    // if the cell reload doesn't save the top position offset
                    if let oldOffSet = currentWebViewScrollPositions[currentIndexPathRow],
                        (abs(oldOffSet.y - scrollView.contentOffset.y) > 100) {
                        // Do nothing
                    } else {

                        currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
                    }
                }

                if pageIndicatorView?.currentPage != webViewPage {
                    
                    pageIndicatorView?.currentPage = webViewPage
                }
                delegate?.pageItemChanged?(webViewPage)
            }
        }
        updatePageScrollDirection(inScrollView: scrollView, forScrollType: scrollType)
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        isScrolling = false
        
        if let cell = (scrollView.superview as? FolioReaderWKWebView)?.navigationDelegate as? FolioReaderPage,
           readerConfig.scrollDirection == .horizontalWithVerticalContent {
            
            let currentIndexPathRow = cell.pageNumber - 1
            currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
        }
        
        let pageSize = readerConfig.isDirection(pageHeight, pageWidth, pageHeight)
        pageIndicatorView?.setProgress(by: scrollView, pageSize: pageSize, configuration: readerConfig)
        
        let isCollectionView = scrollView is UICollectionView
        
        if !isCollectionView {

            collectionView.isScrollEnabled = true
            
        } else if totalPages > 0 {
            
            updateCurrentPage()
            delegate?.pageItemChanged?(getCurrentPageItemNumber())
        }
    }
}
