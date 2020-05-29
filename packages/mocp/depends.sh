#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
sudo apt install -y gcc autoconf libtool gettext libdb-dev libpopt-dev libncursesw5-dev libasound2-dev libcurl4-openssl-dev libogg-dev libvorbis-dev libflac-dev libopus-dev libid3tag0-dev libsndfile1-dev libfaad-dev libavcodec-dev libsamplerate0-dev librcc-dev libavformat-dev
fi
if [ command -v dnf -eq /usr/bin/dnf ]
then
sudo yum install aspell enca faad2-libs ffmpeg-libs fluid-soundfont-common fluid-soundfont-lite-patches intel-mediasdk jack-audio-connection-kit libaom libass libdav1d libffado libguess libid3tag libmad libmodplug librcc librcd libtimidity libva libvdpau libvmaf libxml++ ocl-icd opencore-amr pugixml srt-libs vid.stab vo-amrwbenc x264-libs x265-libs xvidcore zimg zvbi libtool libdb-devel popt-devel libogg-devel libvorbis-devel yum install ffmpeg-devel
fi
