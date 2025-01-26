-------------------------------------------------------------------------------
-- Insert basic dictionary data (TravelClass, Role)
-------------------------------------------------------------------------------
insert into travelclass_table values ( travelclass(
   1,
   'Economy',
   'NajtaÅ„sza klasa, podstawowe udogodnienia'
) );
insert into travelclass_table values ( travelclass(
   2,
   'Premium',
   'Lepsze siedzenia, dodatkowe usÅ‚ugi'
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
-- Insert Airports and TechnicalSupport
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
   'Kraków, Polska',
   technicalsupportlist()
) );

insert into airport_table values ( airport(
   'GDN',
   'Gdansk Lech Walesa Airport',
   'Gdañsk, Polska',
   technicalsupportlist()
) );

insert into airport_table values ( airport(
   'WRO',
   'Copernicus Airport Wroclaw',
   'Wroc³aw, Polska',
   technicalsupportlist()
) );

insert into airport_table values ( airport(
   'KTW',
   'Katowice Airport',
   'Katowice, Polska',
   technicalsupportlist()
) );

insert into airport_table values ( airport(
   'POZ',
   'Poznan Lawica Airport',
   'Poznañ, Polska',
   technicalsupportlist()
) );


----------------------
-- Technical Support Staff
----------------------
-- Warsaw Chopin Airport (WAW)
insert into technicalsupport_table values ( technicalsupport(
   1, 'Jan Kowalski', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'WAW'
) );
insert into technicalsupport_table values ( technicalsupport(
   2, 'Anna Nowak', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'WAW'
) );
insert into technicalsupport_table values ( technicalsupport(
   3, 'Piotr Zielinski', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'WAW'
) );
insert into technicalsupport_table values ( technicalsupport(
   4, 'Maria Lewandowska', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'WAW'
) );
insert into technicalsupport_table values ( technicalsupport(
   5, 'Tomasz Wojcik', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'WAW'
) );
insert into technicalsupport_table values ( technicalsupport(
   6, 'Ewa Kaczmarek', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'WAW'
) );

-- Krakow Airport (KRK)
insert into technicalsupport_table values ( technicalsupport(
   7, 'Jakub Szymanski', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'KRK'
) );
insert into technicalsupport_table values ( technicalsupport(
   8, 'Agnieszka Wrobel', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'KRK'
) );
insert into technicalsupport_table values ( technicalsupport(
   9, 'Krzysztof Nowicki', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'KRK'
) );
insert into technicalsupport_table values ( technicalsupport(
   10, 'Zofia Wisniewska', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'KRK'
) );
insert into technicalsupport_table values ( technicalsupport(
   11, 'Marek D¹browski', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'KRK'
) );
insert into technicalsupport_table values ( technicalsupport(
   12, 'Katarzyna Adamczyk', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'KRK'
) );

-- Gdansk Airport (GDN)
insert into technicalsupport_table values ( technicalsupport(
   13, 'Andrzej Pawlak', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'GDN'
) );
insert into technicalsupport_table values ( technicalsupport(
   14, 'Barbara Michalska', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'GDN'
) );
insert into technicalsupport_table values ( technicalsupport(
   15, 'Grzegorz Majewski', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'GDN'
) );
insert into technicalsupport_table values ( technicalsupport(
   16, 'Magdalena Sobczak', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'GDN'
) );
insert into technicalsupport_table values ( technicalsupport(
   17, 'Rafal Wojciechowski', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'GDN'
) );
insert into technicalsupport_table values ( technicalsupport(
   18, 'Izabela Walczak', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'GDN'
) );

-- Wroclaw Airport (WRO)
insert into technicalsupport_table values ( technicalsupport(
   19, 'Lukasz Kwiatkowski', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'WRO'
) );
insert into technicalsupport_table values ( technicalsupport(
   20, 'Joanna Lis', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'WRO'
) );
insert into technicalsupport_table values ( technicalsupport(
   21, 'Maciej Zalewski', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'WRO'
) );
insert into technicalsupport_table values ( technicalsupport(
   22, 'Pawel Kozlowski', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'WRO'
) );
insert into technicalsupport_table values ( technicalsupport(
   23, 'Natalia Gorska', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'WRO'
) );
insert into technicalsupport_table values ( technicalsupport(
   24, 'Michal Sobolewski', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'WRO'
) );

-- Katowice Airport (KTW)
insert into technicalsupport_table values ( technicalsupport(
   25, 'Karolina Olszewska', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'KTW'
) );
insert into technicalsupport_table values ( technicalsupport(
   26, 'Damian Pawlak', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'KTW'
) );
insert into technicalsupport_table values ( technicalsupport(
   27, 'Alicja Tomaszewska', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'KTW'
) );
insert into technicalsupport_table values ( technicalsupport(
   28, 'Jacek Kruk', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'KTW'
) );
insert into technicalsupport_table values ( technicalsupport(
   29, 'Marta Zajac', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'KTW'
) );
insert into technicalsupport_table values ( technicalsupport(
   30, 'Wiktor Polak', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'KTW'
) );

