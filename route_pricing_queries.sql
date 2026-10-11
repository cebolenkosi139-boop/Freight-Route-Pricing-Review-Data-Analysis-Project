use logistics_db;

-- Data checks on the two tables used: loads and routes_
-- Every column named "..._missing", "duplicate_...", "unknown_...", or "invalid_..." should be 0

select
    (select count(*) from loads)   as total_loads,
    (select count(*) from routes_) as total_routes,
    (select count(*) from loads
        where load_id is null or route_id is null or revenue is null or load_status is null) as loads_with_missing_values,
    (select count(*) from routes_
        where route_id is null or typical_distance_miles is null or base_rate_per_mile is null) as routes_with_missing_values,
    (select count(*) - count(distinct load_id) from loads)    as duplicate_load_ids,
    (select count(*) - count(distinct route_id) from routes_) as duplicate_route_ids,
    (select count(*) from loads l
        left join routes_ r on l.route_id = r.route_id
        where r.route_id is null) as loads_with_unknown_route,
    (select count(*) from loads where revenue <= 0) as loads_with_invalid_revenue,
    (select count(*) from routes_
        where typical_distance_miles <= 0 or base_rate_per_mile <= 0) as routes_with_invalid_distance_or_rate;

-- Which load statuses exist (only 'Completed' is used in the analysis)
select load_status, count(*) as num_loads
from loads
group by load_status
order by num_loads desc;

-- Route pricing: what each route is actually billed per mile
-- Source tables: loads (one row per shipment) and routes_ (one row per route)
-- Only completed loads are counted, and only the base 'revenue' column is used
-- Route pricing: what each route is actually billed per mile
-- Source tables: loads (one row per shipment) and routes_ (one row per route)
-- Only completed loads are counted, and only the base 'revenue' column is used
-- (fuel surcharge and accessorial charges are left out so the price of the driving is not mixed with extras)

select
    l.route_id,
    r.origin_city,
    r.destination_city,
    r.typical_distance_miles,
    r.base_rate_per_mile,                                  -- the list price set for the route
    count(*)                                               as num_loads,       -- shipments on the route
    sum(l.revenue)                                         as total_revenue,   -- total billed for driving
    -- billed price per mile = revenue / (loads x route distance)
    sum(l.revenue) / (count(*) * r.typical_distance_miles) as billed_per_mile
from loads l
join routes_ r on l.route_id = r.route_id                  -- attach each route's distance to its loads
where l.load_status = 'Completed'                          -- ignore cancelled or unfinished loads
group by l.route_id, r.origin_city, r.destination_city,
         r.typical_distance_miles, r.base_rate_per_mile
order by billed_per_mile;                                  -- cheapest routes first