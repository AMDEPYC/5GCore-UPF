#!/bin/sh

mode=release

pkill vpp
pkill pfcpclient
if [ $# -gt 0 ]
then
	mode=debug
fi

#start vpp
if [ $mode = "debug" ]
then
	echo "Debug mode"
	/home/ubuntu/workspace/oai-cn5g-upf-vpp/vpp/build-root/install-vpp_debug-native/vpp/bin/vpp -c /etc/vpp.conf
else
	/bin/vpp -c ./vpp.conf
fi
sleep 10
vppctl sh int
vppctl upf flow timeout ip4 120
vppctl upf flow timeout tcp 120
vppctl upf flow timeout udp 120
vppctl sh upf flow timeout ip4
vppctl sh upf flow timeout udp

# network setup
ifconfig n4 192.168.70.1/24 up
ifconfig n3 192.168.72.1/24 up
ifconfig n6 192.168.73.1/24 up

#start pfcp client
./pfcpclient -l 192.168.70.1:10000 -r 192.168.70.201:8805 -s ./sessions_4.yaml &
sleep 10
vppctl clear run
vppctl sh upf session
vppctl clear interfaces
vppctl clear errors
###################################################################################################################
#                        Traffic test (Setup)  									  #			
#  UE(10.10.10.1) --> gNB(192.168.72.1) --> n3(192.168.72.201) - UPF - n6(192.168.73.201) --> DN (192.168.73.1)   #
###################################################################################################################
./scapy_4.sh
# for sending DL packet (n6 -> upf -> n3)
# sendp(Ether(dst="00:00:00:00:00:0b")/IP(src="192.168.73.1",dst="10.10.10.10",version=4)/ICMP(), iface="n6", count=10)

# for sending UL packet (n3 -> upf -> n6)
# from scapy.contrib.gtp import GTP_U_Header, GTPPDUSessionContainer 
# sendp(Ether(dst="00:00:00:00:00:0a")/IP(src="192.168.72.1",dst="192.168.72.201")/UDP(dport=2152)/GTP_U_Header(teid=1234)/GTPPDUSessionContainer(type=1, QFI=5)/IP(src="10.10.10.10", dst="192.168.73.1", version=4)/ICMP(), iface="n3", count=10)
vppctl show run
vppctl show int
vppctl show errors
vppctl sh ip fib
