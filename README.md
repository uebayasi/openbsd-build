# openbsd-build.sh
OpenBSD simple build wrapper

USAGE

```
% cd /tmp
% git clone github.com:uebayasi/openbsd-build.sh.git obbuild
% cd /usr/src
% doas ln -sf /tmp/obbuild/build.sh .
% doas mkdir /usr/cross
% cd /usr/cross
% /usr/src/build.sh obtools
```
