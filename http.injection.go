package main

import (
	"fmt"
	"regexp"

	"google.golang.org/protobuf/compiler/protogen"
	"google.golang.org/protobuf/types/descriptorpb"
)

// getRegistryName find service register name by location and option
func getRegistryName(gen *protogen.Plugin, service *protogen.Service) string {
	var pb *descriptorpb.FileDescriptorProto = nil
	for _, f := range gen.Request.ProtoFile {
		// api/ping-service/v1/services/ping.service.v1.proto
		if f.Name != nil && *f.Name == service.Location.SourceFile {
			pb = f
			break
		}
	}

	if pb == nil {
		return "CANT FIND SOURCE FILE FOR " + service.GoName
	}

	var srv *descriptorpb.ServiceDescriptorProto = nil
	for _, f := range pb.Service {
		if f.Name != nil && *f.Name == service.GoName {
			srv = f
			break
		}
	}

	if srv == nil {
		return "CANT FIND SERVICE FOR " + service.GoName
	}

	options := srv.GetOptions()
	if options == nil {
		return "HAVEN'T SET OPTION OF SERVICE NAME FOR " + service.GoName
	}
	// [api.ping.service.pingservicev1.name]:"permission-service"
	// check and extract name from string
	regText := fmt.Sprintf(`\[%s.name\]:\"(.+?)\"`, *pb.Package)
	reg := regexp.MustCompile(regText)
	extractFormula := reg.FindStringSubmatch(options.String())
	if len(extractFormula) <= 1 {
		return "DOESN'T MATCH OPTION STRING FOR " + service.GoName
	}

	return extractFormula[1]
}
