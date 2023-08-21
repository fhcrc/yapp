FROM python:3.11.4-slim-bookworm

# Install prerequisites
RUN apt-get update && \
apt-get upgrade --assume-yes && \
apt-get install --assume-yes --no-install-recommends wget

WORKDIR /usr/local/src/yapp/
ADD requirements.txt .
RUN pip install --requirement requirements.txt

# create some mount points
RUN mkdir -p /app /fh /mnt /run/shm

