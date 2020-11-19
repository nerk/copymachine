#!/bin/bash

DEV=`lsusb|grep "LiDE 210" | cut -d " " -f 2,4| sed 's/\([0-9]*\) \([0-9]*\):/\1:\2/'`

SCANBD_DEVICE="genesys:libusb:$DEV"
SCAN_DIR=/data/scanned

DPI=90

function imageToPDF {
    source=$1
    dest=$2

    A4=`echo "$DPI*8.27"|bc`x`echo "$DPI*11.69"|bc`

    convert $source -format jpg -quality 90 -density $DPI \
          -set colorspace Gray -separate -average -resize $A4 -repage $A4 $dest
}

function scanPage {
    scanimage -d $SCANBD_DEVICE --resolution 300 --mode Color \
         --depth 8 --format=tiff | convert - -gravity east -chop 60x0 \
         -level 3%,80%,0.6 $TIFF_FILE 

    imageToPDF $TIFF_FILE $PDF_FILE 
}

function sendEmail {
    for i in "${files[@]}"
    do
       attachment="file://$i"
       if [ "$attachments" = "" ]; then
           attachments="attachment='$attachment"
       else
           attachments="$attachments,$attachment"
       fi
    done
    attachments="$attachments'"
    thunderbird -compose "subject=Dateien,$attachments" &
}

declare -a files=()

while true
do
  NOW=`date +%F_%H%M%S`
  OUTFILE_BASE=scan-$NOW

  TIFF_FILE=$SCAN_DIR/$OUTFILE_BASE.tiff
  PDF_FILE=$SCAN_DIR/$OUTFILE_BASE.pdf

  kdialog --yesno "Bitte Dokument in den Scanner legen und danach 'Scannen' oder 'Fertig' drücken." --yes-label "Weiter" --no-label "Fertig"
  if [ $? -ne 0 ]; then
      kdialog --yesno "Email mit den Dokumenten senden?" --yes-label "Ja" --no-label "Nein"
      r=$?
      if [ $r -eq 0 -a ${#files[@]} -gt 0 ]; then
          sendEmail
      fi
      exit 1
  fi

  dbusRef=`kdialog --progressbar "Dokument wir gescanned..." 16`
  scanPage  &
  num=0
  while true
  do
      ps -C scanimage >/dev/null
      if [ $? -ne 0 ]; then
          qdbus $dbusRef org.kde.kdialog.ProgressDialog.close
          kdialog --yesnocancel "Was möchten Sie mit dem Dokument $TIFF_FILE machen?" --yes-label "Weiter" --no-label "Bearbeiten" --cancel-label "Drucken"
          r=$?
          if [ $r -eq 1 ]; then
            gimp $TIFF_FILE
          elif [ $r -eq 2 ]; then
            lp PDF_FILE.pdf
	  else 
            files+=( $PDF_FILE )
          fi
          break
      fi
      sleep 1
      num=$((num + 1))
      qdbus $dbusRef Set org.kde.kdialog.ProgressDialog value $num
  done
done


