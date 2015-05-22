#!/bin/bash

set -e

REFPKG=
PLACEFILE=
NBC_SEQUENCES=
DEDUP_INFO=
SQLITE_DB=placements.db
ADCL=
TMPDIR=${TMPDIR-$(pwd)}
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
    # echo $1 $2
    case "$1" in
        --refpkg ) REFPKG="$2"; shift 2 ;;
        --placefile ) PLACEFILE="$2"; shift 2 ;;
        --nbc-sequences ) NBC_SEQUENCES="$2"; shift 2 ;;
        --dedup-info ) DEDUP_INFO="$2"; shift 2 ;;
        --adcl ) ADCL="$2"; shift 2 ;;
        --sqlite-db ) SQLITE_DB="$2"; shift 2 ;;
        --tmpdir ) TMPDIR="$2"; shift 2 ;;
        --nproc ) NPROC="$2"; shift 2 ;;
        * ) break ;;
    esac
done

if [[ -n $1 ]]; then
    echo "Error: option $1 is not defined"
    exit 1
fi

# echo "refpkg: ${REFPKG:?}"
# echo "placefile: ${PLACEFILE:?}"
# echo "nbc sequences: ${NBC_SEQUENCES:?}"
# echo "dedup info: ${DEDUP_INFO:?}"
# echo "tmpdir: $TMPDIR"

DB_TMP=$(mktemp --tmpdir="$TMPDIR" placements.db.XXXXXXXXX)
rm -f "$SQLITE_DB"
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
