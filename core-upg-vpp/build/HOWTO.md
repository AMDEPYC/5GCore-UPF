
How to install VPP UPF packages
===============================
* Install VPP in /usr/local/ directory
* Install UPG-VPP UPF plugin in /usr/local/lib/x86_64-linux-gnu/vpp_plugins/ directory
* Copy the external dependancies in /opt/vpp/external directory to /usr/local directory

How to run VPP UPF
===================
* Check the VPP cores and dpdk devices/workers configuration is aligned with test env
* Verify the VPP plugins path is updated properly
* To enable power management, verify `pmd-mgmt` and `empty-polls` configured properly. 
* For sanity, run VPP with tap (softio) interface (./run.sh) OR 
  (vpp -c ./vpp.conf; sleep 10; ./smf_pfcp.sh; ./scapy.sh)
* To run VPP with dpdk
  # vpp -c ./vpp_dpdk.conf (verify $PATH & $LD_LIBRARY_PATH set properly)
  # sleep 10; 
  # ./smf_pfcp.sh 
  # vppctl sh upf session (to verify session establishment)
  # run traffic generation (refer scapy.sh to configure traffic profile)
