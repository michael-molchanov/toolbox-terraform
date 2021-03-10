ARG VARIANT_VERSION=0.35.1
ARG UNICONF_VERSION=0.1.7
ARG GOMPLATE_VERSION=v3.5.0
ARG YQ_VERSION=2.4.0
ARG TOOLBOX_VERSION=0.2.1

FROM aroq/variant:$VARIANT_VERSION as variant
FROM aroq/uniconf:$UNICONF_VERSION as uniconf
FROM hairyhenderson/gomplate:$GOMPLATE_VERSION as gomplate
FROM mikefarah/yq:$YQ_VERSION as yq
FROM aroq/toolbox:$TOOLBOX_VERSION as toolbox

FROM golang:1-alpine as builder

RUN set -eux; apk add --no-cache --virtual .composer-rundeps \
  git \
  curl \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

FROM python:2-alpine

LABEL maintainer "Michael Molchanov <mmolchanov@adyax.com>"

USER root

# SSH config.
RUN mkdir -p /root/.ssh
ADD config/ssh /root/.ssh/config
RUN chown root:root /root/.ssh/config && chmod 600 /root/.ssh/config

COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY --from=variant /usr/bin/variant /usr/bin/
COPY --from=gomplate /gomplate /usr/bin/
COPY --from=uniconf /uniconf/uniconf /usr/bin/uniconf
COPY --from=toolbox /usr/bin/go-getter /usr/bin
COPY --from=toolbox /usr/local/bin/fd /usr/local/bin

RUN set -eux; apk add --no-cache --virtual .composer-rundeps \
  autoconf \
  automake \
  bash \
  build-base \
  bzip2 \
  ca-certificates \
  cargo \
  coreutils \
  curl \
  freetype \
  fuse \
  gawk \
  gcc \
  git \
  git-lfs \
  gmp \
  gmp-dev \
  grep \
  gzip \
  jq \
  libbz2 \
  libffi \
  libffi-dev \
  libjpeg-turbo \
  libmcrypt \
  libpq \
  libpng \
  libxml2 \
  libxslt \
  libzip \
  make \
  mercurial \
  musl-dev \
  mysql-client \
  openssh \
  openssh-client \
  libressl \
  libressl-dev \
  patch \
  procps \
  postgresql-client \
  rsync \
  sqlite \
  strace \
  subversion \
  tar \
  tini \
  unzip \
  wget \
  zip \
  zlib \
  && rm -rf /var/lib/apt/lists/*

# Add git-secret package from edge testing
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing git-secret

# Install ansible.
RUN pip install --upgrade pip \
  && pip install ansible==2.10.6 awscli botocore boto3 s3cmd python-magic

# Install ansistrano.
RUN ansible-galaxy install ansistrano.deploy ansistrano.rollback

ENV HOME /root
ENV NVM_DIR $HOME/.nvm

# Profile
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
RUN echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$HOME/.bashrc"
RUN echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" # This loads nvm bash_completion' >> "$HOME/.bashrc"

RUN mkdir -p $NVM_DIR

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash

RUN source $NVM_DIR/nvm.sh \
  && source $NVM_DIR/nvm.sh \
  && nvm install -s v10.23.3 \
  && nvm alias default v10.23.3 \
  && nvm use --delete-prefix default

ENV PATH $HOME/.yarn/bin:$HOME/.nvm/versions/node/v10.23.3/bin:$PATH

RUN source $NVM_DIR/nvm.sh \
  && npm install -g gulp-cli grunt-cli bower \
  && curl -o- -L https://yarnpkg.com/install.sh | bash \
  && node --version \
  && npm --version \
  && grunt --version \
  && gulp --version \
  && bower --version \
  && yarn versions

# Install terraform.
ENV TERRAFORM_VERSION 0.12.18
RUN curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && mv terraform /usr/local/bin/ \
  && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

RUN mkdir -p /toolbox
COPY --from=toolbox /toolbox/* /toolbox/
