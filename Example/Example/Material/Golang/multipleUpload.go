// package main

// import (
// 	"fmt"
// 	"io"
// 	"net/http"
// 	"os"
// )

// func uploadHandler(w http.ResponseWriter, r *http.Request) {
// 	// 設定最大內存限制 (例如 10MB)
// 	r.ParseMultipartForm(10 << 20)

// 	// 取得上傳的檔案
// 	files := r.MultipartForm.File["files"] // "files" 是 form 中的 name

// 	for _, fileHeader := range files {
// 		// 開啟上傳的檔案
// 		file, err := fileHeader.Open()
// 		if err != nil {
// 			http.Error(w, err.Error(), http.StatusBadRequest)
// 			return
// 		}
// 		defer file.Close()

// 		// 建立目標檔案
// 		dst, err := os.Create("uploads/" + fileHeader.Filename)
// 		if err != nil {
// 			http.Error(w, err.Error(), http.StatusInternalServerError)
// 			return
// 		}
// 		defer dst.Close()

// 		// 複製檔案內容
// 		if _, err := io.Copy(dst, file); err != nil {
// 			http.Error(w, err.Error(), http.StatusInternalServerError)
// 			return
// 		}
// 	}
// }

// func main() {
// 	// 建立上傳目錄
// 	os.MkdirAll("uploads", 0755)

// 	// 設定路由
// 	http.HandleFunc("/multipleUpload", uploadHandler)

// 	// 提供上傳表單的HTML
// 	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
// 		w.Header().Set("Content-Type", "text/html")
// 		html := `
//         <form action="/multipleUpload" method="post" enctype="multipart/form-data">
//             <input type="file" name="files" multiple>
//             <input type="submit" value="Upload">
//         </form>`
// 		fmt.Fprint(w, html)
// 	})

// 	fmt.Println("Server started at :8765")
// 	http.ListenAndServe(":8765", nil)
// }
