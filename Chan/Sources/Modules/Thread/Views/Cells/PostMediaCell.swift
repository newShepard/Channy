//
//  PostMediaCell.swift
//  Chan
//
//  Created by Mikhail Malyshev on 20.09.2018.
//  Copyright © 2018 Mikhail Malyshev. All rights reserved.
//

import UIKit
import SnapKit
import AlamofireImage

class PostMediaCell: PostCell {
    private var firstImage = PostMediaView()
    private var secondImage = PostMediaView()
    private var thirdImage = PostMediaView()
    private var forthImage = PostMediaView()
    
    private var images: [PostMediaView] {
        return [firstImage, secondImage, thirdImage, forthImage]
    }
    
    private var isFirst = true

    override func setupUI() {
        super.setupUI()
        
        self.prepare(image: self.firstImage)
        self.prepare(image: self.secondImage)
        self.prepare(image: self.thirdImage)
        self.prepare(image: self.forthImage)
        
        self.addCopyLinkMenuItems()
        
    }
    
    override func update(with model: PostViewModel) {
        super.update(with: model)
//        self.setupConstrainst(with: model)
        
        let _ = self.images.map { $0.cancelLoad() }
        let _ = self.images.map { $0.isHidden = true }
                
        for (idx, media) in model.media.enumerated() {
            if idx < self.images.count {
                let imgView = self.images[idx]
                Helper.performOnMainThread {
                    imgView.update(with: media)
                    self.updateImagePosition(with: imgView, model: model, idx: idx)
                }
            }
        }
    }
    
    // MARK: Private
    private func prepare(image: UIView) {
        self.contentView.addSubview(image)
        image.isHidden = true
        image.clipsToBounds = true
        image.layer.cornerRadius = DefaultCornerRadius
        image.contentMode = .scaleAspectFill
        
        let tap = UITapGestureRecognizer()
        image.isUserInteractionEnabled = true
        image.addGestureRecognizer(tap)
        
        tap.rx
            .event
            .asDriver()
            .drive(onNext: { [weak self] gesture in
                if let view = gesture.view as? PostMediaView, let idx = self?.images.firstIndex(of: view), let strongSelf = self {
                    self?.action?.on(.next(.openMedia(idx: idx, cell: strongSelf, view: view.image)))
                }
            }).disposed(by: self.disposeBag)
    }
    
    private func updateImagePosition(with view: UIView, model: PostViewModel, idx: Int) {
        
        view.frame = CGRect(x: PostTextLeftMargin + CGFloat(idx) * (PostMediaMargin + model.mediaFrame.width), y: model.mediaFrame.minY, width: model.mediaFrame.width, height: model.mediaFrame.height)
    }
    
    
    private func addCopyLinkMenuItems() {
        for media in self.images {
            media
                .actions
                .subscribe(onNext: { [weak self, weak media] action in
                    
                    switch action {
                    case .disableParentActions: self?.canPerformAction = false
                    case .enableParentActions: self?.canPerformAction = true
                    case .copy:
                        if let media = media, let self = self {
                            if let idx = self.images.firstIndex(of: media) {
                                self.action?.on(.next(.copyMediaLink(cell: self, idx: idx)))
                            }
                        }
                    case .openBrowser:
                        if let media = media, let self = self {
                            if let idx = self.images.firstIndex(of: media) {
                                self.action?.on(.next(.openBrowserMediaLink(cell: self, idx: idx)))
                            }
                        }

                    }

                    
                })
                .disposed(by: self.disposeBag)
        }
    }
    
}
