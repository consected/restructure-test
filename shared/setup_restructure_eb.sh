TEMPLATES_DIR=/tmp
RESTR_FS_ROOT=${RESTR_FS_ROOT:=/efs1}
RESTR_FS_DIR=${RESTR_FS_DIR:=${BOX_NAME}-main}
RESTR_MOUNT_ROOT=${RESTR_MOUNT_ROOT:=/mnt/fphsfs}
RESTR_WEBAPP_USER=${RESTR_WEBAPP_USER:=webapp}
REMOUNT_EFS_SCRIPT=/root/setup/remount_efs.sh
BIND_ALL_ACCESS_GRP=599
BIND_GROUPS='600 601 602 603'
BIND_USER_ID=600
# LO_MINOR_VERSION=6.1
# LO_VERSION=${LO_MINOR_VERSION}.5
LO_MINOR_VERSION=6.4
LO_VERSION=${LO_MINOR_VERSION}.4
LO_PATCH_VERSION=${LO_VERSION}.2
LO_TAR=LibreOffice_${LO_VERSION}_Linux_x86-64_rpm.tar.gz

PDFGREP_FILE=pdfgrep-2.1.2
ALT_POSTGRES_INSTALL_VERSION=postgresql15

TESSERACT_APPIMAGE=tesseract-5.3.3-x86_64.AppImage

function log_function() {
  echo "Running $@"
}

function log() {
  echo "$@"
}

function do_once() {
  return 0
}

function add_status() {
  echo "Completed $@"
}

function setup_restructure_eb() {
  do_once || return 0
  log_function $@

  install_restructure_basics &&
    enable_webapp_restart &&
    install_memcached &&
    install_postgres_client &&
    install_libreoffice &&
    install_dicom_toolkit &&
    install_netpbm &&
    install_pdfgrep &&
    install_ocrmypdf
}

function install_restructure_basics() {
  do_once || return 0
  log_function $@

  amazon-linux-extras install -y epel
  yum install -y autoconf fuse fuse-libs fuse-devel libarchive libarchive-devel amazon-efs-utils || { log ERROR "Failed to install restructure basics"; return 1; }

  install_bindfs

  add_status
}

function install_bindfs() {
  which bindfs && return 0
  log_function $@

  yum install -y wget
  cd ${TEMPLATES_DIR}
  rm -rf bindfs-1.17.4*
  wget https://bindfs.org/downloads/bindfs-1.17.4.tar.gz  || { log ERROR "Failed to download bindfs"; return 1; }
  tar -xzf bindfs-1.17.4.tar.gz
  cd bindfs-1.17.4
  ./configure && make && sudo make install
  cd ..
  rm -rf bindfs-1.17.4*
  if ! which bindfs; then
    log ERROR "Failed to build and install bindfs"
    return 1
  fi

  add_status
}

function install_memcached() {
  do_once || return 0
  log_function $@

  which amazon-linux-extras && amazon-linux-extras install -y memcached1.5
  yum install -y memcached || { log ERROR "Failed to install memcached"; return 1; }

  # Remove the ipv6 protocol from the config, which may prevent startup
  sed -i -E "s/OPTIONS=.+//g" /etc/sysconfig/memcached
  echo 'OPTIONS="-l 127.0.0.1"' >> /etc/sysconfig/memcached

  systemctl restart memcached
  add_status
}

function install_postgres_client() {
  log_function $@
  yum install -y ${ALT_POSTGRES_INSTALL_VERSION} vim || { log ERROR "Failed to install ${ALT_POSTGRES_INSTALL_VERSION}"; return 1; }

  add_status
}

