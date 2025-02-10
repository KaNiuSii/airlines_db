SET SERVEROUTPUT ON;


------------------------------------------------------------------------
-- 1) Procedura pomocnicza: test_bulk_assign_seats
--    (dla wielu rezerwacji i foteli wywo³uje assign_seat_for_reservation w pêtli)
------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE test_bulk_assign_seats(
   p_flight_id       IN NUMBER,
   p_reservation_ids IN SYS.ODCINUMBERLIST,
   p_seat_labels     IN SYS.ODCIVARCHAR2LIST
)
IS
BEGIN
   IF p_reservation_ids.COUNT <> p_seat_labels.COUNT THEN
      DBMS_OUTPUT.PUT_LINE('test_bulk_assign_seats: mismatch in counts! Aborting.');
      RETURN;
   END IF;

   FOR i IN 1..p_reservation_ids.COUNT LOOP
       flight_management.assign_seat_for_reservation(
           p_flight_id      => p_flight_id,
           p_reservation_id => p_reservation_ids(i),
           p_seat_label     => p_seat_labels(i)
       );
   END LOOP;
END;
/
------------------------------------------------------------------------
-- 2)  create_new_flight z nieistniejacym samolotem
------------------------------------------------------------------------
BEGIN
  flight_management.create_new_flight(
       p_plane_id        => 999,  -- nie istnieje
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '3' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
SELECT * FROM Flight_Table;

------------------------------------------------------------------------
-- 3) create_new_flight (LAX->JFK)
------------------------------------------------------------------------
BEGIN
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '4' HOUR,
       p_IATA_from       => 'LAX',
       p_IATA_to         => 'JFK'
  );
END;
/
SELECT * FROM Flight_Table;

------------------------------------------------------------------------
-- 4) kolejny lot za wczesnie po poprzednim (przerwa <2h)
------------------------------------------------------------------------
BEGIN
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '4' HOUR + INTERVAL '30' MINUTE,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '6' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
SELECT count(*) FROM Flight_Table;

------------------------------------------------------------------------
-- 5) create_new_flight po 2h przerwie
------------------------------------------------------------------------
BEGIN
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '6' HOUR,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '8' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
SELECT count(*) FROM Flight_Table;
SELECT * FROM CrewMemberAvailability_Table;

------------------------------------------------------------------------
-- 6) Dostepne samoloty w JFK i LAX
------------------------------------------------------------------------
BEGIN
  flight_management.print_available_planes_for_next_flight('JFK');
  flight_management.print_available_planes_for_next_flight('LAX');
END;
/

------------------------------------------------------------------------
-- 7) Dodanie nowego crew member (Pilot)
------------------------------------------------------------------------
DECLARE
  v_roles SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1);  -- rola 1 = Pilot
BEGIN
  crew_management.add_crew_member(
       p_first_name   => 'NewPilot',
       p_last_name    => 'Test',
       p_birth_date   => DATE '1980-10-10',
       p_email        => 'pilot.test@example.com',
       p_phone        => '111222333',
       p_passport     => 'P4321',
       p_role_ids     => v_roles
  );
END;
/
SELECT * FROM CrewMember_Table ORDER BY Id;

------------------------------------------------------------------------
-- 9) Dodawanie doroslego pasazera
------------------------------------------------------------------------
BEGIN
  reservation_management.add_passenger(
    p_first_name      => 'Adam',
    p_last_name       => 'Nowak',
    p_date_of_birth   => DATE '1980-07-05',
    p_email           => 'adam.nowak@example.com',
    p_phone           => '999888777',
    p_passport_number => 'XYZ111'
  );
END;
/
SELECT * FROM Passenger_Table ORDER BY Id;

------------------------------------------------------------------------
-- 10) Dodanie dziecka bez opiekuna -> b³¹d
------------------------------------------------------------------------
BEGIN
  reservation_management.add_passenger(
    p_first_name      => 'Tom',
    p_last_name       => 'Junior',
    p_date_of_birth   => DATE '2018-07-05',  -- ma 7 lat
    p_email           => 'tom.junior@example.com',
    p_phone           => '123123123',
    p_passport_number => 'XYZCHILD'
    -- brak p_carer_id => powinno rzuciæ b³¹d
  );
END;
/
SELECT * FROM Passenger_Table ORDER BY Id;

------------------------------------------------------------------------
-- 11) Dodanie dziecka z opiekunem = ID=1 (Adam)
------------------------------------------------------------------------
BEGIN
  reservation_management.add_passenger(
    p_first_name      => 'Tom',
    p_last_name       => 'Junior',
    p_date_of_birth   => DATE '2018-07-05',
    p_email           => 'tom.junior@example.com',
    p_phone           => '123123123',
    p_passport_number => 'XYZCHILD',
    p_carer_id        => 1
  );
END;
/
SELECT * FROM Passenger_Table ORDER BY Id;


------------------------------------------------------------------------
-- 12) Dodanie rezerwacji (lot=2, klasa=1 - Economy)
------------------------------------------------------------------------
DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1,2); 
BEGIN
   reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => v_passengers,
       p_travel_class_id => 1
   );
