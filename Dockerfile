FROM scratch
ARG TARGETPLATFORM
ENTRYPOINT [ "/usr/bin/supply-chain-example" ]
COPY $TARGETPLATFORM/supply-chain-example /usr/bin/supply-chain-example
