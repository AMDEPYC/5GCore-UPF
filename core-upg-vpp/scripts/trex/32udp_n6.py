from trex_stl_lib.api import *


class STLFourFixedStreams(object):

    def __init__(self):
        # Fixed parameters
        self.src_ip = "192.168.73.1"
        self.dst_ips = [
            "10.10.10.10", "11.11.11.11", "12.12.12.12", "13.13.13.13",
            "14.14.14.14", "15.15.15.15", "16.16.16.16", "17.17.17.17",
            "18.18.18.18", "19.19.19.19", "20.20.20.20", "21.21.21.21",
            "22.22.22.22", "23.23.23.23", "24.24.24.24", "25.25.25.25",
            "26.26.26.26", "27.27.27.27", "28.28.28.28", "29.29.29.29",
            "30.30.30.30", "31.31.31.31", "32.32.32.32", "33.33.33.33",
            "34.34.34.34", "35.35.35.35", "36.36.36.36", "37.37.37.37",
            "38.38.38.38", "39.39.39.39", "40.40.40.40", "41.41.41.41"
        ]
        self.size = 64
        self.pps = 1000  # packets per second per stream

        # Fixed list of destination MACs (replace with your VF MACs)
        self.dst_macs = [
            "40:11:22:33:44:01",
            "40:11:22:33:44:02",
            "40:11:22:33:44:03",
            "40:11:22:33:44:04",
            "40:11:22:33:44:05",
            "40:11:22:33:44:06",
            "40:11:22:33:44:07",
            "40:11:22:33:44:08",
            "40:11:22:33:44:09",
            "40:11:22:33:44:0a",
            "40:11:22:33:44:0b",
            "40:11:22:33:44:0c",
            "40:11:22:33:44:0d",
            "40:11:22:33:44:0e",
            "40:11:22:33:44:0f",
            "40:11:22:33:44:10"
        ]
        # Number of VFs to map streams onto
        self.num_macs = len(self.dst_macs)

        # Source MAC (can be TRex port MAC)
        self.src_mac = "a0:88:c2:dc:ac:33"

    # --------------------------
    # Utility function
    # --------------------------
    def dst_mac_from_index(self, index):
        """Pick destination MAC from predefined list (cyclic)."""
        return self.dst_macs[index % len(self.dst_macs)]

    # --------------------------
    # Packet creation
    # --------------------------
    def create_stream(self, dst_ip, dst_mac):
        base_pkt = Ether(src=self.src_mac, dst=dst_mac) / IP(src=self.src_ip, dst=dst_ip) / ICMP()
        pad = max(0, self.size - len(base_pkt)) * 'x'
        pkt = STLPktBuilder(pkt=base_pkt / pad)
        return STLStream(packet=pkt, mode=STLTXCont(pps=self.pps))

    # --------------------------
    # Generate streams
    # --------------------------
    def get_streams(self, direction=0, **kwargs):
        streams = []
        for mac_index in range(self.num_macs):
            dst_mac = self.dst_mac_from_index(mac_index)
            for dst_ip in self.dst_ips:
                streams.append(self.create_stream(dst_ip, dst_mac))
        return streams


# --------------------------
# TRex registration
# --------------------------
def register():
    return STLFourFixedStreams()
