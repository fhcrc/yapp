#!/usr/bin/env python

import sys
import fastalite

seqs = fastalite.fastalite(sys.stdin)
for seq in seqs:
    sys.stdout.write('>{}\n{}\n'.format(
        seq.id, seq.seq.replace('.', '-').upper()))

