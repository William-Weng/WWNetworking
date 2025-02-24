package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

func uploadBinaryHandler(w http.ResponseWriter, r *http.Request) {

	if r.Header.Get("Content-Type") != "application/octet-stream" {
		http.Error(w, "Invalid content type", http.StatusBadRequest)
		return
	}

	filename := r.Header.Get("X-Filename")
	dst, err := os.Create("uploads/" + filename)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, r.Body); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func main() {

	os.MkdirAll("uploads", 0755)

	// 設定路由
	http.HandleFunc("/binaryUpload", uploadBinaryHandler)

	fmt.Println("Server started at :8080")
	http.ListenAndServe(":8080", nil)
}
