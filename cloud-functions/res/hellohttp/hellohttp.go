package HelloHttp
/*
 * @see https://cloud.google.com/functions/docs/calling/http
 */

import (
    "encoding/json"
    "fmt"
    "html"
    "net/http"
)

func HelloHttp(w http.ResponseWriter, r *http.Request) {
    var d struct {
        Name string `json:"name"`
    }
    if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
        fmt.Fprint(w, err)
        return
    }
    if d.Name == "" {
        fmt.Fprint(w, "Warning, no name")
        return
    }
    fmt.Fprintf(w, "Hello, %s!", html.EscapeString(d.Name))
}
