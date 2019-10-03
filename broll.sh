#check inputs
if [ $# -lt 3 ]; then
  printf "Usage: broll.sh <input_directory> <output_file> <max_clips> <tempo> <audio_file>\n"
  exit
fi

#parse inputs and set constants
CLIPDIR=$1
OUTPUTFILE=$2
MAXCLIPS=$3
TEMPO=$4
AUDIOFILE=$5
TOTALCLIPS=$(ls -1 "$CLIPDIR" | grep -i ".mp4" | wc -l)
printf "Found $TOTALCLIPS .mp4 clips in directory $CLIPDIR\n"

#if no clips, do not edit
if [ $TOTALCLIPS -lt 1 ]; then
	exit
elif [ $MAXCLIPS -gt $TOTALCLIPS ]; then
  MAXCLIPS=$TOTALCLIPS
fi

#build input and filtergraph for ffmpeg command
printf "Selecting start/end times for each clip...\n"
CLIPNUM=1
FILTERGRAPH_CUT=""
FILTERGRAPH_CONCAT=""
CLIPLIST=""
DIMENSIONS="1920x1080"
BLACKSCREENFILE=".videoblackscreens.mp4"
for CLIPNAME in $(ls -1 "$CLIPDIR" | shuf -n $MAXCLIPS); do
  BEATS=$((2*$(shuf -i 1-4 -n 1)))
  CLIPTIME=$(awk "BEGIN {print ($BEATS*60/$TEMPO)}")
  CLIPLENGTH=$(ffprobe -i $CLIPDIR/$CLIPNAME -show_format -v quiet | sed -n 's/duration=//p' | sed 's/\..*$//')
  CLIPSTARTMAX=$(($CLIPLENGTH-$(echo $CLIPTIME | sed 's/\..*$//')-1))
  if [ $CLIPSTARTMAX -lt 1 ]; then
    MAXCLIPS=$(($MAXCLIPS-1))
    printf "Could not use '$CLIPNAME' --> too short! $MAXCLIPS clips remaining...\n"
    continue
  fi
  CLIPSTART=$(shuf -i 0-$CLIPSTARTMAX -n 1)
  CLIPLIST="$CLIPLIST -i $CLIPDIR/$CLIPNAME"
  FILTERGRAPH_CUT="$FILTERGRAPH_CUT[$CLIPNUM:v]trim=start=$CLIPSTART:duration=$CLIPTIME,setpts=PTS-STARTPTS,scale=$DIMENSONS[v$CLIPNUM];[$CLIPNUM:a]atrim=start=$CLIPSTART:duration=$CLIPTIME,asetpts=PTS-STARTPTS[a$CLIPNUM];"
  FILTERGRAPH_CONCAT="$FILTERGRAPH_CONCAT[v$CLIPNUM][a$CLIPNUM]"
  CLIPNUM=$(($CLIPNUM+1))
done

#add black screens to beginning/end
FOURBEATS=$(awk "BEGIN {print (240/$TEMPO)}")
ffmpeg -f lavfi -i color=c=black:s=$DIMENSIONS:d=$FOURBEATS -f lavfi -i aevalsrc=0:d=$FOURBEATS $BLACKSCREENFILE -y -hide_banner
CLIPLIST="-i $BLACKSCREENFILE $CLIPLIST -i $BLACKSCREENFILE"
FILTERGRAPH_CUT="[0:v]null[v0];[0:a]anull[a0];$FILTERGRAPH_CUT[$(($MAXCLIPS+1)):v]null[v$(($MAXCLIPS+1))];[$(($MAXCLIPS+1)):a]anull[a$((MAXCLIPS+1))];"
FILTERGRAPH_CONCAT="[v0][a0]$FILTERGRAPH_CONCAT[v$(($MAXCLIPS+1))][a$(($MAXCLIPS+1))]"
#build final filtergraph
CRF=31
FILTERGRAPH="$FILTERGRAPH_CUT""$FILTERGRAPH_CONCAT""concat=n=$(($MAXCLIPS+2)):v=1:a=1[outv][outa] -map [outv] -map [outa] -crf $CRF"

#do the thing
if [ -f $AUDIOFILE ]; then
  ffmpeg $CLIPLIST -filter_complex $FILTERGRAPH ."$OUTPUTFILE" -y -hide_banner
  VIDEOLENGTH=$(ffprobe -i ."$OUTPUTFILE" -show_entries stream=codec_type,duration -of compact=p=0:nk=1 | grep "audio|" | sed "s/audio|//")
  STARTFADEOUT=$(awk "BEGIN {print ($VIDEOLENGTH - $FOURBEATS)}")
  ffmpeg -i ."$OUTPUTFILE" -i "$AUDIOFILE" -safe 0 -af "afade=in:st=0:d=$FOURBEATS,afade=out:st=$STARTFADEOUT:d=$FOURBEATS" -c:v copy -map 0:v:0 -map 1:a:0 -shortest "$OUTPUTFILE" -y -hide_banner
  rm ."$OUTPUTFILE" 2>/dev/null
else
  #this has a bug I haven't solved yet - just pass an audio file lol
  ffmpeg $CLIPLIST -filter_complex $FILTERGRAPH "$OUTPUTFILE" -y -hide_banner
fi

sleep 1
rm $BLACKSCREENFILE
