select
c.name as sv,
c.rank,
h.pct_id,
c.tax_name as classif_name,
coalesce(r.description, r.organism) as hit_desc,
r.seqname,
r.version,
r.tax_id,
r.length,
r.ambig_count,
r.is_type
from classif c
join hits h on c.name = h.query
join ref_info r on h.target = r.seqname
where c.want_rank = 'species'
order by c.name;
