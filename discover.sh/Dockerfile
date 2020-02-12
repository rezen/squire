FROM ubuntu:16.04

RUN apt-get update && apt-get install -y git nmap ruby locate firefox python3 \
    python3-pip curl wget util-linux dnsutils bsdmainutils \
    ruby ruby-dev whois libgl1-mesa-dri \
	libgl1-mesa-glx \
	libpulse0 \
	fonts-noto \
	fonts-noto-cjk \
    ca-certificates \
    apt-utils

RUN mkdir -p /opt/discover && \
    git clone https://github.com/leebaird/discover /opt/discover/ && \
    cd /opt/discover/ && \
    ./update.sh

RUN git clone https://github.com/laramies/theHarvester.git /usr/share/theharvester && \
    cd /usr/share/theharvester && pip install -r requirements.txt


RUN git clone https://github.com/darkoperator/dnsrecon.git /usr/share/dnsrecon && \
    cd /usr/share/dnsrecon && \
    pip install -r requirements.txt && \
    mv dnsrecon.py dnsrecon
 
RUN git clone https://github.com/urbanadventurer/WhatWeb /usr/share/whatweb && \
    cd /usr/share/whatweb

RUN git clone https://github.com/urbanadventurer/urlcrazy /usr/share/urlcrazy && \
    cd /usr/share/urlcrazy

RUN git clone https://bitbucket.org/LaNMaSteR53/recon-ng /usr/share/recon-ng && \
    cd /usr/share/recon-ng && \
    pip install -r REQUIREMENTS

ENV PATH="/usr/share/dnsrecon:/usr/share/whatweb:/usr/share/urlcrazy:/usr/share/recon-ng:${PATH}"

WORKDIR /opt/discover
COPY entry.sh entry.sh
CMD ./entry.sh
