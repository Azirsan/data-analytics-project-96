with pain as (SELECT 
        l.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        lead_id, 
       l.created_at,        
        l.amount,
        closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (PARTITION BY l.visitor_id ORDER BY l.created_at DESC, s.visit_date DESC) AS row_num
    FROM 
        leads l
  JOIN 
        sessions s ON l.visitor_id = s.visitor_id
    WHERE 
        s.visit_date <= l.created_at
      and medium not in ('organic'))
select 
visitor_id,
visit_date,
utm_source,
utm_medium, 
utm_campaign,
lead_id,
created_at,
amount,
closing_reason,
status_id
from pain
where pain.row_num=1
ORDER BY
    amount DESC NULLS LAST,
    visit_date ASC, 
    utm_source ASC, 
    utm_medium ASC, 
    utm_campaign asc
limit 10;
