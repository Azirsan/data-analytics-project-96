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
)

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
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    pain.utm_source ASC,
    pain.utm_medium ASC,
    pain.utm_campaign ASC;
