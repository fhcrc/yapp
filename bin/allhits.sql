select
c.name,
c.abundance,
c.tax_name as classif_name,
c.rank,
i.*,
h.pct_id

from classif c
join hits h on c.name = h.query
join ref_info i on h.target = i.seqname
where abundance >= MIN_MASS
order by classif_name, abundance desc;
