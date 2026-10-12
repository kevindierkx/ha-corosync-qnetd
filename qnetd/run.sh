#!/bin/bash
set -e
# Keep the cert DB in /data so it survives add-on updates
[ -d /data/qnetd ] || cp -a /etc/corosync/qnetd /data/qnetd
rm -rf /etc/corosync/qnetd && ln -s /data/qnetd /etc/corosync/qnetd
chown -R coroqnetd:coroqnetd /data/qnetd

PW=$(jq -r '.root_password // empty' /data/options.json)
if [ -n "$PW" ]; then
  echo "root:$PW" | chpasswd
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  mkdir -p /run/sshd && /usr/sbin/sshd
fi
exec corosync-qnetd -f
