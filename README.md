# openbsd-build.sh
OpenBSD simple build wrapper

USAGE

```
% mkdir -p src/openbsd/dest
% cd src/openbsd
% cvs co src
% git clone openbsd-build.sh obbuild
% cd src
% ln -sf ../obbuild/build.sh .
% cd ../dest
% ../src/build.sh obtools
```
