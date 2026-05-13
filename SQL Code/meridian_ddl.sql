------------------------------------------------------------------
--  MERIDIAN VOYAGES DDL SCRIPT (Oracle Apex)
------------------------------------------------------------------

-- drop tables
drop table fact_bookings      cascade constraints purge;
drop table fact_onboard_spend cascade constraints purge;
drop table fact_voyages       cascade constraints purge;
drop table dim_routes         cascade constraints purge;
drop table dim_ships          cascade constraints purge;


------------------------------------------------------------------
create table dim_ships (
    ship_id              varchar2(10)   not null,
    ship_name            varchar2(50)   not null,
    ship_class           varchar2(20)   not null,
    passenger_capacity   number(5)      not null,
    cabin_count          number(5)      not null,
    crew_count           number(5),
    year_built           number(4),
    home_port            varchar2(30),
    constraint pk_ships primary key (ship_id)
);


------------------------------------------------------------------
create table dim_routes (
    route_id             varchar2(10)   not null,
    route_name           varchar2(60)   not null,
    route_type           varchar2(20)   not null,
    departure_port       varchar2(30)   not null,
    destination_region   varchar2(30),
    duration_days        number(3)      not null,
    ports_of_call        varchar2(200),
    constraint pk_routes primary key (route_id)
);


------------------------------------------------------------------
create table fact_voyages (
    voyage_id            varchar2(12)   not null,
    ship_id              varchar2(10)   not null,
    route_id             varchar2(10)   not null,
    sail_date            date           not null,
    return_date          date,
    month                number(2)      not null,
    month_name           varchar2(12),
    duration_days        number(3)      not null,
    total_cabins         number(5)      not null,
    cabins_sold          number(5)      not null,
    passengers           number(6)      not null,
    load_factor          number(6,4)    not null,
    constraint pk_voyages  primary key (voyage_id),
    constraint fk_voy_ship foreign key (ship_id)  references dim_ships  (ship_id),
    constraint fk_voy_rte  foreign key (route_id) references dim_routes (route_id)
);


------------------------------------------------------------------
create table fact_bookings (
    booking_id           varchar2(14)   not null,
    voyage_id            varchar2(12)   not null,
    ship_id              varchar2(10)   not null,
    route_id             varchar2(10)   not null,
    booking_date         date           not null,
    sail_date            date           not null,
    days_before_sail     number(4)      not null,
    cabin_type           varchar2(20)   not null,
    passengers           number(2)      not null,
    cabin_revenue        number(10)     not null,
    constraint pk_bookings  primary key (booking_id),
    constraint fk_bkg_voy   foreign key (voyage_id) references fact_voyages (voyage_id),
    constraint fk_bkg_ship  foreign key (ship_id)   references dim_ships    (ship_id),
    constraint fk_bkg_route foreign key (route_id)  references dim_routes   (route_id)
);


------------------------------------------------------------------
create table fact_onboard_spend (
    voyage_id              varchar2(12)  not null,
    ship_id                varchar2(10)  not null,
    route_id               varchar2(10)  not null,
    sail_date              date          not null,
    month                  number(2)     not null,
    month_name             varchar2(12),
    passengers             number(6)     not null,
    dining_revenue         number(12)    not null,
    excursion_revenue      number(12)    not null,
    retail_spa_revenue     number(12)    not null,
    total_onboard_revenue  number(12)    not null,
    onboard_per_passenger  number(10,2)  not null,
    constraint pk_onboard   primary key (voyage_id),
    constraint fk_ob_voyage foreign key (voyage_id) references fact_voyages (voyage_id),
    constraint fk_ob_ship   foreign key (ship_id)   references dim_ships    (ship_id),
    constraint fk_ob_route  foreign key (route_id)  references dim_routes   (route_id)
);


------------------------------------------------------------------
-- Create indexes for query performance
create index idx_voyages_ship    on fact_voyages      (ship_id);
create index idx_voyages_route   on fact_voyages      (route_id);
create index idx_voyages_month   on fact_voyages      (month);
create index idx_bookings_voyage on fact_bookings     (voyage_id);
create index idx_bookings_cabin  on fact_bookings     (cabin_type);
create index idx_bookings_days   on fact_bookings     (days_before_sail);
create index idx_onboard_ship    on fact_onboard_spend(ship_id);
create index idx_onboard_route   on fact_onboard_spend(route_id);

commit;
