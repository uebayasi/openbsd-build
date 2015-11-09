#!/bin/sh

###
### build.sh - OpenBSD build script
###

set -e
#set -vx

###
### obtools, obdistrib
###
_build_prog=$0
_build_sudo=/usr/bin/doas
_build_env=
_build_make_njobs=-j4
_build_make=
_build_config=

obdirs() {
	cd $s
	$_build_sudo \
	    $_build_env \
	    $_build_make CROSSDIR=$d TARGET=$a cross-dirs
	cd $OLDPWD
}

obtools() {
	cd $s
	$_build_sudo \
	    $_build_env \
	    $_build_make CROSSDIR=$d TARGET=$a cross-obj
	$_build_sudo \
	    $_build_env \
	    $_build_make CROSSDIR=$d TARGET=$a cross-tools
	cd $OLDPWD

	cd $s/usr.sbin/config
	$_build_env make clean
	$_build_env make depend
	$_build_env make all
	$_build_sudo cp ./config $t/bin
	cd $OLDPWD
}

obdistrib() {
	cd $s
	$_build_sudo \
	    $_build_env \
	    $_build_make CROSSDIR=$d TARGET=$a cross-distrib
	cd $OLDPWD
}

obreset() {
	$_build_sudo rm -f $d/.*_done
}

obsetperm() {
	$_build_sudo chown -R :wsrc $o
	$_build_sudo chmod -R g+w $o
}

###
### obkernel
###
_obkernel_conf=GENERIC.MP
_obkernel() {
	local _sudo
	_sudo=$1
	shift

	cd $s/sys/arch/$a/conf
	$_build_sudo mkdir -p $ko/compile/${_obkernel_conf}
	$_build_sudo chown -R :wsrc $ko
	$_build_sudo chmod -R g+w $ko
	# XXX ${_build_config}
	$t/bin/config -s $s/sys -b $ko/compile/${_obkernel_conf} ${_obkernel_conf}
	cd $OLDPWD

	#cd $s/sys/arch/$a/compile/${_obkernel_conf}
	cd $ko/compile/${_obkernel_conf}
	printf '===> cd %s\n' "$(pwd)"
	printf '===> kernel build start: %s\n' "$(date)"
	$_sudo $_build_make DEBUG=-g $@
	printf '===> kernel build end: %s\n' "$(date)"
	cd $OLDPWD
	printf '===> cd %s\n' "$(pwd)"
	return 0
}
obkernel() {
	if [ $# -gt 0 ]; then
		_obkernel_conf=$1
	fi
	_obkernel ""
	return 0
}
obkernelinstall() {
	if [ $# -gt 0 ]; then
		_obkernel_conf=$1
	fi
	_obkernel $_build_sudo install
	return 0
}
obkernelconf() {
	local _conf
	_conf="$1"
	if [ ! -e $s/sys/arch/$a/conf/${_conf} ]; then
		echo >&2 "File not exist: ${_conf}"
		return 1
	fi
	_obkernel_conf="$1"
	return 0
}
obkernelclean() {
	rm -fr $o/sys/arch/$a/compile/${_obkernel_conf}
	mkdir -p $o/sys/arch/$a/compile/${_obkernel_conf}
}

###
### obcvsup
###
_obcvsup_linkroot() {
	of=./CVS/Root
	oinum=$( ls -i $of | { read a b; echo $a; } )
	find ./[a-z]* -name Root \! -inum $oinum -print |
	grep 'CVS/Root$' |
	while read f; do
		ln -f $of $f
		printf '.'
	done
	printf '\n'
}
obcvsup() {
	cd $s
	{
		cvs up -PdAkk
		cvs di
	} | tee di
	_obcvsup_linkroot
	cd $OLDPWD
}

###
### obshell
###
obshell() {
	local _env=$( mktemp /tmp/build.sh.XXXXXX )

	cp $_build_prog $_env
	env ENV=$_env BSDSRCDIR=$( cd "${_build_prog%/*}" && pwd -P ) /bin/sh -i
	rm -f $_env
}

###
### buildenv, unbuildenv
###
buildenv() {
	# set dirs
	d=$( pwd -P )
	if [ "${_build_prog}" != "/bin/sh" ]; then
		s=$( cd "${_build_prog%/*}" && pwd -P )
	else
		s=${BSDSRCDIR}
	fi
	o=$d/usr/obj
	# XXX
	a=amd64
	ks=$s/sys/arch/$a
	ko=$o/sys/arch/$a

	# XXX ${BSDSRCDIR} is used in a few places
	_build_env="/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin BSDSRCDIR=$s"
	_build_make="/usr/bin/make -m $s/share/mk ${_build_make_njobs}"

	# check dirs
	if [ ! -n "$s" ]; then
		return 1
	elif [ ! -d "$s" ]; then
		return 1
	elif [ ! -f "$s/Makefile" ]; then
		return 1
	elif [ ! -f "$s/etc/rc.conf" ]; then
		return 1
	fi

	if [ ! -e $d/TARGET_CANON ]; then
		obdirs
	fi
	if [ ! -e $d/TARGET_CANON ]; then
		return 1
	fi

	cd $s
	eval export $(
		$_build_env $_build_make CROSSDIR=$d TARGET=$a cross-env
	)
	cd $OLDPWD

	CROSSDIR=$d
	TARGET=$a
	export CROSSDIR TARGET

	t=${CC%/*/*}

	OPATH=$PATH
	PATH=$t/bin:$PATH

	OPS1=$PS1
	PS1="${t##*/}@$d
 s=$s
 o=$o
ks=$ks
ko=$ko
% "
}
unbuildenv() {
	PATH=$OPATH
	PS1=$OPS1
	unset a s ks d o ko t
}
m() {
	$_build_make "$@"
}

usage() {
	echo 'build.sh'
	echo
	echo 'Usage: build.sh [dirs | tools | distrib | reset | kernel=XXX | cleankernel=XXX]'
	exit 0
}

###
### main
###
if [ $# -eq 0 ]; then
	case "${ENV}" in
	/tmp/build.sh.*)
		# interactive mode; this file is read as ${ENV}; don't exit!
		buildenv
		;;
	*)
		obshell
		exit $?
		;;
	esac
else
	buildenv
	while [ $# -gt 0 ]; do
		eval $1
		shift
	done
	exit $?
fi
