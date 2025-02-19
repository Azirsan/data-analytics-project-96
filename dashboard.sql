-- 90 % закрытия лидов
with pain as (
    select
        l.visitor_id,
        s.visit_date,
        l.created_at,
        AGE(l.created_at, s.visit_date) as time_clouse,
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

select MAX(time_clouse) as final_day
from decil_pain
where nt <= 9;

-- МЕТРИКИ
with pain as (
    select
        l.visitor_id,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        date(s.visit_date) as visit_date,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as row_num
    from
        sessions as s
    left join
        leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

ads_total as (
    select
        date(campaign_date) as camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(
            coalesce(daily_spent, 0)
        ) as total_cost
    from
        ya_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    union all
    select
        date(campaign_date) as camp_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(
            coalesce(daily_spent, 0)
        ) as total_cost
    from
        vk_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
),

final as (
    select
        pain.visit_date,
        pain.utm_source,
        pain.utm_medium,
        pain.utm_campaign,
        adt.total_cost,
        count(*) as visitors_count,
        count(pain.lead_id) as leads_count,
        sum(case
            when pain.status_id = 142 then 1
            else 0
        end) as purchases_count,
        sum(case
            when pain.status_id = 142 then pain.amount
            else 0
        end) as revenue
    from
        pain
    left join ads_total as adt
        on
            pain.visit_date = adt.camp_date
            and pain.utm_source = adt.utm_source
            and pain.utm_medium = adt.utm_medium
            and pain.utm_campaign = adt.utm_campaign
    where
        pain.row_num = 1
    group by
        pain.utm_source,
        pain.utm_medium,
        pain.utm_campaign,
        date(pain.visit_date),
        adt.total_cost
) -- можно расчет тут сделать, но код становится нечитаемым

select
    -- visit_date,
    utm_source,
    -- utm_medium,
    -- utm_campaign,
    round(sum(total_cost) / sum(visitors_count), 2) as cpu,
    round(sum(total_cost) / sum(leads_count), 2) as cpl,
    round(sum(total_cost) / sum(purchases_count), 2) as cppu,
    round(100 * (sum(revenue) - sum(total_cost)) / sum(total_cost), 2) as roi,
    round(100 * sum(leads_count) / sum(visitors_count), 2) as lcr,
    round(100 * sum(purchases_count) / sum(leads_count), 2) as lscr
from final
group by utm_source
having round(sum(total_cost) / sum(visitors_count), 2) is not null
order by utm_source desc;

-- анализ посещаемости по неделям
select
    medium as utm_medium,
    campaign as utm_campaign,
    case
        when
            lower(source) like '%telegram%'
            or lower(source) = 'tg'
            then 'telegram'
        when lower(source) like '%vk%'
            then 'vk'
        when
            lower(source) like '%yandex%'
            then 'yandex'
        else source
    end as utm_source,
    extract(week from visit_date)
    - extract(week from date_trunc('month', visit_date))
    + 1 as week_number,
    count(*) as visits
from
    sessions
group by
    utm_source,
    medium,
    campaign,
    extract(week from visit_date)
    - extract(week from date_trunc('month', visit_date))
    + 1
