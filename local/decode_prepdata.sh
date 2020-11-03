#!/bin/bash

#
#    Prepare source data for Kaldi ASR.
#    This includes processing the command line for source materials and starting the diarization through flist2scp.sh
#

timer="$(which time) -o $inter/time.log -f \"%e %U %S %M\""

mkdir -p $datadir/ALL/liumlog 
echo "Data preparation" >$inter/stage	
	
# handle input types: either directory, separate files, or list of files to process
while [[ $# > 1 ]] ; do
	i=$1
	shift
	if [ -f $i ]; then
		filetype=$(file -b $i)
		if [[ $filetype =~ .*audio.* ]]; then
			echo "Argument $i is a sound file, using it as audio"		
			if $copyall; then			
				cp $i $datadir/
			else
				fn=$(readlink -f $i)
				ln -s -f $fn $datadir
			fi
		elif [[ $filetype =~ .*text.* ]]; then
			echo "Argument $i is a text file, using it as list of files to copy"
			if $copyall; then				
				xargs -a $i cp -t $datadir
			else
				xargs -a $i ln -s -t $datadir
			fi
		fi
	elif [ -d $i ]; then
		echo -n "Argument $i is a directory, copying contents..  "		
		if $copyall; then
			cp -a $i/* $datadir
		else
			find $i -mindepth 1 -depth -type d -printf "%P\n" | while read dir; do mkdir -p "$datadir/$dir"; done
			find $i -type f -printf "%P\n" | while read file; do rm -f $datadir/$file; ln -s "$i/$file" "$datadir/$file"; done 
		# ln -s -f $i/* $data
		fi
		echo "done"
	else
		echo "Argument $i cannot be processed - skipping"		
	fi
done	

## Process source directory
# create file list to process, only use audio files whose type was specified in file_types
findcmd="find $datadir "
for type in $file_types; do
	findcmd="$findcmd -iname '*.${type}' -o "
done
findcmd=${findcmd%????}
eval $findcmd >$datadir/test.flist

# prepare data & do diarization
>$datadir/ALL/liumlog/done.log
eval $timer local/flist2scp.sh $datadir >>$logging 2>&1 &
pid=$!
numfiles=$(cat $datadir/test.flist | wc -l)
while kill -0 $pid 2>/dev/null; do
	numsegmented=$(cat $datadir/ALL/liumlog/done.log | wc -l)
	local/progressbar.sh $numsegmented $numfiles 50 "Diarization" 
	sleep 1
done
cat $inter/time.log | awk '{printf( "Diarization completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
		
numsegments=$(cat $datadir/ALL/segments | wc -l)
plu1=
plu2=
[ $numfiles -gt 1 ] && plu1="s"
[ $numsegments -gt 1 ] && plu2="s"
echo "Split $numfiles source file${plu1} into $numsegments segment${plu2}                              "         
cat $datadir/*.glm 2>/dev/null >$datadir/ALL/all.glm								# copy any .glm's	
utils/fix_data_dir.sh $datadir/ALL >>$logging 2>&1
cp -r $datadir/ALL/liumlog $result
