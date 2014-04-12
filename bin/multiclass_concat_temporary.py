#!/usr/bin/env python
"""
This script serves two roles:

First - Depending on the classification method used, the classification database may actually be left in a
somewhat inconsistent/incomplete state. In particular, the multiclass table may not contain classifications
for all the sequences needed to merge with
Second - Creates a view `multiclass_concat` and add names for concatenated taxids to the taxa table.
"""

import itertools
import argparse
import operator
import warnings
import logging
import sqlite3
import csv

log = logging.getLogger(__name__)
warnings.filterwarnings("always", category=UserWarning)


def concat_name(taxnames, rank, sep='/'):
    """Heuristics for creating a sensible combination of species names."""
    splits = [x.split() for x in taxnames]

    if (rank == 'species'
            and all(len(x) > 1 for x in splits)
            and len(set(s[0] for s in splits)) == 1):
        name = '%s %s' % (splits[0][0],
                          sep.join(sorted('_'.join(s[1:]) for s in splits)))
    else:
        name = sep.join('_'.join(s) for s in splits)

    return name


def add_multiclass_concat(database):
    """Does all the work of creating a multiclass concat table, populating it, and
    ensuring the rest of the database is consistent with it."""

    curs = database.cursor()
    curs.execute('DROP TABLE IF EXISTS multiclass_concat')

    curs.execute("""
        CREATE TABLE multiclass_concat AS
        SELECT placement_id,
               name,
               want_rank,
               GROUP_CONCAT(DISTINCT tax_id) AS tax_id,
               GROUP_CONCAT(DISTINCT rank)   AS rank,
               SUM(likelihood)               AS likelihood,
               COUNT(*)                      AS id_count
          FROM multiclass
         GROUP BY placement_id,
                  name,
                  want_rank
    """)

    curs.execute('CREATE INDEX multiclass_concat_name ON multiclass_concat (name)')

    # Get all of the constructed tax_ids and their constituent tax_names.
    curs.execute("""
        SELECT DISTINCT mcc.tax_id,
                        mc.rank,
                        t.tax_name
          FROM multiclass_concat mcc
               JOIN multiclass mc USING (placement_id, name, want_rank)
               JOIN taxa t
                 ON t.tax_id = mc.tax_id
         WHERE id_count > 1
    """)

    new_taxa = itertools.groupby(curs, operator.itemgetter(slice(None, 2)))
    def build_new_taxa():
        for (tax_id, rank), names in new_taxa:
            new_name = concat_name([name for _, _, name in names], rank)
            log.info('adding %r as %r at %r', tax_id, new_name, rank)
            yield tax_id, rank, new_name

    # We need another cursor so we can read from one and write using the other.
    database.cursor().executemany(
        "INSERT OR REPLACE INTO taxa (tax_id, rank, tax_name) VALUES (?, ?, ?)",
        build_new_taxa())

    database.commit()

#import itertools as it
#def get_results(curs, query, limit=None):
    #curs.execute(query)
    #iterable = curs if not limit else it.islice(curs, limit)
    #for res in iterable:
        #print res

