#!/bin/sh

xrun \
 -64bit \
 -q \
 -f ./rtl/ip/hyperram/dv/hyperram_dv.f \
 -licqueue \
 -elaborate \
 -debug_opts verisium_interactive \
 -l build.log \
 -access rwc \
 -linedebug
#vcs \
# -full64 \
# -f ./dv/hyperram/hyperram_dv.f \
# -sverilog \
# -l build.log \
# -timescale=1ns/10ps \
# -licqueue