function install_libreoffice() {
  log_function $@

  if [ -f '/usr/bin/libreoffice' ]; then
    log INFO "Libreoffice already installed"
  else
    yum install -y cups dbus-libs dbus-glib || { log ERROR "Failed to install libreoffice dependencies"; return 1; }
    cd /tmp
    rm -f /usr/bin/libreoffice
    cp /shared/${LO_TAR} .
    tar -xzf ${LO_TAR}
    rm -f ${LO_TAR}
    cd LibreOffice_${LO_PATCH_VERSION}_Linux_x86-64_rpm/RPMS/
    yum localinstall -y *.rpm || { log ERROR "Failed to install libreoffice RPMs"; return 1; }
    ln -s /usr/bin/libreoffice${LO_MINOR_VERSION} /usr/bin/libreoffice
    # Give webapp a home directory so libreoffice can store its config
    # No need for shell access though
    # chsh -s /bin/bash webapp
    mkdir /home/webapp
    # chown webapp:webapp /home/webapp
    # chmod 700 /home/webapp/
    echo "012,123" > a.csv
    # sudo -u webapp 
    libreoffice --headless --convert-to pdf a.csv
    cd /tmp
    rm -rf /tmp/LibreOffice_${LO_PATCH_VERSION}_Linux_x86-64_rpm

    libreoffice --headless --version
    if [ $? != 0 ]; then
      log ERROR "Failed to install libreoffice"
    else
      add_status
    fi
  fi

}

function install_dicom_toolkit() {
  log_function $@

  if [ -f '/usr/bin/dcmj2pnm' ]; then
    log INFO "dcmj2pnm already installed"
  else
    cd /tmp
    mkdir dcmtk
    cd dcmtk/
    cp /shared/dcmtk-3.6.4-install.tar.gz .
    tar -xzf dcmtk-3.6.4-install.tar.gz
    rm -f dcmtk-3.6.4-install.tar.gz
    cd dcmtk-3.6.4-install
    cp -R usr/local/* /usr/
    ln -s /usr/share/dcmtk /usr/local/share/dcmtk
    # sudo -u webapp 
    dcmj2pnm --version
    cd /tmp
    rm -rf /tmp/dcmtk
  fi

  add_status
}

function install_netpbm() {
  log_function $@

  if [ -f '/usr/bin/jpegtopnm' ]; then
    log INFO "netpbm already installed"
  else
    yum install -y netpbm netpbm-progs
  fi

  add_status
}

function install_pdfgrep() {
  log_function $@

  if [ -z "$(which pdfgrep)" ]; then
    yum install -y poppler-cpp poppler-cpp-devel libgcrypt-devel || { log ERROR "Failed to install pdfgrep dependencies"; return 1; }
    cd /tmp
    mkdir pdfgrep
    cd pdfgrep/
    cp /shared/${PDFGREP_FILE}.tar.gz .
    tar -xzf ${PDFGREP_FILE}.tar.gz
    rm -f ${PDFGREP_FILE}.tar.gz
    cd ${PDFGREP_FILE}
    ./configure
    make
    make install
    rm -rf /tmp/${PDFGREP_FILE}
    ln -s /usr/local/bin/pdfgrep /bin/
    pdfgrep --version
    if [ $? != 0 ]; then
      log ERROR "Failed to install pdfgrep"
      return 1
    fi
  else
    log INFO "pdfgrep already installed"
  fi
  add_status
}

function install_ocrmypdf() {
  log_function $@

  if [ -z "$(which ocrmypdf)" ] || [ -z "$(which tesseract)" ]; then
    unlink /bin/ocrmypdf

    get_source setup_utils.sh
    install_pip

    pip3 install ocrmypdf
    if [ $? != 0 ]; then
      log ERROR "Failed to install ocrmypdf"
      return 1
    fi
    ln -s /usr/local/bin/ocrmypdf /bin/
    ocrmypdf --version
    if [ $? != 0 ]; then
      log ERROR "Failed to install ocrmypdf"
      return 2
    fi

    # Use the AppImage, since installation fails on AL2023
    wget https://github.com/AlexanderP/tesseract-appimage/releases/download/v5.3.3/${TESSERACT_APPIMAGE}
    chmod a+x ${TESSERACT_APPIMAGE}
    rm -f /usr/bin/tesseract
    mv ${TESSERACT_APPIMAGE} /usr/bin/tesseract
    tesseract --version
    if [ $? != 0 ]; then
      log ERROR "Failed to install tesseract"
      return 3
    fi
  else
    log INFO "ocrmypdf already installed"
  fi

  add_status
}

# Allow user to restart jobs
function enable_webapp_restart() {
  log_function $@

  cat > /etc/sudoers.d/${RESTR_WEBAPP_USER} << SUDO
${RESTR_WEBAPP_USER} ALL= NOPASSWD: /bin/systemctl restart delayed_job.service
${RESTR_WEBAPP_USER} ALL= NOPASSWD: /bin/systemctl restart memcached.service
SUDO

  add_status
}
