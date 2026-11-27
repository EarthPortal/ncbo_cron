# syntax=docker/dockerfile:1

# Set from .ruby-version by ontoportal_testkit and docker-image.yml (not used for the image tag below)
ARG OPTK_RUBY_VERSION
# EarthPortal: the server runs Ruby 3.1.0 (.ruby-version), which has no bookworm image, and bullseye
# is no longer installable (end of Debian LTS). The containers use the latest Ruby 3.1.x on bookworm.
ARG RUBY_IMAGE_VERSION=3.1
ARG DISTRO_NAME=slim-bookworm

# OS, Java, Raptor and gems shared by both images, so CI tests the runtime we ship
FROM ruby:${RUBY_IMAGE_VERSION}-${DISTRO_NAME} AS base

WORKDIR /srv/ontoportal/ncbo_cron

# Set environment variables
ENV BUNDLE_PATH=/srv/ontoportal/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=5 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        file \
        ca-certificates \
        openjdk-17-jre-headless \
        raptor2-utils \
        wait-for-it \
        libraptor2-dev \
        build-essential \
         libxml2 \
         libxslt-dev \
         libmariadb-dev \
         git \
         curl \
         libffi-dev \
     pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Same Bundler as Gemfile.lock (BUNDLED WITH) and the server; the latest one needs Ruby >= 3.2
RUN gem install bundler -v 2.6.7

COPY Gemfile* *.gemspec ./

# Install dependencies
RUN bundle install --jobs ${BUNDLE_JOBS} --retry ${BUNDLE_RETRY}

# Built by ontoportal_testkit (target: test in .ontoportal-testkit.yml).
# /app because the testkit mounts coverage at /app/coverage; gems stay in BUNDLE_PATH
FROM base AS test

WORKDIR /app

# Slice size the old CI ran with (config default: 500); small slices keep goo's sliced loading exercised
ENV GOO_SLICES=100

COPY . .

CMD ["bundle", "exec", "rake"]

# Published agroportal/ncbo_cron image. Last, so builds without a target get it
FROM base AS production

# Copy application code
COPY . .
RUN cp /srv/ontoportal/ncbo_cron/config/config.rb.sample /srv/ontoportal/ncbo_cron/config/config.rb

CMD ["/bin/bash"]
