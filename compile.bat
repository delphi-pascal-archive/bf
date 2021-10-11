@echo off


brcc32 bfdlgwin.RC
brcc32 bfver.RC
brcc32 bfinstall.RC

dcc32 BF.DPR -$O+
dcc32 BFINSTALL.DPR -$O+
start bf