-- Poznan Airport (POZ)
insert into technicalsupport_table values ( technicalsupport(
   31, 'Marcin Borowski', 'Electronics', timestamp '2025-01-20 06:00:00', timestamp '2025-01-20 14:00:00', 'POZ'
) );
insert into technicalsupport_table values ( technicalsupport(
   32, 'Sylwia Zawadzka', 'Engines', timestamp '2025-01-20 14:00:00', timestamp '2025-01-20 22:00:00', 'POZ'
) );
insert into technicalsupport_table values ( technicalsupport(
   33, 'Tadeusz Konieczny', 'Hydraulics', timestamp '2025-01-21 06:00:00', timestamp '2025-01-21 14:00:00', 'POZ'
) );
insert into technicalsupport_table values ( technicalsupport(
   34, 'Magda Urbanska', 'Avionics', timestamp '2025-01-21 14:00:00', timestamp '2025-01-21 22:00:00', 'POZ'
) );
insert into technicalsupport_table values ( technicalsupport(
   35, 'Radoslaw Czerwinski', 'Fuel Systems', timestamp '2025-01-22 06:00:00', timestamp '2025-01-22 14:00:00', 'POZ'
) );
insert into technicalsupport_table values ( technicalsupport(
   36, 'Iwona Lesniak', 'Airframe Maintenance', timestamp '2025-01-22 14:00:00', timestamp '2025-01-22 22:00:00', 'POZ'
) );


