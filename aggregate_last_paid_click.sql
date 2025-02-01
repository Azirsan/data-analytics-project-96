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
all_count AS (
    SELECT 
        COUNT(visitor_id) AS visitors_count,
        to_char(visit_date, 'DD.MM.YYYY') AS con_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign
    FROM 
        sessions
    GROUP BY 
        to_char(visit_date, 'DD.MM.YYYY'), source, medium, campaign
) -- отдельно пришлось посчитать ВСЕ клики по ютмкам
SELECT -- сводим все в финал
    to_char(lc.visit_date, 'DD.MM.YYYY') AS visit_date,
    lc.source AS utm_source,
    lc.medium AS utm_medium,
    lc.campaign AS utm_campaign,
    ac.visitors_count,
    at.total_cost,
    COUNT(lc.visitor_id) AS leads_count,
    SUM(CASE WHEN lc.closing_reason = 'Успешная продажа' THEN 1 ELSE 0 END) AS purchases_count,
    SUM(lc.amount) AS revenue
FROM 
    lst_click lc
JOIN 
    ads_total at ON at.camp_date = to_char(lc.visit_date, 'DD.MM.YYYY')
                 AND at.utm_source = lc.source
                 AND at.utm_medium = lc.medium
                 AND at.utm_campaign = lc.campaign
JOIN 
    all_count ac ON ac.con_date = to_char(lc.visit_date, 'DD.MM.YYYY')
                 AND ac.utm_source = lc.source
                 AND ac.utm_medium = lc.medium
                 AND ac.utm_campaign = lc.campaign
WHERE 
    lc.row_num = 1
GROUP BY 
    to_char(lc.visit_date, 'DD.MM.YYYY'), lc.source, lc.medium, lc.campaign, ac.visitors_count, at.total_cost
ORDER BY 
    revenue DESC NULLS LAST,
    visit_date ASC,
    ac.visitors_count DESC,
    lc.source ASC, 
    lc.medium ASC, 
    lc.campaign ASC
LIMIT 15; -- не очень ясно нужен ли лимит в коде или только при выгрузке ограничивать