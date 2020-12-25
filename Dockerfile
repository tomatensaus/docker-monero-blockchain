# Step 1 Edit the line that says Monero version... it forces docker to rebuild
# Step 2: docker build -t monerod .
# Usage: docker run -tid --restart=always -v /var/data/DockerSpace/xmr:/home/monero/.bitmonero -p 18080:18080 -p 18081:18081 --name=monerod monerod:latest

FROM ubuntu:18.04 AS build

RUN apt-get update && apt-get install -y curl bzip2 gawk git gnupg libpcsclite-dev

ENV MONERO_VERSION=0.17.1.7.latest

WORKDIR /root

RUN git clone --depth=1 https://github.com/monero-project/monero.git && \
  gpg --import monero/utils/gpg_keys/* && \
  curl https://www.getmonero.org/downloads/hashes.txt > hashes.txt && \
  awk -i inplace '!p;/^-----END PGP SIGNATURE-----/{p=1}' hashes.txt && \
  gpg --verify hashes.txt && \
  cat hashes.txt| grep "monero-linux-x64-v" | awk -F"  " '{$0=$2}1' > binary.txt && \
  cat hashes.txt| grep "monero-linux-x64-v" | awk -F"  " '{$0=$1}1' > sha256.txt && \
  rm -r monero

RUN curl https://downloads.getmonero.org/cli/`cat binary.txt` -O && \
  echo `cat sha256.txt` '' `cat binary.txt` | sha256sum -c - && \
  tar -xvf *.tar.bz2 && \
  cp ./monero-x86_64-linux-gnu-*/monerod . && \
  rm *.tar.bz2 && \
  rm -r monero-x86_64-linux-gnu-*

RUN echo "blockList new"
RUN curl https://gui.xmr.pm/files/block_tor.txt  > block.txt

FROM ubuntu:18.04

RUN useradd -ms /bin/bash monero && mkdir -p /home/monero/.bitmonero && chown -R monero:monero /home/monero/.bitmonero
USER monero
WORKDIR /home/monero

COPY --chown=monero:monero --from=build /root/monerod /home/monero/monerod
COPY --chown=monero:monero --from=build /root/block.txt /home/monero/block.txt

# blockchain loaction
VOLUME /home/monero/.bitmonero

EXPOSE 18080 18081 

ENTRYPOINT ["./monerod"]
CMD ["--restricted-rpc", "--rpc-bind-ip=0.0.0.0", "--confirm-external-bind", "--ban-list=/home/monero/block.txt"]
