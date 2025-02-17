-- 90 % закрытия лидов
with pain as (
    select
        l.visitor_id,
        s.visit_date,
        l.created_at,
        EXTRACT(
            epoch from (l.created_at - s.visit_date) / 86400.0
        ) as time_clouse,
        ROW_NUMBER() over (
            partition by l.visitor_id
            order by s.visit_date asc
        ) as row_num
    from
        leads as l
    inner join
        sessions as s
        on
            l.visitor_id = s.visitor_id
            and l.created_at >= s.visit_date
            and s.medium != 'organic'
    where l.status_id = 142
),

decil_pain as (
    select
        time_clouse,
        NTILE(10) over (
            order by time_clouse asc
        ) as nt
    from pain
    where row_num = 1
)

select ROUND(MAX(time_clouse)::numeric, 0) as fianl_day
from decil_pain
where nt <= 9;
-- МЕТРИКИ
WITH pain AS (
    SELECT
        l.visitor_id,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        DATE(s.visit_date) AS visit_date,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS row_num
    FROM
        sessions AS s
    LEFT JOIN
        leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
),

ads_total AS (
    SELECT
        DATE(campaign_date) AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(
            COALESCE(daily_spent, 0)
        ) AS total_cost
    FROM
        ya_ads
    GROUP BY
        DATE(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        DATE(campaign_date) AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(
            COALESCE(daily_spent, 0)
        ) AS total_cost
    FROM
        vk_ads
    GROUP BY
        DATE(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
),

fianl AS (
    SELECT
        pain.visit_date,
        pain.utm_source,
        pain.utm_medium,
        pain.utm_campaign,
        adt.total_cost,
        COUNT(*) AS visitors_count,
        COUNT(pain.lead_id) AS leads_count,
        SUM(CASE
            WHEN pain.status_id = 142 THEN 1
            ELSE 0
        END) AS purchases_count,
        SUM(CASE
            WHEN pain.status_id = 142 THEN pain.amount
            ELSE 0
        END) AS revenue
    FROM
        pain
    LEFT JOIN ads_total AS adt
        ON
            pain.visit_date = adt.camp_date
            AND pain.utm_source = adt.utm_source
            AND pain.utm_medium = adt.utm_medium
            AND pain.utm_campaign = adt.utm_campaign
    WHERE
        pain.row_num = 1
    GROUP BY
        pain.utm_source,
        pain.utm_medium,
        pain.utm_campaign,
        DATE(pain.visit_date),
        adt.total_cost
) -- можно расчет тут сделать, но код становится нечитаемым

SELECT
    /*  visit_date,*/
    utm_source,
    /*utm_medium,
    utm_campaign,*/
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    ROUND(SUM(total_cost) / SUM(leads_count), 2) AS cpl,
    ROUND(SUM(total_cost) / SUM(purchases_count), 2) AS cppu,
    ROUND(100 * (SUM(revenue) - SUM(total_cost)) / SUM(total_cost), 2) AS roi,
    ROUND(100 * SUM(leads_count) / SUM(visitors_count), 2) AS lcr,
    ROUND(100 * SUM(purchases_count) / SUM(leads_count), 2) AS lscr
FROM fianl
GROUP BY utm_source
HAVING ROUND(SUM(total_cost) / SUM(visitors_count), 2) IS NOT null
ORDER BY utm_source DESC;
-- анализ посещаемости по неделям
SELECT
    medium AS utm_medium,
    campaign AS utm_campaign,
    CASE
        WHEN LOWER(source) LIKE '%admitad%' THEN 'admitad'
        WHEN LOWER(source) LIKE '%baidu%' THEN 'baidu.com'
        WHEN LOWER(source) LIKE '%bing%' THEN 'bing.com'
        WHEN LOWER(source) LIKE '%botmother%' THEN 'botmother'
        WHEN LOWER(source) LIKE '%dzen%' THEN 'dzen'
        WHEN LOWER(source) LIKE '%facebook%' THEN 'facebook.com'
        WHEN LOWER(source) LIKE '%go.mail.ru%' THEN 'go.mail.ru'
        WHEN LOWER(source) LIKE '%google%' THEN 'google'
        WHEN LOWER(source) LIKE '%instagram%' THEN 'instagram'
        WHEN LOWER(source) LIKE '%mytarget%' THEN 'mytarget'
        WHEN LOWER(source) LIKE '%organic%' THEN 'organic'
        WHEN LOWER(source) LIKE '%partners%' THEN 'partners'
        WHEN LOWER(source) LIKE '%podcast%' THEN 'podcast'
        WHEN LOWER(source) LIKE '%public%' THEN 'public'
        WHEN LOWER(source) LIKE '%rutube%' THEN 'rutube'
        WHEN LOWER(source) LIKE '%search.ukr.net%' THEN 'search.ukr.net'
        WHEN LOWER(source) LIKE '%slack%' THEN 'slack'
        WHEN LOWER(source) LIKE '%social%' THEN 'social'
        WHEN
            LOWER(source) LIKE '%telegram%'
            OR LOWER(source) = 'telegram.me'
            OR LOWER(source) = 'tg'
            THEN 'telegram'
        WHEN LOWER(source) LIKE '%timepad%' THEN 'timepad'
        WHEN LOWER(source) LIKE '%tproger%' THEN 'tproger'
        WHEN LOWER(source) LIKE '%twitter%' THEN 'twitter.com'
        WHEN LOWER(source) LIKE '%vc%' THEN 'vc'
        WHEN
            LOWER(source) LIKE '%vk%'
            OR LOWER(source) IN ('vk.com', 'vk-group', 'vkontakte', 'vk-senler')
            THEN 'vk'
        WHEN
            LOWER(source) LIKE '%yandex%'
            OR LOWER(source) IN ('yandex.com', 'yandex-direct')
            THEN 'yandex'
        WHEN
            LOWER(source) LIKE '%zen%' OR LOWER(source) IN ('zen_from_telegram')
            THEN 'dzen'
        ELSE source
    END AS utm_source,
    EXTRACT(WEEK FROM visit_date) - 21 AS week_number,
    COUNT(*) AS visits
FROM
    sessions
GROUP BY utm_source, medium, campaign, EXTRACT(WEEK FROM visit_date) - 21;
