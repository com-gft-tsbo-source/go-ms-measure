package msmeasure

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/url"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/com-gft-tsbo-source/go-common/device"
	"github.com/com-gft-tsbo-source/go-common/device/implementation/devicevalue"
	"github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher"
	"github.com/com-gft-tsbo-source/go-common/ms-framework/microservice"
)

// ###########################################################################
// ###########################################################################
// MsMeasure
// ###########################################################################
// ###########################################################################

// MsMeasure Encapsulates the ms-measure data
type MsMeasure struct {
	microservice.MicroService
	*UpstreamConfiguration
	*RandomSvcConfiguration
	*DeviceConfiguration

	device.Device
	starttime   time.Time
	lastRequest time.Time
}

type randomFn = func(url string) (value int, version string)

type RandomNumber struct {
	microservice.Response
	Value int `json:value`
}

// ###########################################################################

// InitFromArgs ...
func InitFromArgs(ms *MsMeasure, args []string, flagset *flag.FlagSet) *MsMeasure {
	var cfg Configuration

	if flagset == nil {
		flagset = flag.NewFlagSet("ms-measure", flag.PanicOnError)
	}

	InitConfigurationFromArgs(&cfg, args, flagset)
	ms.UpstreamConfiguration = &cfg.UpstreamConfiguration
	ms.RandomSvcConfiguration = &cfg.RandomSvcConfiguration
	ms.DeviceConfiguration = &cfg.DeviceConfiguration
	microservice.Init(&ms.MicroService, &cfg.Configuration, nil)

	if cfg.GetDeviceType() == "thermometer" {
		device.InitThermometer(&ms.Device, cfg.GetDeviceAddress(), 400, 300, -1, 50)
	} else if cfg.DeviceType == "hygrometer" {
		device.InitHygrometer(&ms.Device, cfg.GetDeviceAddress(), 9400, 500, -1, 100)
	} else {
		flagset.Usage()
		panic("Error: Wrong device! Use 'thermometer' or 'hygrometer'.")
	}

	if len(ms.GetRandomSvc()) > 0 {

		_, error := url.Parse(ms.GetRandomSvc())

		if error != nil {
			flagset.Usage()
			panic(fmt.Sprintf("Error: Could not parse random svc url '%s'!.", ms.GetRandomSvc()))
		}
	}

	ms.starttime = time.Now()
	ms.lastRequest = ms.starttime
	measureHandler := ms.DefaultHandler()
	measureHandler.Get = ms.httpGetMeasure
	ms.AddHandler("/measure", measureHandler)
	deviceHandler := ms.DefaultHandler()
	deviceHandler.Get = ms.httpGetDevice
	ms.AddHandler("/device", deviceHandler)
	return ms
}

// ---------------------------------------------------------------------------

var deviceMutex sync.Mutex

func fmt_msg_header(version string, environment string, address string) string {
	if len(environment) > 0 {
		return fmt.Sprintf("'%s' in '%s' @ '%s'.", version, environment, address)
	} else {
		return fmt.Sprintf("'%s' @ '%s'.", version, address)
	}
}

func (ms *MsMeasure) httpGetMeasure(w http.ResponseWriter, r *http.Request) (status int, contentLen int, msg string) {
	var v devicevalue.DeviceValue
	deviceMutex.Lock()
	value, name, version, trace := ms.getRandomNumber(r)
	ms.TranslateValue(value)
	deviceMutex.Unlock()
	ms.lastRequest = time.Now()
	status = http.StatusOK
	ms.FillDeviceValue(&v)
	environment := r.Header.Get("X-Environment")
	msg = fmt_msg_header(ms.GetVersion(), environment, ms.GetDeviceAddress())
	msg = fmt.Sprintf("%s reported value '%s' with rnrsrc '%s@%s'.", msg, v.GetFormatted(), name, version)
	response := NewMeasureResponse(status, msg, ms)
	response.Trace = *trace
	response.RnrSvcVersion = version
	response.RnrSvcName = name
	ms.SetResponseHeaders("application/json; charset=utf-8", w, r)
	w.WriteHeader(status)
	contentLen = ms.Reply(w, response)
	return status, contentLen, msg
}

// ---------------------------------------------------------------------------

func (ms *MsMeasure) httpGetDevice(w http.ResponseWriter, r *http.Request) (status int, contentLen int, msg string) {
	status = http.StatusOK
	environment := r.Header.Get("X-Environment")
	msg = fmt_msg_header(ms.GetVersion(), environment, ms.GetDeviceAddress())
	msg = fmt.Sprintf("%s reported details of device.", msg)
	response := NewDeviceResponse(status, msg, ms)
	ms.SetResponseHeaders("application/json; charset=utf-8", w, r)
	w.WriteHeader(status)
	contentLen = ms.Reply(w, response)
	return status, contentLen, msg
}

// ---------------------------------------------------------------------------

var maxLastRequest time.Duration = time.Duration(10 * time.Second)

// NeedsRegistration ...
func (ms *MsMeasure) NeedsRegistration() bool {
	if ms.starttime == ms.lastRequest {
		return true
	}
	now := time.Now()
	if now.Sub(ms.lastRequest) > maxLastRequest {
		return true
	}
	return false
}

// ---------------------------------------------------------------------------

var seededRand *rand.Rand = rand.New(rand.NewSource(time.Now().UnixNano()))
var re_find_random_number = regexp.MustCompile("^.*\\s+received\\s+[\"']?(?P<value>\\d+)[\"']?\\s+from\\s+[\"']?(?P<server>.*?)[\"']?\\.?$")
var re_find_random_number_group_value = re_find_random_number.SubexpIndex("value")
var re_find_random_number_group_server = re_find_random_number.SubexpIndex("server")

