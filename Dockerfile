# Cirro requires tools only available with full ubuntu image
LABEL org.opencontainers.image.authors="ngh2@uw.edu,crosenth@uw.edu"
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive TZ="America/Los_Angeles"
RUN apt-get update && \
apt-get upgrade --assume-yes && apt-get install --assume-yes r-base python3 python3-pip wget
# R deps
RUN R -e "install.packages('argparse',clean=TRUE,repos='http://cran.us.r-project.org/')" && \
R -e "install.packages('dplyr',clean=TRUE,repos='http://cran.us.r-project.org/')" && \
R -e "install.packages('tidyr',clean=TRUE,repos='http://cran.us.r-project.org/')" && \
R -e "install.packages('BiocManager',clean=TRUE,repos='http://cran.us.r-project.org/')" && \
R -e "BiocManager::install('phyloseq')"
WORKDIR /usr/local/src/yapp/
# Other deps
ADD bin/install_infernal_and_easel.sh bin/install_pplacer.sh requirements.txt ./
RUN ./install_infernal_and_easel.sh && ./install_pplacer.sh
# Python deps
RUN pip3 install --break-system-packages --requirement requirements.txt --root-user-action=ignore
