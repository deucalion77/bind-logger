# bind-logger
log generator for bind service (  Act as a FIM so you can use this for other services as well ). purly bash and run as a service on the system

run the setup as a service

[Unit]
Description=Bind Zone File Watcher with bpftrace
After=network.target

[Service]
Type=simple
ExecStart=/home/deucalion/bindlog-script/bind-zone-watcher.sh
Restart=on-failure
User=root
Group=root
CapabilityBoundingSet=CAP_BPF CAP_PERFMON CAP_SYS_ADMIN
AmbientCapabilities=CAP_BPF CAP_PERFMON CAP_SYS_ADMIN
SystemCallFilter=~@mount @reboot @swap
NoNewPrivileges=false


# BPF/trace-related permissions
CapabilityBoundingSet=CAP_SYS_ADMIN CAP_BPF CAP_PERFMON CAP_NET_ADMIN CAP_NET_RAW
AmbientCapabilities=CAP_SYS_ADMIN CAP_BPF CAP_PERFMON CAP_NET_ADMIN CAP_NET_RAW
NoNewPrivileges=false
ProtectSystem=off
ProtectHome=false
MemoryDenyWriteExecute=false
PrivateTmp=false

# Environment variables if needed
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
