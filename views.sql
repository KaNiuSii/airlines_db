select username,
       osuser,
       machine,
       schemaname
  from gv$session
 where sid = (
   select sys_context(
      'userenv',
      'sid'
   )
     from dual
);
  
  --GRANT CREATE VIEW TO SCOOT;
-------------------------------------------------------------------------------
-- 1) Tworzenie widok�w
-------------------------------------------------------------------------------
create or replace view v_travelclass_stats as
   select t.class_name as class_name,
          count(*) as seat_count,
          min(ps.price) as min_price,
          max(ps.price) as max_price,
          round(
             avg(ps.price),
             2
          ) as avg_price
     from planeseat_table ps
     join travelclass_table t
   on ps.travelclassref = ref(t)
    group by t.class_name;

create or replace view v_plane_seatcount as
   select p.id as plane_id,
          (
             select count(*)
               from table ( p.seat_list )
          ) as seat_count
     from plane_table p;

create or replace view v_plane_requiredroles as
   select p.id as plane_id,
          (
             select count(*)
               from table ( p.required_role_list )
          ) as required_roles_count
     from plane_table p;

create or replace view v_crewmember_rolecount as
   select c.id as crew_member_id,
          c.first_name
          || ' '
          || c.last_name as full_name,
          (
             select count(*)
               from table ( c.roles_list )
          ) as role_count
     from crewmember_table c;

create or replace view v_airport_techsupport as
   select a.iata as airport_iata,
          a.name as airport_name,
          (
             select count(*)
               from table ( a.technical_support_list )
          ) as tech_support_count
     from airport_table a;

create or replace view v_flights_seatings as
   select f.id as flight_id,
          p.id as plane_id,
          ( deref(s.column_value) ).seatrow as seat_row,
          ( deref(s.column_value) ).seatcolumn as seat_column,
          ( deref((deref(s.column_value)).travelclassref) ).id as travel_class_id,
          ( deref((deref(s.column_value)).travelclassref) ).class_name as travel_class_name,
          ( deref(s.column_value) ).price as price
     from flight_table f
     join plane_table p
   on f.plane_id = p.id
    cross join table ( cast(p.seat_list as planeseatlist) ) s;

-------------------------------------------------------------------------------
-- 2) SELECT z utworzonych widok�w
-------------------------------------------------------------------------------
select *
  from v_travelclass_stats;
select *
  from v_plane_seatcount;
select *
  from v_plane_requiredroles;
select *
  from v_crewmember_rolecount;
select *
  from v_airport_techsupport;

select *
  from v_flights_seatings;