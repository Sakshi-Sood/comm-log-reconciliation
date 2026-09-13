-- basic count, no filters applied yet
select count(*) from communication_log
where merchant_id = 501 and communication_type = '2';
-- 30

-- trying distinct customers too, just to compare
select count(distinct customer_id) from communication_log
where merchant_id = 501 and communication_type = '2';
-- 25 (turned out to be misleading later)

-- checking which campaigns fail the eligibility rule from README
select id, creation_status, processing_status
from campaign
where not (
    creation_status in ('approved','aborted','resumed','stopped')
    and processing_status = 'processed'
);
-- 9004 shows up here, still approval_awaiting

-- count again after removing that campaign
select count(*)
from communication_log cl
join campaign c on c.id = cl.communication_id
where cl.merchant_id = 501
  and cl.communication_type = '2'
  and c.creation_status in ('approved','aborted','resumed','stopped')
  and c.processing_status = 'processed';
-- 26

-- comparing rows vs distinct customers per campaign
select communication_id, count(*) as total_rows,
       count(distinct customer_id) as distinct_customers
from communication_log
group by communication_id;
-- noticed 9101 has 7 rows but 6 distinct customers, and it's not
-- part of any retry chain, so it shouldn't get collapsed like the others