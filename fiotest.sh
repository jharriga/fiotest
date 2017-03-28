#!/bin/bash

LOGFILE=HOLD.log
#FILENAME="/mnt/usb/fioscratch"
FILENAME="/tmp/fioscratch" 
RUNTIME="30"
BLOCKsize_arr=(4K 64K 512K)
SIZE="100M"
# List of dependencies - verfied by 'chk_dependencies' function
DEPENDENCIES_arr=(
  "fio"               # I/O workload genarator
  "grep" "awk"        # tools
)

# GLOBALS used for FIO summary print functions
bw_rw_read=""
iops_rw_read=""
lat_rw_read=""
bw_rw_write=""
iops_rw_write=""
lat_rw_write=""

select_bw_rw() 
{
  file=$1
  bw_read=`grep "bw=" "$file" | grep read | \
    awk -F[=,s]+ '{printf("%s%s", $4, "s")}'`
#    bw_read=`grep "bw=" "$file" | grep read | awk -F[=,B]+ '{if(match($4, /[0-9]+K$/)) {printf("%d", substr($4, 0, length($4)-1));} else {printf("%d", int($4)/1024)}}'`
#
  bw_write=`grep "bw=" "$file" | grep write | \
    awk -F[=,s]+ '{printf("%s%s", $4, "s")}'`
#    bw_write=`grep "bw=" "$file" | grep write | awk -F[=,B]+ '{if(match($4, /[0-9]+K$/)) {printf("%d", substr($4, 0, length($4)-1));} else {printf("%d", int($4)/1024)}}'`

    bw_rw_read="$bw_read"
    bw_rw_write="$bw_write"
}

select_iops_rw() 
{
    file=$1
    iops_read=`grep "iops=" "$file" | grep read | awk -F[=,]+ '{print $6}'`
    iops_write=`grep "iops=" "$file" | grep write | awk -F[=,]+ '{print $6}'`
    iops_rw_read="$iops_read"
    iops_rw_write="$iops_write"
}

select_lat_rw() 
{
    file=$1
    # unit:ms
    line=`grep "read" "$file" -A3 | grep "avg" | grep -v -E "clat|slat"`
    lat_read=`echo $line | awk -F[=,:]+ '{if($1 == "lat (usec)") {printf("%.2f", $7/1000);} else {printf("%.2f", $7)} }'`
    line=`grep "write" "$file" -A3 | grep "avg" | grep -v -E "clat|slat"`
    lat_write=`echo $line | awk -F[=,:]+ '{if($1 == "lat (usec)") {printf("%.2f", $7/1000);} else {printf("%.2f", $7)} }'`

    lat_rw_read="$lat_read"
    lat_rw_write="$lat_write"
}

print_results()
{
  fioout=$1
  select_bw_rw $fioout
  select_iops_rw $fioout
  select_lat_rw $fioout

  echo -n "> READ: [bw] ${bw_rw_read}"    | tee -a $LOGFILE
  echo -n "  -  [iops] ${iops_rw_read}"   | tee -a $LOGFILE
  echo    "  -  [lat] ${lat_rw_read} ms"  | tee -a $LOGFILE
  echo -n "> WRITE: [bw] ${bw_rw_write}"  | tee -a $LOGFILE
  echo -n "  -  [iops] ${iops_rw_write}"  | tee -a $LOGFILE
  echo    "  -  [lat] ${lat_rw_write} ms" | tee -a $LOGFILE

}

function error_exit
{
# Function for exit due to fatal program error
# Accepts 1 argument:
#   string containing descriptive error message
# Copied from - http://linuxcommand.org/wss0150.php
    echo "${PROGNAME}: ${1:-"Unknown Error"} ABORTING..." 1>&2
    exit 1
}

function chk_dependencies {
  for cmd in "${DEPENDENCIES_arr[@]}"; do
    command -v $cmd >/dev/null 2>&1 || \
      error_exit "I require ${cmd} but it's not installed."
  done
}

# END FUNCTIONS

# MAIN
#
# Check dependencies are met
chk_dependencies

# Remove any existing LOGFILE
if [ -e $LOGFILE ]; then
  rm -f $LOGFILE
fi

# Timestamp the LOGFILE
echo "Timestamp: $(date)" | tee -a $LOGFILE

for bs in "${BLOCKsize_arr[@]}"; do
  echo "---------------------" | tee -a $LOGFILE
  echo "Running with bs of ${bs}" | tee -a $LOGFILE
  output="fio_${bs}.out"
  if [ -e $output ]; then
    rm -f $output
  fi
  fio --output="${output}" --rw=randrw --rwmixread=80 --bs="${bs}" \
    --time_based --runtime="${RUNTIME}" --filename="${FILENAME}" \
    --size="${SIZE}" --name=test >> $LOGFILE
  if [ ! -e $output ]; then
    echo "ERROR on fio run. Aborting"
    exit 1
  fi
  echo "SUMMARY ${SIZE}" | tee -a $LOGFILE
  print_results $output
  echo "FIO output ${SIZE}" >> $LOGFILE
  cat ${output} >> $LOGFILE
  echo "---------------------" | tee -a $LOGFILE
done


