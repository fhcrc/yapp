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
where c.tax_id = ?
order by abundance desc;
