package main

import (
	"fmt"
	"log"
	"os"

	"gopkg.in/yaml.v3"
)

// This the Kubernetes Cluster Configuration
type Config struct {
	ClusterName string `yaml:"cluster_name"`

	// List of Machine Configurations
	Machines []MachineConfig `yaml:"machines"`
}

type MachineConfig struct {
	Name string `yaml:"machine_name"`
	Type string `yaml:"machine_type"` // This can be either "master" or "worker" or "both"

	OSConfig  OSConfig
	SshConfig SshConfig

	ListOfCommands []BashCommand `yaml:"listofcommands"`
}

type OSConfig struct {
	Hostname string `yaml:"hostname"`
	Username string `yaml:"username"`
	Password string `yaml:"password"`
}

type SshConfig struct {
	IPAddress  string   `yaml:"ipaddress"`
	Port       int      `yaml:"port"`
	SshKey     string   `yaml:"sshkey"` // This should be the path to the ssh key
	ListString []string `yaml:"liststring"`
}

type BashCommand struct {
	CWD     string `yaml:"cwd"`
	Command string `yaml:"command"`
}

func readYamlFile(filepath string) {
	// Read the file as bytes
	data, err := os.ReadFile(filepath)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	config := Config{}

	parseErr := yaml.Unmarshal([]byte(data), &config)
	if parseErr != nil {
		log.Fatalf("error: %v", parseErr)
	}
	fmt.Printf("--- t:\n%v\n\n", config)

	fmt.Println(string(data))
}

func writeYamlFile(filepath string, config *Config) {
	data, err := yaml.Marshal(config)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	// RW-R--R--
	err = os.WriteFile(filepath, data, 0644)
	if err != nil {
		log.Fatalf("error: %v", err)
	}
}

func makeConfigTemplate() *Config {
	config := Config{
		ClusterName: "testcluster",

		Machines: []MachineConfig{
			{
				Name: "testmachine",

				OSConfig: OSConfig{
					Hostname: "testhostname",
					Username: "testuser",
					Password: "testpassword",
				},

				SshConfig: SshConfig{
					IPAddress: "192.168.1.100",
					// Port:      22,
					SshKey: `----------`,
					ListString: []string{
						"string1",
						"string2",
					},
				},

				ListOfCommands: []BashCommand{
					{"~", "ls -la"},
					{"~.ssh/", "ls -la"},
				},
			},

			{
				Name: "testmachine2",

				OSConfig: OSConfig{
					Hostname: "testhostname",
					Username: "testuser",
					Password: "testpassword",
				},

				SshConfig: SshConfig{
					IPAddress: "192.168.1.101",
					// Port:      22,
					SshKey: `----------`,
					ListString: []string{
						"string1",
						"string2",
						"string2",
						"string2",
					},
				},

				ListOfCommands: []BashCommand{
					{"~", "ls -la"},
				},
			},
		},
	}
	return &config
}
