#!/bin/sh

buildtype=release
iotype=softio #softio/phy
nconns="" # default:1 conns(2 sessions ul/dl)
waittime=10

if [ $# -gt 0 ] && [ $1 = "-h" ]
then
	echo "./run.sh <iotype(softio/phy)> <nconns(2x sessions ul/dl)> <waittime(s)> <buildtype(debug/release)"
        exit 0
fi
pkill vpp
pkill pfcpclient
if [ $# -gt 0 ]
then
        iotype=$1
fi
if [ $# -gt 1 ]
then
	if [ $2 -gt 1 ]
	then
		nconns=_$2
	else
		nconns=""
	fi
fi
if [ $# -gt 2 ]
then
        watitime=$3
fi
if [ $# -gt 3 ]
then
        buildtype=$4
fi

#start vpp
if [ $buildtype = "debug" ]
then
        echo "buildtype: Debug"
        /opt/ws/pb/upf/oai-cn5g-upf-vpp/vpp/build-root/install-vpp_debug-native/vpp/bin/vpp -c /etc/vpp/vpp.conf
else
        if [ $iotype = "softio" ]
        then
                /usr/local/bin/vpp -c ./vpp.conf
        else
                #vpp -c /etc/vpp/vpp_phy.conf
                /usr/local/bin/vpp -c ./vpp_dpdk.conf
                #/bin/vpp -c ./vpp_dpdk.conf
        fi
fi
sleep $waittime
vppctl sh int

# network setup
ifconfig n4 192.168.70.1/24 up
if [ $iotype = "softio" ]
then
	ifconfig n3 192.168.72.1/24 up
	ifconfig n6 192.168.73.1/24 up
fi
# upf session timeout (60x waittime)
timeout=$((waittime*60))
vppctl upf flow timeout ip4 $timeout
vppctl upf flow timeout tcp $timeout
vppctl upf flow timeout udp $timeout
vppctl sh upf flow timeout ip4
vppctl sh upf flow timeout udp

echo "start pfcp....!!!!" 
echo "sleeping for 300s......."
sleep 300

#start pfcp client
./pfcpclient -l 192.168.70.1:10000 -r 192.168.70.201:8805 -s ./sessions$nconns.yaml &
sleep $waittime
vppctl clear run
vppctl sh upf session
vppctl clear interfaces
vppctl clear errors
###################################################################################################################
#                        Traffic test (Setup)                                                                     #
#  UE(10.10.10.1) --> gNB(192.168.72.1) --> n3(192.168.72.201) - UPF - n6(192.168.73.201) --> DN (192.168.73.1)   #
###################################################################################################################
if [ $iotype = "softio" ]
then
        ./scapy$nconns.sh
else
        echo "Run Traffic (Ixia/Pktgen/TRex) on connected interfaces now"
fi
# for sending DL packet (n6 -> upf -> n3)
# sendp(Ether(dst="00:00:00:00:00:0b")/IP(src="192.168.73.1",dst="10.10.10.10",version=4)/ICMP(), iface="n6", count=10)

# for sending UL packet (n3 -> upf -> n6)
# from scapy.contrib.gtp import GTP_U_Header, GTPPDUSessionContainer
# sendp(Ether(dst="00:00:00:00:00:0a")/IP(src="192.168.72.1",dst="192.168.72.201")/UDP(dport=2152)/GTP_U_Header(teid=1234)/GTPPDUSessionContainer(type=1, QFI=5)/IP(src="10.10.10.10", dst="192.168.73.1", version=4)/ICMP(), iface="n3", count=10)
vppctl show run
vppctl show int
vppctl show errors
vppctl sh ip fib
