-- ================================================================
--  MERIDIAN VOYAGES EDA
-- ================================================================

-------------------------------------------------------------------
--  Part 1: EDA
-------------------------------------------------------------------

-------------------------------------------------------------------
--  Enterprise summary
-------------------------------------------------------------------
select
    count(distinct v.voyage_id) as total_voyages,
    sum(v.passengers) as total_passengers,
    sum(b.cabin_revenue) as total_cabin_revenue,
    sum(o.total_onboard_revenue) as total_onboard_revenue,
    sum(b.cabin_revenue) + sum(o.total_onboard_revenue) as total_revenue,
    round(avg(v.load_factor) * 100, 1)   as avg_load_factor_pct,
    round((sum(b.cabin_revenue) + sum(o.total_onboard_revenue)) / sum(v.passengers), 2)    as revenue_per_passenger
from
    fact_voyages v
left join
    fact_bookings b on b.voyage_id = v.voyage_id
left join 
    fact_onboard_spend o on o.voyage_id = v.voyage_id;


-------------------------------------------------------------------
--  Revenue and load factor by ship, determine which ships are carrying the business
-------------------------------------------------------------------
select
    s.ship_name,
    s.ship_class,
    s.home_port,
    count(distinct v.voyage_id) as voyages,
    sum(v.passengers) as total_passengers,
    round(avg(v.load_factor) * 100, 1) as avg_load_factor_pct,
    sum(b.cabin_revenue) as cabin_revenue,
    sum(o.total_onboard_revenue) as onboard_revenue,
    sum(b.cabin_revenue) + sum(o.total_onboard_revenue) as total_revenue,
    round((sum(b.cabin_revenue) + sum(o.total_onboard_revenue)) / sum(v.passengers), 2) as revenue_per_passenger
from 
    fact_voyages v
left join  
    dim_ships s on s.ship_id = v.ship_id
left join  
    fact_bookings b on b.voyage_id = v.voyage_id
left join 
    fact_onboard_spend o on o.voyage_id = v.voyage_id
group by 
    s.ship_name, 
    s.ship_class, 
    s.home_port
order by   
    total_revenue desc;


-------------------------------------------------------------------
--  Revenue and load factor by route, determine which ships are carrying the business
-------------------------------------------------------------------
select
    r.route_name,
    r.route_type,
    r.departure_port,
    r.duration_days,
    count(distinct v.voyage_id) as voyages,
    sum(v.passengers) as total_passengers,
    round(avg(v.load_factor) * 100, 1) as avg_load_factor_pct,
    sum(b.cabin_revenue) as cabin_revenue,
    sum(o.total_onboard_revenue) as onboard_revenue,
    sum(b.cabin_revenue) + sum(o.total_onboard_revenue) as total_revenue,
    round((sum(b.cabin_revenue) + sum(o.total_onboard_revenue)) / sum(v.passengers), 2) as revenue_per_passenger
from 
    fact_voyages v
left join 
    dim_routes r on r.route_id = v.route_id
left join
    fact_bookings b on b.voyage_id = v.voyage_id
left join  
    fact_onboard_spend o on o.voyage_id = v.voyage_id
group by 
    r.route_name, 
    r.route_type, 
    r.departure_port, 
    r.duration_days
order by   
    total_revenue desc;


-------------------------------------------------------------------
--  MoM revenue with a running total
--  Shows which ships are ganing momentum over time
-------------------------------------------------------------------
with monthly_revenue as (
    select
        v.month,
        v.month_name,
        s.ship_name,
        sum(b.cabin_revenue) + sum(o.total_onboard_revenue) as monthly_revenue,
        round(avg(v.load_factor) * 100, 1) as avg_load_factor_pct
    from 
        fact_voyages v
    left join 
        dim_ships s on s.ship_id = v.ship_id
    left join  
        fact_bookings b on b.voyage_id = v.voyage_id
    left join  
        fact_onboard_spend o on o.voyage_id = v.voyage_id
    group by   
        v.month, 
        v.month_name, 
        s.ship_name
)
select
    month,
    month_name,
    ship_name,
    monthly_revenue,
    avg_load_factor_pct,
    sum(monthly_revenue) over (
        partition by ship_name
        order by     month
        rows between unbounded preceding and current row
    )  as cumulative_revenue
from  
    monthly_revenue
order by 
    ship_name, 
    month;

-------------------------------------------------------------------
--  Onboard spenging benchmark vs fleet average
--  Flagging routes running 15%+ below benchmark
-------------------------------------------------------------------
select
    r.route_name,
    r.route_type,
    round(avg(o.onboard_per_passenger), 2) as avg_onboard_per_pax,
    round(
        (select avg(onboard_per_passenger) from fact_onboard_spend), 2
    ) as fleet_avg_onboard_per_pax,
    round(
        avg(o.onboard_per_passenger)
        - (select avg(onboard_per_passenger) from fact_onboard_spend), 2
    )  as delta_vs_fleet_avg,
    case
        when avg(o.onboard_per_passenger) <
             (select avg(onboard_per_passenger) from fact_onboard_spend) * 0.85
        then 'Below Threshold'
        else 'On Track'
    end as spend_flag
from       
    fact_onboard_spend o
left join  
    dim_routes r on r.route_id = o.route_id
group by   
    r.route_name, 
    r.route_type
order by   
    avg_onboard_per_pax desc;


