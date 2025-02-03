WITH ads AS (
    SELECT 
        to_char(campaign_date, 'DD.MM.YYYY') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COALESCE(daily_spent, 0) AS daily_spent
    FROM ya_ads 
    UNION ALL
    SELECT 
        to_char(campaign_date, 'DD.MM.YYYY') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COALESCE(daily_spent, 0) AS daily_spent
    FROM vk_ads
), -- объединили две рекламные кампании
ads_total AS (
    SELECT 
        camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost 
    FROM ads
    GROUP BY 
        camp_date, utm_source, utm_medium, utm_campaign
), -- расчитали общие затраты по дням, чтобы потом приджойнить в финале
lst_click AS (
    SELECT 
        l.visitor_id,
        l.created_at AS lead_created_at,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.amount,
        l.closing_reason,
        ROW_NUMBER() OVER (PARTITION BY l.visitor_id ORDER BY l.created_at DESC, s.visit_date DESC) AS row_num
    FROM 
        leads l
  JOIN 
        sessions s ON l.visitor_id = s.visitor_id
    WHERE 
        s.visit_date <= l.created_at
        AND s.source IN (SELECT utm_source FROM ads)
        AND s.medium IN (SELECT utm_medium FROM ads)
        AND s.campaign IN (SELECT utm_campaign FROM ads)
), -- нашли ютмки по модели последний клик у последней конверсии
total_amount as (select
to_char(visit_date, 'DD.MM.YYYY') as visit_date
, source
, medium
, campaign
, COUNT (closing_reason) as leads_count
,  SUM(CASE WHEN closing_reason = 'Успешная продажа' THEN 1 ELSE 0 END) AS purchases_count
, sum (amount) as revenue
from lst_click 
where row_num=1
group by to_char(visit_date, 'DD.MM.YYYY')
, source
, medium
, campaign)
 SELECT 
        to_char(s.visit_date, 'DD.MM.YYYY') AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(s.visitor_id) AS visitors_count,
        total_cost,
        leads_count,
        purchases_count,
        revenue
    FROM 
        sessions s
    join ads_total at on at.camp_date=to_char(s.visit_date, 'DD.MM.YYYY') 
and at.utm_source=s.source
 and s.medium=at.utm_medium
 and s.campaign=at.utm_campaign
 left join total_amount lc
        on lc.visit_date=to_char(s.visit_date, 'DD.MM.YYYY')
and lc.source=s.source
 and s.medium=lc.medium
 and s.campaign=lc.campaign
 GROUP BY 
        to_char(s.visit_date, 'DD.MM.YYYY'), s.source, s.medium, s.campaign, total_cost,  leads_count,
        purchases_count,  revenue
        ORDER BY 
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    s.source ASC, 
    s.medium ASC, 
    s.campaign ASC