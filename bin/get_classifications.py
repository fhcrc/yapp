#!/usr/bin/env python3

"""Produce a table of classifications for each input sequence in the
output of guppy classify

"""

from __future__ import print_function
import sys
import argparse
import sqlite3
import csv
from itertools import groupby
from operator import itemgetter, xor
from functools import reduce
import logging
import pprint

import sqlalchemy
from taxtastic.taxonomy import Taxonomy
from taxtastic.subcommands.taxtable import as_taxtable_rows

logging.basicConfig(level=logging.WARNING, format='%(levelname)s %(funcName)s %(lineno)d %(message)s')
log = logging.getLogger(__name__)


def dict_factory(cursor, row):
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d


def concat_name(taxnames, rank, sep='/'):
    """Heuristics for creating a sensible combination of species names."""

    if len(taxnames) == 1:
        return taxnames[0]

    splits = [x.split() for x in taxnames]

    if (rank == 'species'
            and all(len(x) > 1 for x in splits)
            and len(set(s[0] for s in splits)) == 1):
        name = '%s %s' % (splits[0][0],
                          sep.join(sorted('_'.join(s[1:]) for s in splits)))
    else:
        name = sep.join(' '.join(s) for s in splits)

    return name


def unconcat_name(name, rank):
    name = name.strip()

    if '/' in name:
        if rank == 'species' and len(name.split()) == 2:
            genus, species = name.split()
            names = {' '.join([genus, s]) for s in species.split('/')}
        else:
            names = set(name.split('/'))
    else:
        names = {name}

    return names


def test_unconcat_names():
    tests = [
        ('Genus a/b', 'species', {'Genus a', 'Genus b'}),
        ('GenusA/GenusB', 'genus', {'GenusA', 'GenusB'}),
        ('Genus a', 'species', {'Genus a'}),
        ('Lelliottia amnigena/Buttiauxella agrestis', 'species',
         {'Lelliottia amnigena', 'Buttiauxella agrestis'}),
    ]

    for name, rank, result in tests:
        print([name, rank, result])
        assert unconcat_name(name, rank) == result


def combine_lineages(lineages):

    d = {}
    for key in reduce(set.union, [set(L.keys()) for L in lineages]):
        vals = {L[key] for L in lineages if key in L}
        d[key] = ','.join(vals)

    d['tax_name'] = concat_name([L['tax_name'] for L in lineages], d['rank'])

    return d


