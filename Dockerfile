FROM r-base:4.3.1
RUN apt-get update && \
apt-get upgrade --assume-yes && \
apt-get install --assume-yes --no-install-recommends infernal pplacer python3
