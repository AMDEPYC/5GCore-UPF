#!/bin/sh

# network setup
ifconfig n4 192.168.70.1/24 up

#start pfcp client
pkill pfcpclient
sleep 10
./pfcpclient -l 192.168.70.1:10000 -r 192.168.70.201:8805 -s ./sessions.yaml &
