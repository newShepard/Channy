//
//  WriteViewController.swift
//  Chan
//
//  Created by Mikhail Malyshev on 24/11/2018.
//  Copyright © 2018 Mikhail Malyshev. All rights reserved.
//

import RIBs
import RxSwift
import UIKit
import RxCocoa
import UITextView_Placeholder


protocol WritePresentableListener: class {
    var viewActions: PublishSubject<WriteViewActions> { get }
    var moduleState: WriteModuleState { get }
    func imagesCount() -> Observable<Int>
}

final class WriteViewController: BaseViewController, WritePresentable, WriteViewControllable {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var subjectView: UITextView!
    @IBOutlet weak var bButton: UIButton!
    @IBOutlet weak var iButton: UIButton!
    @IBOutlet weak var spoilerButton: UIButton!
    @IBOutlet weak var sButton: UIButton!
    @IBOutlet weak var uButton: UIButton!
    
    @IBOutlet weak var firstImageView: UIImageView!
    @IBOutlet weak var secondImageView: UIImageView!
    @IBOutlet weak var thirdImageView: UIImageView!
    @IBOutlet weak var forthImageView: UIImageView!

    @IBOutlet weak var firstImageButton: UIButton!
    @IBOutlet weak var secondImageButton: UIButton!
    @IBOutlet weak var thirdImageButton: UIButton!
    @IBOutlet weak var forthImageButton: UIButton!
    
    private var firstImage: UIImage? = nil
    private var secondImage: UIImage? = nil
    private var thirdImage: UIImage? = nil
    private var forthImage: UIImage? = nil
    
    private weak var sendButton: UIBarButtonItem?
    
    private var currentPicker: WriteImagePicker? = nil
    
    var vc: UIViewController { return self }
    
    var data: Observable<String>? = nil
    
//    private var recaptchaView: UIView? = nil
    
    private var buttons: [UIButton] {
        return [self.bButton, self.iButton, self.spoilerButton, self.sButton, self.uButton]
    }
    
    private var imageButtons: [UIButton] {
        return [self.firstImageButton, self.secondImageButton, self.thirdImageButton, self.forthImageButton]
    }
    
    private var imageViews: [UIImageView] {
        return [self.firstImageView, self.secondImageView, self.thirdImageView, self.forthImageView]
    }

    var images: [UIImage] {
        var result: [UIImage] = []
        
        if let first = self.firstImage {
            result.append(first)
        }
        
        if let second = self.secondImage {
            result.append(second)
        }
        
        if let third = self.thirdImage {
            result.append(third)
        }
        
        if let forth = self.forthImage {
            result.append(forth)
        }
        
        return result
    }
    
    weak var listener: WritePresentableListener?
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    // MARK: WritePresentable
    func solveRecaptcha(with key: String?, host: String) -> Observable<(String?, String?)> {
        
//        if let key = key {
//            let manager = RecaptchaManager(recptcha: key, host: host)
//            return manager
//                .solve(from: self)
//                .flatMap({ result -> Observable<(String?, String?)> in
//                    return Observable<(String?, String?)>.just((key, result))
//                })
//        } else {
            return Observable<(String?, String?)>.just((nil, nil))
//        }
        
    }
    
    //MARK: Private
    private func setup() {
        self.setupUI()
        self.setupRx()
    }
    
