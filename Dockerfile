ARG RUBY_BASE=ruby:2
FROM $RUBY_BASE
MAINTAINER rlyons@mdsol.com

ENV LANG C.UTF-8

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

ARG KEYS
ENV KEYS ${KEYS}

RUN mkdir ~/.gnupg
RUN chmod 700 ~/.gnupg
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in ${KEYS}; \
  do \
    echo "$key"; \
    gpg --no-tty --keyserver pool.sks-keyservers.net --recv-keys "$key"; \
  done

ARG NODE_MAJOR=11
ENV NODE_MAJOR ${NODE_MAJOR}

RUN NODE_VERSION=$(curl -SL "https://nodejs.org/dist/index.tab" \
  | grep "^v$NODE_MAJOR" \
  | head -n 1 | awk '{ print substr($1,2) }') \
  && ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --import
RUN YARN_VERSION=$(curl -sSL --compressed https://yarnpkg.com/latest-version) \
  set -ex \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

CMD ruby -v && echo -n "node " && node -v && echo -n "yarn " && yarn -v && ls -la /usr/local/bin
