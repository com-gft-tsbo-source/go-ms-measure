package msmeasure

import (
	"github.com/com-gft-tsbo-source/go-common/device/implementation/devicedescriptor"
	"github.com/com-gft-tsbo-source/go-common/device/implementation/devicesimulation"
	"github.com/com-gft-tsbo-source/go-common/device/implementation/devicevalue"
	"github.com/com-gft-tsbo-source/go-common/ms-framework/microservice"
)

// ###########################################################################
// ###########################################################################
// MsMeasure Response - Device
// ###########################################################################
// ###########################################################################

// DeviceResponse Encapsulates the reploy of ms-measure
type DeviceResponse struct {
	microservice.Response
	devicedescriptor.DeviceDescriptor
	devicesimulation.DeviceSimulation
	URLDevice  string `json:"urlDevice"`
	URLMeasure string `json:"urlMeasure"`
	URLStatus  string `json:"urlStatus"`
}

// ###########################################################################

// InitDeviceResponse Constructor of a response of ms-measure
func InitDeviceResponse(r *DeviceResponse, code int, status string, ms *MsMeasure) {
	microservice.InitResponseFromMicroService(&r.Response, ms, code, status)
	devicedescriptor.InitFromDeviceDescriptor(&r.DeviceDescriptor, &ms.DeviceDescriptor)
	devicesimulation.InitFromDeviceSimulation(&r.DeviceSimulation, &ms.DeviceSimulation)
	r.URLDevice = ms.GetEndpoint("device")
	r.URLMeasure = ms.GetEndpoint("measure")
	r.URLStatus = ms.GetEndpoint("status")
}

// NewDeviceResponse ...
func NewDeviceResponse(code int, status string, ms *MsMeasure) *DeviceResponse {
	var r DeviceResponse
	InitDeviceResponse(&r, code, status, ms)
	return &r
}

// ###########################################################################
// ###########################################################################
// MsMeasure Response - Measure
// ###########################################################################
// ###########################################################################

// MeasureResponse Encapsulates the reploy of ms-measure
type MeasureResponse struct {
	microservice.Response
	devicedescriptor.DeviceDescriptor
	devicevalue.DeviceValue
	RnrSvcVersion string `json:"rnrSvcVersion"`
	RnrSvcName    string `json:"rnrSvcName"`
}

// ###########################################################################

// InitMeasureResponse Constructor of a response of ms-measure
func InitMeasureResponse(r *MeasureResponse, code int, status string, ms *MsMeasure) {
	microservice.InitResponseFromMicroService(&r.Response, ms, code, status)
	devicedescriptor.InitFromDeviceDescriptor(&r.DeviceDescriptor, &ms.Device)
	ms.FillDeviceValue(&r.DeviceValue)
	r.RnrSvcVersion = "???"
	r.RnrSvcName = "???"
}

// NewMeasureResponse ...
func NewMeasureResponse(code int, status string, ms *MsMeasure) *MeasureResponse {
	var r MeasureResponse
	InitMeasureResponse(&r, code, status, ms)
	return &r
}
