//
//  FolioReaderAddHighlightNote.swift
//  FolioReaderKit
//
//  Created by ShuichiNagao on 2018/05/06.
//

import UIKit
import RealmSwift

class FolioReaderAddHighlightNote: UIViewController {

    var textView: UITextView!
    var highlightLabel: UILabel!
    var scrollView: UIScrollView!
    var containerView = UIView()
    var highlight: Highlight!
    var highlightSaved = false
    var isEditHighlight = false
    var resizedTextView = false
    
    private var folioReader: FolioReader
    private var readerConfig: FolioReaderConfig
    
    init(withHighlight highlight: Highlight, folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        self.folioReader = folioReader
        self.highlight = highlight
        self.readerConfig = readerConfig
        
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }
    
    // MARK: - life cycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setCloseButton(withConfiguration: readerConfig)
        prepareScrollView()
        configureTextView()
        configureLabel()
        configureNavBar()
        configureKeyboardObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        textView.becomeFirstResponder()
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.frame = view.bounds
        containerView.frame = view.bounds
        scrollView.contentSize = view.bounds.size
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if !highlightSaved && !isEditHighlight {
            guard let currentPage = folioReader.readerCenter?.currentPage else { return }
            currentPage.webView?.js("removeThisHighlight()")
        }
    }
    
    // MARK: - private methods
    
    private func prepareScrollView(){
        
        scrollView = UIScrollView()
        scrollView.delegate = self as UIScrollViewDelegate
        scrollView.bounces = false
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = .clear
        
        if #available(iOS 11, *) {
            
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        view.addSubview(scrollView)
        
        let leftScrollViewConstraint = NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0)
        let rightScrollViewConstraint = NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0)
        let topScrollViewConstraint = NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
        let botScrollViewConstraint = NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
        
        view.addConstraints([leftScrollViewConstraint, rightScrollViewConstraint, topScrollViewConstraint, botScrollViewConstraint])
        
        containerView = UIView()
        containerView.backgroundColor = folioReader.isNight(readerConfig.nightModeBackground, .white)
        
        scrollView.addSubview(containerView)
    }
    
    private func configureTextView(){
        
        textView = UITextView()
        textView.keyboardAppearance = folioReader.isNight(.dark, .light)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textColor = folioReader.isNight(.white, .black)
        textView.backgroundColor = .clear
        textView.font = UIFont.boldSystemFont(ofSize: 15)
        
        if isEditHighlight {
            
             textView.text = highlight.noteForHighlight
        }
        
        containerView.addSubview(textView)
        
        let leftConstraint = NSLayoutConstraint(item: textView, attribute: .left, relatedBy: .equal, toItem: containerView, attribute: .left, multiplier: 1.0, constant: 20)
        let rightConstraint = NSLayoutConstraint(item: textView, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1.0, constant: -20)
        let topConstraint = NSLayoutConstraint(item: textView, attribute: .top, relatedBy: .equal, toItem: containerView, attribute: .top, multiplier: 1, constant: 100)
        let heiConstraint = NSLayoutConstraint(item: textView, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: -20)
        containerView.addConstraints([leftConstraint, rightConstraint, topConstraint, heiConstraint])
    }
    
    private func configureLabel() {
        
        highlightLabel = UILabel()
        highlightLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightLabel.numberOfLines = 3
        highlightLabel.font = UIFont.systemFont(ofSize: 15)
        highlightLabel.text = highlight.content.stripHtml().truncate(250, trailing: "...").stripLineBreaks()
        highlightLabel.textColor = folioReader.isNight(.white, .black)
        highlightLabel.backgroundColor = .clear
        
        containerView.addSubview(highlightLabel!)
        
        let leftConstraint = NSLayoutConstraint(item: highlightLabel!, attribute: .left, relatedBy: .equal, toItem: containerView, attribute: .left, multiplier: 1.0, constant: 20)
        let rightConstraint = NSLayoutConstraint(item: highlightLabel!, attribute: .right, relatedBy: .equal, toItem: containerView, attribute: .right, multiplier: 1.0, constant: -20)
        let topConstraint = NSLayoutConstraint(item: highlightLabel, attribute: .top, relatedBy: .equal, toItem: containerView, attribute: .top, multiplier: 1, constant: 20)
        let heiConstraint = NSLayoutConstraint(item: highlightLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 70)
        
        containerView.addConstraints([leftConstraint, rightConstraint, topConstraint, heiConstraint])
    }
    
    private func configureNavBar() {
        
        let navBackground = folioReader.isNight(readerConfig.nightModeNavBackground, readerConfig.daysModeNavBackground)
        let tintColor = readerConfig.tintColor
        let navText = folioReader.isNight(UIColor.white, UIColor.black)
        let font = UIFont(name: "Avenir-Light", size: 17)!
        
        setTranslucentNavigation(false, color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
        
        navigationController?.navigationBar.backgroundColor = navBackground
        
        let titleAttrs = [NSAttributedString.Key.foregroundColor: readerConfig.tintColor]
        let saveButton = UIBarButtonItem(title: readerConfig.localizedSave, style: .plain, target: self, action: #selector(saveNote(_:)))
        saveButton.setTitleTextAttributes(titleAttrs, for: UIControl.State())
        navigationItem.rightBarButtonItem = saveButton
    }
    
    private func configureKeyboardObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name:UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name:UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc
    private func keyboardWillShow(notification: NSNotification){
        
        //give room at the bottom of the scroll view, so it doesn't cover up anything the user needs to tap
        guard var keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        keyboardFrame = view.convert(keyboardFrame, from: nil)
        scrollView.contentInset.bottom = keyboardFrame.size.height
        scrollView.scrollIndicatorInsets.bottom = keyboardFrame.size.height
    }
    
    @objc
    private func keyboardWillHide(notification:NSNotification){
        
        scrollView.contentInset = .zero
    }
    
    @objc
    private func saveNote(_ sender: UIBarButtonItem) {
        
        if !textView.text.isEmpty {
            if isEditHighlight {
                let realm = try! Realm(configuration: readerConfig.realmConfiguration)
                realm.beginWrite()
                highlight.noteForHighlight = textView.text
                highlightSaved = true
                try! realm.commitWrite()
            } else {
                highlight.noteForHighlight = textView.text
                highlight.persist(withConfiguration: readerConfig)
                highlightSaved = true
            }
        }
        
        dismiss()
    }
}

// MARK: - UITextViewDelegate
extension FolioReaderAddHighlightNote: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        
        let fixedWidth = textView.frame.size.width
        textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height + 15)
        
        textView.frame = newFrame;
    }
    
//    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
//        textView.frame.size.height = textView.frame.height + 30
//
//        if resizedTextView {
//
//            scrollView.scrollRectToVisible(textView.frame, animated: true)
//
//        } else{
//
//            resizedTextView = true
//        }
//
//        return true
//    }
}
