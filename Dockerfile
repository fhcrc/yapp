FROM python:3.9

# Install prerequisites
RUN apt-get update && \
apt-get upgrade --assume-yes && \
apt-get install --assume-yes --no-install-recommends wget

ADD bin/install_pplacer.sh /tmp/install_pplacer.sh
RUN /tmp/install_pplacer.sh

RUN pip install pandas csvkit fastalite

# clean up sources apt packages
RUN rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip

# create some mount points
RUN mkdir -p /app /fh /mnt /run/shm


