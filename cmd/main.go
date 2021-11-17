package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/com-gft-tsbo-source/go-ms-measure/msmeasure"
)

// ###########################################################################
// ###########################################################################
// MAIN
// ###########################################################################
// ###########################################################################

var usage []byte = []byte("ms-measure: [OPTIONS] ")

func main() {

	var ms msmeasure.MsMeasure
	msmeasure.InitFromArgs(&ms, os.Args, nil)

	go func() {

		if len(ms.GetUpstream()) == 0 {
			return
		}

		var err error
		var req *http.Request
		var res *http.Response
		var body []byte
		var url string

		for ever := true; ever; ever = true {

			if !ms.NeedsRegistration() {
				goto sleep
			}

			req = nil
			res = nil
			url = ms.GetEndpoint("device")
			req, err = http.NewRequest(http.MethodPost, ms.GetUpstream(), strings.NewReader(url))

			if err != nil {
				goto sleep
			}
			ms.SetRequestHeaders("", req, nil)

			res, err = ms.HTTPClient.Do(req)
			if err != nil {
				goto sleep
			}

			body, err = ioutil.ReadAll(res.Body)

			if err != nil {
				goto sleep
			}

			if res.StatusCode != http.StatusCreated {

				if res.StatusCode == http.StatusConflict {
					ms.GetLogger().Printf("Warning: Upstream reports device as already registered!, message was '%s'!\n", body)
				} else if res.StatusCode != http.StatusOK {
					err = errors.New(fmt.Sprintf("Upstream '%s' replied with status '%s' and message '%s'.", ms.GetUpstream(), res.StatusCode, body))
				}
			}

		sleep:
			if res != nil {
				res.Body.Close()
			}
			if err != nil {
				ms.GetLogger().Printf("Error: Failed to register at upstream '%s'!, error was '%s'!\n", ms.GetUpstream(), err.Error())
				ms.GetLogger().Println("Rertying registration in 10s.")
			}
			res = nil
			err = nil
			time.Sleep(10 * time.Second)
		}

	}()

	ms.Run()
}