    private func setupUI() {
        self.setupTheme()
        
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        self.view.addGestureRecognizer(tap)
        self.view.isUserInteractionEnabled = true
        tap
            .rx
            .event
            .subscribe(onNext: { [weak self] _ in
                self?.view.endEditing(true)
            })
            .disposed(by: self.disposeBag)
        
        self.textView.placeholder = "enter_text".localized
        self.textView.keyboardDismissMode = .onDrag
        self.textView.alwaysBounceVertical = true
        
        self.subjectView.placeholder = "Topic".localized
        self.subjectView.keyboardDismissMode = .onDrag
        

        let _ = self.buttons.map({ self.setup(view: $0) })
        let _ = self.imageButtons.map({ self.setupImageButton($0) })
        let _ = self.imageViews.map({ self.setupImage($0) })
        
        let sendButton = UIBarButtonItem(title: "Send".localized, style: UIBarButtonItem.Style.done, target: nil, action: nil)
        self.sendButton = sendButton
        
        self.navigationItem.rightBarButtonItem = sendButton
        
        if let state = self.listener?.moduleState {
            switch state {
            case .create:
                self.navigationItem.title = "thread_creature".localized
            case .write:
                self.navigationItem.title = "reply_thread".localized
            }
        }
      
        
        self.listener?
            .imagesCount()
            .subscribe(onNext: { [weak self] count in
                guard let self = self else { return }
                
                var c: Int = count
                if count == 0 {
                    c = -1
                }
                
                for (idx, imageView) in self.imageButtons.enumerated() {
                    imageView.isEnabled = idx < c
                }
            })
            .disposed(by: self.disposeBag)
      
    }
    
