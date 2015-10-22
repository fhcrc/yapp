select
c.name as otu_rep,
c.abundance,
h.pct_id,
c.tax_name as classif_name,
c.rank,
i.*
from classif c
join hits h on c.name = h.query
join ref_info i on h.target = i.seqname
where abundance >= MIN_MASS
order by classif_name, abundance desc;
