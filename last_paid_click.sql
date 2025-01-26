/*visitor_id — уникальный человек на сайте
visit_date — время визита
utm_source / utm_medium / utm_campaign — метки c учетом модели атрибуции
lead_id — идентификатор лида, если пользователь сконвертился в лид после(во время) визита, NULL — если пользователь не оставил лид
created_at — время создания лида, NULL — если пользователь не оставил лид
amount — сумма лида (в деньгах), NULL — если пользователь не оставил лид
closing_reason — причина закрытия, NULL — если пользователь не оставил лид
status_id — код причины закрытия, NULL — если пользователь не оставил лид*/
select 
sessions.visitor_id
, visit_date
, source as utm_source 
, medium as utm_medium 
, campaign as utm_campaign
, lead_id
, created_at
, amount
, closing_reason
, status_id
from sessions
left join leads on sessions.visitor_id=leads.visitor_id
where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
order by amount DESC NULLS last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc
limit 10;