FROM r-base:4.3.1
RUN apt-get update && \
apt-get upgrade --assume-yes && \
apt-get install --assume-yes --no-install-recommends infernal pplacer python3 python3-pip
WORKDIR /usr/local/src/yapp/
ADD requirements.txt .
RUN pip install --break-system-packages --requirement requirements.txt
