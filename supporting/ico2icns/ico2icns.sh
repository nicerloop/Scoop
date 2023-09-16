#!/bin/sh
# set -x

source="$1"
destination="$2"

fatal(){
  echo "$@" >&2
  exit 1
}

icotool --version >/dev/null 2>&1 || ( fatal "missing icotool ( homebrew install icoutils )" )
wrestool --version >/dev/null 2>&1 || ( fatal "missing wrestool ( homebrew install icoutils )" )
gsort --version >/dev/null 2>&1 || ( fatal "missing gsort ( homebrew install coreutils )" )

start_pwd=$(pwd)
work_dir="$(mktemp -d)"
cd "$work_dir" || exit 1

if [ "$(basename $source | rev | cut -d '.' -f 1 | rev)" = "exe" ]; then
    icon_name=$(wrestool -t 14 "$source" | head -n 1 | cut -d ' ' -f 2 | cut -d '=' -f 2)
    wrestool -x -t 14 -n "$icon_name" -o "work.ico" "$source"
    source="work.ico"
fi

if [ ! -f "$source" ]; then
  fatal "No icon in source"
fi

mkdir "work.iconset"
icotool -x -o "work.iconset" "$source"
cd "work.iconset" || exit
# identify images
for f in *
do
	PNG_WIDTH=$(basename -s ".png" "$f" | cut -d '_' -f 3 | cut -d 'x' -f 1)
	PNG_DEPTH=$(basename -s ".png" "$f" | cut -d '_' -f 3 | cut -d 'x' -f 3)
    mv "$f" "$PNG_DEPTH.$PNG_WIDTH.png"
done
# resize is necessary
for f in *
do
	PNG_DEPTH=$(basename -s ".png" "$f" | cut -d '.' -f 1)
	PNG_WIDTH=$(basename -s ".png" "$f" | cut -d '.' -f 2)
  MULTIPLE_WIDTH=$((2**($(echo "obase=2; $PNG_WIDTH" | bc | wc -m) - 2)))
  if [ "$PNG_WIDTH" != $MULTIPLE_WIDTH ];
  then
    MULTIPLE_TGT="$PNG_DEPTH.$MULTIPLE_WIDTH.png"
    if [ ! -e "$MULTIPLE_TGT" ];
    then
      sips -z $MULTIPLE_WIDTH $MULTIPLE_WIDTH "$f" --out "$MULTIPLE_TGT" >/dev/null
    fi
  fi
done
# prepare for icns
for f in $(ls . | gsort -V)
do
	PNG_WIDTH=$(basename -s ".png" "$f" | cut -d '.' -f 2)
	PNG_HALF_WIDTH=$((PNG_WIDTH / 2))
	PNG_ICON_NAME="icon_${PNG_WIDTH}x${PNG_WIDTH}.png"
	mv "$f" "$PNG_ICON_NAME"
	cp "$PNG_ICON_NAME" "icon_${PNG_HALF_WIDTH}x${PNG_HALF_WIDTH}@2x.png"
done
cd ..
iconutil --convert icns "work.iconset" --output "$destination"

cd "$start_pwd" || exit 1
rm -rf "$work_dir"

