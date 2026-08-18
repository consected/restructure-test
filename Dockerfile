FROM amazonlinux:2023

LABEL maintainer=phil.ayres@consected.com

COPY build-container.sh /root/build-container.sh
COPY shared/run-dev.sh /shared/run-dev.sh
COPY shared/build-vars.sh /shared/build-vars.sh
COPY shared/default-ruby-version.sh /shared/default-ruby-version.sh
COPY shared/.netrc /root/.netrc
COPY shared/setup-dev-env.sh /shared/setup-dev-env.sh
COPY shared/test-restructure.sh /shared/test-restructure.sh
COPY shared/check-config.sh /shared/check-config.sh
COPY shared/setup_restructure_eb.sh /shared/setup_restructure_eb.sh
COPY shared/dcmtk-3.6.4-install.tar.gz /shared/dcmtk-3.6.4-install.tar.gz
COPY shared/pdfgrep-2.1.2.tar.gz /shared/pdfgrep-2.1.2.tar.gz
COPY shared/LibreOffice_6.4.4_Linux_x86-64_rpm.tar.gz /shared/LibreOffice_6.4.4_Linux_x86-64_rpm.tar.gz

RUN cd /root; chmod 600 /root/.netrc; /root/build-container.sh

CMD /shared/check-config.sh

