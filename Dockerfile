FROM amazonlinux:2

LABEL maintainer=phil.ayres@consected.com

COPY build-container.sh /root/build-container.sh
COPY run-dev.sh /root/run-dev.sh
COPY shared/build-vars.sh /shared/build-vars.sh
COPY shared/.netrc /root/.netrc
COPY shared/setup-dev-env.sh /shared/setup-dev-env.sh

RUN cd /root; chmod 600 /root/.netrc; /root/build-container.sh

CMD ["/root/run-dev.sh"]

