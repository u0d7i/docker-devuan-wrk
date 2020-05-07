FROM dyne/devuan:beowulf as scratch
ENV LANG=en_US.UTF-8

RUN sh -c 'echo "deb http://deb.devuan.org/merged beowulf main contrib non-free" > /etc/apt/sources.list' && \
    apt-get update && apt-get -y upgrade && \
    apt-get clean

FROM scratch as builder
LABEL stage=builder
# ceanup with: docker image prune --filter label=stage=builder

RUN apt-get -y install \
        bc \
        build-essential \
        fakeroot \
        gcc-arm-none-eabi

RUN useradd user
RUN sh -c 'install -o user -g user -d /build'
WORKDIR /data
USER user
RUN sh -c 'cd /build && git clone https://github.com/u0d7i/debian900  && cd debian900 && ./build_kernel.sh || ls -al debian900/*deb'

FROM scratch

RUN apt-get -y install \
        bc \
        binfmt-support \
        cryptsetup \
        debootstrap \
        file \
        locales \
        qemu-user \
        qemu-user-static \
        tzdata \
        whiptail \
        && \
    apt-get clean


RUN ln -fs /usr/share/zoneinfo/Europe/Helsinki /etc/localtime && \
	dpkg-reconfigure --frontend noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
	touch /usr/share/locale/locale.alias && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=en_US.UTF-8

RUN mkdir -p /data/kernel

COPY --from=builder /build/debian900/*deb /data/kernel/
COPY scripts /data

