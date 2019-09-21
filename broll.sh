#check inputs
if [ $# -lt 3 ]; then
  printf "Usage: broll.sh <input_directory> <output_file> <audio_tempo> [<audio_file>]\n"
  exit
fi

#parse inputs and set constants
CLIPDIR=$1
OUTPUTFILE=$2
TEMPO=$3
AUDIOFILE=$4
TOTALCLIPS=$(ls -1 "$CLIPDIR" | grep -i ".mp4" | wc -l)
printf "Found $TOTALCLIPS .mp4 clips in directory $CLIPDIR\n"

#if no clips, do not edit
if [ $TOTALCLIPS -lt 1 ]; then
	exit
fi

#build input and filtergraph for ffmpeg command
printf "Selecting start/end times for each clip...\n"
CLIPNUM=0
FILTERGRAPH_CUT=""
FILTERGRAPH_CONCAT=""
CLIPLIST=""
for CLIPNAME in $(ls -1 "$CLIPDIR"); do
  BEATS=$((2*$(shuf -i 1-4 -n 1)))
  CLIPTIME=$(awk "BEGIN {print ($BEATS*60/$TEMPO)}")
  CLIPLENGTH=$(ffprobe -i $CLIPDIR/$CLIPNAME -show_format -v quiet | sed -n 's/duration=//p' | sed 's/\..*$//')
  CLIPSTARTMAX=$(($CLIPLENGTH-$(echo $CLIPTIME | sed 's/\..*$//')-1))
  CLIPSTART=$(shuf -i 0-$CLIPSTARTMAX -n 1)
  CLIPLIST="$CLIPLIST -i $CLIPDIR/$CLIPNAME"
  FILTERGRAPH_CUT="$FILTERGRAPH_CUT[$CLIPNUM:v]trim=start=$CLIPSTART:duration=$CLIPTIME,setpts=PTS-STARTPTS[v$CLIPNUM];[$CLIPNUM:a]atrim=start=$CLIPSTART:duration=$CLIPTIME,asetpts=PTS-STARTPTS[a$CLIPNUM];"
  FILTERGRAPH_CONCAT="$FILTERGRAPH_CONCAT[v$CLIPNUM][a$CLIPNUM]"
  CLIPNUM=$(($CLIPNUM+1))
done
FILTERGRAPH="$FILTERGRAPH_CUT""$FILTERGRAPH_CONCAT""concat=n=$TOTALCLIPS:v=1:a=1[outv][outa] -map [outv] -map [outa]"

#does not include mp3 yet
ffmpeg -safe 0 $CLIPLIST -filter_complex $FILTERGRAPH ."$OUTPUTFILE" -y

if [ -f $AUDIOFILE ]; then
  ffmpeg -safe 0 -i ."$OUTPUTFILE" -i "$AUDIOFILE" -shortest "$OUTPUTFILE" -y
  rm ."$OUTPUTFILE" 2>/dev/null
fi
