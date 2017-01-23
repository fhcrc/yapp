select SUBSTR(mc.name,1,8) as otu,
       mc.rank,
       rank_order,
       mc.tax_id,
       taxa.tax_name,
       adcl,
       sum(weight) as mass
from multiclass_concat mc
join taxa using(tax_id, rank)
join ranks using(rank)
join adcl using (name)
where want_rank='species'
group by otu
order by rank_order, tax_name, mass desc;
