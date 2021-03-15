//
//  TemporaryFile.swift
//
//  Created by Jiawei on 2019/1/5.
//  Copyright © 2019 kamikuo. All rights reserved.
//

import Foundation

public class TemporaryFile {
    private static var fileCacheController: FileCacheController = {
        let fileCacheController = FileCacheController(directoryName: "tw.kamikuo.temp", timeout: 0)
        fileCacheController.clearAll()
        return fileCacheController
    }()

    private var data: Data?
    private let fileName = "temp-\(UUID().uuidString)"
    public init(data: Data){
        self.data = data
        TemporaryFile.fileCacheController.store(data: data, filename: fileName, completion: { [weak self] success in
            if success {
                self?.data = nil
            }
        })
    }

    public func get(_ completion: @escaping (Data?) -> Void) {
        if let data = data {
            completion(data)
        } else {
            TemporaryFile.fileCacheController.get(filename: fileName, completion: completion)
        }
    }

    deinit {
        TemporaryFile.fileCacheController.delete(filename: fileName)
    }
}
