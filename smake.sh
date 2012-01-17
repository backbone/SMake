#!/bin/bash
# Usage examples:
# smake.sh --help
# smake.sh -t main
# smake.sh -t server -t client -i ~/projects/include -i ~/projects/gnulib -lpthread -lexpat
# smake.sh -t "program1 program2" -c gcc -x g++ -i "~/my_include /usr/local/include" -l "-llist -lhash"

REP_CC=cc
REP_CXX=c++
REP_INCLUDE='$(HOME)/projects/include /usr/local/include'
REP_LIBRARIES=
REP_TARGET=target

# SMAKE_DIR=~/etc/smake
SMAKE_DIR=`realpath "$0"`
SMAKE_DIR=${SMAKE_DIR%/*}
HELP_FILE=$SMAKE_DIR/help.smk
ENV_FILE=$SMAKE_DIR/env.smk
BUILD_FILE=$SMAKE_DIR/build.smk
RULES_FILE=$SMAKE_DIR/rules.smk

# Debug
DEBUG=1

# Parameters processing
TEMP=`getopt -o hc:x:i:l:t: --long help,cc:,cxx:,include:,libraries:,target: -- "$@"`
eval set -- "$TEMP"

include_changed=false
libraries_changed=false
target_changed=false

while true ; do
	case "$1" in
		-h|--help) echo "Usage: smake.sh [key]... [goal]..." ;
			echo "Keys:"
			echo -e "-h, --help\t\t\tShow this help and exit."
			echo -e "-c [CC], --cc [CC]\t\tUse CC as C compiler."
			echo -e "-x [CXX], --cxx [CXX]\t\tUse CXX as C++ compiler." 
			echo -e "-i [INC], --include [INC]\tSet INC as include path."
			echo -e "-l [LIB], --libraries [LIB]\tSet LIB as libraries that must be linked with."
			echo -e "-t [TGT], --target [TGT]\tSet TGT as target name."
			echo
			echo -e "This program works on any Linux with GNU Baurne's shell"
			echo -e "Report bugs to <mecareful@gmail.com>"
			exit 0 ;
			;;
		-c|--cc) REP_CC=$2 ; echo "CC=$REP_CC" ; shift 2 ;;
		-x|--cxx) REP_CXX=$2 ; echo "CXX=$REP_CXX" ; shift 2 ;;
		-i|--include) [ $include_changed == false ] && REP_INCLUDE="" && include_changed=true;  REP_INCLUDE="$REP_INCLUDE `echo $2 | sed "s~\~~\$\(HOME\)~g; s~^${HOME}~\$\(HOME\)~g ; s~/*$~~g"`" ; shift 2 ;;
		-l|--libraries) [ $libraries_changed == false ] && REP_LIBRARIES="" && libraries_changed=true;  REP_LIBRARIES="$REP_LIBRARIES $2" ; shift 2 ;;
		-t|--target) [ $target_changed == false ] && REP_TARGET="" && target_changed=true; REP_TARGET="$REP_TARGET $2"; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

# ======= Show Environment =======
REP_INCLUDE="`echo $REP_INCLUDE | sed 's~ ~\n~g' | sort -u | tr '\n' ' '`"
echo "INCLUDE=$REP_INCLUDE"; 
REP_LIBRARIES=`echo $REP_LIBRARIES | sed 's~\<\([A-Za-z]\)~-l\1~g'`
echo "LIBRARIES=$REP_LIBRARIES"; 

# ======= Help =======
cat $HELP_FILE > Makefile
echo >> Makefile

# ======= Test for target =======
TARGET_SRC=
for tgt in $REP_TARGET; do
	tgt_src=
	for ext in c cpp cxx cc; do
		[ -f "$tgt.$ext" ] && tgt_src=$tgt.$ext && break
	done
	[ "$tgt_src" == "" ] && echo "source file for $tgt not found" && exit -1
	TARGET_SRC="$TARGET_SRC $tgt_src"
done

# ======= Environment =======
tmp=$REP_TARGET
REP_TARGET=
i=0
for tgt in $tmp; do
	REP_TARGET="$REP_TARGET TARGET$i=$tgt"
	let i++
done
REP_TARGET=`echo $REP_TARGET | sed 's~ ~\\\n~g'`
REP_TARGET="$REP_TARGET\nTARGET="
i=0
for tgt in $tmp; do
	REP_TARGET="$REP_TARGET \$\(TARGET$i\)"
	let i++
done

sed "s~REP_CC~$REP_CC~ ; s~REP_CXX~$REP_CXX~ ; \
     s~REP_LIBRARIES~$REP_LIBRARIES~ ; s~REP_TARGET~$REP_TARGET~" $ENV_FILE >> Makefile

i=1
for d in $REP_INCLUDE; do
	echo "INCLUDE$i=$d" >> Makefile
	let i++
done

echo -n "INCLUDE=" >> Makefile

i=1
for d in $REP_INCLUDE; do
	if [ $i != 1 ]; then
		echo -n ' ' >> Makefile
	fi
	echo -n '-I$(INCLUDE'$i')' >> Makefile
	let i++
done
echo >> Makefile

echo >> Makefile

# ======= Build =======
cat $BUILD_FILE >> Makefile

echo >> Makefile

# ======= Rules =======
cat $RULES_FILE >> Makefile
REP_INCLUDE=`echo $REP_INCLUDE | sed "s~-I~~g ; s~\\$(HOME)~${HOME}~g"`
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
			for d in . $REP_INCLUDE; do
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
				for d in $REP_INCLUDE ; do
					_fname=`echo ${fpath[$j]} | sed "s~^$d~\$\(INCLUDE$k\)~"`
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

