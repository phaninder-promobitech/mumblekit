#!/bin/bash
# Note: This script requires a protobuf installation in /usr/local/, including
# a compiled protc-gen-objc in there as well. The ObjC plugin can be built by
# issuing these commands from the root of th MumbleKit source tree:
#  cd 3rdparty/protobuf/
#  ./autogen.sh
#  ./configure --prefix=/usr/local
#  make
#  sudo make install

#
# Grab the latest Mumble.proto file from desktop Mumble.
#
# curl "https://raw.githubusercontent.com/mumble-voip/mumble/master/src/Mumble.proto" > Mumble.proto.clean
# cat Mumble.proto.objc Mumble.proto.clean > Mumble.proto
sed -i '' -e  's, hash =, cert_hash =,g' Mumble.proto
/usr/local/bin/protoc --objc_out=. \
	-I. \
	-I../3rdparty/protobuf/src/compiler/ \
	-I/usr/local/include \
	Mumble.proto \
	../3rdparty/protobuf/src/compiler/google/protobuf/objectivec-descriptor.proto
rm Mumble.proto.clean
# Mangle headers so they work with our slightly wonky setup.
sed -i '' -e 's,<ProtocolBuffers/ProtocolBuffers.h>,"ProtocolBuffers.h",' Mumble.pb.h
sed -i '' -e 's,<ProtocolBuffers/ProtocolBuffers.h>,"ProtocolBuffers.h",' ObjectivecDescriptor.pb.h

#
# Patch the generated Descriptor.pb.m if needed.
#
if [ "`grep ProtocolBuffers.h Descriptor.pb.m`" != "" ]; then exit; fi
cat >Descriptor.pb.m.patch <<EOF
--- ./Descriptor.pb.m
+++ ./Descriptor.pb.m
@@ -1,3 +1,4 @@
 // Generated by the protocol buffer compiler.  DO NOT EDIT!
 
+#include "ProtocolBuffers.h"
 #import "Descriptor.pb.h"
 
EOF
patch --no-backup-if-mismatch -p0 < Descriptor.pb.m.patch
rm Descriptor.pb.m.patch
