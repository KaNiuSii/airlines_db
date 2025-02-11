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


