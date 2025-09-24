#!/bin/bash
# scripts/hardening/cis-hardening.sh - CIS Compliance Hardening for Demo Infrastructure

set -e

# Variables
ENVIRONMENT="${1:-demo}"
HOSTNAME=$(hostname)
LOG_FILE="/var/log/cis-hardening.log"

# Logging setup
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "=== CIS HARDENING - DEMO INFRASTRUCTURE ==="
echo "=========================================="
echo "Hostname: $HOSTNAME"
echo "Environment: $ENVIRONMENT"
echo "Start time: $(date)"
echo "CIS Benchmark: Ubuntu 22.04 LTS"

# Function to print section headers
print_section() {
    echo
    echo "### $1 ###"
    echo "----------------------------------------"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_section "1. INITIAL SETUP"

# 1.1.1.1 Ensure cramfs kernel module is not available
echo "Disabling cramfs kernel module..."
echo "install cramfs /bin/true" >> /etc/modprobe.d/demo-cis.conf
rmmod cramfs 2>/dev/null || true

# 1.1.1.2 Ensure freevxfs kernel module is not available
echo "Disabling freevxfs kernel module..."
echo "install freevxfs /bin/true" >> /etc/modprobe.d/demo-cis.conf
rmmod freevxfs 2>/dev/null || true

# 1.1.1.3 Ensure jffs2 kernel module is not available
echo "Disabling jffs2 kernel module..."
echo "install jffs2 /bin/true" >> /etc/modprobe.d/demo-cis.conf
rmmod jffs2 2>/dev/null || true

# 1.1.1.4 Ensure hfs kernel module is not available
echo "Disabling hfs kernel module..."
echo "install hfs /bin/true" >> /etc/modprobe.d/demo-cis.conf
rmmod hfs 2>/dev/null || true

print_section "1.3 FILESYSTEM INTEGRITY CHECKING"

# Install and initialize AIDE if not already done
if ! command_exists aide; then
    apt-get update
    apt-get install -y aide aide-common
    aideinit
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
fi

# Create AIDE cron job
cat > /etc/cron.daily/aide << 'EOF'
#!/bin/bash
aide --check
EOF
chmod +x /etc/cron.daily/aide

print_section "1.4 SECURE BOOT SETTINGS"

# 1.4.1 Ensure bootloader password is set (not applicable for cloud instances)
echo "Bootloader password configuration skipped (cloud instance)"

# 1.4.2 Ensure permissions on bootloader config are configured
if [ -f /boot/grub/grub.cfg ]; then
    chown root:root /boot/grub/grub.cfg
    chmod og-rwx /boot/grub/grub.cfg
fi

print_section "1.5 ADDITIONAL PROCESS HARDENING"

# 1.5.1 Ensure address space layout randomization (ASLR) is enabled
echo "kernel.randomize_va_space = 2" >> /etc/sysctl.d/60-demo-cis.conf

# 1.5.3 Ensure Automatic Error Reporting is not enabled
systemctl disable apport.service 2>/dev/null || true
systemctl stop apport.service 2>/dev/null || true

print_section "1.6 MANDATORY ACCESS CONTROLS"

# 1.6.1.1 Ensure AppArmor is installed
if ! command_exists apparmor_status; then
    apt-get install -y apparmor apparmor-utils
fi

# 1.6.1.2 Ensure AppArmor is enabled in the bootloader configuration
# Typically handled by cloud-init in AWS instances

# 1.6.1.3 Ensure all AppArmor Profiles are in enforce or complain mode
aa-enforce /etc/apparmor.d/* 2>/dev/null || true

print_section "1.7 WARNING BANNERS"

# 1.7.1 Ensure message of the day is configured properly
cat > /etc/motd << 'EOF'

***************************************************************************
                           DEMO INFRASTRUCTURE
                    TechCorp Demo Environment
                          
WARNING: This is a demonstration system for AWS infrastructure capabilities.
All activities are logged and monitored.

Authorized personnel only.
***************************************************************************

EOF

# 1.7.2 Ensure local login warning banner is configured properly
cat > /etc/issue << 'EOF'
***************************************************************************
                           DEMO INFRASTRUCTURE
                          Authorized Access Only
                         
This is a demonstration environment for AWS infrastructure capabilities.
All activities are logged and monitored.

Unauthorized access is prohibited.
***************************************************************************
EOF

# 1.7.3 Ensure remote login warning banner is configured properly
cp /etc/issue /etc/issue.net

# 1.7.4 Ensure permissions on /etc/motd are configured
chown root:root /etc/motd
chmod 644 /etc/motd

# 1.7.5 Ensure permissions on /etc/issue are configured
chown root:root /etc/issue
chmod 644 /etc/issue

# 1.7.6 Ensure permissions on /etc/issue.net are configured
chown root:root /etc/issue.net
chmod 644 /etc/issue.net

print_section "2. SERVICES"

# 2.1 Disable unused services
SERVICES_TO_DISABLE=(
    "avahi-daemon"
    "cups"
    "dhcpcd"
    "slapd"
    "nfs-server"
    "rpcbind"
    "bind9"
    "vsftpd"
    "apache2"
    "nginx"
    "dovecot"
    "smbd"
    "squid"
    "snmpd"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "Disabling service: $service"
        systemctl stop "$service"
        systemctl disable "$service"
    fi
done

print_section "3. NETWORK CONFIGURATION"

# 3.1.1 Disable unused network protocols
cat >> /etc/sysctl.d/60-demo-cis.conf << 'EOF'

# 3.1.1 Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# 3.1.2 Ensure packet redirect sending is disabled
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 3.2.1 Ensure source routed packets are not accepted
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# 3.2.2 Ensure ICMP redirects are not accepted
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# 3.2.3 Ensure secure ICMP redirects are not accepted
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# 3.2.4 Ensure suspicious packets are logged
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# 3.2.5 Ensure broadcast ICMP requests are ignored
net.ipv4.icmp_echo_ignore_broadcasts = 1

# 3.2.6 Ensure bogus ICMP responses are ignored
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 3.2.7 Ensure Reverse Path Filtering is enabled
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# 3.2.8 Ensure TCP SYN Cookies is enabled
net.ipv4.tcp_syncookies = 1

# Additional security settings
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.conf.all.forwarding = 0
EOF

print_section "4. LOGGING AND AUDITING"

# 4.1.1 Ensure auditing is enabled
if ! systemctl is-active --quiet auditd; then
    systemctl enable auditd
    systemctl start auditd
fi

# 4.1.2 Ensure system is disabled when audit logs are full
sed -i 's/^space_left_action.*/space_left_action = email/' /etc/audit/auditd.conf
sed -i 's/^admin_space_left_action.*/admin_space_left_action = halt/' /etc/audit/auditd.conf
sed -i 's/^max_log_file_action.*/max_log_file_action = keep_logs/' /etc/audit/auditd.conf

# Enhanced audit rules
cat > /etc/audit/rules.d/demo-cis.rules << 'EOF'
# Demo CIS Audit Rules

# 4.1.3 Ensure events that modify date and time information are collected
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# 4.1.4 Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# 4.1.5 Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# 4.1.6 Ensure events that modify the system's Mandatory Access Controls are collected
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy

# 4.1.7 Ensure login and logout events are collected
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# 4.1.8 Ensure session initiation information is collected
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# 4.1.9 Ensure discretionary access control permission modification events are collected
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# 4.1.10 Ensure unsuccessful unauthorized file access attempts are collected
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# 4.1.11 Ensure use of privileged commands is collected
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-sudo
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-su

# 4.1.12 Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# 4.1.13 Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete

# 4.1.14 Ensure changes to system administration scope (sudoers) is collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# 4.1.15 Ensure system administrator actions (sudolog) are collected
-w /var/log/sudo.log -p wa -k actions

# 4.1.16 Ensure kernel module loading and unloading is collected
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
EOF

print_section "5. ACCESS AUTHENTICATION AND AUTHORIZATION"

# 5.1.1 Ensure cron daemon is enabled and running
systemctl enable cron
systemctl start cron

# 5.1.2 Ensure permissions on /etc/crontab are configured
chown root:root /etc/crontab
chmod og-rwx /etc/crontab

# 5.1.3 Ensure permissions on /etc/cron.hourly are configured
chown root:root /etc/cron.hourly
chmod og-rwx /etc/cron.hourly

# 5.1.4 Ensure permissions on /etc/cron.daily are configured
chown root:root /etc/cron.daily
chmod og-rwx /etc/cron.daily

# 5.1.5 Ensure permissions on /etc/cron.weekly are configured
chown root:root /etc/cron.weekly
chmod og-rwx /etc/cron.weekly

# 5.1.6 Ensure permissions on /etc/cron.monthly are configured
chown root:root /etc/cron.monthly
chmod og-rwx /etc/cron.monthly

# 5.1.7 Ensure permissions on /etc/cron.d are configured
chown root:root /etc/cron.d
chmod og-rwx /etc/cron.d

# 5.2 SSH Server Configuration (already done in bootstrap)
echo "SSH hardening already configured in bootstrap script"

# 5.3 Configure PAM
print_section "5.3 PAM CONFIGURATION"

# 5.3.1 Ensure password creation requirements are configured
apt-get install -y libpam-pwquality

cat > /etc/security/pwquality.conf << 'EOF'
# Demo password quality requirements
minlen = 12
minclass = 3
maxrepeat = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
EOF

# 5.3.2 Ensure lockout for failed password attempts is configured
cat >> /etc/pam.d/common-auth << 'EOF'
auth required pam_tally2.so onerr=fail audit silent deny=3 unlock_time=900
EOF

print_section "5.4 USER ACCOUNTS AND ENVIRONMENT"

# 5.4.1 Set Shadow Password Suite Parameters
sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs
sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs

# 5.4.2 Ensure system accounts are secured
for user in $(awk -F: '($3 < 1000) {print $1 }' /etc/passwd | grep -v "^root$\|^sync$\|^shutdown$\|^halt$"); do
    usermod -L $user 2>/dev/null
    if [ $user != "sync" ] && [ $user != "shutdown" ] && [ $user != "halt" ]; then
        usermod -s /usr/sbin/nologin $user 2>/dev/null
    fi
done

# 5.4.3 Ensure default group for the root account is GID 0
usermod -g 0 root

# 5.4.4 Ensure default user umask is 027 or more restrictive
echo "umask 027" >> /etc/bash.bashrc
echo "umask 027" >> /etc/profile

print_section "6. SYSTEM MAINTENANCE"

# 6.1 System File Permissions
# 6.1.1 Audit system file permissions
echo "Setting correct permissions on system files..."

# 6.1.2 Ensure permissions on /etc/passwd are configured
chown root:root /etc/passwd
chmod 644 /etc/passwd

# 6.1.3 Ensure permissions on /etc/shadow are configured
chown root:shadow /etc/shadow
chmod o-rwx,g-wx /etc/shadow

# 6.1.4 Ensure permissions on /etc/group are configured
chown root:root /etc/group
chmod 644 /etc/group

# 6.1.5 Ensure permissions on /etc/gshadow are configured
chown root:shadow /etc/gshadow
chmod o-rwx,g-rw /etc/gshadow

# 6.1.6 Ensure permissions on /etc/passwd- are configured
chown root:root /etc/passwd-
chmod 644 /etc/passwd-

# 6.1.7 Ensure permissions on /etc/shadow- are configured
chown root:shadow /etc/shadow-
chmod o-rwx,g-rw /etc/shadow-

# 6.1.8 Ensure permissions on /etc/group- are configured
chown root:root /etc/group-
chmod 644 /etc/group-

# 6.1.9 Ensure permissions on /etc/gshadow- are configured
chown root:shadow /etc/gshadow-
chmod o-rwx,g-rw /etc/gshadow-

print_section "APPLYING CONFIGURATIONS"

# Apply sysctl settings
sysctl -p /etc/sysctl.d/60-demo-cis.conf

# Restart auditd to apply new rules
systemctl restart auditd

# Regenerate initramfs
update-initramfs -u

print_section "CIS HARDENING VERIFICATION"

# Create verification script
cat > /usr/local/bin/demo-cis-check << 'EOF'
#!/bin/bash
echo "=== Demo CIS Compliance Check ==="
echo "Date: $(date)"
echo

echo "=== Kernel Security ==="
echo "ASLR Status: $(cat /proc/sys/kernel/randomize_va_space)"
echo "AppArmor Status:"
aa-status --brief

echo
echo "=== Network Security ==="
echo "IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo "Send Redirects: $(cat /proc/sys/net/ipv4/conf/all/send_redirects)"
echo "Accept Source Route: $(cat /proc/sys/net/ipv4/conf/all/accept_source_route)"
echo "TCP SYN Cookies: $(cat /proc/sys/net/ipv4/tcp_syncookies)"

echo
echo "=== Audit Status ==="
systemctl status auditd --no-pager -l

echo
echo "=== File Permissions Check ==="
ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow

echo
echo "=== Failed Login Attempts ==="
pam_tally2 --user=root 2>/dev/null || echo "No failed attempts recorded"

echo
echo "=== CIS Check Completed ==="
EOF

chmod +x /usr/local/bin/demo-cis-check

# Run final verification
echo "Running CIS compliance verification..."
/usr/local/bin/demo-cis-check

print_section "HARDENING COMPLETED"

echo "=========================================="
echo "=== CIS HARDENING COMPLETED SUCCESSFULLY ==="
echo "=========================================="
echo "Completion time: $(date)"
echo "Log file: $LOG_FILE"
echo "Verification script: /usr/local/bin/demo-cis-check"
echo
echo "IMPORTANT: Some changes may require a reboot to take full effect."
echo "Run 'sudo reboot' after reviewing the changes."
echo "=========================================="

# Create reboot reminder file
cat > /etc/update-motd.d/99-cis-reboot << 'EOF'
#!/bin/bash
echo "*** CIS Hardening Applied - Reboot Recommended ***"
echo "Run: sudo reboot"
echo
EOF
chmod +x /etc/update-motd.d/99-cis-reboot