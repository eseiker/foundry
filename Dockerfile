# syntax=docker/dockerfile:1.4

FROM --platform=$BUILDPLATFORM alpine:3.18 as build-environment

ARG TARGETARCH
WORKDIR /opt

RUN apk add clang lld curl build-base linux-headers git \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup.sh \
    && chmod +x ./rustup.sh \
    && ./rustup.sh -y

RUN [[ "$TARGETARCH" = "arm64" ]] \
    && echo "export CFLAGS=-mno-outline-atomics; export TARGET=aarch64-unknown-linux-musl" >> $HOME/.profile \
    || echo "export TARGET=x86_64-unknown-linux-musl" >> $HOME/.profile

WORKDIR /opt/foundry
COPY . .

RUN --mount=type=cache,target=/root/.cargo/registry --mount=type=cache,target=/root/.cargo/git --mount=type=cache,target=/opt/foundry/target \
    source $HOME/.profile \
    && rustup target add $TARGET \
    && cargo build --release --target $TARGET \
    && mkdir out \
    && mv target/release/forge out/forge \
    && mv target/release/cast out/cast \
    && mv target/release/anvil out/anvil \
    && mv target/release/chisel out/chisel \
    && strip out/forge \
    && strip out/cast \
    && strip out/chisel \
    && strip out/anvil;

FROM gcr.io/distroless/cc:nonroot as foundry-client

COPY --from=build-environment /bin/sh /bin/sh
COPY --from=build-environment /usr/bin/git /usr/bin/git
COPY --from=build-environment /opt/foundry/out/forge /usr/local/bin/forge
COPY --from=build-environment /opt/foundry/out/cast /usr/local/bin/cast
COPY --from=build-environment /opt/foundry/out/anvil /usr/local/bin/anvil
COPY --from=build-environment /opt/foundry/out/chisel /usr/local/bin/chisel

ENTRYPOINT ["/bin/sh", "-c"]

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Foundry" \
      org.label-schema.description="Foundry" \
      org.label-schema.url="https://getfoundry.sh" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/foundry-rs/foundry.git" \
      org.label-schema.vendor="Foundry-rs" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"
