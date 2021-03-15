//
//  FileCacheController.swift
//
//  Created by Jiawei on 2018/11/12.
//  Copyright © 2018 kamikuo. All rights reserved.
//

import Foundation
import WebKit.WKWebsiteDataStore

open class FileCacheController {
    private static let ioQueue = DispatchQueue(label: "tw.kamikuo.filecacheio")
    private static let fileManager = FileManager()

    public let directoryName: String
    public let timeout: TimeInterval
    public let cachePath: String

    public init(directoryName: String, timeout: TimeInterval) {
        self.directoryName = directoryName
        self.timeout = timeout

        cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "/" + directoryName
        FileCacheController.ioQueue.async {
            if !FileCacheController.fileManager.fileExists(atPath: self.cachePath) {
                try? FileCacheController.fileManager.createDirectory(atPath: self.cachePath, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    open func getPath(fileName: String) -> String {
        return "\(cachePath)/\(fileName)"
    }

    open func get(filename: String, completion: @escaping (Data?) -> Void) {
        let path = getPath(fileName: filename)
        FileCacheController.ioQueue.async {
            var data: Data?
            if FileCacheController.fileManager.fileExists(atPath: path) {
                try? FileCacheController.fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
                data = FileCacheController.fileManager.contents(atPath: path)
            }
            DispatchQueue.main.async {
                completion(data)
            }
        }
    }

    open func store(data: Data, filename: String, completion: @escaping (Bool) -> Void) {
        let path = getPath(fileName: filename)
        FileCacheController.ioQueue.async {
            let success = FileCacheController.fileManager.createFile(atPath: path, contents: data, attributes: [.modificationDate: Date()])
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    open func delete(filename: String) {
        let path = getPath(fileName: filename)
        FileCacheController.ioQueue.async {
            try? FileCacheController.fileManager.removeItem(atPath: path)
        }
    }

    open func move(formLocation location: URL, withFilename filename: String) {
        let filePathUrl = URL(fileURLWithPath: getPath(fileName: filename))
        FileCacheController.ioQueue.sync {
            try? FileCacheController.fileManager.moveItem(at: location, to: filePathUrl)
        }
    }

    open func clearTimeout() {
        guard self.timeout > 0 else { return }
        FileCacheController.ioQueue.async {
            let nowDate = Date()
            (try? FileCacheController.fileManager.contentsOfDirectory(atPath: self.cachePath))?.forEach({ (fileName) in
                let filePath = "\(self.cachePath)/\(fileName)"
                if let fileDate = (try? FileCacheController.fileManager.attributesOfItem(atPath: filePath))?[.modificationDate] as? Date, nowDate.timeIntervalSince(fileDate) < self.timeout {
                    return
                }
                try? FileCacheController.fileManager.removeItem(atPath: filePath)
            })
        }
    }

    open func clearAll() {
        FileCacheController.ioQueue.async {
            (try? FileCacheController.fileManager.contentsOfDirectory(atPath: self.cachePath))?.forEach({ (fileName) in
                let filePath = "\(self.cachePath)/\(fileName)"
                try? FileCacheController.fileManager.removeItem(atPath: filePath)
            })
        }
    }
}
