select * from multiclass_concat
join taxa using(tax_id)
join ranks using(rank)
join (
  select name, sum(count) as abundance
  from weights
  group by name
) using(name)
where want_rank = 'species'
order by rank_order, tax_name;
