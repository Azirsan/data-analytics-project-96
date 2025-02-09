WITH lst_click AS (
    SELECT
        visitor_id,
        MAX(sessions.visit_date) AS lst_visit
    FROM
        sessions
    WHERE
        medium != 'organic'
    GROUP BY
        visitor_id
),
ads_total AS (
    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(
            COALESCE(daily_spent, 0)
        ) AS total_cost
    FROM
        ya_ads
    GROUP BY
        TO_CHAR(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(
            COALESCE(daily_spent, 0)
        ) AS total_cost
    FROM
        vk_ads
    GROUP BY
        TO_CHAR(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
),
leads AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        DATE(lc.lst_visit) AS visit_date,
        COUNT(DISTINCT lc.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(
            DISTINCT CASE
                WHEN
                    l.closing_reason = 'Успешно реализовано'
                    OR l.status_id = 142 THEN l.lead_id
            END
        ) AS purchases_count,
        SUM(l.amount) AS revenue
    FROM
        lst_click AS lc
    INNER JOIN sessions AS s
        ON
            lc.visitor_id = s.visitor_id
            AND lc.lst_visit = s.visit_date
    LEFT JOIN leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    GROUP BY
        s.source,
        s.medium,
        s.campaign,
        DATE(lc.lst_visit)
)
SELECT
    visit_date,
    l.visitors_count,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    atot.total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM
    leads AS l
LEFT JOIN ads_total as atot
    ON
        TO_CHAR(l.visit_date, 'YYYY-MM-DD') = atot.camp_date
        AND l.utm_source = atot.utm_source
        AND l.utm_medium = atot.utm_medium
        AND l.utm_campaign = atot.utm_campaign
ORDER BY
    l.revenue DESC NULLS LAST,
    l.visit_date ASC,
    l.visitors_count DESC,
    l.utm_source ASC,
    l.utm_medium ASC,
    l.utm_campaign ASC
