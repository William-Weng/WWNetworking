# WWNetworking

[![Swift-5.7](https://img.shields.io/badge/Swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/) [![iOS-16.0](https://img.shields.io/badge/iOS-16.0-pink.svg?style=flat)](https://developer.apple.com/swift/) ![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNetworking) [![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/) [![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

## [Introduction - 簡介](https://swiftpackageindex.com/William-Weng)
- This is a simple integration of HTTP transmission, upload and download functions. It is a rare and good tool for iOS engineers.
- 這是一個簡單的HTTP傳輸、上傳、下載功能整合，是iOS工程師不可多得的好工具。

![WWNetworking](./Example.webp)

### [Installation with Swift Package Manager](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/使用-spm-安裝第三方套件-xcode-11-新功能-2c4ffcf85b4b)
```
dependencies: [
    .package(url: "https://github.com/William-Weng/WWNetworking.git", .upToNextMajor(from: "1.8.1"))
]
```

## [Function - 可用函式](https://gitbook.swiftgg.team/swift/swift-jiao-cheng)
### [一般版本](https://medium.com/彼得潘的-swift-ios-app-開發教室/簡易說明swift-4-closures-77351c3bf775)
|函式|功能|
|-|-|
|request(httpMethod:urlString:timeout:contentType:paramaters:headers:httpBodyType:result:)|發出URLRequest|
|header(urlString:timeout:headers:result:)|取得該URL資源的HEAD資訊|
|upload(httpMethod:urlString:timeout:formData:parameters:headers:result)|上傳檔案 - 模仿Form|
|multipleUpload(httpMethod:urlString:timeout:formDatas:parameters:headers:result)|上傳檔案 (多個) - 模仿Form|
|binaryUpload(httpMethod:urlString:timeout:formData:headers:delegateQueue:progress:completion:)|二進制檔案上傳 - 大型檔案|
|download(httpMethod:urlString:timeout:configuration:delegateQueue:progress:completion:)|下載資料 - URLSessionDownloadDelegate|
|fragmentDownload(urlString:timeout:fragment:configiguration:delegateQueue:progress:fragmentTask:completion:)|分段下載|
|multipleDownload(httpMethod:urlStrings:timeout:configuration:delegateQueue:progress:completion:)|下載多筆資料- URLSessionDownloadDelegate|

### [async / await版本](https://youtu.be/s2PiL_Vte4E)
|函式|功能|
|-|-|
|request(httpMethod:urlString:timeout:contentType:paramaters:headers:httpBodyType:)|發出URLRequest|
|header(urlString:timeout:headers:)|取得該URL資源的HEAD資訊|
|upload(httpMethod:timeout:urlString:formData:parameters:headers:)|上傳檔案 - 模仿Form|
|multipleUpload(httpMethod:urlString:timeout:formDatas:parameters:headers:)|上傳檔案 (多個) - 模仿Form|
|binaryUpload(httpMethod:urlString:timeout:formData:headers:delegateQueue:)|二進制檔案上傳 - 大型檔案|
|download(httpMethod:urlString:timeout:configuration:delegateQueue:)|下載資料 - URLSessionDownloadDelegate|
|fragmentDownload(urlString:fragment:timeout:configiguration:delegateQueue:)|分段下載|
|multipleDownload(httpMethod:urlStrings:timeout:configuration:delegateQueue:)|下載多筆資料- URLSessionDownloadDelegate|
|multipleRequest(types:)|發出多個request|
|multipleRequestWithTaskGroup(types:)|同時發出多個request|

## [Example](https://ezgif.com/video-to-webp)
```swift
import UIKit
import WWNetworking

final class ViewController: UIViewController {

    @IBOutlet weak var resultTextField: UITextView!
    @IBOutlet var resultImageViews: [UIImageView]!
    @IBOutlet var resultProgressLabels: [UILabel]!

    private let ImageUrlInfos: [String] = [
        ("https://images-assets.nasa.gov/image/PIA18033/PIA18033~orig.jpg"),
        ("https://images-assets.nasa.gov/image/KSC-20210907-PH-KLS01_0009/KSC-20210907-PH-KLS01_0009~orig.jpg"),
        ("https://images-assets.nasa.gov/image/iss065e095794/iss065e095794~orig.jpg"),
    ]
    
    private let UrlStrings = [
        "GET": "https://httpbin.org/get",
        "POST": "https://httpbin.org/post",
        "DOWNLOAD": "https://raw.githubusercontent.com/William-Weng/AdobeIllustrator/master/William-Weng.png",
        "UPLOAD": "http://192.168.4.92:8080/upload",
        "BINARY-UPLOAD": "http://192.168.4.92:8080/binaryUpload",
        "FRAGMENT": "https://photosku.com/images_file/images/i000_803.jpg",
    ]
    
    override func viewDidLoad() { super.viewDidLoad() }
    
    @IBAction func httpGetAction(_ sender: UIButton) { httpGetTest() }
    @IBAction func httpPostAction(_ sender: UIButton) { httpPostTest() }
    @IBAction func httpDownloadAction(_ sender: UIButton) { httpDownloadData() }
    @IBAction func httpFragmentDownloadAction(_ sender: UIButton) { Task { await fragmentDownloadData() }}
    @IBAction func httpMultipleDownloadAction(_ sender: UIButton) { httpMultipleDownload() }
    @IBAction func httpUploadAction(_ sender: UIButton) { httpUploadData() }
    @IBAction func httpBinaryUpload(_ sender: UIButton) { httpBinaryUploadData() }
}

private extension ViewController {

    func httpGetTest() {
        
        let urlString = UrlStrings["GET"]!
        let parameters: [String: String?] = ["name": "William.Weng", "github": "https://william-weng.github.io/"]
        
        _ = WWNetworking.shared.request(httpMethod: .GET, urlString: urlString, paramaters: parameters) { result in

            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info): self.displayText(info.data?._jsonSerialization())
            }
        }
    }
    
    func httpPostTest() {
        
        let urlString = UrlStrings["POST"]!
        let parameters: [String: Any] = ["name": "William.Weng", "github": "https://william-weng.github.io/"]
        
        _ = WWNetworking.shared.request(httpMethod: .POST, urlString: urlString, paramaters: nil, httpBodyType: .dictionary(parameters)) { result in

            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info): self.displayText(info.data?._jsonSerialization())
            }
        }
    }
    
    func httpUploadData() {
        
        let urlString = UrlStrings["UPLOAD"]!
        let imageData = resultImageViews[0].image?.pngData()
        let formData: WWNetworking.FormDataInformation = (name: "file", filename: "Demo.png", contentType: .png, data: imageData!)
                
        _ = WWNetworking.shared.upload(urlString: urlString, formData: formData) { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info): self.displayText("\(info.data?._jsonSerialization() ?? "NOT JSON")")
            }
        }
    }
    
    func httpBinaryUploadData() {
        
        let urlString = UrlStrings["BINARY-UPLOAD"]!
        let index = 1
        let imageData = resultImageViews[index].image?.pngData()
        let formData: WWNetworking.FormDataInformation = (name: "x-filename", filename: "Large.png", contentType: .octetStream, data: imageData!)
        
        _ = WWNetworking.shared.binaryUpload(urlString: urlString, formData: formData, progress: { info in
             
            let progress = Float(info.totalBytesSent) / Float(info.totalBytesExpectedToSend)
            DispatchQueue.main.async { self.title = "\(progress)" }
            
        }, completion: { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let isSuccess): self.displayText(isSuccess)
            }
        })
    }
    
    func httpDownloadData() {
        
        let urlString = UrlStrings["DOWNLOAD"]!
        let index = 0
        
        self.displayText("")
        
        _ = WWNetworking.shared.download(urlString: urlString, progress: { info in
            
            let progress = Float(info.totalWritten) / Float(info.totalSize)
            self.displayProgressWithIndex(index, progress: progress)
                        
        }, completion: { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info): self.displayImageWithIndex(index, data: info.data)
            }
        })
    }
    
    func fragmentDownloadData() async {
        
        let urlString = UrlStrings["FRAGMENT"]!
        let index = 1
        
        self.displayText("")
        
        do {
            for try await state in WWNetworking.shared.fragmentDownload(urlString: urlString) {
                switch state {
                case .start(let task): print("task = \(task)")
                case .finished(let data): displayImageWithIndex(index, data: data)
                case .progress(let info):
                    let progress = Float(info.totalWritten) / Float(info.totalSize)
                    displayProgressWithIndex(index, progress: progress)
                }
            }
        } catch {
            displayText(error)
        }
    }
    
    func httpMultipleDownload() {
        
        resultImageViews.forEach { $0.image = nil }
        
        _ = WWNetworking.shared.multipleDownload(urlStrings: ImageUrlInfos) { info in
            
            guard let index = self.displayImageIndex(urlStrings: self.ImageUrlInfos, urlString: info.urlString),
                  let progress = Optional.some(Float(info.totalWritten) / Float(info.totalSize))
            else {
                return
            }

            self.displayProgressWithIndex(index, progress: progress)
            
        } completion: { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info):
                guard let index = self.displayImageIndex(urlStrings: self.ImageUrlInfos, urlString: info.urlString) else { return }
                self.displayImageWithIndex(index, data: info.data)
            }
        }
    }
}

private extension ViewController {
    
    func displayProgressWithIndex(_ index: Int, progress: Float) {
        self.resultProgressLabels[index].text = "\(progress * 100.0) %"
    }
    
    func displayImageWithIndex(_ index: Int, data: Data?) {
        guard let data = data else { return }
        self.resultImageViews[index].image = UIImage(data: data)
    }
    
    func displayText(_ text: Any?) {
        DispatchQueue.main.async { self.resultTextField.text = "\(text ?? "NULL")" }
    }
    
    func displayImageIndex(urlStrings: [String], urlString: String?) -> Int? {
        
        guard let urlString = urlString,
              let index = urlStrings.firstIndex(of: urlString)
        else {
            return nil
        }

        return index
    }
}
```