func (ms *MsMeasure) getRandomNumberInternal(in *http.Request) (int, string, string, *dispatcher.Trace) {

	// var stdout, stderr bytes.Buffer
	var trace dispatcher.Trace
	dispatcher.InitTraceFromDispatcher(&trace, ms, http.StatusOK, "200 - Ok")
	trace.Hostname = ""
	trace.Name = "internal"
	trace.Version = "1.0.0"
	value := seededRand.Intn(100)

	return value, "internal", "n/a", &trace
}

func (ms *MsMeasure) getRandomNumberCmd(in *http.Request) (int, string, string, *dispatcher.Trace) {

	var stdout, stderr bytes.Buffer
	var trace dispatcher.Trace
	dispatcher.InitTraceFromDispatcher(&trace, ms, http.StatusOK, "200 - Ok")
	trace.Version = "cmd"

	cmd := exec.Command("/bin/sh", "-c", ms.GetRandomSvc())
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()

	if err != nil {
		ms.GetLogger().Printf("Command '%s' failed with '%s'.\n", ms.GetRandomSvc(), err)
		return 0, "failed", "n/a", &trace
	}

	outStr, errStr := string(stdout.Bytes()), string(stderr.Bytes())

	if len(errStr) > 0 {
		ms.GetLogger().Printf("Command '%s' reported error: '%s'.\n", ms.GetRandomSvc(), errStr)
		return 0, "failed", "n/a", &trace
	}

	scanner := bufio.NewScanner(strings.NewReader(outStr))
	for scanner.Scan() {
		line := scanner.Text()
		matches := re_find_random_number.FindStringSubmatch(line)

		if matches == nil {
			continue
		}

		value_str := matches[re_find_random_number_group_value]
		server := matches[re_find_random_number_group_server]
		value_int, err := strconv.Atoi(value_str)

		if err != nil {
			ms.GetLogger().Printf("Command '%s' failed to convert '%s' to int.'.\n", ms.GetRandomSvc(), value_str)
			return 0, "failed", "n/a", &trace
		}
		return value_int, server, "n/a", &trace
	}

	return 0, "failed", "n/a", &trace
}

func (ms *MsMeasure) getRandomNumberRest(in *http.Request) (int, string, string, *dispatcher.Trace) {
	var err error
	var req *http.Request
	var res *http.Response
	var body []byte
	var url url.URL = *ms.GetRandomSvcUrl()
	var trace dispatcher.Trace
	dispatcher.InitTraceFromDispatcher(&trace, ms, http.StatusOK, "200 - Ok")

	req, err = http.NewRequest(http.MethodGet, url.String(), strings.NewReader(url.String()))

	if err != nil {
		ms.GetLogger().Printf("Error: Failed to receive random number at randomsvc '%s'!, error was '%s'!\n", ms.GetRandomSvc(), err.Error())
		return 0, "failed", "n/a", &trace
	}

	ms.SetRequestHeaders("", req, in)

	res, err = ms.HTTPClient.Do(req)
	if err != nil {
		ms.GetLogger().Printf("Error: Failed to receive random number at randomsvc '%s'!, error was '%s'!\n", ms.GetRandomSvc(), err.Error())
		return 0, "failed", "n/a", &trace
	}

	body, err = ioutil.ReadAll(res.Body)
	ms.HTTPClient.CloseIdleConnections()

	if err != nil {
		ms.GetLogger().Printf("Error: Failed to receive random number at randomsvc '%s'!, error was '%s'!\n", ms.GetRandomSvc(), err.Error())
		return 0, "failed", "n/a", &trace
	}

	if res.StatusCode != http.StatusOK {
		ms.GetLogger().Printf("RandomSvc '%s' replied with status '%s' and message '%s'.\n", ms.GetRandomSvc(), res.StatusCode, body)
		return 0, "failed", "n/a", &trace
	}

	if res != nil {
		res.Body.Close()
	}

	if err != nil {
		ms.GetLogger().Printf("Error: Failed to receive random number at randomsvc '%s'!, error was '%s'!\n", ms.GetRandomSvc(), err.Error())
		return 0, "failed", "n/a", &trace
	}

	var randomNumber RandomNumber
	_ = json.Unmarshal(body, &randomNumber)
	trace.Traces = make([]dispatcher.Trace, 1)
	trace.Traces[0] = randomNumber.Trace

	return randomNumber.Value, randomNumber.Name, randomNumber.Version, &trace
}

// getRandomNumber ...
func (ms *MsMeasure) getRandomNumber(in *http.Request) (int, string, string, *dispatcher.Trace) {
	// var trace dispatcher.Trace
	// dispatcher.InitTraceFromDispatcher(&trace, ms, "200 - Ok")

	randomSvc := ms.GetRandomSvc()
	// fmt.Printf("'%s' (%d)\n", randomSvc, len(randomSvc))
	// if len(randomSvc) == 0 {
	// 	var internalTrace dispatcher.Trace
	// 	dispatcher.InitTraceFromDispatcher(&internalTrace, ms, "XXX")
	// 	trace.Traces = make([]dispatcher.Trace, 1)
	// 	trace.Traces[0] = internalTrace
	// }

	if len(randomSvc) == 0 || strings.HasPrefix(randomSvc, ".") {
		return ms.getRandomNumberInternal(in)
	}

	if strings.HasPrefix(randomSvc, "/") {
		return ms.getRandomNumberCmd(in)
	}

	return ms.getRandomNumberRest(in)
}
