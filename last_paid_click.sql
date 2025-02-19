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
)

SELECT
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
FROM
    pain
WHERE
    pain.row_num = 1
ORDER BY
    pain.amount DESC NULLS LAST,
    pain.visit_date ASC,
    pain.utm_source ASC,
    pain.utm_medium ASC,
    pain.utm_campaign ASC
LIMIT 10;
