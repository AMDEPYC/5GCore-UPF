#!/usr/bin/python3

import yaml
import sys

num_sessions = 64
pfcp_session = "pfcp_sessions_with_urr.yaml"
if len(sys.argv) > 1:
    try:
        num_sessions = int(sys.argv[1])
    except ValueError:
        print(f"Invalid input '{sys.argv[1]}', using default num_sessions=64")
if len(sys.argv) > 2:
    try:
        pfcp_session = sys.argv[2]
    except ValueError:
        print(f"Invalid input '{sys.argv[2]}', using default pfcp_sessions_with_urr.yaml")

print(f"Generating {num_sessions} sessions")

ue_ip_base = [10, 10, 10, 10]
upf_ip = "192.168.72.201"
teid_ul_base = 1234
teid_dl_base = 4321

sessions = []

for i in range(num_sessions):
    # generate UE IPs
    ue_ip = f"{ue_ip_base[0] + i}.{ue_ip_base[1] + i}.{ue_ip_base[2] + i}.{ue_ip_base[3] + i}"
    seid_ul = i * 2
    seid_dl = i * 2 + 1
    pdr_ul_id = i * 2
    pdr_dl_id = i * 2 + 1
    far_ul_id = i * 2 + 10
    far_dl_id = i * 2 + 11
    urr_ul_id = i * 2 + 100
    urr_dl_id = i * 2 + 101

    # uplink session
    sessions.append({
        "seid": seid_ul,
        "pdrs": [
            {
                "pdrID": pdr_ul_id,
                "precedence": 0,
                "pdi": {
                    "sourceInterface": "Access",
                    "localFTEID": {
                        "teid": teid_ul_base + i,
                        "ip4": upf_ip
                    },
                    "networkInstance": "access",
                    "ueIPAddress": {
                        "isDestination": False,
                        "ip4": ue_ip
                    }
                },
                "outerHeaderRemoval": "OUTER_HEADER_GTPU_UDP_IPV4",
                "farID": far_ul_id,
                "urrIDs": [urr_ul_id]
            }
        ],
        "fars": [
            {
                "farID": far_ul_id,
                "applyAction": "Forward",
                "forwardingParameters": {
                    "destinationInterface": "SGiLAN",
                    "networkInstance": "sgi"
                }
            }
        ],
        "urrs": [
            {
                "urrID": urr_ul_id,
                "measurementMethod": {
                    "volume": True,
                    "duration": True
                },
                "reportingTriggers": {
                    "startOfTraffic": True,
                    "endOfTraffic": True,
                    "volumeThreshold": True
                },
                "measurementPeriod": 10,
                "volumeThreshold": {
                    "totalVolume": 10000000  # bytes (10 MB)
                },
                "reportingFrequency": 1,
                "reportType": {
                    "usageReport": True,
                    "eventReport": False
                }
            }
        ]
    })

    # downlink session
    sessions.append({
        "seid": seid_dl,
        "pdrs": [
            {
                "pdrID": pdr_dl_id,
                "precedence": 0,
                "pdi": {
                    "sourceInterface": "SGiLAN",
                    "networkInstance": "sgi",
                    "ueIPAddress": {
                        "isDestination": True,
                        "ip4": ue_ip
                    },
                    "sdfFilter": {
                        "flowDescription": f"permit in ip from 0.0.0.0/0 to {ue_ip}/32"
                    }
                },
                "farID": far_dl_id,
                "urrIDs": [urr_dl_id]
            }
        ],
        "fars": [
            {
                "farID": far_dl_id,
                "applyAction": "Forward",
                "forwardingParameters": {
                    "destinationInterface": "Access",
                    "networkInstance": "access",
                    "outerHeaderCreation": {
                        "desc": "OUTER_HEADER_CREATION_GTPU_UDP_IPV4",
                        "teid": teid_dl_base + i,
                        "ip": "192.168.72.1"
                    }
                }
            }
        ],
        "urrs": [
            {
                "urrID": urr_dl_id,
                "measurementMethod": {
                    "volume": True,
                    "duration": True
                },
                "reportingTriggers": {
                    "startOfTraffic": True,
                    "endOfTraffic": True,
                    "volumeThreshold": True
                },
                "measurementPeriod": 10,
                "volumeThreshold": {
                    "totalVolume": 10000000
                },
                "reportingFrequency": 1,
                "reportType": {
                    "usageReport": True,
                    "eventReport": False
                }
            }
        ]
    })

# write YAML file
with open(pfcp_session, "w") as f:
    yaml.dump(sessions, f, sort_keys=False)
