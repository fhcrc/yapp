FROM python:3.11-slim-bullseye

# Install prerequisites
RUN apt-get update && \
apt-get upgrade --assume-yes && \
apt-get install --assume-yes --no-install-recommends wget

# ADD bin/install_pplacer.sh /tmp/install_pplacer.sh
# RUN /tmp/install_pplacer.sh

RUN pip install pandas csvkit fastalite

# create some mount points
RUN mkdir -p /app /fh /mnt /run/shm

