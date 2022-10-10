package msmeasure

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/url"
	"os"

	"github.com/com-gft-tsbo-source/go-common/ms-framework/microservice"
)

// UpstreamConfiguration ...
type UpstreamConfiguration struct {
	Upstream string `json:"logger"`
}

// IUpstreamConfiguration ...
type IUpstreamConfiguration interface {
	GetUpstream() string
}

// RandomSvcConfiguration ...
type RandomSvcConfiguration struct {
	RandomSvc    string `json:"randomsvc"`
	RandomSvcUrl *url.URL
}

// IRandomSvcConfiguration ...
type IRandomSvcConfiguration interface {
	GetRandomSvc() string
	GetRandomSvcUrl() *url.URL
}

// DeviceConfiguration ...
type DeviceConfiguration struct {
	DeviceType    string `json:"type"`
	DeviceAddress string `json:"address"`
}

// IDeviceConfiguration ...
type IDeviceConfiguration interface {
	GetDeviceType() string
	GetDeviceAddress() string
}

// Configuration ...
type Configuration struct {
	microservice.Configuration
	UpstreamConfiguration
	RandomSvcConfiguration
	DeviceConfiguration
}

// IConfiguration ...
type IConfiguration interface {
	microservice.IConfiguration
	IUpstreamConfiguration
	IRandomSvcConfiguration
	IDeviceConfiguration
}

// GetUpstream ...
func (cfg UpstreamConfiguration) GetUpstream() string { return cfg.Upstream }

// GetRandomSvc ...
func (cfg RandomSvcConfiguration) GetRandomSvc() string { return cfg.RandomSvc }

// GetRandomSvcUrl ...
func (cfg RandomSvcConfiguration) GetRandomSvcUrl() *url.URL { return cfg.RandomSvcUrl }

// GetDeviceType ...
func (cfg DeviceConfiguration) GetDeviceType() string { return cfg.DeviceType }

// GetDeviceAddress ...
func (cfg DeviceConfiguration) GetDeviceAddress() string { return cfg.DeviceAddress }

// ---------------------------------------------------------------------------

// InitConfigurationFromArgs ...
func InitConfigurationFromArgs(cfg *Configuration, args []string, flagset *flag.FlagSet) {
	var err error

	if flagset == nil {
		flagset = flag.NewFlagSet("ms-measure", flag.PanicOnError)
	}

	pupstream := flagset.String("upstream", "", "URL for the upstream service.")
	prandomsvc := flagset.String("randomsvc", "", "URL for the random number service.")
	pdeviceType := flagset.String("type", "", "Type of device ('thermometer' or 'hygrometer').")
	pDeviceAddress := flagset.String("address", "", "Address of the device.")

	microservice.InitConfigurationFromArgs(&cfg.Configuration, args, flagset)

	if len(*pupstream) > 0 {
		cfg.Upstream = *pupstream
	}

	if len(*prandomsvc) > 0 {
		cfg.RandomSvc = *prandomsvc
		cfg.RandomSvcUrl, err = url.Parse(cfg.RandomSvc)

		if err != nil {
			flagset.Usage()
			panic(fmt.Sprintf("Error: RandomSvc has bad url: '%s'. Error was %s!\n", cfg.RandomSvc, err.Error()))
		}
	}

	if len(*pdeviceType) > 0 {
		cfg.DeviceType = *pdeviceType
	}

	if len(*pDeviceAddress) > 0 {
		cfg.DeviceAddress = *pDeviceAddress
	}

	if len(cfg.GetConfigurationFile()) > 0 {
		file, err := os.Open(cfg.GetConfigurationFile())

		if err != nil {
			flagset.Usage()
			panic(fmt.Sprintf("Error: Failed to open onfiguration file '%s'. Error was %s!\n", cfg.GetConfigurationFile(), err.Error()))
		}

		defer file.Close()
		decoder := json.NewDecoder(file)
		configuration := Configuration{}
		err = decoder.Decode(&configuration)
		if err != nil {
			flagset.Usage()
			panic(fmt.Sprintf("Error: Failed to parse onfiguration file '%s'. Error was %s!\n", cfg.GetConfigurationFile(), err.Error()))
		}

		if len(cfg.Upstream) == 0 {
			cfg.Upstream = configuration.Upstream
		}

		if len(cfg.RandomSvc) == 0 {
			cfg.RandomSvc = configuration.RandomSvc
			cfg.RandomSvcUrl, err = url.Parse(cfg.RandomSvc)

			if err != nil {
				flagset.Usage()
				panic(fmt.Sprintf("Error: RandomSvc has bad url: '%s'. Error was %s!\n", cfg.RandomSvc, err.Error()))
			}
		}

		if len(cfg.DeviceType) == 0 {
			cfg.DeviceType = configuration.DeviceType
		}

		if len(cfg.DeviceAddress) == 0 {
			cfg.DeviceAddress = configuration.DeviceAddress
		}
	}

	if len(cfg.Upstream) == 0 {
		cfg.Upstream = os.Getenv("MS_UPSTREAM")
	}

	if len(cfg.RandomSvc) == 0 {
		cfg.RandomSvc = os.Getenv("MS_RANDOMSVC")
		cfg.RandomSvcUrl, err = url.Parse(cfg.RandomSvc)

		if err != nil {
			flagset.Usage()
			panic(fmt.Sprintf("Error: RandomSvc has bad url: '%s'. Error was %s!\n", cfg.RandomSvc, err.Error()))
		}
	}

	if len(cfg.DeviceType) == 0 {
		cfg.DeviceType = os.Getenv("MS_DEVICETYPE")
	}

	if len(cfg.DeviceAddress) == 0 {
		cfg.DeviceAddress = os.Getenv("MS_DEVICEADDRESS")
	}
}
