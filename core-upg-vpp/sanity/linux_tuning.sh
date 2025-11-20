maxfreq=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
for cpu in {0..191}; do
        echo performance > /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor
        echo $maxfreq > /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq
        echo 0 > /sys/devices/system/cpu/cpu$cpu/cpuidle/state0/disable
        echo 0 > /sys/devices/system/cpu/cpu$cpu/cpuidle/state1/disable
        echo 0 > /sys/devices/system/cpu/cpu$cpu/cpuidle/state2/disable
done

service irqbalance stop
irq=`cat /proc/interrupts|awk '{print $1}' | tr -d ':' | egrep -v "CPU0|NMI|LOC|SPU|PMI|IWI|RTR|RES|CAL|TLB|TRM|THR|DFR|MCE|HYP|HRE|HVS|ERR|MIS|PIN|NPI|PIW|MCP"`
for c in $irq; do
        echo "00000000,00000000,00000001,00000000,00000000,00000001" > /proc/irq/$c/smp_affinity
        if [ $? -ne 0 ]; then
                echo "echo /proc/irq/$c/smp_affinity failed"
        fi
done

echo 10000 > /proc/sys/vm/stat_interval
echo 0 > /proc/sys/kernel/watchdog
echo 0 > /proc/sys/kernel/nmi_watchdog
echo 0 > /proc/sys/kernel/hung_task_timeout_secs
echo 0 > /proc/sys/kernel/timer_migration

echo 100000 > /sys/kernel/debug/sched/min_granularity_ns

echo 0 > /proc/sys/kernel/numa_balancing
echo 0 > /sys/bus/workqueue/devices/writeback/numa

echo 3 > /proc/sys/vm/drop_caches

systemctl stop apt-daily.timer
systemctl stop apt-daily-upgrade.timer

cd /sys/devices/virtual/workqueue/
files=`find . -name cpumask`
for f in $files; do
        echo "00000000,00000000,00000001,00000000,00000000,00000001" > $f
done

nets=`ls /sys/class/net/`
for net in $nets; do
        cd /sys/class/net/$net
        queues=`find . -name "rx-*"`
        for q in $queues; do
                echo "00000000,00000000,00000001,00000000,00000000,00000001" > $q/rps_cpus
        done
done

for c in {1..95};do echo 0 > /sys/devices/system/cpu/cpu$c/online; done
for c in {97..191};do echo 0 > /sys/devices/system/cpu/cpu$c/online; done

for c in {1..95};do echo 1 > /sys/devices/system/cpu/cpu$c/online; done
for c in {97..191};do echo 1 > /sys/devices/system/cpu/cpu$c/online; done

sysctl -w vm.dirty_background_ratio=0
sysctl -w vm.dirty_background_bytes=26214400
sysctl -w vm.dirty_ratio=0
sysctl -w vm.dirty_bytes=52428800
echo "Drop the ram cache"
sync
echo 1 > /proc/sys/vm/drop_caches
