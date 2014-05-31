#!/usr/bin/env python

from __future__ import print_function
import sys, math
import pandas as pd
from matplotlib import pylab as plt

default_layout = (2, 2)
default_plots = [
(
    'Single Thread - Linear',
    'Random == 0 and Threads == 1 and Stride in (1, 16, 1024)',
),(
    'Multiple Threads - Linear (Locked)',
    'Atomic == 1 and Random == 0 and Threads in (2,4) and Stride in (1, 16, 1024)',
),(
    'Stride in (1, 16)',
    'Random == 0 and Stride in (1, 16) and ((Atomic == 0 and Threads == 1) or (Atomic == 1 and Threads in (2, 4)))',
),(
    'Stride = 1024',
    'Stride == 1024 and ((Atomic == 0 and Threads == 1) or (Atomic == 1 and Threads in (2, 4)))',
)
]

def mk_plots(filename, plots=default_plots, layout=default_layout):
    df = pd.read_csv(filename, index_col=[0,1,2,3,4])
    rows, cols = layout
    fig, axes = plt.subplots(nrows=rows, ncols=cols, sharey=True)
    i = 0
    for title_str, query_str in plots:
        r = i // cols
        c = i - r*cols
        df.query(query_str).Time.unstack([0,1,2,3]).plot(
            title=title_str,
            ax=axes[r,c],
            logx=True,
        ).set_ylabel('Latency (nsec)')
        i += 1

    return fig

if __name__ == '__main__':
    if len(sys.argv) == 1:
        print('Usage: '+sys.argv[0]+' report_file [report_file [...]]')
        sys.exit(1)
    for report in sys.argv[1:]:
        mk_plots(report)
    plt.show()