-------------------------------------------------------------------
--  Categorizing bookings into Early, Standard, Late
--  Filtering out booking < 5
-------------------------------------------------------------------
select
    v.voyage_id,
    s.ship_name,
    r.route_name,
    r.route_type,
    v.month_name,
    case
        when b.days_before_sail >= 90 then 'Early (90+ days)'
        when b.days_before_sail >= 30 then 'Standard (30-89 days)'
        else                               'Late (under 30 days)'
    end as booking_window,
    count(*) as bookings,
    round(avg(b.cabin_revenue), 2) as avg_cabin_revenue,
    sum(b.cabin_revenue) as total_cabin_revenue
from       fact_bookings      b
left join  fact_voyages 
    v on v.voyage_id = b.voyage_id
left join  
    dim_ships s on s.ship_id = v.ship_id
left join  
    dim_routes r on r.route_id  = v.route_id
group by
    v.voyage_id,
    s.ship_name,
    r.route_name,
    r.route_type,
    v.month_name,
    case
        when b.days_before_sail >= 90 then 'Early (90+ days)'
        when b.days_before_sail >= 30 then 'Standard (30-89 days)'
        else                               'Late (under 30 days)'
    end
having 
    count(*) > 5
order by 
    v.voyage_id, 
    booking_window;


-------------------------------------------------------------------
--  Lets create the final table to bring into Tableau for visualization
-------------------------------------------------------------------
create table mv_tableau_final as

with

-- step 1: aggregate cabin revenue per voyage
cabin_agg as (
    select
        voyage_id,
        sum(cabin_revenue) as total_cabin_revenue,
        count(*) as total_bookings
    from  
        fact_bookings
    group by 
        voyage_id
),

-- step 2: booking window breakdown per voyage
booking_windows as (
    select
        voyage_id,
        count(case when days_before_sail >= 90             then 1 end) as early_bookings,
        count(case when days_before_sail between 30 and 89 then 1 end) as standard_bookings,
        count(case when days_before_sail < 30              then 1 end) as late_bookings,
        sum(case when days_before_sail >= 90
                 then cabin_revenue else 0 end)                        as early_cabin_revenue,
        sum(case when days_before_sail between 30 and 89
                 then cabin_revenue else 0 end)                        as standard_cabin_revenue,
        sum(case when days_before_sail < 30
                 then cabin_revenue else 0 end)                        as late_cabin_revenue,
        round(avg(case when days_before_sail >= 90
                       then cabin_revenue end), 2)                     as avg_revenue_early,
        round(avg(case when days_before_sail between 30 and 89
                       then cabin_revenue end), 2)                     as avg_revenue_standard,
        round(avg(case when days_before_sail < 30
                       then cabin_revenue end), 2)                     as avg_revenue_late
    from  fact_bookings
    group by voyage_id
),

-- step 3: fleet average onboard spend per passenger (scalar benchmark)
fleet_avg as (
    select round(avg(onboard_per_passenger), 2)                        as fleet_avg_onboard_per_pax
    from   fact_onboard_spend
)

-- final select — one row per voyage
select
    -- identifiers
    v.voyage_id,
    v.sail_date,
    v.return_date,
    v.month,
    v.month_name,
    v.duration_days,

    -- ship
    s.ship_id,
    s.ship_name,
    s.ship_class,
    s.home_port,
    s.passenger_capacity,

    -- route
    r.route_id,
    r.route_name,
    r.route_type,
    r.departure_port,
    r.destination_region,

    -- capacity and occupancy
    v.total_cabins,
    v.cabins_sold,
    v.passengers,
    round(v.load_factor * 100, 1) as load_factor_pct,

    -- cabin revenue
    ca.total_cabin_revenue,
    ca.total_bookings,

    -- onboard revenue streams
    o.dining_revenue,
    o.excursion_revenue,
    o.retail_spa_revenue,
    o.total_onboard_revenue,
    o.onboard_per_passenger,

    -- total revenue and per-passenger metrics
    ca.total_cabin_revenue + o.total_onboard_revenue  as total_revenue,
    round(
        (ca.total_cabin_revenue + o.total_onboard_revenue)
        / nullif(v.passengers, 0), 2
    ) as revenue_per_passenger,
    round(
        ca.total_cabin_revenue / nullif(v.passengers, 0), 2
    ) as cabin_revenue_per_passenger,

    -- onboard spend benchmark
    fa.fleet_avg_onboard_per_pax,
    round(o.onboard_per_passenger - fa.fleet_avg_onboard_per_pax, 2) as onboard_delta_vs_fleet,
    case
        when o.onboard_per_passenger < fa.fleet_avg_onboard_per_pax * 0.85
        then 'Below Threshold'
        else 'On Track'
    end as onboard_spend_flag,

    -- booking window counts
    bw.early_bookings,
    bw.standard_bookings,
    bw.late_bookings,

    -- booking window revenue totals
    bw.early_cabin_revenue,
    bw.standard_cabin_revenue,
    bw.late_cabin_revenue,

    -- average cabin revenue per booking window
    bw.avg_revenue_early,
    bw.avg_revenue_standard,
    bw.avg_revenue_late

from       
    fact_voyages v
left join  
    dim_ships s on s.ship_id = v.ship_id
left join  
    dim_routes r on r.route_id = v.route_id
left join  
    cabin_agg ca on ca.voyage_id = v.voyage_id
left join  
    fact_onboard_spend o on o.voyage_id  = v.voyage_id
left join  
    booking_windows bw on bw.voyage_id = v.voyage_id
cross join 
    fleet_avg fa
order by   
    v.sail_date,
     v.voyage_id;