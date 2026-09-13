-- final query for target_base

with recursive eligible as (
    select id, parent_id
    from campaign
    where creation_status in ('approved','aborted','resumed','stopped')
      and processing_status = 'processed'
),
chain_root(id, root_id) as (
    select id, id from eligible where parent_id is null
    union all
    select e.id, cr.root_id
    from eligible e
    join chain_root cr on e.parent_id = cr.id
),
campaign_family as (
    select c.id as campaign_id, cr.root_id,
        case when c.parent_id is null
              and not exists (select 1 from campaign child where child.parent_id = c.id)
             then 'standalone' else 'chain'
        end as family_type
    from campaign c
    join chain_root cr on cr.id = c.id
),
qualifying as (
    select cl.customer_id, cf.root_id, cf.family_type
    from communication_log cl
    join campaign_family cf on cf.campaign_id = cl.communication_id
    where cl.merchant_id = 501
      and cl.communication_type = '2'
)
select
    (select count(distinct root_id || '|' || customer_id) from qualifying where family_type = 'chain')
  + (select count(*) from qualifying where family_type = 'standalone')
  as target_base;

-- returns 22