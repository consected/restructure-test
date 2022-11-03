FROM amazonlinux:2

LABEL maintainer=phil.ayres@consected.com

COPY build-container.sh /root/build-container.sh
COPY shared/build-vars.sh /shared/build-vars.sh
COPY shared/.netrc /root/.netrc

RUN cd /root; chmod 600 /root/.netrc; /root/build-container.sh

CMD ["/shared/test-restructure.sh"]