-------------------------------------------------------------------------------
-- Insert Plane Seats
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
-- Insert Crew Members
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
-- Assign Roles to Crew Members
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
-- Insert Planes with Seats and Required Roles
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
       where ps.id between 1 and 4
   ) loop
      v_seats_small.extend(1);
      v_seats_small(v_seats_small.count) := seat_ref.r;
   end loop;

   -- Plane 2 Seats
   for seat_ref in (
      select ref(ps) as r
        from planeseat_table ps
       where ps.id between 5 and 9
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
-- Insert Passengers
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

insert into passenger_table values ( passenger(
   3,
   'Dorosly',
   'Czlowiek',
   date '1995-12-25',
   'dc@mail.com',
   '981234321',
   'PAS123123',
   null
) );

insert into passenger_table values ( passenger(
   4,
   'Male',
   'Dziecko',
   date '1995-12-25',
   'md@mail.com',
   '981234321',
   'PAS45612321',
   3
) );

commit;

-------------------------------------------------------------------------------
-- Insert Flights
-------------------------------------------------------------------------------
declare
   v_seats_taken planeseatlist := planeseatlist();
begin
   insert into flight_table values ( flight(
      1,
      1,
      timestamp '2025-02-01 09:00:00',
      timestamp '2025-02-01 11:00:00',
      'WAW',
      'KRK',
      timestamp '2025-01-31 23:59:00',
      v_seats_taken,
      rolelist()
   ) );

   insert into flight_table values ( flight(
      2,
      2,
      timestamp '2025-02-02 14:00:00',
      timestamp '2025-02-02 17:00:00',
      'KRK',
      'WAW',
      timestamp '2025-02-01 23:59:00',
      v_seats_taken,
      rolelist()
   ) );

   commit;
end;
/

-------------------------------------------------------------------------------
-- Insert Reservations
-------------------------------------------------------------------------------
insert into reservation_table values ( reservation(
   1,
   1,
   1,
   (
      select ref(t)
        from travelclass_table t
       where t.id = 1
   ),
   null
) );

insert into reservation_table values ( reservation(
   2,
   1,
   2,
   (
      select ref(t)
        from travelclass_table t
       where t.id = 2
   ),
   null
) );

insert into reservation_table values ( reservation(
   3,
   2,
   1,
   (
      select ref(t)
        from travelclass_table t
       where t.id = 1
   ),
   null
) );

insert into reservation_table values ( reservation(
   4,
   2,
   2,
   (
      select ref(t)
        from travelclass_table t
       where t.id = 3
   ),
   null
) );

----------------
-- Planes techncail support
----------------

DECLARE
   v_tech_list technicalsupportlist := technicalsupportlist();
   v_ref       REF technicalsupport;

   -- Define a collection to store airport codes
   TYPE airport_list IS TABLE OF VARCHAR2(3);
   v_airports airport_list := airport_list('WAW', 'KRK', 'GDN', 'WRO', 'KTW', 'POZ');
BEGIN
   -- Iterate through the list of airports
   FOR i IN 1..v_airports.COUNT LOOP
      v_tech_list := technicalsupportlist();
      
      -- Collect references to technical support staff for the current airport
      FOR rec IN (
         SELECT REF(ts) AS ref_tech
         FROM technicalsupport_table ts
         WHERE ts.Airport_IATA = v_airports(i)
      ) LOOP
         v_tech_list.EXTEND;
         v_tech_list(v_tech_list.COUNT) := rec.ref_tech;
      END LOOP;

      -- Update the airport table with the technical support list
      UPDATE airport_table
      SET technical_support_list = v_tech_list
      WHERE IATA = v_airports(i);
   END LOOP;

   COMMIT;
END;
/

----------------
-- More flights
----------------
DECLARE
   v_seats_taken planeseatlist := planeseatlist();
BEGIN
   -- Plane 1: From KRK to GDN
   insert into flight_table values ( flight(
      3,
      1, -- Plane 1
      timestamp '2025-02-01 15:00:00', -- Departure
      timestamp '2025-02-01 17:00:00', -- Arrival
      'KRK', -- From
      'GDN', -- To
      timestamp '2025-01-31 23:59:00', -- Reservation Closing
      v_seats_taken,
      rolelist()
   ) );

   -- Plane 1: From GDN to WAW
   insert into flight_table values ( flight(
      4,
      1, -- Plane 1
      timestamp '2025-02-01 20:00:00', -- Departure
      timestamp '2025-02-01 22:00:00', -- Arrival
      'GDN', -- From
      'WAW', -- To
      timestamp '2025-02-01 15:59:00', -- Reservation Closing
      v_seats_taken,
      rolelist()
   ) );

   -- Plane 2: From WAW to KTW
   insert into flight_table values ( flight(
      5,
      2, -- Plane 2
      timestamp '2025-02-02 20:00:00', -- Departure
      timestamp '2025-02-02 21:30:00', -- Arrival
      'WAW', -- From
      'KTW', -- To
      timestamp '2025-02-02 19:00:00', -- Reservation Closing
      v_seats_taken,
      rolelist()
   ) );

   -- Plane 2: From KTW to WRO
   insert into flight_table values ( flight(
      6,
      2, -- Plane 2
      timestamp '2025-02-03 09:00:00', -- Departure
      timestamp '2025-02-03 10:30:00', -- Arrival
      'KTW', -- From
      'WRO', -- To
      timestamp '2025-02-03 08:00:00', -- Reservation Closing
      v_seats_taken,
      rolelist()
   ) );

   -- Plane 1: From WAW to POZ
   insert into flight_table values ( flight(
      7,
      1, -- Plane 1
      timestamp '2025-02-02 08:00:00', -- Departure
      timestamp '2025-02-02 09:30:00', -- Arrival
      'WAW', -- From
      'POZ', -- To
      timestamp '2025-02-01 23:59:00', -- Reservation Closing
      v_seats_taken,
      rolelist()
   ) );

   COMMIT;
END;
/

-- Insert additional crew members
insert into crewmember_table values ( crewmember(
   3,
   'Marek',
   'Steward',
   date '1992-08-20',
   'marek.steward@airline.com',
   '555123789',
   'ST7654321',
   rolelist(),
   1200.0
) );

insert into crewmember_table values ( crewmember(
   4,
   'Anna',
   'Pilot',
   date '1988-04-15',
   'anna.pilot@airline.com',
   '555987654',
   'PL9876543',
   rolelist(),
   2800.0
) );

insert into crewmember_table values ( crewmember(
   5,
   'Jan',
   'CoPilot',
   date '1991-11-30',
   'jan.copilot@airline.com',
   '555456789',
   'CP4567890',
   rolelist(),
   1800.0
) );

-- Assign roles to new crew members
declare
   v_pilot   ref role;
   v_copilot ref role;
   v_steward ref role;
begin
   select ref(r) into v_pilot from role_table r where r.role_name = 'Pilot';
   select ref(r) into v_copilot from role_table r where r.role_name = 'CoPilot';
   select ref(r) into v_steward from role_table r where r.role_name = 'Steward';

   update crewmember_table c set c.roles_list = rolelist(v_steward) where c.id = 3;
   update crewmember_table c set c.roles_list = rolelist(v_pilot) where c.id = 4;
   update crewmember_table c set c.roles_list = rolelist(v_copilot) where c.id = 5;
end;
/

-- Insert crew availability data
insert into crewmemberavailability_table values ( crewmemberavailability(
   1, 1, 1, timestamp '2025-02-01 13:00:00'
) );

insert into crewmemberavailability_table values ( crewmemberavailability(
   2, 2, 1, timestamp '2025-02-01 13:00:00'
) );

insert into crewmemberavailability_table values ( crewmemberavailability(
   3, 3, 1, timestamp '2025-02-01 13:00:00'
) );