END;
/
SELECT count(*) FROM Reservation_Table WHERE Flight_id = 2;

------------------------------------------------------------------------
-- 13) Za du¿o pasa¿erów -> "Not enough seats available"
------------------------------------------------------------------------
DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
BEGIN
   FOR i IN 1..25 LOOP
     v_passengers.EXTEND;
     v_passengers(v_passengers.COUNT) := i + 100; 
   END LOOP;

   reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => v_passengers,
       p_travel_class_id => 1
   );
END;
/
SELECT * FROM Reservation_Table WHERE Flight_id = 2;

------------------------------------------------------------------------
-- 14 Rêczne przypisywanie foteli do rezerwacji (np. ID=1,2)
------------------------------------------------------------------------

-- fail
DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);  -- rezerwacje #1 i #2
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','3C');
BEGIN
  test_bulk_assign_seats(
    p_flight_id       => 2,
    p_reservation_ids => v_res,
    p_seat_labels     => v_seat
  );
END;
/
SELECT Id, Seat FROM Reservation_Table WHERE Id IN (1,2);

-- sukces
DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','2B');
BEGIN
  test_bulk_assign_seats(
    p_flight_id       => 2,
    p_reservation_ids => v_res,
    p_seat_labels     => v_seat
  );
END;
/
SELECT 
  r.Id, 
  r.Passenger_id,
  (SELECT ps.SeatRow || CHR(64 + ps.SeatColumn)
     FROM PlaneSeat_Table ps
    WHERE REF(ps) = r.Seat
  ) AS seat_label
FROM Reservation_Table r
WHERE r.Id IN (1,2);

------------------------------------------------------------------------
-- 15) Dodanie 2 doros³ych i 1 dziecka (z opiekunem) i zamkniêcie rezerwacji.
------------------------------------------------------------------------

DECLARE
    v_adult1_id NUMBER;
    v_adult2_id NUMBER;
    v_child_id  NUMBER;
BEGIN
    -- 1) Dodajemy pierwszego doros³ego pasa¿era
    reservation_management.add_passenger(
       p_first_name      => 'Adult1',
       p_last_name       => 'Test1',
       p_date_of_birth   => DATE '1990-01-01',  -- doros³y
       p_email           => 'adult1@test.com',
       p_phone           => '12345',
       p_passport_number => 'PASS-A1',
       p_carer_id        => NULL
    );

    -- Pobieramy ID pierwszego doros³ego
    SELECT MAX(Id)
      INTO v_adult1_id
      FROM Passenger_Table;
    DBMS_OUTPUT.PUT_LINE('Dodano Adult1, ID = ' || v_adult1_id);

    -- 2) Dodajemy drugiego doros³ego pasa¿era
    reservation_management.add_passenger(
       p_first_name      => 'Adult2',
       p_last_name       => 'Test2',
       p_date_of_birth   => DATE '1985-05-10',  -- doros³y
       p_email           => 'adult2@test.com',
       p_phone           => '54321',
       p_passport_number => 'PASS-A2',
       p_carer_id        => NULL
    );

    -- Pobieramy ID drugiego doros³ego
    SELECT MAX(Id)
      INTO v_adult2_id
      FROM Passenger_Table;
    DBMS_OUTPUT.PUT_LINE('Dodano Adult2, ID = ' || v_adult2_id);

    -- 3) Dodajemy dziecko z opiekunem = pierwszy doros³y (v_adult1_id)
    reservation_management.add_passenger(
       p_first_name      => 'Child1',
       p_last_name       => 'TestChild',
       p_date_of_birth   => DATE '2018-07-05',  -- dziecko
       p_email           => 'child1@test.com',
       p_phone           => '999999999',
       p_passport_number => 'CHILD-PASS-1',
       p_carer_id        => v_adult1_id
    );

    -- Pobieramy ID dziecka
    SELECT MAX(Id)
      INTO v_child_id
      FROM Passenger_Table;
    DBMS_OUTPUT.PUT_LINE('Dodano Child1, ID = ' || v_child_id);

    -- 4) Dodajemy wspóln¹ rezerwacjê na lot o ID=2 (klasa=1 => Economy)
    reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => SYS.ODCINUMBERLIST(v_adult1_id, v_adult2_id, v_child_id),
       p_travel_class_id => 1
    );
    DBMS_OUTPUT.PUT_LINE('Utworzono rezerwacjê (lot=2, klasa=Economy) dla 3 osób.');

    -- 5) Zamykamy rezerwacje w locie=2 => automatyczne przydzielanie miejsc
    reservation_management.close_reservation(p_flight_id => 2);
    DBMS_OUTPUT.PUT_LINE('Zamkniêto rezerwacje w locie=2.');
END;
/

SELECT 
  r.Id, 
  r.Passenger_id,
  (SELECT ps.SeatRow || CHR(64 + ps.SeatColumn)
     FROM PlaneSeat_Table ps
    WHERE REF(ps) = r.Seat
  ) AS seat_label
FROM Reservation_Table r;


begin
    flight_management.show_plane_seats_distribution(1);
end;
/