def clean_database(database, dedup_info):
    """There are a number of problems with the classification database that make it so that (depending on the
    classification method) use of classif_table downstream of this analysis will not produce the correct
    results. Furthermore, """

    curs = database.cursor()

    # First create an index on multiclass. This will ensure we don't put anything in twice
    curs.execute("""CREATE UNIQUE INDEX IF NOT EXISTS multiclass_index
                        ON multiclass (name, want_rank, tax_id)""")

    # Rename placement_names so that we can create a new, correct placement_names. If user specifies
    # --keep-tables, we'll leave this copy in, in case they need it for mucking with things
    curs.execute("""ALTER TABLE placement_names RENAME
                       TO old_placement_names""")

    # Create the new placement_names table (note origin, which is in the origin, is not needed here)
    curs.execute("""
        CREATE TABLE placement_names (
               placement_id INTEGER NOT NULL,
               name TEXT NOT NULL,
               mass REAL NOT NULL,
               PRIMARY KEY (name))""")

    # Read the dedup info into a new dedup_info table. We need this for it's masses and for inflating
    # multiclass so it has classifications for all of the sequences it's supposed to
    curs.execute("""
        CREATE TABLE dedup_info (
               global_rep TEXT NOT NULL,
               specimen_rep TEXT NOT NULL,
               mass REAL NOT NULL, PRIMARY KEY (global_rep, specimen_rep))""")
    curs.executemany("INSERT INTO dedup_info VALUES (?, ?, ?)", dedup_info)

    # POPULATING placement_names:
    # First - fill with the things that we have matches for in the multiclass table. We'll use the
    # placement_id values in multiclass as the corresponding values in placement_names and get masses from
    # dedup_info
    curs.execute("""
        INSERT INTO placement_names
        SELECT placement_id,
               name,
               mass
          FROM dedup_info
               JOIN (SELECT DISTINCT placement_id, name
                       FROM multiclass) ON name = specimen_rep""")
    # Next - fill with the things there weren't name matches for in multiclass. Here, we look for the names
    # in dedup_info that are missing in multiclass, then use the global_rep match found in placement_names for
    # a (somewhat dummy) placement_id. WARNING! this placement_id may not actually be consistent with the
    # extraneous tables in the database (those deleted if --keep-tables isn't specified).
    curs.execute("""
        INSERT INTO placement_names
        SELECT placement_id,
               specimen_rep,
               di.mass
          FROM placement_names
               JOIN (SELECT *
                       FROM dedup_info
                      WHERE specimen_rep NOT IN (SELECT DISTINCT name from multiclass)) di
               ON global_rep = name""")

    # Inflate multiclass - now that placement_names is complete, we find the names that are missing in the
    # multiclass table, and using dedup_info, figure out for each of these names what the "global_rep" name is
    # that already lies in multiclass and create a copy of those mc tables where the name and placement id
    # point to the afore mentioned "missing" placement_id and name in placement_names.
    curs.execute("""
        INSERT INTO multiclass
        SELECT pn.placement_id, specimen_rep, want_rank, rank, tax_id, likelihood
          FROM (SELECT *
                  FROM placement_names
                 WHERE name NOT IN (SELECT DISTINCT name from multiclass)) pn
               JOIN dedup_info    ON pn.name = specimen_rep
               JOIN multiclass mc ON mc.name = global_rep""")

    # Commit database
    database.commit()


def drop_uneeded_tables(database):
    """Since the most pertinent tables are XXX"""
    curs = database.cursor()
    for table in ["placement_classifications",
                    "placement_evidence",
                    "placement_median_identities",
                    "placement_nbc",
                    "placement_positions",
                    "old_placement_names",
                    "dedup_info", # XXX not sure about this one...
                    "runs"]:
        curs.execute("DROP TABLE IF EXISTS %s" % table)
    database.commit()


def main():
    print """
************************************************************************
Warning! this version of multiclass_concat.py is only necessary until
https://github.com/matsen/pplacer/tree/334-missing-class-mass has been
merged and incorporated into the next pplacer release!
************************************************************************"""

    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s: %(message)s")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('database', type=sqlite3.connect,
        help='sqlite database (output of `rppr prep_db` after `guppy classify`)')
    parser.add_argument('-d', '--dedup-info', type=argparse.FileType('r'), required=True)
    parser.add_argument('-k', '--keep-tables', action="store_true")
    args = parser.parse_args()


    # Clean up the database so that masses will come out correctly/completely for all specimens downstream
    print "Starting cleanup"
    dedup_info_reader = csv.reader(args.dedup_info)
    clean_database(args.database, dedup_info_reader)

    # Run the actual multiclass_concat code
    print "Adding multiclass_concat"
    add_multiclass_concat(args.database)

    if not args.keep_tables:
        print "Removing uneeded tables"
        drop_uneeded_tables(args.database)


if __name__ == '__main__':
    main()

