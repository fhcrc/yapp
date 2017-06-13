select
c.name as otu_rep,
c.abundance,
h.pct_id,
c.tax_name as classif_name,
c.rank,
-- r.*
-- r.organism,
-- r.date,
r.seqname,
r.version,
r.tax_id,
coalesce(r.description, r.organism) as description_or_organism,
r.length,
r.ambig_count,
r.is_type,
r.collection
from classif c
join hits h on c.name = h.query
join ref_info r on h.target = r.seqname
where abundance >= MIN_MASS
order by classif_name, abundance desc;
