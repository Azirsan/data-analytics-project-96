with pain as (
    select
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
        ROW_NUMBER()
            over (
                partition by l.visitor_id
                order by l.created_at desc, s.visit_date desc
            )
        as row_num
    from
        leads as l
    inner join
        sessions as s on l.visitor_id = s.visitor_id
    where
        s.visit_date <= l.created_at
        and medium not in ('organic')
)

select
    pain.visitor_id,
    pain.visit_date,
    pain.utm_source,
    pain.utm_medium,
    pain.utm_campaign,
    pain.lead_id,
    pain.created_at,
    pain.amount,
    pain.closing_reason,
    pain.status_id
from pain
where pain.row_num = 1
order by
    pain.amount desc nulls last,
    pain.visit_date asc,
    pain.utm_source asc,
    pain.utm_medium asc,
    pain.utm_campaign asc
limit 10;
