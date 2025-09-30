//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2021/9/11.
//

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
    
    override func viewDidLoad() {
        // WWNetworking.sslPinning = (bundle: .main, values: ["github.io": "google.cer"])
        super.viewDidLoad()
    }
    
    @IBAction func httpGetAction(_ sender: UIButton) { Task { await httpGetTest() }}
    @IBAction func httpPostAction(_ sender: UIButton) { httpPostTest() }
    @IBAction func httpDownloadAction(_ sender: UIButton) { httpDownloadData() }
    @IBAction func httpFragmentDownloadAction(_ sender: UIButton) { Task { await fragmentDownloadData() }}
    @IBAction func httpMultipleDownloadAction(_ sender: UIButton) { httpMultipleDownload() }
    @IBAction func httpUploadAction(_ sender: UIButton) { httpUploadData() }
    @IBAction func httpBinaryUpload(_ sender: UIButton) { httpBinaryUploadData() }
}

// MARK: - ViewController (private class function)
private extension ViewController {

    /// 測試GET (GET不能有httpBody)
    @MainActor
    func httpGetTest() async {
        
        let urlString = UrlStrings["GET"]!
        let parameters: [String: String?] = ["name": "William.Weng", "github": "https://william-weng.github.io/"]
        
        do {
            let info = try await WWNetworking.shared.request(httpMethod: .GET, urlString: urlString, paramaters: parameters).get()
            displayText(info.data?._jsonSerialization())
        } catch {
            displayText(error)
        }
    }
    
    /// 測試POST
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
    
    /// 上傳圖片
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
    
    /// 上傳檔案 (二進制)
    func httpBinaryUploadData() {
        
        let urlString = UrlStrings["BINARY-UPLOAD"]!
        let index = 1
        let imageData = resultImageViews[index].image?.pngData()
        let formData: WWNetworking.FormDataInformation = (name: "x-filename", filename: "Large.png", contentType: .octetStream, data: imageData!)
        
        _ = WWNetworking.shared.binaryUpload(urlString: urlString, formData: formData, progress: { info in
            
            let progress = Float(info.totalBytesSent) / Float(info.totalBytesExpectedToSend)
            DispatchQueue.main.async { self.title = "\(progress)" }
            
            print(progress)
            
        }, completion: { result in
            
            switch result {
            case .failure(let error): self.displayText(error)
            case .success(let isSuccess): self.displayText(isSuccess)
            }
        })
    }
    
    /// 下載檔案 (單個)
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
    
    /// 分段下載 (單一檔案分多點合併下載)
    @MainActor
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
    
    /// 下載檔案 (多個檔案)
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

// MARK: - 小工具 (class function)
private extension ViewController {
    
    /// 顯示進度百分比
    /// - Parameters:
    ///   - index: Int
    ///   - progress: Float
    func displayProgressWithIndex(_ index: Int, progress: Float) {
        self.resultProgressLabels[index].text = "\(progress * 100.0) %"
    }
    
    /// 顯示圖片
    /// - Parameters:
    ///   - index: Int
    ///   - data: Data?
    func displayImageWithIndex(_ index: Int, data: Data?) {
        guard let data = data else { return }
        self.resultImageViews[index].image = UIImage(data: data)
    }
    
    /// 顯示文字
    /// - Parameter text: Any?
    func displayText(_ text: Any?) {
        DispatchQueue.main.async { self.resultTextField.text = "\(text ?? "NULL")" }
    }
    
    /// 尋找UIImageViewd的index
    /// - Parameters:
    ///   - urlStrings: [String]
    ///   - urlString: String?
    /// - Returns: Int?
    func displayImageIndex(urlStrings: [String], urlString: String?) -> Int? {
        
        guard let urlString = urlString,
              let index = urlStrings.firstIndex(of: urlString)
        else {
            return nil
        }

        return index
    }
}
