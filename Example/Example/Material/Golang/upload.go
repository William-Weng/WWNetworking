package main

import (
    "fmt"
    "io"
    "net/http"
    "os"
)

func uploadHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // 讀取上傳的檔案
    file, header, err := r.FormFile("file")
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    defer file.Close()

    // 建立目標檔案
    dst, err := os.Create("uploads/" + header.Filename)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer dst.Close()

    // 複製檔案內容
    if _, err := io.Copy(dst, file); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    fmt.Fprintf(w, "File uploaded successfully: %s", header.Filename)
}

func main() {
    // 建立上傳目錄
    os.MkdirAll("uploads", 0755)

    // 設定路由
    http.HandleFunc("/upload", uploadHandler)

    // 提供上傳表單的HTML
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/html")
        html := `
        <form action="/upload" method="post" enctype="multipart/form-data">
            <input type="file" name="file">
            <input type="submit" value="Upload">
        </form>`
        fmt.Fprint(w, html)
    })

    fmt.Println("Server started at :8080")
    http.ListenAndServe(":8080", nil)
}