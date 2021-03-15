//
//  FileDownloader.swift
//
//  Created by Jiawei on 2018/11/14.
//  Copyright © 2018 kamikuo. All rights reserved.
//

import Foundation

open class FileDownloader : NSObject, URLSessionDownloadDelegate {

    private let downloadQueue = OperationQueue()
    lazy private var downloadSession: URLSession = {
        downloadQueue.qualityOfService = .background
        return URLSession(configuration: .default, delegate: self, delegateQueue: downloadQueue)
    }()

    public let cacheController: FileCacheController
    public init(cacheController: FileCacheController) {
        self.cacheController = cacheController
        super.init()
    }

    open class Request {
        public let url: URL
        fileprivate let progress: ((Float) -> Void)?
        fileprivate let completion: (Data?) -> Void
        public init(url: URL, progress: ((Float) -> Void)? = nil, completion: @escaping ((Data?) -> Void)) {
            self.url = url
            self.progress = progress
            self.completion = completion
        }
    }

    private var urlRequests = [URL: (task: URLSessionDownloadTask?, requests: [Request])]()
    private var downloadTaskMap = [Int: URL]()

    open func getFileName(url: URL) -> String {
        //use MD5(url) as filename
        let cstring = url.absoluteString.cString(using: .utf8)!
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(cstring, CC_LONG(cstring.count), &digest)
        return digest.map{ String(format: "%02hhx", $0) }.joined()
    }

    open func fetch(request: Request) {
        let url = request.url

        if urlRequests[url] != nil {
            urlRequests[url]!.requests.append(request)
            return
        }

        urlRequests[url] = (task: nil, requests: [request])

        if url.isFileURL {
            if let data = FileManager.default.contents(atPath: url.path) {
                fetchCompletion(url: url, data: data)
            } else {
                fetchFail(url: url, isCancel: false)
            }
            return
        }

        cacheController.get(filename: getFileName(url: url)) { (data) in
            if data != nil {
                self.fetchCompletion(url: url, data: data)
            } else {
                let urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60)
                let downloadTask = self.downloadSession.downloadTask(with: urlRequest)
                self.downloadTaskMap[downloadTask.taskIdentifier] = url
                self.urlRequests[url]?.task = downloadTask
                self.urlRequests[url]?.task?.resume()
            }
        }
    }

    open func cancel(request: Request) {
        let url = request.url
        if let index = urlRequests[url]?.requests.firstIndex(where: {$0 === request}) {
            urlRequests[url]?.requests.remove(at: index)
            if urlRequests[url]?.requests.isEmpty ?? false {
                self.fetchFail(url: url, isCancel: true)
            }
        }
    }

    private func fetchCompletion(url: URL, data: Data?){
        guard let urlRequest = urlRequests[url] else { return }
        if let task = urlRequest.task {
            downloadTaskMap.removeValue(forKey: task.taskIdentifier)
        }
        urlRequests.removeValue(forKey: url)

        urlRequest.requests.forEach{ $0.completion(data) }
    }

    private func fetchFail(url: URL, isCancel: Bool) {
        guard let urlRequest = urlRequests[url] else { return }
        if let task = urlRequest.task {
            if isCancel {
                task.cancel()
            }
            downloadTaskMap.removeValue(forKey: task.taskIdentifier)
        }
        urlRequests.removeValue(forKey: url)
        if !isCancel {
            urlRequest.requests.forEach{ $0.completion(nil) }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.sync {
            guard let url = downloadTaskMap[downloadTask.taskIdentifier], let requests = urlRequests[url]?.requests else { return }
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            requests.forEach{ $0.progress?(progress) }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var url: URL?
        DispatchQueue.main.sync {
            url = downloadTaskMap[downloadTask.taskIdentifier]
        }
        if let url = url {
            let filename = getFileName(url: url)
            cacheController.move(formLocation: location, withFilename: filename)
            cacheController.get(filename: filename) { (data) in
                self.fetchCompletion(url: url, data: data)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { //fail?
        if error != nil {
            DispatchQueue.main.sync {
                if let url = downloadTaskMap[task.taskIdentifier] {
                    DispatchQueue.main.async {
                        self.fetchFail(url: url, isCancel: false)
                    }
                }
            }
        }
    }
}
