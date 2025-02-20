# multistage build for docker image for AlexandrusPS pipeline 
FROM ubuntu:20.04 AS base
#FROM debian:stable-slim AS base

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
  LANG=en_US.UTF-8 \
  LC_ALL=C.UTF-8 \
  LANGUAGE=en_US.UTF-8

# run time apps
RUN apt-get update && \
  apt-get install -yq screen \
  proteinortho \
  cpanminus \
  perl \
  r-base && \
  rm -rf /var/lib/apt/lists/*

# build layer
FROM base AS build

# Update system and install packages, libcurl for rstatix
RUN apt-get update && \
  apt-get install -yq \
  build-essential \
  libcurl4-openssl-dev \ 
  libnlopt-dev \
  cmake \
  wget && \
  rm -rf /var/lib/apt/lists/*

FROM rocker/r-ver:4.2.2  # Use newer R version

# install R packages
RUN R -q -e 'install.packages(c("caret", "reshape2", "dplyr", "stringr", "lme4"))' && \
  R -q -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pbkrtest/pbkrtest_0.4-4.tar.gz", repos=NULL, type="source")' && \
  R -q -e 'install.packages("rstatix", repos = "https://cloud.r-project.org", dependencies = TRUE, version="0.7.1")' && \
  rm -rf /tmp/downloaded_packages

# install PRANK
WORKDIR /programs
RUN  wget http://wasabiapp.org/download/prank/prank.linux64.170427.tgz && \
  tar zxf prank.linux64.170427.tgz

# install PAML
RUN wget http://abacus.gene.ucl.ac.uk/software/paml4.9j.tgz && \
  tar xzf paml4.9j.tgz && \
  rm -rf paml4.9j.tgz && \
  cd paml4.9j/src && \
  make

# run layer
FROM base AS runtime 

# Copy build artifacts from build layer
COPY --from=build /usr/local /usr/local

# Install cpan modules (somehow doesn't work in build layer)
RUN cpanm Data::Dumper List::MoreUtils Array::Utils String::ShellQuote List::Util POSIX

COPY --from=build /programs /programs

# add prank to commandline
RUN cp -R ./programs/prank/bin/* ./bin/

# add paml to commandline
RUN cp -R ./programs/paml4.9j/src/baseml ./bin/ &&\
  cp -R ./programs/paml4.9j/src/codeml ./bin/ &&\
  cp -R ./programs/paml4.9j/src/evolver ./bin/

# Create the writable directory
RUN mkdir /tmp/screens

# Set appropriate permissions
RUN chmod 700 /tmp/screens
ENV SCREENDIR=/tmp/screens

WORKDIR /app
# copy AlexandrusPS
COPY AlexandrusPS_Positive_selection_pipeline ./AlexandrusPS_Positive_selection_pipeline

# set permissions
RUN chown -R 755:755 /app
RUN chmod 755 /app
RUN chown -R 755:755 /usr
RUN chmod 755 /usr
RUN chown -R 755:755 /programs
RUN chmod 755 /programs
RUN chmod a+x /usr/bin/prank
#RUN chown root:root /usr/bin/prank

# mark shell scripts as executable
WORKDIR /app/AlexandrusPS_Positive_selection_pipeline
RUN chmod +x *.sh

SHELL ["/bin/bash", "-c"]
