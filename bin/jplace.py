from Bio import Phylo


class JParser(Phylo.NewickIO.Parser):
    def _parse_tree(self, text):
        tree = super()._parse_tree(text)
        return Phylo.PhyloXML.Phylogeny(
            root=tree.root,
            rooted=tree.rooted)

    def new_clade(sef, parent=None):
        clade = JClade()
        if parent:
            clade.parent = parent
        return clade


class JClade(Phylo.PhyloXML.Clade):
    def __init__(self, edge=None, **kwds):
        Phylo.PhyloXML.Clade.__init__(self, **kwds)
        self.edge = edge

    def __setattr__(self, name, value):
        if name == 'name' and value and value.startswith('{'):
            self.edge = int(value.strip('{}'))
        else:
            super().__setattr__(name, value)
