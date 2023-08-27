######################################################################################
# Leveraging the official Debian image for lots of support and package availability. #
######################################################################################

FROM amd64/debian:latest



##################################
# Download and install packages. #
##################################

RUN apt update -y && apt upgrade -y

# Big downloads first.
RUN apt install -y gcc
RUN apt install -y bochs
RUN apt install -y bochs-sdl
RUN apt install -y qemu-system-x86

# Other downloads.
RUN apt install -y zsh
RUN apt install -y sudo
RUN apt install -y make
RUN apt install -y nasm
RUN apt install -y dosfstools
RUN apt install -y mtools
RUN apt install -y x11-apps
RUN apt install -y libx11-6
RUN apt install -y libxext6
RUN apt install -y git



###################
# Setup the user. #
###################

RUN useradd -ms /bin/zsh devel
RUN echo "devel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers



###########
# Finish. #
###########

USER devel
