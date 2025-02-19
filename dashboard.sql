-- 90 % закрытия лидов
WITH pain AS (
    SELECT
        l.visitor_id,
        s.visit_date,
        l.created_at,
        AGE(l.created_at, s.visit_date) AS time_clouse,
        ROW_NUMBER() OVER (
            PARTITION BY l.visitor_id
            ORDER BY s.visit_date ASC
        ) AS row_num
    FROM
        leads AS l
    INNER JOIN
        sessions AS s
        ON
            l.visitor_id = s.visitor_id
            AND l.created_at >= s.visit_date
            AND s.medium != 'organic'
    WHERE l.status_id = 142
),

decil_pain AS (
    SELECT
        time_clouse,
        NTILE(10) OVER (
            ORDER BY time_clouse ASC
        ) AS nt
    FROM pain
    WHERE row_num = 1
)

SELECT MAX(time_clouse) AS final_day
FROM decil_pain
WHERE nt <= 9;

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

final AS (
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
)

SELECT
    -- visit_date,
    utm_source,
    -- utm_medium,
    -- utm_campaign,
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    ROUND(SUM(total_cost) / SUM(leads_count), 2) AS cpl,
    ROUND(SUM(total_cost) / SUM(purchases_count), 2) AS cppu,
    ROUND(100 * (SUM(revenue) - SUM(total_cost)) / SUM(total_cost), 2) AS roi,
    ROUND(100 * SUM(leads_count) / SUM(visitors_count), 2) AS lcr,
    ROUND(100 * SUM(purchases_count) / SUM(leads_count), 2) AS lscr
FROM final
GROUP BY utm_source
HAVING ROUND(SUM(total_cost) / SUM(visitors_count), 2) IS NOT NULL
ORDER BY utm_source DESC;

-- анализ посещаемости по неделям
SELECT
    medium AS utm_medium,
    campaign AS utm_campaign,
    CASE
        WHEN
            LOWER(source) LIKE '%telegram%'
            OR LOWER(source) = 'tg' THEN 'telegram'
        WHEN LOWER(source) LIKE '%vk%' THEN 'vk'
        WHEN LOWER(source) LIKE '%yandex%' THEN 'yandex'
        ELSE source
    END AS utm_source,
    EXTRACT(WEEK FROM visit_date)
    - EXTRACT(WEEK FROM date_trunc('month', visit_date))
    + 1 AS week_number,
    COUNT(*) AS visits
FROM sessions
GROUP BY
    utm_source,
    medium,
    campaign,
    EXTRACT(WEEK FROM visit_date)
    - EXTRACT(WEEK FROM DATE_TRUNC('month', visit_date))
    + 1;
