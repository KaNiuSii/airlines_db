-------------------------------------------------------------------------------
-- 1. Insert basic dictionary data (TravelClass, Role)
-------------------------------------------------------------------------------
insert into travelclass_table values ( travelclass(
   1,
   'Economy',
   'Najta�sza klasa, podstawowe udogodnienia'
) );
insert into travelclass_table values ( travelclass(
   2,
   'Premium',
   'Lepsze siedzenia, dodatkowe us�ugi'
) );
insert into travelclass_table values ( travelclass(
   3,
   'Business',
   'Wysoki komfort, szerokie fotele, priorytet'
) );

insert into role_table values ( role(
   1,
   'Pilot'
) );
insert into role_table values ( role(
   2,
   'CoPilot'
) );
insert into role_table values ( role(
   3,
   'Steward'
) );

-------------------------------------------------------------------------------
-- 2. Insert Airports and TechnicalSupport
-------------------------------------------------------------------------------
insert into airport_table values ( airport(
   'WAW',
   'Warsaw Chopin Airport',
   'Warszawa, Polska',
   technicalsupportlist()
) );

insert into airport_table values ( airport(
   'KRK',
   'Krakow Airport',
   'Krak�w, Polska',
   technicalsupportlist()
) );

-- Technical Support Staff
insert into technicalsupport_table values ( technicalsupport(
   1,
   'Jan Kowalski',
   'Elektronika',
   timestamp '2025-01-20 06:00:00',
   timestamp '2025-01-20 14:00:00',
   'WAW'
) );

insert into technicalsupport_table values ( technicalsupport(
   2,
   'Anna Nowak',
   'Silniki',
   timestamp '2025-01-20 14:00:00',
   timestamp '2025-01-20 22:00:00',
   'WAW'
) );

-------------------------------------------------------------------------------
-- 3. Insert Plane Seats
-------------------------------------------------------------------------------
declare
   v_economy  ref travelclass;
   v_premium  ref travelclass;
   v_business ref travelclass;
begin
   select ref(t)
     into v_economy
     from travelclass_table t
    where t.id = 1;
   select ref(t)
     into v_premium
     from travelclass_table t
    where t.id = 2;
   select ref(t)
     into v_business
     from travelclass_table t
    where t.id = 3;

  -- Seats for Plane 1 (Small)
   insert into planeseat_table values ( planeseat(
      1,
      1,
      1,
      v_economy,
      100.0
   ) );
   insert into planeseat_table values ( planeseat(
      2,
      1,
      2,
      v_economy,
      100.0
   ) );
   insert into planeseat_table values ( planeseat(
      3,
      2,
      1,
      v_premium,
      150.0
   ) );
   insert into planeseat_table values ( planeseat(
      4,
      2,
      2,
      v_business,
      200.0
   ) );

  -- Seats for Plane 2 (Large)
   insert into planeseat_table values ( planeseat(
      5,
      1,
      1,
      v_economy,
      200.0
   ) );
   insert into planeseat_table values ( planeseat(
      6,
      1,
      2,
      v_economy,
      200.0
   ) );
   insert into planeseat_table values ( planeseat(
      7,
      2,
      1,
      v_economy,
      200.0
   ) );
   insert into planeseat_table values ( planeseat(
      8,
      2,
      2,
      v_premium,
      280.0
   ) );
   insert into planeseat_table values ( planeseat(
      9,
      3,
      1,
      v_business,
      350.0
   ) );
end;
/

-------------------------------------------------------------------------------
-- 4. Insert Crew Members
-------------------------------------------------------------------------------
insert into crewmember_table values ( crewmember(
   1,
   'Adam',
   'Pilot',
   date '1985-06-10',
   'adam.pilot@airline.com',
   '123456789',
   'AB1234567',
   rolelist(),
   3000.0
) );

insert into crewmember_table values ( crewmember(
   2,
   'Ewa',
   'CoPilot',
   date '1990-03-15',
   'ewa.copilot@airline.com',
   '987654321',
   'CD7654321',
   rolelist(),
   1500.0
) );

