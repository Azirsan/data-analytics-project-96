WITH pain AS (
    SELECT
        l.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id, 
        l.created_at,
        l.amount,
        l.closing_reason, 
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.visitor_id
            ORDER BY l.created_at DESC, s.visit_date DESC
        ) AS row_num
    FROM
        leads AS l
    INNER JOIN
        sessions AS s ON l.visitor_id = s.visitor_id
    WHERE
        s.visit_date <= l.created_at
        AND s.medium NOT IN ('organic')
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
