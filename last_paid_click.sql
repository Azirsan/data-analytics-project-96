with pain as (select 
 source as utm_source 
, medium as utm_medium 
, campaign as utm_campaign
, lead_id
, closing_reason
, status_id
, sessions.visitor_id
, amount
, created_at
, visit_date
, max (visit_date) over (partition by sessions.visitor_id, lead_id) as lst_visit
from sessions
left join leads on sessions.visitor_id=leads.visitor_id
where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'))
select 
visitor_id
, visit_date
, utm_source 
, utm_medium 
, utm_campaign
, lead_id
, created_at
, amount
, closing_reason
, status_id
from pain
where lst_visit=visit_date
order by amount DESC NULLS last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc
limit 10;