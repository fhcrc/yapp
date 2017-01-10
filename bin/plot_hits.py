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
from bokeh.models.annotations import Label
from bokeh.layouts import gridplot
from bokeh.layouts import layout
from bokeh.palettes import brewer

logging.basicConfig(
    file=sys.stdout,
    format='%(levelname)s %(module)s %(lineno)s %(message)s',
    level=logging.WARNING)

log = logging


def make_link(row, key, fstr):
    if not isinstance(row[key], basestring):
        return ''
    else:
        return fstr.format(**row)


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
    data['fg_size'] = data['abundance'].apply(np.log10) * 10
    data['bg_size'] = data['fg_size'] + 5

    source = ColumnDataSource(data)

    text_data = data[['x', 'y', 'i', 'col', 'fg_size', 'bg_size'] + text_cols]
    text_source = ColumnDataSource(data=text_data)

    callback = CustomJS(
        args=dict(
            source=source,
            text_source=text_source
        ),
        code="""
        function contains(a, obj) {
            for (var e in a) {
                if (e == obj) {
                    return true;
                }
            }
            return false;
        }

        var inds = cb_obj.get('selected')['1d'].indices;
        var data = source.get('data');
        var text_data = text_source.get('data');

        for (var column in text_data){
            text_data[column] = [];
            for (var i = 0; i < inds.length; i++) {
                var ind = inds[i];
                text_data[column].push(data[column][ind]);
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
        line_color='black',
        size='bg_size'
    )

    mds_plt.circle(
        x='x',
        y='y',
        source=source,
        # fill_color='col',
        # line_color='black',
        line_color='col',
        fill_color=None,
        size='fg_size'
    )

    formatters = {
        'accession': bokeh.models.widgets.tables.HTMLTemplateFormatter(),
        }

    widths = {
        'organism': 400,
    }

    tab = DataTable(
        source=text_source,
        columns=[
            TableColumn(
                field=col,
                title=col,
                width=widths.get(col, 100),
                formatter=formatters.get(col)
            )
            for col in text_cols
        ],
        fit_columns=False,
        width=1200,
        # height=1200,
        sortable=True,
    )

    # note that the callback is added to the source for the scatter plot only
    source.callback = callback

    return mds_plt, tab


def annotation_plot(msg):

    plt = figure(
        # plot_width=100, plot_height=100,
    )

    # create an invisible plot to suppress the warning message
    plt.circle(line_color=None, fill_color=None)
    plt.axis.visible = False
    plt.grid.visible = False

    text = Label(
        text=msg, x=0, y=-10,
        x_units='screen',
        y_units='screen',
        render_mode='css',
    )

    plt.add_layout(text, 'above')
    return plt


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

    gb_fstr = ('<a href="https://www.ncbi.nlm.nih.gov/nuccore/{accession}" '
               'target=_blank>{accession}</a>')

    tab.loc[:, 'accession'] = tab.apply(make_link, axis=1, args=('accession', gb_fstr))

    mds_plt, tab_plt = paired_plots(
        data=tab,
        title=args.title,
        text_cols=[
            'qname', 'abundance', 'accession', 'pct_id', 'organism',
        ])

    msg = """
    <ul>
    <li>Circles correspond to inferred sequences</li>
    <li>Circle size is proportional to log10(weight)</li>
    <li>Select points and click on the title bar of the table to show
        annotation for specified sequences</li>
    <li><code>pct_id</code> shows the percent identity to the type strain
        identified in the column <code>organism</code></li>
    <li>Click on a point to highlight the corresponding annotation</li>
    <li>Refresh the page to reset the plot</li>
    </ul>
    """

    annotation_plt = annotation_plot(msg)

    output_file(filename=args.outfile, title=args.title)
    save(gridplot([[mds_plt, annotation_plt], [tab_plt]],
                  plot_width=1200,
                  plot_height=1200,
                  sizing_mode='stretch_both',
                  # sizing_mode='scale_both',

    ))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
