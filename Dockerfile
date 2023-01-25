FROM amazonlinux:2

LABEL maintainer=phil.ayres@consected.com

COPY build-container.sh /root/build-container.sh
COPY shared/run-dev.sh /shared/run-dev.sh
COPY shared/build-vars.sh /shared/build-vars.sh
COPY shared/.netrc /root/.netrc
COPY shared/setup-dev-env.sh /shared/setup-dev-env.sh
COPY shared/test-restructure.sh /shared/test-restructure.sh

RUN /root/build-container.sh

CMD ["/shared/run-dev.sh"]

