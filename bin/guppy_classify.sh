#!/bin/bash

set -e

maketemp() {
  # use this instead of mktemp to retain group file system permissions
  MYFILE=$(mktemp --tmpdir="$2" --dry-run "$1")
  touch $MYFILE
  echo $MYFILE
}

source $(dirname $0)/argparse.bash || exit 1
argparse "$@" <<EOF || exit 1
parser.add_argument('--refpkg')
parser.add_argument('--placefile')
parser.add_argument('--classifier', choices=['pplacer', 'nbc', 'hybrid2', 'hybrid5', 'rdp'],
                     default='hybrid2')
parser.add_argument('--nbc-sequences')
parser.add_argument('--dedup-info')
parser.add_argument('--adcl')
parser.add_argument('--seq-info')
parser.add_argument('--sqlite-db', default='placements.db', help='[%(default)s]')
parser.add_argument('--tmpdir', default="$(pwd)", help='[%(default)s]')
parser.add_argument('--nproc', type=int, default=1, help='[%(default)s]')
EOF

# echo "refpkg: ${REFPKG:?}"
# echo "placefile: ${PLACEFILE:?}"
# echo "nbc sequences: ${NBC_SEQUENCES:?}"
# echo "dedup info: ${DEDUP_INFO:?}"
# echo "tmpdir: $TMPDIR"

DB_TMP=$(maketemp placements.db.XXXXXXXXX "$TMPDIR")
rm -f "$SQLITE_DB"
rppr prep_db -c "$REFPKG" --sqlite "$DB_TMP"

guppy classify --pp "$PLACEFILE" \
      --classifier "$CLASSIFIER" \
      -j "$NPROC" \
      -c "$REFPKG" \
      --nbc-sequences "$NBC_SEQUENCES" \
      --sqlite "$DB_TMP"

multiclass_concat.py --dedup-info "$DEDUP_INFO" "$DB_TMP"

if [[ -n "$ADCL" ]]; then
    csvsql --db "sqlite:///$DB_TMP" --table adcl --insert --snifflimit 1000 "$ADCL"
fi

if [[ -n "$SEQ_INFO" ]]; then
    sqlite3 "$DB_TMP" 'create table seq_info (name TEXT, specimen TEXT)'
    sqlite3 "$DB_TMP" <<EOF
.mode csv
.import "$SEQ_INFO" seq_info
EOF
fi

if [[ -n "$DEDUP_INFO" ]]; then
    sqlite3 "$DB_TMP" 'create table weights (name TEXT, name1 TEXT, count INTEGER)'
    sqlite3 "$DB_TMP" <<EOF
.mode csv
.import "$DEDUP_INFO" weights
EOF
fi

# add placement details
details_temp=$(maketemp details.csv.XXXXXXXXX "$TMPDIR")
detail_names_temp=$(maketemp detail_names.csv.XXXXXXXXX "$TMPDIR")

placements.py "$PLACEFILE" --details "$details_temp" --names "$detail_names_temp"
csvsql --db "sqlite:///$DB_TMP" --table details --insert --snifflimit 1000 "$details_temp"
csvsql --db "sqlite:///$DB_TMP" --table detail_names --insert --snifflimit 1000 "$detail_names_temp"
bioy index "$DB_TMP" seq_info,name,name1,pnum

rm -f "$details_temp" "$detail_names_temp"
mv "$DB_TMP" "$SQLITE_DB"
