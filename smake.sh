#!/bin/bash
# Usage examples:
# smake.sh --help

REP_CC=cc
REP_CXX=c++
INCLUDES=
REP_LIBS=
REP_TARGETS=target

SOURCES=
PACKAGES=

SMAKE_DIR=`realpath "$0"`
SMAKE_DIR=${SMAKE_DIR%/*}
HELP_FILE=$SMAKE_DIR/help.smk
ENV_FILE=$SMAKE_DIR/env.smk
BUILD_FILE=$SMAKE_DIR/build.smk
RULES_FILE=$SMAKE_DIR/rules.smk

# Debug
DEBUG=1

# Parameters processing
TEMP=`getopt -o h:S:P:I:l:c:x:t: --long help:,sources:,package:,include:,libs:,cc:,cxx:,target: -- "$@"`
eval set -- "$TEMP"

sources_changed=false
packages_changed=false
includes_changed=false
libraries_changed=false
targets_changed=false

while true ; do
	case "$1" in
		-h|--help) echo "Usage: smake.sh [key]... [goal]..." ;
			echo "Keys:"
			echo -e "-h, --help\t\t\tShow this help and exit."
			echo -e "-S [SRC], --sources [SRC]\tSet SRC as path for search sources (ex: -S/home/user/src)."
			echo -e "-P [PKG], --package [PKG]\tSet PKG as used package (ex: -Pglib-2.0)."
			echo -e "-I [INC], --include [INC]\tSet INC as system include path (ex: -I/usr/include/glib-2.0)."
			echo -e "-l [LIB], --libs [LIB]\tSet LIB as libraries that must be linked with (ex: -lglib-2.0)."
			echo -e "-c [CC], --cc [CC]\t\tUse CC as C compiler (ex: -cgcc)."
			echo -e "-x [CXX], --cxx [CXX]\t\tUse CXX as C++ compiler (ex: -xg++)." 
			echo -e "-t [TGT], --target [TGT]\tSet TGT as target name (ex: -tmain)."
			echo
			echo -e "This program works on any GNU/Linux with GNU Baurne's shell"
			echo -e "Report bugs to <mecareful@gmail.com>"
			exit 0 ;
			;;
		-S|--source) [ $sources_changed == false ] && SOURCES="" && sources_changed=true; SOURCES="$SOURCES `echo $2 | sed "s~\~~\$\(HOME\)~g; s~^${HOME}~\$\(HOME\)~g ; s~/*$~~g"`" ; shift 2 ;;
		-I|--include) [ $includes_changed == false ] && INCLUDES="" && includes_changed=true; INCLUDES="$INCLUDES -I`echo $2 | sed "s~\~\~~\$\(HOME\)~g; s~^${HOME}~\$\(HOME\)~g ; s~/*$~~g"`" ; shift 2 ;;
		-P|--package) [ $packages_changed == false ] && PACKAGES="" && packages_changed=true; PACKAGES="$PACKAGES $2" ; shift 2 ;;
		-l|--libs) [ $libraries_changed == false ] && REP_LIBS="" && libraries_changed=true;  REP_LIBS="$REP_LIBS -l$2" ; shift 2 ;;
		-c|--cc) REP_CC=$2 ; echo "CC=$REP_CC" ; shift 2 ;;
		-x|--cxx) REP_CXX=$2 ; echo "CXX=$REP_CXX" ; shift 2 ;;
		-t|--target) [ $targets_changed == false ] && REP_TARGETS="" && targets_changed=true; REP_TARGETS="$REP_TARGETS $2"; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

# ======= Show Environment =======
INCLUDES="$INCLUDES `pkg-config --cflags $PACKAGES 2>/dev/null`"
REP_LIBS="$REP_LIBS `pkg-config --libs $PACKAGES 2>/dev/null`"
SOURCES="`echo $SOURCES | sed 's~ ~\n~g' | sort -u | tr '\n' ' '`"
PACKAGES="`echo $PACKAGES | sed 's~ ~\n~g' | sort -u | tr '\n' ' '`"
INCLUDES="`echo $INCLUDES | sed 's~ ~\n~g' | sort -u | tr '\n' ' '`"
REP_LIBS="`echo $REP_LIBS | sed 's~ ~\n~g' | sort -u | tr '\n' ' '`"
echo "SOURCES=$SOURCES"; 
echo "PACKAGES=$PACKAGES"; 
echo "INCLUDES=$INCLUDES"; 
echo "LIBS=$REP_LIBS"; 

# ======= Help =======
cat $HELP_FILE > Makefile
echo >> Makefile

# ======= Test for target =======
TARGET_SRC=
for tgt in $REP_TARGETS; do
	tgt_src=
	for ext in c cpp cxx cc; do
		[ -f "$tgt.$ext" ] && tgt_src=$tgt.$ext && break
	done
	[ "$tgt_src" == "" ] && echo "source file for $tgt not found" && exit -1
	TARGET_SRC="$TARGET_SRC $tgt_src"
done

# ======= Environment =======
tmp=$REP_TARGETS
REP_TARGETS=
i=0
for tgt in $tmp; do
	REP_TARGETS="$REP_TARGETS TARGET$i=$tgt"
	let i++
done
REP_TARGETS=`echo $REP_TARGETS | sed 's~ ~\\\n~g'`
REP_TARGETS="$REP_TARGETS\nTARGETS="
i=0
for tgt in $tmp; do
	REP_TARGETS="$REP_TARGETS \$\(TARGET$i\)"
	let i++
done

sed "s~REP_CC~$REP_CC~ ; s~REP_CXX~$REP_CXX~ ; \
     s~REP_LIBS~$REP_LIBS~ ; s~REP_TARGETS~$REP_TARGETS~" $ENV_FILE >> Makefile

i=1
for d in $SOURCES; do
	echo "SRC$i=$d" >> Makefile
	let i++
done

echo -n "SRC=" >> Makefile

i=1
for d in $SOURCES; do
	if [ $i != 1 ]; then
		echo -n ' ' >> Makefile
	fi
	echo -n '-I$(SRC'$i')' >> Makefile
	let i++
done
echo >> Makefile

echo 'INCLUDES='"$INCLUDES" >> Makefile

# ======= Build =======
cat $BUILD_FILE >> Makefile

echo >> Makefile

# ======= Rules =======
cat $RULES_FILE >> Makefile
SOURCES=`echo $SOURCES | sed "s~-I~~g ; s~\\$(HOME)~${HOME}~g"`
nfiles=0
for tgt_src in $TARGET_SRC; do
	flist[$nfiles]=$tgt_src
	fpath[$nfiles]=$tgt_src
	fdeplist[$nfiles]=`$SMAKE_DIR/remove_c_comments.pl $tgt_src | grep -P '^[\t ]*#include[\t ]*"' | sed 's~[^"]*"\([^"]*\)".*~\1~' | sort -u`
	let nfiles++
done
nparsed=0
files_not_found=
# Building common for all targets dependencies tree
while [ $nfiles != $nparsed ]; do
	for f in ${fdeplist[$nparsed]}; do
		extension=`basename $f | sed 's~.*\.~~g'`
		f=`echo $f | sed "s~.$extension$~~"`
		extensions=$extension
		[[ "$extension" == h || "$extension" == hpp || "$extension" == "hxx" || "$extension" == "hh" ]] && extensions="$extension c cpp cxx cc"
		already_in_list=false
		for ext in $extensions; do 
			for i in `seq 0 $((nfiles))`; do
				if [ "${flist[$i]}" == "$f.$ext" ]; then
					already_in_list=true
					break;
				fi
			done
			[ $already_in_list == true ] && continue 

			F=
			for d in . $SOURCES; do
				if [ -f "$d/$f.$ext" ]; then
					F="$d/$f.$ext"
				elif [ -f "$d/`basename $f.$ext`" ]; then
					F="$d/`basename $f.$ext`"
				fi
				if [ "$F" != "" ]; then
					flist[$nfiles]=$f.$ext
					fpath[$nfiles]=$F
					fdeplist[$nfiles]=`$SMAKE_DIR/remove_c_comments.pl $F | grep -P '^[\t ]*#include[\t ]*"' | sed 's~[^"]*"\([^"]*\)".*~\1~' | sort -u`
					let nfiles++
					break
				fi
			done
			[[ "$F" == "" && "$ext" == "$extension" ]] && files_not_found=`echo "$files_not_found\n$f.$ext" | sort -u`
			[[ "$F" != "" && "$ext" != "$extension" ]] && break
		done
		[ $already_in_list == true ] && continue 
	done
	let nparsed++
done

#for i in `seq 0 $((nfiles-1))`; do
#	echo ----
#	echo 
#	echo `echo ${flist[$i]}[${fpath[$i]}]: ${fdeplist[$i]}`
#done

# ======= Target rules =======
target_objs=
i=0
for tgt_src in $TARGET_SRC; do
	target_objs=${fdeplist[$i]}
	_target_objs=

	while [ "$target_objs" != "$_target_objs" ]; do
		_target_objs=$target_objs
		for j in `seq 0 $((nfiles-1))`; do
			if [ "`echo $target_objs | grep \"\<${flist[$j]}\>\"`" != "" ]; then
				target_objs="$target_objs ${fdeplist[$j]}"
				extension=`basename ${flist[$j]} | sed 's~.*\.~~g'`
				f=`echo ${flist[$j]} | sed "s~.$extension$~~"`
				for k in `seq 0 $((nfiles-1))`; do
					if [[ "${flist[$k]}" == "$f.c" || "${flist[$k]}" == "$f.cpp"
					     || "${flist[$k]}" == "$f.cxx" || "${flist[$k]}" == "$f.cc" ]]; then
						if [ "$tgt_src" != "${flist[$k]}" ]; then
							target_objs="$target_objs ${flist[$k]}"
						fi
					fi
				done
			fi
			target_objs=`echo $target_objs | sed 's~ ~\n~g' | sort -u`
		done
	done

	echo -n "target_objs$i =" >> Makefile
	extension=`basename $tgt_src | sed 's~.*\.~~g'`
	f=`echo $tgt_src | sed "s~.$extension$~~"`
	echo ' \' >> Makefile
	echo -ne "\t`basename $f.o`" >> Makefile
	for obj_f in $target_objs; do
		extension=`basename $obj_f | sed 's~.*\.~~g'`
		f=`echo $obj_f | sed "s~.$extension$~~"`
		[[ "$extension" != c &&	"$extension" != cpp
		   && "$extension" != cxx && "$extension" != cc ]] && continue
		echo ' \' >> Makefile
		echo -ne "\t`basename $f.o`" >> Makefile
	done
	echo >> Makefile
	echo >> Makefile
	echo '$(TARGET'$i'): $(target_objs'$i')' >> Makefile
	echo -e '\t$(CC) $(LDFLAGS) -o $@ $(target_objs'$i')' >> Makefile
	echo >> Makefile
	
	echo >> Makefile
	let i++
done
#echo $tgt_src:$target_objs


ntargets=0
for tgt_src in $TARGET_SRC; do
	let ntargets++
done

# ======= Object's rules =======
for i in `seq 0 $((nfiles-1))`; do
	extension=`basename ${flist[$i]} | sed 's~.*\.~~g'`
	f=`echo ${flist[$i]} | sed "s~.$extension$~~"`
	[[ "$extension" != c &&	"$extension" != cpp
	   && "$extension" != cxx && "$extension" != cc ]] && continue
	echo -n `basename $f.o:` >> Makefile

	dep_lst=${fdeplist[$i]}
	_dep_lst=
	while [ "$dep_lst" != "$_dep_lst" ]; do
		_dep_lst="$dep_lst"

		for fl in $_dep_lst; do
			for j in `seq 0 $((nfiles-1))`; do
				if [ "$fl" == "${flist[$j]}" ]; then
					dep_lst="$dep_lst ${fdeplist[$j]}"
				fi
			done
		done

		dep_lst=`echo $dep_lst | sed 's~ ~\n~g' | sort -u`
	done

	dep_lst="${flist[$i]} $dep_lst"

	for fl in $dep_lst; do
		for j in `seq 0 $((nfiles-1))`; do
			if [ "${flist[$j]}" == "$fl" ]; then
				echo ' \' >> Makefile
				echo -ne "\t" >> Makefile
				fname=${fpath[$j]}
				k=1
				for d in $SOURCES ; do
					_fname=`echo ${fpath[$j]} | sed "s~^$d~\$\(SRC$k\)~"`
					[ "$_fname" != "${fpath[$j]}" ] && fname=$_fname
					let k++
				done

				fname=`echo $fname | sed "s~^${HOME}~\$\(HOME\)~g ; s~^\./~~g"`

				echo -n "$fname" >> Makefile
				break
			fi
		done
	done

	echo >> Makefile
	echo >> Makefile
done

# ======= Warning =======
files_not_found=`echo -e "$files_not_found" | sort -u`
if [ "$files_not_found" != "" ]; then
	echo WARNING: Include files not found: $files_not_found
fi

