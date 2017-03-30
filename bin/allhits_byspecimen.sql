select
w.name as otu_rep,
w.name1 as specimen_rep,
s.specimen,
w.abundance,
h.pct_id,
c.tax_name as classif_name,
c.rank,
-- r.*
-- r.organism,
-- r.date,
r.seqname,
r.version,
r.tax_id,
r.description,
r.length,
r.ambig_count,
r.is_type
from classif c
join hits h on c.name = h.query
join ref_info r on h.target = r.seqname
join weights w on w.name = c.name
join seq_info s on s.name = w.name1
where c.abundance >= MIN_MASS  -- total abundance
order by classif_name, c.abundance desc;
