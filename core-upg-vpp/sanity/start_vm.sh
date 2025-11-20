#!/bin/sh

taskset -c 15-23 qemu-system-x86_64 -cpu host -enable-kvm -m 32768 -smp sockets=1,cores=8 \
	   -net user,hostfwd=tcp::10021-:22 -net nic -object memory-backend-file,id=mem,size=8192M,mem-path=/dev/hugepages,share=on -numa node,memdev=mem -mem-prealloc /var/lib/libvirt/images/ubuntu20.04.qcow2 --nographic &

