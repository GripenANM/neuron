FROM ubuntu:24.04 AS base

RUN apt update
RUN apt install -y libssl-dev
RUN apt install -y openssl
RUN apt install -y unzip
RUN apt install -y git

#builder
FROM base AS builder

RUN apt install -y build-essential
RUN apt install -y cmake
RUN apt install -y ninja-build
RUN apt install -y curl
RUN apt install -y wget
RUN apt install -y autoconf
RUN apt install -y libtool

WORKDIR /opt

RUN git clone -b 1.2.15 https://github.com/HardySimpson/zlog.git
RUN git clone https://github.com/neugates/jansson.git
RUN git clone -b v2.16.12 https://github.com/Mbed-TLS/mbedtls.git
RUN git clone -b neuron https://github.com/neugates/NanoSDK.git
RUN git clone -b v1.13.1 https://github.com/benmcollins/libjwt.git
RUN git clone -b release-1.11.0 https://github.com/google/googletest.git
RUN curl -o sqlite3.tar.gz https://www.sqlite.org/2022/sqlite-autoconf-3390000.tar.gz
RUN wget --no-check-certificate --content-disposition https://github.com/protocolbuffers/protobuf/releases/download/v3.20.1/protobuf-cpp-3.20.1.tar.gz
RUN git clone -b v1.4.0 https://github.com/protobuf-c/protobuf-c.git
RUN git clone -b 2.10.2 https://github.com/emqx/neuron.git

RUN cd zlog && make && make install
RUN cd jansson && mkdir build && cd build && cmake -DJANSSON_BUILD_DOCS=OFF -DJANSSON_EXAMPLES=OFF .. && make && make install
RUN cd mbedtls && mkdir build && cd build && cmake -DUSE_SHARED_MBEDTLS_LIBRARY=OFF -DENABLE_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON .. && make && make install
RUN cd NanoSDK && mkdir build && cd build && cmake -DBUILD_SHARED_LIBS=OFF -DNNG_TESTS=OFF -DNNG_ENABLE_SQLITE=ON -DNNG_ENABLE_TLS=ON .. && make && make install
RUN cd libjwt && mkdir build && cd build && cmake -DENABLE_PIC=ON -DBUILD_SHARED_LIBS=OFF .. && make && make install
RUN cd googletest && mkdir build && cd build && cmake .. && make && make install
RUN mkdir sqlite3 && tar xzf sqlite3.tar.gz --strip-components=1 -C sqlite3 && cd sqlite3 && ./configure CFLAGS=-fPIC && make && make install
RUN tar -xzvf protobuf-cpp-3.20.1.tar.gz && cd protobuf-3.20.1 && ./configure --enable-shared=no CFLAGS=-fPIC CXXFLAGS=-fPIC && make && make install
RUN cd protobuf-c && ./autogen.sh && ./configure  --disable-protoc --enable-shared=no CFLAGS=-fPIC CXXFLAGS=-fPIC && make && make install
RUN cd neuron && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DDISABLE_WERROR=1 .. && make

#runner
FROM base AS runner

RUN apt install -y wget

COPY --from=builder /usr/lib/x86_64-linux-gnu/libasan.so.8.0.0 /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libasan.so.8 /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

COPY --from=builder /opt/neuron/build/config /opt/neuron/config
COPY --from=builder /opt/neuron/build/libneuron-base.so /opt/neuron
COPY --from=builder /opt/neuron/build/logs /opt/neuron/logs
COPY --from=builder /opt/neuron/build/neuron /opt/neuron
COPY --from=builder /opt/neuron/build/persistence /opt/neuron/persistence
COPY --from=builder /opt/neuron/build/plugins /opt/neuron/plugins
COPY --from=builder /opt/neuron/build/simulator /opt/neuron/simulator
COPY --from=builder /opt/neuron/build/tests /opt/neuron/tests

WORKDIR /opt/neuron

COPY ./dist ./dist
#RUN wget https://github.com/emqx/neuron-dashboard/releases/download/2.4.9/neuron-dashboard-lite.zip
#RUN unzip neuron-dashboard-lite.zip

EXPOSE 7000

CMD ["./neuron"]