FROM dyne/devuan:beowulf

RUN sh -c 'echo "deb http://deb.devuan.org/merged beowulf main contrib non-free" > /etc/apt/sources.list' && \
    apt-get update && apt-get -y upgrade && \
    apt-get -y install \
	bc \
	binfmt-support \
	build-essential \
	cryptsetup \
	debootstrap \
	fakeroot \
	file \
	gcc-arm-none-eabi \
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


RUN mkdir -p /data

COPY kernel /data
COPY scripts /data


#RUN useradd user
#RUN sh -c 'install -o user -g user -d /data'

#USER user
#WORKDIR /data
#RUN sh -c 'cd /data && git clone https://github.com/u0d7i/debian900  && cd debian900 && ./build_kernel.sh || ls -al debian900/*deb'
	
