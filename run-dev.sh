#!/bin/bash
source /shared/build-vars.sh
source /shared/setup-dev-env.sh

if [ -z ${SSH_USERNAME} ]; then
  echo "No SSH user configured"
else
  echo "SSH user ${SSH_USERNAME}"
  if [ ${SSH_USERNAME} != root ]; then
    adduser ${SSH_USERNAME}
    mkdir -p /home/${SSH_USERNAME}/.ssh/
    chown ${SSH_USERNAME}:${SSH_USERNAME} /home/${SSH_USERNAME}/.ssh
    chmod 600 /home/${SSH_USERNAME}/.ssh 600
    cat /shared/id_rsa.pub > /home/${SSH_USERNAME}/.ssh/authorized_keys
    chmod 600 /home/${SSH_USERNAME}/.ssh/id_rsa.pub
    chown ${SSH_USERNAME}:${SSH_USERNAME} /home/${SSH_USERNAME}/.ssh/id_rsa.pub
  else
    mkdir -p /root/.ssh/
    cat /shared/id_rsa.pub > /root/.ssh/authorized_keys
  fi
  /usr/sbin/sshd
fi

/bin/bash
