#check inputs
if [ $# -lt 3 ]; then
  printf "Usage: broll.sh <input_directory> <output_file> <audio_tempo>\n"
  exit
fi

#parse inputs and set constants
LISTFILE=".cliplist.txt"
CLIPDIR=$1
OUTPUTFILE=$2
TEMPO=$3
TOTALCLIPS=$(ls -1 "$CLIPDIR" | grep -i ".mp4" | wc -l)
printf "Found $TOTALCLIPS .mp4 clips in $CLIPDIR\n"

#cut video clips to length
for CLIPNAME in $(ls -1 "$CLIPDIR"); do
  BEATS=$((2*$(shuf -i 1-4 -n 1)))
  CLIPTIME=$(awk "BEGIN {print ($BEATS*60/$TEMPO)}")
  CLIPLENGTH=$(ffprobe -i $CLIPDIR/$CLIPNAME -show_format -v quiet | sed -n 's/duration=//p' | sed 's/\..*$//')
  CLIPSTARTMAX=$(($CLIPLENGTH-$(echo $CLIPTIME | sed 's/\..*$//')-1))
  CLIPSTART=$(shuf -i 0-$CLIPSTARTMAX -n 1)
  ffmpeg -i "$CLIPDIR"/"$CLIPNAME" -ss $CLIPSTART -t $CLIPTIME ./."$(echo $CLIPNAME | sed -e 's/.mp4/_cut&/I')"
done

#generate input file for concatenation and concatenate clips
ls -1a | grep "_cut" | sed "s/^/file /" | shuf > "$LISTFILE"
ffmpeg -f concat -safe 0 -i "$LISTFILE" -c copy "$OUTPUTFILE" -y

#cleanup temporary files
rm ./.*_cut.mp4 2>/dev/null
rm ./.*_cut.MP4 2>/dev/null
rm "$LISTFILE" 2>/dev/null

printf "Done.\n"
sleep 2
