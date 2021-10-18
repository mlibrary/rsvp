#!/usr/bin/env bash
VAR_DIR="/tmp/shipment_mover"
PREV_MD5="${VAR_DIR}/prev.md5"
THIS_MD5="${VAR_DIR}/this.md5"
LOCK_FILE="${VAR_DIR}/lock"
SHIP_LIST="${VAR_DIR}/shipments.txt"


# Where everything in process lives
PROCESS_BASE="/mnt/ulib-chaos/Mayhem/09_Vendor_Shipments"
# The directory examined for shipments
BASE_DIR="${PROCESS_BASE}/01_Auto_Intake"
# Container for 10% sample
VENDOR_REVIEW="${PROCESS_BASE}/02_Visual_QC"
# 10% sample goes here
TEN_PERCENT="${VENDOR_REVIEW}/ready_for_qc"
# Whole-shipment destination
HT_VENDOR="${PROCESS_BASE}/03_digital_QC"
# List of shipments processed
LIST_DIR="${PROCESS_BASE}/05_Vendor_Lists"
COUNT_LIST="${LIST_DIR}/auto-`date '+%Y%m%d'`.txt"


main() {
  stop_if_a_count_list_is_there
  be_sure_var_dir_exists

  run_if_not_already_running
}

stop_if_a_count_list_is_there() {
  if [ -s "$COUNT_LIST" ]; then
    exit 0
  fi
}

be_sure_var_dir_exists() {
  if ! [ -d "$VAR_DIR" ]; then
    require mkdir -p "$VAR_DIR"
    require touch "$PREV_MD5"
  fi
}

require() {
  if ! "$@"; then
    error_out "command failed: $*"
  fi
}

error_out() {
  for i in "$@"; do
    echo "${0}: error: $i" >&2
  done
  exit 1
}

run_if_not_already_running() {
  if ! mover_is_locked; then
    lock_shipment_mover
    require touch "$THIS_MD5"
    require echo -n "" > "$SHIP_LIST"
    examine_shipments
    [ -s "$SHIP_LIST" ] && move_shipments
    require mv "$THIS_MD5" "$PREV_MD5"
    unlock_shipment_mover
  fi
}

mover_is_locked() {
  if [ -e "$LOCK_FILE" ]; then
    ps `cat $LOCK_FILE` > /dev/null
  else
    false;
  fi
}

lock_shipment_mover() {
  echo "$$" > "$LOCK_FILE"
}

unlock_shipment_mover() {
  rm "$LOCK_FILE"
}

examine_shipments() {
  require cd "$BASE_DIR"

  for shipment in *; do
    examine_if_its_a_directory "$shipment"
  done
}

examine_if_its_a_directory() {
  if [ -d "$1" ]; then
    echo "$1" >> "$SHIP_LIST"
    examine_shipment "$1"
  fi
}

examine_shipment() {
  find "$1" -type f | sort | while read f; do
    md5sum "$f"
  done >> "$THIS_MD5"
}

move_shipments() {
  if dropoff_dir_has_changed; then
    while read shipment; do
      move_shipment "$shipment"
    done < "$SHIP_LIST"
    cd "$HT_VENDOR"
    #chmod 664 "$COUNT_LIST"
  fi
}

dropoff_dir_has_changed() {
  diff "$PREV_MD5" "$THIS_MD5" > /dev/null
  [ $? -ne 0 ]
}

move_shipment() {
  require mkdir -p "${TEN_PERCENT}/$1"
  pushd "${BASE_DIR}/$1" > /dev/null

  for volume in *; do
    if [ -d "$volume" ]; then
      deal_with_volume "$1" "$volume"
    fi
  done

  popd > /dev/null

  require mv "${BASE_DIR}/$1" "$HT_VENDOR"
}

deal_with_volume() {
  require mkdir -p "${TEN_PERCENT}/${1}/$2"
  pagecount=`ls "$2"/0???????.??? | wc -l`
  verify_pagecount "$2" "$pagecount"
  print_to_count_list "$1" "$2" "$pagecount"
  select_random_sample "$1" "$2" "$pagecount"
}

verify_pagecount() {
  n=1
  while [ $n -lt $2 ]; do
    base="`printf '%s/%08d\n' "$1" "$n"`"

    if ! [ -e "${base}.tif" ]; then
      if ! [ -e "${base}.TIF" ]; then
        if ! [ -e "${base}.jp2" ]; then
          error_out "$shipment/$volume missing seq=$n"
        fi
      fi
    fi
    ((n+=1))
  done
}

print_to_count_list() {
  printf '%s\t%s\t%s\t%s\r\n' \
    "`date '+%m/%d/%Y'`" "${1#Shipment_}" "$2" "$3" >> "$COUNT_LIST"
}

select_random_sample() {
  total="$3"
  size="$(((total+9)/10))"
  max_start="$((total - size + 1))"
  img_seq="$(((RANDOM % max_start) + 1))"
  stop_seq="$((img_seq + size))"

  while ! [ "$img_seq" = "$stop_seq" ]; do
    move_random_page "$1" "$2" "$img_seq"
    ((img_seq += 1))
  done
}

move_random_page() {
  random_dest="${TEN_PERCENT}/${1}/$2"
  base="`printf '%s/%08d' "$2" "$3"`"

  if [ -e "${base}.tif" ]; then
    ln -it "$random_dest" "${base}.tif"

  elif [ -e "${base}.TIF" ]; then
    ln -it "$random_dest" "${base}.TIF"

  elif [ -e "${base}.jp2" ]; then
    ln -it "$random_dest" "${base}.jp2"
  fi
}

main
