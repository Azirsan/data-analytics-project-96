WITH lst_click AS (
    SELECT
        visitor_id,
        MAX(visit_date) AS lst_visit -- психанул переписал через max, потому что через row_number итоги отличались от верного результата на единицу, Карл (!)
    FROM 
        sessions
    WHERE 
        medium != 'organic'
    GROUP BY 
        visitor_id
),
ads_total AS (
    SELECT 
        to_char(campaign_date, 'YYYY-MM-DD') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(COALESCE(daily_spent, 0)) AS total_cost
    FROM 
        ya_ads 
    GROUP BY 
        to_char(campaign_date, 'YYYY-MM-DD'), 
        utm_source, 
        utm_medium, 
        utm_campaign
    UNION ALL
    SELECT 
        to_char(campaign_date, 'YYYY-MM-DD') AS camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(COALESCE(daily_spent, 0)) AS total_cost
    FROM 
        vk_ads
    GROUP BY 
        to_char(campaign_date, 'YYYY-MM-DD'), 
        utm_source, 
        utm_medium, 
        utm_campaign
),
leads AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        date(lc.lst_visit) AS visit_date,
        COUNT(DISTINCT lc.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(DISTINCT CASE WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142 THEN l.lead_id END) AS purchases_count,
        SUM(l.amount) AS revenue
    FROM 
        lst_click lc
    JOIN 
        sessions s ON lc.visitor_id = s.visitor_id AND lc.lst_visit = s.visit_date
    LEFT JOIN 
        leads l ON s.visitor_id = l.visitor_id AND l.created_at >= s.visit_date
    GROUP BY 
        s.source, s.medium, s.campaign, date(lc.lst_visit)
)
SELECT 
    to_char(l.visit_date, 'YYYY-MM-DD') as visit_date,
    l.visitors_count,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    COALESCE(at.total_cost, 0) AS total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM 
    leads l
LEFT JOIN 
    ads_total at ON to_char(l.visit_date, 'YYYY-MM-DD') = at.camp_date
        AND l.utm_source = at.utm_source 
        AND l.utm_medium = at.utm_medium 
        AND l.utm_campaign = at.utm_campaign
ORDER BY 
    l.revenue DESC NULLS LAST, 
    l.visit_date ASC, 
    l.visitors_count DESC, 
    l.utm_source, 
    l.utm_medium, 
    l.utm_campaign
limit 15;
