# WWNetworking

[![Swift-5.8](https://img.shields.io/badge/Swift-5.8-orange.svg?style=flat)](https://developer.apple.com/swift/) [![iOS-16.0](https://img.shields.io/badge/iOS-16.0-pink.svg?style=flat)](https://developer.apple.com/swift/) ![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNetworking) [![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/) [![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

## [Introduction - 簡介](https://swiftpackageindex.com/William-Weng)
- [This is a simple integration of HTTP transmission, elegant HTTP networking, upload and download functions. It is a rare and good tool for iOS engineers.](https://github.com/pro648/tips/blob/master/sources/URLSession详解.md)
- [這是一個簡單的HTTP傳輸、上傳、下載功能整合，優雅的HTTP網路功能，是iOS工程師不可多得的好工具。](https://medium.com/@jerrywang0420/urlsession-教學-swift-3-ios-part-1-a1029fc9c427)

https://github.com/user-attachments/assets/6c2a02b4-34e8-4678-8d0b-48169dda53fe

### [Installation with Swift Package Manager](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/使用-spm-安裝第三方套件-xcode-11-新功能-2c4ffcf85b4b)
```
dependencies: [
    .package(url: "https://github.com/William-Weng/WWNetworking.git", .upToNextMajor(from: "2.1.3"))
]
```

## [Function - 可用函式](https://gitbook.swiftgg.team/swift/swift-jiao-cheng)
### [Closure版本](https://medium.com/彼得潘的-swift-ios-app-開發教室/簡易說明swift-4-closures-77351c3bf775)
|函式|功能|
|-|-|
|builder()|建立一個新的WWNetworking|
|sslPinningSetting(_:delegate:)|SSL-Pinning設定 => host + .cer|
|request(httpMethod:urlString:timeout:contentType:paramaters:headers:httpBodyType:delegateQueue:result:)|發出URLRequest|
|header(urlString:timeout:headers:delegateQueue:result:)|取得該URL資源的HEAD資訊|
|upload(httpMethod:urlString:timeout:formData:parameters:headers:delegateQueue:result)|上傳檔案 - 模仿Form|
|multipleUpload(httpMethod:urlString:timeout:formDatas:parameters:headers:delegateQueue:result)|上傳檔案 (多個) - 模仿Form|
|binaryUpload(httpMethod:urlString:timeout:formData:headers:delegateQueue:progress:completion:)|二進制檔案上傳 - 大型檔案|
|download(httpMethod:urlString:timeout:configuration:headers:delegateQueue:progress:completion:)|下載資料 - URLSessionDownloadDelegate|
|fragmentDownload(urlString:timeout:fragment:configiguration:headers:delegateQueue:progress:fragmentTask:completion:)|分段下載|
|multipleDownload(httpMethod:urlStrings:timeout:configuration:headers:delegateQueue:progress:completion:)|下載多筆資料- URLSessionDownloadDelegate|

### [async / await版本](https://youtu.be/s2PiL_Vte4E)
|函式|功能|
|-|-|
|request(httpMethod:urlString:timeout:contentType:paramaters:headers:httpBodyType:delegateQueue:)|發出URLRequest|
|header(urlString:timeout:headers:delegateQueue:)|取得該URL資源的HEAD資訊|
|upload(httpMethod:timeout:urlString:formData:parameters:headers:delegateQueue:)|上傳檔案 - 模仿Form|
|multipleUpload(httpMethod:urlString:timeout:formDatas:parameters:headers:delegateQueue:)|上傳檔案 (多個) - 模仿Form|
|binaryUpload(httpMethod:urlString:timeout:formData:headers:delegateQueue:)|二進制檔案上傳 - 大型檔案|
|download(httpMethod:urlString:timeout:configuration:headers:delegateQueue:)|下載資料 - URLSessionDownloadDelegate|
|fragmentDownload(urlString:fragment:timeout:configiguration:headers:delegateQueue:)|分段下載|
|multipleDownload(httpMethod:urlStrings:timeout:configuration:headers:delegateQueue:)|下載多筆資料- URLSessionDownloadDelegate|
|multipleRequest(types:)|順序執行多個Request|
|multipleRequestWithTaskGroup(types:)|同時執行多個Request|
|multipleRequestWithStream(types:)|串流執行多個Request|

### [WWNetworking.Delegate](https://youtu.be/s2PiL_Vte4E)
|函式|功能|
|-|-|
|authChalleng(_:host:disposition:credential:)|SSL-Pinning的結果|

## 取得公鑰
```bash
openssl s_client -connect <your.server.com>:443 -showcerts </dev/null | openssl x509 -outform DER > <server>.cer
openssl s_client -connect google.com:443 -showcerts </dev/null | openssl x509 -outform DER > google.cer
```

## [Example](https://ezgif.com/video-to-webp)
```swift
import UIKit
import WWNetworking

final class ViewController: UIViewController {

    @IBOutlet weak var resultTextField: UITextView!
    @IBOutlet var resultImageViews: [UIImageView]!
    @IBOutlet var resultProgressLabels: [UILabel]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Task { await WWNetworking.shared.sslPinningSetting((bundle: .main, values: [.init(host: "httpbin.org", cer: "google.cer")])) }
    }
    
    @IBAction func httpGetAction(_ sender: UIButton) { Task { await httpGetTest() }}
    @IBAction func httpPostAction(_ sender: UIButton) { httpPostTest() }
    @IBAction func httpDownloadAction(_ sender: UIButton) { Task { await httpDownloadData()} }
    @IBAction func httpFragmentDownloadAction(_ sender: UIButton) { Task { await fragmentDownloadData() }}
    @IBAction func httpMultipleDownloadAction(_ sender: UIButton) { Task { await httpMultipleDownload() }}
    @IBAction func httpUploadAction(_ sender: UIButton) { Task { await httpUploadData() }}
    @IBAction func httpBinaryUpload(_ sender: UIButton) { Task { await httpBinaryUploadData() }}
}

private extension ViewController {

    func httpGetTest() async {
        
        let urlString = "https://httpbin.org/get"
        let parameters: [String: String?] = ["name": "William.Weng", "github": "https://william-weng.github.io/"]
        
        do {
            let info = try await WWNetworking.shared.request(httpMethod: .GET, urlString: urlString, paramaters: parameters).get()
            displayText(info.data?._jsonSerialization())
        } catch {
            displayText(error)
        }
    }
    
    func httpPostTest() {
        
        let urlString = "https://httpbin.org/post"
        let parameters: [String: Any] = ["name": "William.Weng", "github": "https://william-weng.github.io/"]
        
        Task {
            await WWNetworking.shared.request(httpMethod: .POST, urlString: urlString, paramaters: nil, httpBodyType: .dictionary(parameters)) { result in
                
                switch result {
                case .failure(let error): self.displayText(error)
                case .success(let info): self.displayText(info.data?._jsonSerialization())
                }
            }
        }
    }
    
    func httpDownloadData() async {
        
        let urlString = "https://raw.githubusercontent.com/William-Weng/AdobeIllustrator/master/William-Weng.png"
        let index = 0
        
        displayText("")
        
        await WWNetworking.shared.download(urlString: urlString, progress: { info in
            
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
        
        let urlString = "https://photosku.com/images_file/images/i000_803.jpg"
        let index = 1
        
        displayText("")
        
        do {
            for try await state in await WWNetworking.shared.fragmentDownload(urlString: urlString) {
                switch state {
                case .start(let task): print("task = \(task)")
                case .finished(let data): displayImageWithIndex(index, data: data)
                case .progress(let info): displayProgressWithIndex(index, progress: Float(info.totalWritten) / Float(info.totalSize))
                }
            }
        } catch {
            displayText(error)
        }
    }
    
    func httpMultipleDownload() async {
        
        let imageUrlInfos: [String] = [
            ("https://images-assets.nasa.gov/image/PIA18033/PIA18033~orig.jpg"),
            ("https://images-assets.nasa.gov/image/KSC-20210907-PH-KLS01_0009/KSC-20210907-PH-KLS01_0009~orig.jpg"),
            ("https://images-assets.nasa.gov/image/iss065e095794/iss065e095794~orig.jpg"),
        ]

        resultImageViews.forEach { $0.image = nil }
        
        await WWNetworking.shared.multipleDownload(urlStrings: imageUrlInfos) { info in

            print(Float(info.totalWritten) / Float(info.totalSize))
            
            guard let index = self.displayImageIndex(urlStrings: imageUrlInfos, urlString: info.urlString) else { return }
            self.displayProgressWithIndex(index, progress: Float(info.totalWritten) / Float(info.totalSize))
            
        } completion: { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info):
                guard let index = self.displayImageIndex(urlStrings: imageUrlInfos, urlString: info.urlString) else { return }
                self.displayImageWithIndex(index, data: info.data)
            }
        }
    }
    
    func httpUploadData() async {
        
        let urlString = "http://192.168.4.200:8080/upload"
        let imageData = resultImageViews[0].image?.pngData()
        let formData: WWNetworking.FormDataInformation = (name: "file", filename: "Demo.png", contentType: .png, data: imageData!)
        
        await WWNetworking.shared.upload(urlString: urlString, formData: formData) { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let info): self.displayText(info.response?.statusCode ?? 404)
            }
        }
    }
    
    func httpBinaryUploadData() async {
        
        let urlString = "http://192.168.4.200:8081/binaryUpload"
        let index = 1
        let imageData = resultImageViews[index].image?.pngData()
        let formData: WWNetworking.FormDataInformation = (name: "x-filename", filename: "Large.png", contentType: .octetStream, data: imageData!)
        
        await WWNetworking.shared.binaryUpload(urlString: urlString, formData: formData, progress: { info in
            self.title = "\(Float(info.totalBytesSent) / Float(info.totalBytesExpectedToSend))"
        }, completion: { result in
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let isSuccess): self.displayText(isSuccess)
            }
        })
    }
}

private extension ViewController {
    
    func displayProgressWithIndex(_ index: Int, progress: Float) {
        resultProgressLabels[index].text = "\(progress * 100.0) %"
    }

    func displayImageWithIndex(_ index: Int, data: Data?) {
        guard let data = data else { return }
        resultImageViews[index].image = UIImage(data: data)
    }
    
    func displayText(_ text: Any?) {
        self.resultTextField.text = "\(text ?? "NULL")"
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
