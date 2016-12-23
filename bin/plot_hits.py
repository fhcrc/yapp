#!/usr/bin/env python

"""Generate an annotated plot of distances among sequences
"""

import argparse
import logging
import pandas as pd
import sys
from itertools import cycle

import numpy as np

import bokeh
from bokeh.plotting import figure, save, output_file, ColumnDataSource
from bokeh.models import CustomJS
from bokeh.models.widgets import DataTable, TableColumn
from bokeh.layouts import gridplot
from bokeh.palettes import brewer

logging.basicConfig(
    file=sys.stdout,
    format='%(levelname)s %(module)s %(lineno)s %(message)s',
    level=logging.WARNING)

log = logging


def get_colormap(levels, palette_name, ncol=None):

    levels.discard('')

    palettes = brewer[palette_name]
    ncol = ncol if ncol in palettes else max(palettes.keys())
    colors = palettes[ncol]
    color_cycle = cycle(colors)

    colormap = {level: next(color_cycle) for level in levels}
    colormap[''] = 'black'
    return colormap


def paired_plots(data, title=None, text_cols=None, palette_name='Paired'):
    """Create an interactive scatterplot. ``data`` is a pandas dataframe
    with (at least) column 'dist' in addition to columns
    containing other features. ``text_cols`` is a list of columns to
    include in the DataTable.

    Returns a pair of plot objects (plt, tab).

    """

    levels = data['organism'].fillna('')
    colormap = get_colormap(set(levels), palette_name)
    text_cols = text_cols or ['seqname']

    data['i'] = range(len(data))
    data['col'] = [colormap[x] for x in levels]
    data['fg_size'] = data['abundance'].apply(np.log2)
    data['bg_size'] = data['fg_size'] + 5

    # print data[['abundance', 'size']]

    source = ColumnDataSource(data)

    text_data = data[['x', 'y', 'i', 'col', 'fg_size', 'bg_size'] + text_cols]
    text_source = ColumnDataSource(data=text_data)

    callback = CustomJS(
        args=dict(
            source=source, text_source=text_source),
        code="""
        var inds = cb_obj.get('selected')['1d'].indices;
        var data = source.get('data');
        var text_data = text_source.get('data');

        for (var column in text_data){
            text_data[column] = [];
            for (var i = 0; i < inds.length; i++) {
                var ind = inds[i];
                text_data[column].push(data[column][ind])
            }
        }

        source.trigger('change');
        text_source.trigger('change');
        """)

    tools = [
        'box_select', 'lasso_select', 'resize', 'box_zoom', 'pan', 'reset',
        'tap'
    ]

    mds_plt = figure(
        title=title,
        plot_width=400,
        plot_height=400,
        tools=tools)

    # underlying markers are visible only when selected
    mds_plt.circle(
        x='x',
        y='y',
        source=text_source,
        fill_color='col',
        # line_color='black',
        size='bg_size'
    )

    mds_plt.circle(
        x='x',
        y='y',
        source=source,
        fill_color='col',
        line_color='black',
        size='fg_size'
    )

    formatters = {
        'accession': bokeh.models.widgets.tables.HTMLTemplateFormatter(),
        }

    tab = DataTable(
        source=text_source,
        columns=[
            TableColumn(
                field=col,
                title=col,
                formatter=formatters.get(col))
            for col in text_cols
        ],
        fit_columns=False,
        width=1200,
        # height=1200,
        sortable=True)

    # note that the callback is added to the source for the scatter plot only
    source.callback = callback

    return mds_plt, tab


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('coords', help="")
    parser.add_argument('hits', help="")
    parser.add_argument(
        '-o', '--outfile', default='plot_hits.html',
        help='output html file')
    parser.add_argument('-t', '--title', default='plot_hits')

    args = parser.parse_args(arguments)

    hits = pd.read_csv(args.hits)
    hits['qname'] = hits['qname'].apply(lambda x: x.split(':')[0])
    hits = hits.set_index('qname')

    coords = pd.read_csv(args.coords)
    coords['qname'] = coords['seqname'].apply(lambda x: x.split('_')[0])
    coords = coords.drop('seqname', axis=1)
    coords = coords.set_index('qname')

    tab = hits.join(coords, how='outer')
    tab = tab.reset_index()  # move qname back as a column

    def gb_link(row):
        url = '<a href="https://www.ncbi.nlm.nih.gov/nuccore/{a}" target=_blank>{a}</a>'
        accession = row['accession']
        if isinstance(accession, basestring):
            return url.format(a=accession)
        else:
            return ''

    tab.loc[:, 'accession'] = tab.apply(gb_link, axis=1)

    mds_plt, tab = paired_plots(
        data=tab,
        title=args.title,
        text_cols=[
            'qname', 'abundance', 'organism', 'accession', 'pct_id',
        ])

    output_file(filename=args.outfile, title=args.title)
    save(gridplot([[mds_plt], [tab]],
                  plot_width=1200,
                  plot_height=1200,
                  sizing_mode='stretch_both'))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
