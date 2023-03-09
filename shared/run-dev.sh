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
    source /home/${SSH_USERNAME}/.bash_profile
  else
    mkdir -p /root/.ssh/
    cat /shared/id_rsa.pub > /root/.ssh/authorized_keys
    source /root/.bash_profile
  fi
  /usr/sbin/sshd
fi

cat <<EOF
---
Your development container setup is complete
---
To create an admin user:

    RAILS_ENV=development app-scripts/add_admin.sh <email address>
    
Run a Rails server with:

    FPHS_2FA_AUTH_DISABLED=true bundle exec rails s -b 0.0.0.0

The server will be available for user login at:
http://localhost:13000

Or to login as an admin (and set up an initial user using the admin password created previously):
http://localhost:13000/admins/sign_in?secure_entry=access-admin

To run the parallel test suite within the dev container:

    # First time, create the test DBs
    DBOWNER=${DB_USER} app-scripts/create-test-db.sh
    # Then run the test suite
    FPHS_POSTGRESQL_DATABASE= app-scripts/parallel_test.sh

---
Continuing with bash to keep the container running
Connect to the container directly with VSCode, or another IDE via SSH (see the build-vars.sh)
Run `exit` (or Ctrl-D) to close the container
---
EOF

/bin/bash