    private func setupRx() {
        self.sendButton?
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.view.endEditing(true)
                self?.listener?.viewActions.on(.next(.send(text: self?.textView.text, subject: self?.subjectView?.text)))
            }).disposed(by: self.disposeBag)
        
        self.data?
            .subscribe(onNext: { [weak self] newText in
                if let self = self, newText.count != 0 {
                    var insertText = newText
                    if self.textView.text.count != 0 {
                        insertText = "\n" + insertText
                    }
                    insertText += "\n"
                    
                    self.textView.text += insertText
                }
            })
            .disposed(by: self.disposeBag)
        
        self.bButton
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.insert(tag: "b")
            })
            .disposed(by: self.disposeBag)
        
        self.iButton
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.insert(tag: "i")
            })
            .disposed(by: self.disposeBag)
        
        self.spoilerButton
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.insert(tag: "spoiler")
            })
            .disposed(by: self.disposeBag)
        
        self.sButton
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.insert(tag: "s")
            })
            .disposed(by: self.disposeBag)
        
        self.uButton
            .rx
            .tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.insert(tag: "u")
            })
            .disposed(by: self.disposeBag)
        
        
        
        self.firstImageButton
            .rx
            .tap
            .asObservable()
            .flatMap({ [weak self] _ -> Observable<UIImage?> in
                guard let self = self else { return Observable<UIImage?>.just(nil) }

                if self.firstImage != nil {
                    return Observable<UIImage?>.just(nil)
                } else {
                    let picker = WriteImagePicker()
                    self.currentPicker = picker
                    return picker.pickImage(from: self)
                }
            })
            .subscribe(onNext: { [weak self] image in
                self?.currentPicker = nil
                guard let self = self else { return }
                if let image = image {
                    self.firstImage = image
                    self.firstImageView.image = image
                    self.image(selected: true, for: self.firstImageButton)
                } else {
                    self.firstImage = nil
                    self.firstImageView.image = nil
                    self.image(selected: false, for: self.firstImageButton)
                }
            })
            .disposed(by: self.disposeBag)
        
        self.secondImageButton
            .rx
            .tap
            .asObservable()
            .flatMap({ [weak self] _ -> Observable<UIImage?> in
                guard let self = self else { return Observable<UIImage?>.just(nil) }
                
                if self.secondImage != nil {
                    return Observable<UIImage?>.just(nil)
                } else {
                    let picker = WriteImagePicker()
                    self.currentPicker = picker
                    return picker.pickImage(from: self)
                }
            })
            .subscribe(onNext: { [weak self] image in
                self?.currentPicker = nil
                guard let self = self else { return }
                if let image = image {
                    self.secondImage = image
                    self.secondImageView.image = image
                    self.image(selected: true, for: self.secondImageButton)
                } else {
                    self.secondImage = nil
                    self.secondImageView.image = nil
                    self.image(selected: false, for: self.secondImageButton)
                }
            })
            .disposed(by: self.disposeBag)
        
        
        self.thirdImageButton
            .rx
            .tap
            .asObservable()
            .flatMap({ [weak self] _ -> Observable<UIImage?> in
                guard let self = self else { return Observable<UIImage?>.just(nil) }
                
                if self.thirdImage != nil {
                    return Observable<UIImage?>.just(nil)
                } else {
                    let picker = WriteImagePicker()
                    self.currentPicker = picker
                    return picker.pickImage(from: self)
                }
            })
            .subscribe(onNext: { [weak self] image in
                self?.currentPicker = nil
                guard let self = self else { return }
                if let image = image {
                    self.thirdImage = image
                    self.thirdImageView.image = image
                    self.image(selected: true, for: self.thirdImageButton)
                } else {
                    self.thirdImage = nil
                    self.thirdImageView.image = nil
                    self.image(selected: false, for: self.thirdImageButton)
                }
            })
            .disposed(by: self.disposeBag)
        
        self.forthImageButton
            .rx
            .tap
            .asObservable()
            .flatMap({ [weak self] _ -> Observable<UIImage?> in
                guard let self = self else { return Observable<UIImage?>.just(nil) }
                
                if self.forthImage != nil {
                    return Observable<UIImage?>.just(nil)
                } else {
                    let picker = WriteImagePicker()
                    self.currentPicker = picker
                    return picker.pickImage(from: self)
                }
            })
            .subscribe(onNext: { [weak self] image in
                self?.currentPicker = nil
                guard let self = self else { return }
                if let image = image {
                    self.forthImage = image
                    self.forthImageView.image = image
                    self.image(selected: true, for: self.forthImageButton)
                } else {
                    self.forthImage = nil
                    self.forthImageView.image = nil
                    self.image(selected: false, for: self.forthImageButton)
                }
            })
            .disposed(by: self.disposeBag)
    }
    
    override func setupTheme() {
        self.themeManager.append(view: ThemeView(view: self.textView, type: .input, subtype: .none))
        self.themeManager.append(view: ThemeView(object: self.view, type: .background, subtype: .none))
        self.themeManager.append(view: ThemeView(view: self.subjectView, type: .input, subtype: .none))

        for button in self.buttons + self.imageButtons {
            self.themeManager.append(view: ThemeView(object: button, type: .button, subtype: .none))
        }
    }
    
    private func setup(view button: UIView) {
        button.layer.borderWidth = 1
//        button.layer.borderColor = self.themeManager.theme.main.cgColor
        button.layer.cornerRadius = DefaultCornerRadius
    }
    
    private func setupImageButton(_ button: UIView) {
//        button.tintColor = self.themeManager.theme.main
    }

    private func setupImage(_ image: UIView) {
//        button.tintColor = self.themeManager.theme.main
        image.layer.cornerRadius = DefaultCornerRadius
        image.clipsToBounds = true
    }

    
    
    private func insert(tag: String) {
        let open = "[\(tag)]"
        let close = "[/\(tag)]"
        
        
        let range = self.textView.selectedRange
        let start = range.location
        let end = range.location + range.length + open.count
        
        
        
        let text = (self.textView.text as NSString?)?.mutableCopy() as? NSMutableString
//        if start == end {
        
        text?.insert(open, at: start)
        text?.insert(close, at: end)
            
//            text?.insert(contentsOf: open, at: <#T##String.Index#>)
//
//            text?.insert(contentsOf: open, at: String.Index(encodedOffset: start))
//            end += open.count
//            text?.insert(contentsOf: close, at: String.Index(encodedOffset: end))
//        } else {
//            text?.insert(contentsOf: close, at: String.Index(encodedOffset: end))
//            text?.insert(contentsOf: open, at: String.Index(encodedOffset: start))
//        }
        self.textView.text = text as String?
        
        if range.length == 0 {
            self.textView.selectedRange = NSMakeRange(start + open.count, 0)
        }
    }
    
    private func image(selected: Bool, for button: UIButton) {
        button.layer.removeAllAnimations()
        UIView.animate(withDuration: AnimationDuration) {
            if !selected {
                button.transform = CGAffineTransform(rotationAngle: 0)
            } else {
                button.transform = CGAffineTransform(rotationAngle: CGFloat(Float.pi / 4))
            }
        }
    }
    
}
