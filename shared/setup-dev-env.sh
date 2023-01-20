export PGSQLBIN=/usr/bin
export PATH=${PGSQLBIN}:$PATH
export PGCLIENTENCODING=UTF8
export HOME=/root
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
export NO_BRAKEMAN
export FS_TEST_BASE=/root
export FS_FORCE_ROOT=true
export WEBAPP_USER=$(whoami)
export NOT_HEADLESS=false
if [ "${DB_NAME}" ]; then
  export FPHS_POSTGRESQL_DATABASE=${DB_NAME}
fi
export FPHS_POSTGRESQL_USERNAME=${DB_USER}
export FPHS_POSTGRESQL_PASSWORD=${DB_PASSWORD}
export FPHS_POSTGRESQL_PORT=5432
export FPHS_POSTGRESQL_HOSTNAME=localhost
export PGSQL_DATA_DIR=/output/pgsql/data
export PGVER=12
