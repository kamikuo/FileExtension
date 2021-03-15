# FileExtension
file cache controller and downloader

## Usage

### FileCacheController
```swift
//Define
let fileCache = FileCacheController(directoryName: "cache", timeout: 604800)

//Store File
fileCache.store(data: data, filename: "filename") { success in 
    //...
}

//Get File
fileCache.get("filename") { data in 
    guard let data = data else {
        //Get failed
        return
    }
    //...
}

//Delete File
fileCache.delete("filename")

fileCache.clearTimout() //Delete timeout files
fileCache.clearAll() //Delete all files
```

### FileDownloader
```swift
let downloadCache = FileCacheController(directoryName: "download", timeout: 604800)
let downloader = FileDownloader(cacheController: downloadCache)

let url = URL(string: "https://...")!
let request = FileDownloader.Request(url: url, progress: { progress in
    //progress is Float 0.0~1.0
}) { data in
    guard let data = data else {
        //download failed.
        return
    }
    //...
}
downloader.fetch(request: request)
```

Cancel Downloading
```swift
downloader.cancel(request: request)
```

### TemporaryFile
TemporaryFile object will create a file that will be delete when object is deinit.
It's useful for save memory cost when multi huge data processing.


## Lisence
The MIT License (MIT)
