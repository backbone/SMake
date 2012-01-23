# This file is generated with smake.sh.
# You can use this make file with instruction make to
# use one of build mode: debug, profile, develop, release.
# No need to call make clean if You make with other mode,
# because the Makefile containes rules for automatically clean.
# Some usage examples:
# make # default mode is debug
# CFLAGS="-O2 -march=core2 -mtune=core2 -msse4.1 -mfpmath=sse -fomit-frame-pointer -pipe" LDFLAGS="-Wl,-O1" make mode=develop
# CFLAGS="-O2 -march=amdfam10 -mtune=amdfam10 -msse4a --mfpmath=sse -fomit-frame-pointer -pipe" LDFLAGS="-Wl,-O1" make mode=profile
# CFLAGS="-O2 -march=k6-2 -mtune=k6-2 -m3dnow --mfpmath=387 -fomit-frame-pointer -pipe" LDFLAGS="-Wl,-O1" make mode=release
# Report bugs to <mecareful@gmail.com>
