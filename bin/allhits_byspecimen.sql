select
w.name as sv,
w.name1 as specimen_rep,
w.abundance,
s.specimen,
c.rank,
h.pct_id,
c.tax_name as classif_name,
coalesce(r.description, r.organism) as description_or_organism,
r.seqname,
r.version,
r.tax_id,
r.length,
r.ambig_count,
r.is_type
from classif c
join hits h on c.name = h.query
join ref_info r on h.target = r.seqname
join weights w on w.name = c.name
join seq_info s on s.name = w.name1
where c.want_rank = 'species'
order by sv, w.abundance desc;
