package main

import (
	"fmt"
	"net/http"
)

type Account struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type HTTPError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// ShowAccount godoc
// @Summary      Show an account
// @Description  get string by ID
// @ID           get-string-by-int
// @Accept       json
// @Produce      json
// @Param        id   path      int  true  "Account ID"
// @Success      200  {object}  Account
// @Failure      400  {object}  HTTPError
// @Failure      404  {object}  HTTPError
// @Failure      500  {object}  HTTPError
// @Router       /accounts/{id} [get]
func ShowAccount(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Account")
}

func main() {
	http.HandleFunc("/account", ShowAccount)
	http.ListenAndServe(":8080", nil)
}
