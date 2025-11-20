from trex_stl_lib.api import *
from scapy.all import *
from scapy.contrib.gtp import GTP_U_Header


class STLGtpuFixedUEs(object): 

    def __init__(self):
        # Outer GTP-U endpoints
        self.upf_ip = "192.168.72.201"       # UPF tunnel endpoint
        self.ran_ip = "192.168.72.1"         # RAN tunnel endpoint
        self.dst_ip = "192.168.73.1"         # Inner UE destination (post-GTPU)

        # UE IPs per session
        self.ue_ips = [
            "10.10.10.10", "11.11.11.11", "12.12.12.12", "13.13.13.13",
            "14.14.14.14", "15.15.15.15", "16.16.16.16", "17.17.17.17",
            "18.18.18.18", "19.19.19.19", "20.20.20.20", "21.21.21.21",
            "22.22.22.22", "23.23.23.23", "24.24.24.24", "25.25.25.25",
            "26.26.26.26", "27.27.27.27", "28.28.28.28", "29.29.29.29",
            "30.30.30.30", "31.31.31.31", "32.32.32.32", "33.33.33.33",
            "34.34.34.34", "35.35.35.35", "36.36.36.36", "37.37.37.37",
            "38.38.38.38", "39.39.39.39", "40.40.40.40", "41.41.41.41"
        ]

        # General stream parameters
        self.size = 96                       # Fixed packet size
        self.pps = 1000                      # Packets per second per stream
        self.base_teid = 1234                # Base TEID for GTP-U sessions

        # Fixed list of destination MACs (replace with your VF MACs)
        self.dst_macs = [
            #"30:11:22:33:44:01",
            #"30:11:22:33:44:02",
            "30:11:22:33:44:03",
            #"30:11:22:33:44:04",
            #"30:11:22:33:44:05",
            #"30:11:22:33:44:06",
            #"30:11:22:33:44:07",
            #"30:11:22:33:44:08",
            #"30:11:22:33:44:09",
            #"30:11:22:33:44:0a",
            "30:11:22:33:44:0b"
            #"30:11:22:33:44:0c",
            #"30:11:22:33:44:0d",
            #"30:11:22:33:44:0e",
            #"30:11:22:33:44:0f",
            #"30:11:22:33:44:10"
        ]
        # Number of VFs to map streams onto
        self.num_macs = len(self.dst_macs)

    # -----------------------------------------------------
    # Utility functions
    # -----------------------------------------------------

    def dst_mac_from_index(self, index):
        """Pick destination MAC from predefined list (cyclic)."""
        return self.dst_macs[index % len(self.dst_macs)]

    def ip_from_index(self, base_ip, index):
        """Increment last octet of base IP."""
        octets = list(map(int, base_ip.split('.')))
        octets[3] = (octets[3] + index) % 255
        return '.'.join(map(str, octets))

    # -----------------------------------------------------
    # Stream creation
    # -----------------------------------------------------

    def create_gtpu_stream(self, src_ip, teid, ran_ip, dst_mac):
        """Build one GTP-U encapsulated ICMP stream."""
        GTPU_PORT = 2152

        base_pkt = (
            Ether(dst=dst_mac, src="a0:88:c2:dc:ac:32") /
            IP(src=ran_ip, dst=self.upf_ip) /
            UDP(sport=GTPU_PORT, dport=GTPU_PORT) /
            GTP_U_Header(teid=teid, gtp_type=255) /
            IP(src=src_ip, dst=self.dst_ip) /
            ICMP()
        )

        pad = max(0, self.size - len(base_pkt)) * "x"
        pkt = STLPktBuilder(pkt=base_pkt / pad)
        return STLStream(packet=pkt, mode=STLTXCont(pps=self.pps))

    # -----------------------------------------------------
    # Generate all streams
    # -----------------------------------------------------

    def get_streams(self, direction=0, **kwargs):
        """
        For each destination MAC (VF), create all UE streams.
        e.g. MAC0 -> UE1..UE64, MAC1 -> UE1..UE64, etc.
        """
        streams = []

        for mac_index in range(self.num_macs):
            dst_mac = self.dst_mac_from_index(mac_index)
            for i, ue_ip in enumerate(self.ue_ips):
                teid = self.base_teid + i + (mac_index * 1000)
                ran_ip = self.ip_from_index(self.ran_ip, i)
                streams.append(self.create_gtpu_stream(ue_ip, teid, ran_ip, dst_mac))

        return streams


# -----------------------------------------------------
# TRex registration entry point
# -----------------------------------------------------

def register():
    return STLGtpuFixedUEs()
