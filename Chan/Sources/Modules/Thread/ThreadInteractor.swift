//
//  ThreadInteractor.swift
//  Chan
//
//  Created by Mikhail Malyshev on 12.09.2018.
//  Copyright © 2018 Mikhail Malyshev. All rights reserved.
//

import RIBs
import RxSwift

protocol ThreadRouting: ViewableRouting {
    func openThread(with post: PostReplysViewModel)
    func openNewThread(with thread: ThreadModel)
    func popToCurrent()
}

protocol ThreadPresentable: Presentable {
    var listener: ThreadPresentableListener? { get set }
}

protocol ThreadListener: class {
    func popToRoot()
}

final class ThreadInteractor: PresentableInteractor<ThreadPresentable>, ThreadInteractable, ThreadPresentableListener {

    weak var router: ThreadRouting?
    weak var listener: ThreadListener?
    
    var service: ThreadServiceProtocol
    
    private let publish: PublishSubject<ThreadServiceProtocol.ResultType> = PublishSubject()
    private let disposeBag = DisposeBag()
    
    private var data: [PostModel] = []
    
    private let postsManager: PostManager
    private let moduleIsRoot: Bool
    
    init(presenter: ThreadPresentable, service: ThreadServiceProtocol, moduleIsRoot: Bool, cachedVM: [PostViewModel]? = nil) {
        self.service = service
        self.moduleIsRoot = moduleIsRoot
        self.mainViewModel = Variable(PostMainViewModel(title: service.name, canRefresh: self.moduleIsRoot))
        self.postsManager = PostManager(thread: service.thread)
        self.postsManager.update(vms: cachedVM)
        
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        self.setup()
    }

    override func willResignActive() {
        super.willResignActive()
    }
    
    // MARK: ThreadPresentableListener
    var mainViewModel: Variable<PostMainViewModel>
    var dataSource: Variable<[PostViewModel]> = Variable([])
    var viewActions: PublishSubject<PostAction> = PublishSubject()
    
    // MARK: ThreadListener
    func popToRoot() {
        if self.moduleIsRoot {
            self.router?.popToCurrent()
        } else {
            self.listener?.popToRoot()
        }
    }
    
    // MARK:Private
    private func setup() {
        self.setupRx()
        self.service.load()
    }
    
    private func setupRx() {
        self.service.publish = self.publish
        
        self.publish
            .observeOn(Helper.rxBackgroundThread)
            .subscribe(onNext: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                let models = result.result
                self?.data = models
                
                self?.postsManager.update(posts: models)
                self?.postsManager.process()
                
                switch result.type {
                case .all: self?.postsManager.resetFilters()
                case .replys(let parent): self?.postsManager.addFilter(by: parent.uid)
                case .replyed(let model): self?.postsManager.onlyReplyed(uid: model.uid)
                }
                
                strongSelf.dataSource.value = self?.postsManager.filtredPostsVM ?? []
                if let newName = self?.service.name {
                    self?.mainViewModel.value = PostMainViewModel(title: newName, canRefresh: self?.moduleIsRoot ?? false)
                }

            }, onError: { [weak self] error in
                
            }).disposed(by: self.disposeBag)
        
        self.viewActions
            .subscribe(onNext: { [weak self] action in
                switch action {
                case .openReplys(let postUid): do {
                    if let post = self?.data.filter({ $0.uid == postUid }).first, let posts = self?.data, let thread = self?.service.thread {
                        let replyModel = PostReplysViewModel(parent: post, posts: posts, thread: thread, cachedVM: self?.postsManager.internalPostVM)
                        self?.router?.openThread(with: replyModel)
                    }
                    }
                case .openLink(let postUid, let url): do {
                    self?.openByTextIndex(postUid: postUid, url: url)
                }
                case .refresh: do {
                    if self?.moduleIsRoot ?? false {
                        self?.postsManager.resetCache()
                        self?.service.refresh()
                    }
                }
                case .popToRoot: do {
                    self?.popToRoot()
                }
                }
            }).disposed(by: self.disposeBag)
    }
    
    private func openByTextIndex(postUid: String, url: URL) {
        let posts = self.data
        let thread = self.service.thread
        
        if let post = self.data.first(where: { $0.uid == postUid }) {
            let stringUrl = url.absoluteString
            let linkParser = LinkParser(path: stringUrl)
            
            switch linkParser.type {
            case .boardLink(let boardLink): do {
                if let openThread = boardLink.thread, let boardUid = boardLink.board {
                    
                    if thread.uid != openThread {
                        let board = BoardModel(uid: boardUid)
                        let threadToOpen = ThreadModel(uid: openThread, board: board)
                        
                        self.router?.openNewThread(with: threadToOpen)
                    } else {
                        if let replyedPost = posts.filter({ $0.uid == boardLink.post}).first {
                            let replyes = PostReplysViewModel(parent: post, posts: posts, thread: thread, replyed: replyedPost, cachedVM: self.postsManager.internalPostVM)
                            self.router?.openThread(with: replyes)
                        } else {
                            self.router?.openNewThread(with: thread)

                        }
                    }
                } else {
                    // TODO: Если ссылка вида /hw/catalog.html, '/web/'
                }
            }
                
            case .externalLink: Helper.open(url: url)
            }
        }
    }

}