-------------------------------------------------------------------------------
-- 5. Assign Roles to Crew Members
-------------------------------------------------------------------------------
declare
   v_pilot   ref role;
   v_copilot ref role;
begin
   select ref(r)
     into v_pilot
     from role_table r
    where r.role_name = 'Pilot';
   select ref(r)
     into v_copilot
     from role_table r
    where r.role_name = 'CoPilot';

   update crewmember_table c
      set
      c.roles_list = rolelist(v_pilot)
    where c.id = 1;

   update crewmember_table c
      set
      c.roles_list = rolelist(v_copilot)
    where c.id = 2;
end;
/

-------------------------------------------------------------------------------
-- 6. Insert Planes with Seats and Required Roles
-------------------------------------------------------------------------------
declare
   v_seats_small  planeseatlist := planeseatlist();
   v_seats_big    planeseatlist := planeseatlist();
   v_role_pilot   ref role;
   v_role_copilot ref role;
begin
   select ref(r)
     into v_role_pilot
     from role_table r
    where r.role_name = 'Pilot';
   select ref(r)
     into v_role_copilot
     from role_table r
    where r.role_name = 'CoPilot';

  -- Plane 1 Seats
   for seat_ref in (
      select ref(ps) as r
        from planeseat_table ps
       where ps.seatrow between 1 and 2
   ) loop
      v_seats_small.extend(1);
      v_seats_small(v_seats_small.count) := seat_ref.r;
   end loop;

  -- Plane 2 Seats
   for seat_ref in (
      select ref(ps) as r
        from planeseat_table ps
       where ps.seatrow between 3 and 5
   ) loop
      v_seats_big.extend(1);
      v_seats_big(v_seats_big.count) := seat_ref.r;
   end loop;

  -- Insert Planes
   insert into plane_table values ( plane(
      1,
      v_seats_small,
      rolelist(
         v_role_pilot,
         v_role_copilot
      )
   ) );
   insert into plane_table values ( plane(
      2,
      v_seats_big,
      rolelist(
         v_role_pilot,
         v_role_copilot
      )
   ) );
end;
/

-------------------------------------------------------------------------------
-- 7. Insert Passengers
-------------------------------------------------------------------------------
insert into passenger_table values ( passenger(
   1,
   'Piotr',
   'Nowak',
   date '2000-01-01',
   'piotr.nowak@mail.com',
   '123456789',
   'PAS123',
   null
) );

insert into passenger_table values ( passenger(
   2,
   'Anna',
   'Kowalska',
   date '1995-12-25',
   'anna.kowalska@mail.com',
   '987654321',
   'PAS456',
   null
) );

commit;

-------------------------------------------------------------------------------
-- 8. Flights
-------------------------------------------------------------------------------

declare
   v_seats_taken planeseatlist := planeseatlist(); -- Initialize empty seat list
begin
   insert into flight_table values ( flight(
      1,                -- Flight ID
      1,                -- Plane ID
      timestamp '2025-02-01 09:00:00',  -- Departure
      timestamp '2025-02-01 11:00:00',  -- Arrival
      'WAW',            -- IATA_from
      'KRK',            -- IATA_to
      timestamp '2025-01-31 23:59:00',  -- Reservation Closing
      v_seats_taken,    -- Empty seats list for now
      rolelist()        -- Empty crew list for now
   ) );

   insert into flight_table values ( flight(
      2,                -- Flight ID
      2,                -- Plane ID
      timestamp '2025-02-02 14:00:00',  -- Departure
      timestamp '2025-02-02 17:00:00',  -- Arrival
      'KRK',            -- IATA_from
      'WAW',            -- IATA_to
      timestamp '2025-02-01 23:59:00',  -- Reservation Closing
      v_seats_taken,    -- Empty seats list for now
      rolelist()        -- Empty crew list for now
   ) );

   commit;
end;
/