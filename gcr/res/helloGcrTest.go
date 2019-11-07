package main

import (
    "fmt"
    "net/http"
    "time"
)

func handler(w http.ResponseWriter, r *http.Request) {
    now := time.Now()
    fmt.Fprintf(w, "Hello GCR Test!\nThe local time now is: %s", now.Format("2006-01-02 15:04:05"))
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":80", nil)
}
