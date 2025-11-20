#!/bin/sh

vppctl clear interfaces
vppctl clear trace
vppctl trace add virtio-input 300
./pfcpclient -l 192.168.70.1:10000 -r 192.168.70.201:8805 -s sessions.yaml &
./scapy.sh 
vppctl sh trace
vppctl sh int
pkill pfcpclient
wait
