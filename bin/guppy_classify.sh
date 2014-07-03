#!/bin/bash

set -e

REFPKG=
PLACEFILE=
NBC_SEQUENCES=
DEDUP_INFO=
SQLITE_DB=placements.db
ADCL=
TMPDIR=$(pwd)
NPROC=1

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "Run `guppy classify` and multiclass_concat.py"
    echo "Options:"
    echo "--refpkg              - "
    echo "--placefile           - "
    echo "--nbc-sequences       - "
    echo "--dedup-info          - "
    echo "--adcl                - optional csv file containing output of 'guppy adcl'"
    echo "--sqlite-db           - outfile [$SQLITE_DB]"
    echo "--tmpdir              - use this temporary directory [$TMPDIR]"
    echo "--nproc               - number of processes [$NPROC]"
    exit 0
fi

while true; do
    case "$1" in
        --refpkg ) REFPKG="$2"; shift 2 ;;
        --placefile ) PLACEFILE="$2"; shift 2 ;;
        --nbc-sequences ) NBC_SEQUENCES="$2"; shift 2 ;;
        --dedup-info ) DEDUP_INFO="$2"; shift 2 ;;
        --sqlite-db ) SQLITE_DB="$2"; shift 2 ;;
        --tmpdir ) TMPDIR="$2"; shift 2 ;;
        * ) break ;;
    esac
done

for fn in "$REFPKG" "$PLACEFILE" "$NBC_SEQUENCES" "$DEDUP_INFO"; do
    test -f "$fn" || (echo "one or more required files were undefined or not found"; exit 1)
done

DB_TMP=$(mktemp --tmpdir="$TMPDIR" placements.db.XXXXXXXXX)

set -v

rm -f $SQLITE_DB

rppr prep_db -c "$REFPKG" --sqlite "$DB_TMP"

guppy classify --pp --classifier hybrid2 "$PLACEFILE" \
    -j "$NPROC" \
    -c "$REFPKG" \
    --nbc-sequences "$NBC_SEQUENCES" \
    --sqlite "$DB_TMP"

multiclass_concat.py --dedup-info "$DEDUP_INFO" "$DB_TMP"

if [[ -n "$ADCL" ]]; then
    csvsql --db "sqlite:///$DB_TMP" --table adcl --insert --snifflimit 1000 "$ADCL"
fi

mv "$DB_TMP" "$SQLITE_DB"