def test_combine_lineages():
    lineages = [{'superkingdom': '2', 'family': '1570339', 'rank':
                 'species', 'order': '1737405', 'parent_id': '165779',
                 'root_': '131567', 'phylum': '1239', 'superkingdom_':
                 '1783272', 'species': '33034', 'tax_name':
                 'Anaerococcus prevotii', 'genus': '165779', 'root':
                 '1', 'class': '1737404', 'tax_id': '33034'},
                {'superkingdom': '2', 'family': '1570339', 'rank':
                 'species', 'order': '1737405', 'parent_id': '165779',
                 'root_': '131567', 'phylum': '1239', 'superkingdom_':
                 '1783272', 'species': '33036', 'tax_name':
                 'Anaerococcus tetradius', 'genus': '165779', 'root':
                 '1', 'class': '1737404', 'tax_id': '33036'}]

    combined = combine_lineages(lineages)
    assert isinstance(combined, dict)
    assert combined['tax_name'] == 'Anaerococcus prevotii/tetradius'


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    inputs = parser.add_argument_group('input files')
    inputs.add_argument(
        'placedb', help="output of 'guppy classify' (sqlite3)")

    inputs.add_argument(
        '--to-rename', type=argparse.FileType(),
        help="""csv file with headers 'tax_name', 'rank', 'sv',
        'new_tax_name', 'new_rank'""")
    inputs.add_argument(
        '--taxdb', help="taxonomy database (sqlite3)")

    outputs = parser.add_argument_group('output files')
    outputs.add_argument(
        '-c', '--classifications', default=sys.stdout, type=argparse.FileType('w'),
        help="csv file describing classification of each input (default stdout)")

    parser.add_argument('--test', action='store_true', default=False,
                        help='run tests and exit')

    args = parser.parse_args(arguments)

    if args.test:
        test_combine_lineages()
        test_unconcat_names()
        sys.exit()

    cmd = """
    select placement_id,
           name,
           m.want_rank,
           group_concat(distinct m.tax_id) as tax_id,
           m.rank,
           sum(m.likelihood) as likelihood,
           group_concat(t.tax_name, '^') as _tax_name,
           r.rank_order
    from placement_names
    left join multiclass m using(placement_id, name)
    left join taxa t using(tax_id)
    left join ranks r on m.rank = r.rank
    left join ranks wr on m.want_rank = wr.rank
    where want_rank is not NULL
    and (m.rank = want_rank
         or want_rank in ('phylum', 'class', 'order', 'family', 'genus', 'species'))
    and wr.rank_order <= :min_rank_order
    group by placement_id, name, want_rank
    order by name, wr.rank_order, tax_name
    """

    fieldnames = ['name', 'want_rank', 'rank', 'rank_order',
                  'tax_id', 'tax_name', 'likelihood']
    writer = csv.DictWriter(args.classifications, fieldnames, extrasaction='ignore')
    writer.writeheader()

    min_rank = 'species'
    rows = []
    with sqlite3.connect(args.placedb) as conn:
        conn.row_factory = dict_factory
        cur = conn.cursor()

        cur.execute('select rank, rank_order from ranks')
        all_ranks = {r['rank']: r['rank_order'] for r in cur.fetchall()}
        min_rank_order = all_ranks[min_rank]

        cur.execute(cmd, {'min_rank_order': min_rank_order})
        for row in cur.fetchall():
            row['tax_name'] = concat_name(row['_tax_name'].split('^'), row['rank'])
            rows.append(row)

    if xor(bool(args.to_rename), bool(args.taxdb)):
        sys.exit('both --to-rename and --taxdb are required '
                 'if one or the other is provided')
    elif not (args.to_rename and args.taxdb):
        writer.writerows(rows)
        return

    # get list of all tax_names represented among new_tax_names
    to_rename = list(csv.DictReader(args.to_rename))

    new_tax_names = reduce(
        set.union, [unconcat_name(row['new_tax_name'], row['new_rank'])
                    for row in to_rename])

    log.info('new tax names:')
    log.info(pprint.pformat(new_tax_names))

    # retrieve tax_id(s) and lineage of each new tax_name
    engine = sqlalchemy.create_engine('sqlite:///' + args.taxdb)
    tax = Taxonomy(engine)

    # find a tax_id correponding to each new tax_name. Substitute the
    # original tax_id when the new tax_name cannot be found.
    new_tax_ids = []
    missing_tax_names = []
    for tax_name in new_tax_names:
        try:
            new_tax_id, __, __ = tax.primary_from_name(tax_name)
        except ValueError:
            log.error(f'could not find {tax_name} in taxonomy')
            missing_tax_names.append(tax_name)
        else:
            new_tax_ids.append(new_tax_id)

    if missing_tax_names:
        sys.exit('Error: missing tax names')

    taxdict = dict(zip(new_tax_names, new_tax_ids))

    log.info('taxdict: ')
    log.info(pprint.pformat(taxdict))

    lineage_rows = tax._get_lineage_table(new_tax_ids)
    taxtable = {}
    for tax_id, grp in groupby(lineage_rows, lambda row: row[0]):
        __, tax_rows = as_taxtable_rows(
            grp, unordered=tax.unordered_ranks, seen=taxtable)
        taxtable.update(dict(tax_rows))

    log.info('taxtable')
    log.info(pprint.pformat(taxtable))

    # identify SVs or tax_names to rename
    rename_sv = {}
    rename_taxon = {}
    for row in to_rename:
        getter = itemgetter('tax_name', 'rank', 'sv', 'new_tax_name', 'new_rank')
        tax_name, rank, sv, new_tax_name, new_rank = [x.strip() for x in getter(row)]
        new_tax_ids = [taxdict[name] for name in unconcat_name(new_tax_name, new_rank)]

        if len(new_tax_ids) == 1:
            lineage = taxtable[new_tax_ids[0]]
        else:
            lineage = combine_lineages([taxtable[tax_id] for tax_id in new_tax_ids])

        new = (new_rank, lineage)
        if sv:
            rename_sv[sv] = new
        else:
            rename_taxon[(rank, tax_name)] = new

    # rename taxa if necessary and write output
    for sv_name, grp in groupby(rows, itemgetter('name')):
        grp = list(grp)
        ranks = {row['want_rank']: row for row in grp}

        for rank, rank_order in sorted(all_ranks.items(), key=lambda x: x[1]):
            orig = ranks.get(rank, {})
            if not orig:
                continue

            new_rank, new_lineage = (
                rename_sv.get(sv_name) or
                rename_taxon.get((orig['rank'], orig['tax_name'])) or
                [None, None])

            if new_rank:
                new_tax_id = new_lineage[new_rank]
                row = {'name': sv_name,
                       'want_rank': new_rank,
                       'rank': new_rank,
                       'rank_order': all_ranks[new_rank],
                       'tax_id': new_tax_id,
                       'tax_name': new_lineage['tax_name'],
                       'likelihood': None}

                ranks[new_rank] = row
                if not rank == new_rank:
                    # delete the record for the original rank (eg,
                    # species_group replacing a species-level
                    # classification)
                    del ranks[rank]

        writer.writerows(
            sorted(ranks.values(), key=lambda row: all_ranks[row['want_rank']]))

    args.classifications.close()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
