from Bio.Seq import Seq

def replace_dots(seqs):
    for seq in seqs:
        seq.seq = Seq(seq.seq.tostring().replace('.', '-'))
        yield seq
