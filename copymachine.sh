#!/bin/bash

SCANBD_DEVICE="genesys:libusb:003:005"
SCAN_DIR=/data/scanned
NOW=`date +%F_%H%M%S`
OUTFILE_BASE=scan-$NOW

DPI=150

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
         -level 3%,80%,0.6 $SCAN_DIR/$OUTFILE_BASE.tiff 
}

while true
do
  kdialog --yesno "Bitte Dokument in den Scanner legen und danach 'Weiter' drücken." --yes-label "Weiter" --no-label "Abbruch"
  if [ $? -ne 0 ]; then
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
          kdialog --yesnocancel "Was möchten Sie mit dem Dokument $SCAN_DIR/$OUTFILE_BASE.tiff machen?" --yes-label "Nichts" --no-label "Bearbeiten" --cancel-label "Drucken"
          if [ $? -eq 1 ]; then
            gimp $SCAN_DIR/$OUTFILE_BASE.tiff
          elif [ $? -eq 2 ]; then
            imageToPDF $SCAN_DIR/$OUTFILE_BASE.tiff $SCAN_DIR/$OUTFILE_BASE.pdf
            lp $SCAN_DIR/$OUTFILE_BASE.pdf
          fi
          break
      fi
      sleep 1
      num=$((num + 1))
      qdbus $dbusRef Set org.kde.kdialog.ProgressDialog value $num
  done
done
