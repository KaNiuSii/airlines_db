------------------------------------------------------------------------
--  Przed uruchomieniem ustaw:
SET SERVEROUTPUT ON;
------------------------------------------------------------------------


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
-- 2) TEST B1: create_new_flight z nieistniejacym samolotem
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B1: create_new_flight z nieistniejacym samolotem (ID=999) ---');
  flight_management.create_new_flight(
       p_plane_id        => 999,  -- nie istnieje
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '3' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
-- Sprawdzamy
SELECT * FROM Flight_Table;

------------------------------------------------------------------------
-- 3) TEST B2: create_new_flight (LAX->JFK) - powinno siê udaæ, bo samolot ID=1 istnieje
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B2: create_new_flight LAX -> JFK ---');
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
-- 4) TEST B3: kolejny lot za wczesnie po poprzednim (przerwa <2h)
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B3: create_new_flight za wczesnie po poprzednim locie ---');
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '4' HOUR + INTERVAL '30' MINUTE,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '6' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
SELECT * FROM Flight_Table;

------------------------------------------------------------------------
-- 5) TEST B4: create_new_flight po 2h przerwie
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B4: create_new_flight po 2h przerwie ---');
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '6' HOUR,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '8' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
SELECT * FROM Flight_Table;
SELECT * FROM CrewMemberAvailability_Table;

------------------------------------------------------------------------
-- (Jeœli brakuje in¿yniera w za³odze, mo¿na dodaæ kolejnego)
------------------------------------------------------------------------
DECLARE
    v_roles RoleList := RoleList();
BEGIN
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 3; -- Engineer
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          6, 'Nowy', 'Inzynier',
          DATE '1980-12-12',
          'engineer2@example.com','123321132','E74652',
          v_roles, 
          0
        )
    );
    DBMS_OUTPUT.PUT_LINE('Dodano nowego in¿yniera o ID=6');
END;
/
COMMIT;

------------------------------------------------------------------------
-- 6) TEST B5: Dostepne samoloty w JFK i LAX
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B5: Dostêpne samoloty na JFK ---');
  flight_management.print_available_planes_for_next_flight('JFK');
  DBMS_OUTPUT.PUT_LINE('--- TEST B5: Dostêpne samoloty na LAX ---');
  flight_management.print_available_planes_for_next_flight('LAX');
END;
/

------------------------------------------------------------------------
-- 7) TEST C1: Dodanie nowego crew member (Pilot)
------------------------------------------------------------------------
DECLARE
  v_roles SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1);  -- rola 1 = Pilot
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST C1: Dodanie nowego crew member (pilot) ---');
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
-- 8) TEST C2: assign_crew_to_flight(2)
--    Przypisanie za³ogi (jeœli lot o ID=2 istnieje w Flight_Table)
------------------------------------------------------------------------
--BEGIN
--  DBMS_OUTPUT.PUT_LINE('--- TEST C2: assign_crew_to_flight(2) ---');
--  crew_management.assign_crew_to_flight(2);
--END;
--/
--SELECT * FROM CrewMemberAvailability_Table WHERE Flight_id = 2;

------------------------------------------------------------------------
-- 9) TEST D1: Dodawanie doroslego pasazera
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D1: Dodawanie doros³ego pasa¿era (ID generowane) ---');
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
-- 10) TEST D2: Dodanie dziecka bez opiekuna -> b³¹d
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D2: Dodanie dziecka bez opiekuna, oczekiwany b³¹d ---');
  reservation_management.add_passenger(
    p_first_name      => 'Tom',
    p_last_name       => 'Junior',
    p_date_of_birth   => DATE '2018-07-05',  -- ma 5 lat
    p_email           => 'tom.junior@example.com',
    p_phone           => '123123123',
    p_passport_number => 'XYZCHILD'
    -- brak p_carer_id => powinno rzuciæ b³¹d
  );
END;
/
SELECT * FROM Passenger_Table ORDER BY Id;

------------------------------------------------------------------------
-- 11) TEST D3: Dodanie dziecka z opiekunem = ID=1 (Adam)
------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D3: Dodanie dziecka z carer_id=1 (Adam) ---');
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
-- 12) TEST D4: Dodanie rezerwacji (lot=2, klasa=1 - Economy)
------------------------------------------------------------------------
DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1,2); 
   -- Zak³adamy, ¿e Adam ma ID=1, Tom (dziecko) ma ID=2 -> sprawdŸ w Passenger_Table
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D4: add_reservation flight=2, klasa=1 (Economy) ---');
   reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => v_passengers,
       p_travel_class_id => 1
   );
END;
/
SELECT * FROM Reservation_Table WHERE Flight_id = 2;

------------------------------------------------------------------------
-- 13) TEST D5: Za du¿o pasa¿erów -> "Not enough seats available"
------------------------------------------------------------------------
DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D5: zbyt wiele miejsc w Economy, b³¹d ---');
   FOR i IN 1..25 LOOP
     v_passengers.EXTEND;
     v_passengers(v_passengers.COUNT) := i + 100; -- ID=101..125 (najpewniej nie istniej¹)
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
-- 14) TEST D6: Rêczne przypisywanie foteli do rezerwacji (np. ID=1,2)
--    U¿ywamy test_bulk_assign_seats (definiowanej na pocz¹tku).
------------------------------------------------------------------------
DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);  -- rezerwacje #1 i #2
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','2B');
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D6a: caretaker adjacency error ---');
  test_bulk_assign_seats(
    p_flight_id       => 2,
    p_reservation_ids => v_res,
    p_seat_labels     => v_seat
  );
END;
/
SELECT Id, Seat FROM Reservation_Table WHERE Id IN (1,2);

-- Druga próba: np. '2A' i '3A' => kolumna ta sama => "obok"?
DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','3A');
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D6b: caretaker adjacency success ---');
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
-- 15) D7: Najpierw dodajemy doros³ego pasa¿era + rezerwacjê -> close_reservation(2)
-------------------------------------------------------------------------------

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- TEST D7 STEP A: Dodajemy doros³ego pasa¿era (Carer=NULL) ---');
    reservation_management.add_passenger(
       p_first_name      => 'Adult',
       p_last_name       => 'Test',
       p_date_of_birth   => DATE '1990-01-01',  -- doros³y
       p_email           => 'adult@test.com',
       p_phone           => '12345',
       p_passport_number => 'PASS1234',
       p_carer_id        => NULL
    );
END;
/
   
-- Teraz pobieramy ID œwie¿o utworzonego pasa¿era i dodajemy rezerwacjê w locie=2, klasa=1
DECLARE
    v_new_passenger_id NUMBER;
BEGIN
    -- Zak³adamy, ¿e nowo dodany pasa¿er ma najwiêksze ID w Passenger_Table:
    SELECT MAX(Id)
      INTO v_new_passenger_id
      FROM Passenger_Table;

    DBMS_OUTPUT.PUT_LINE('Nowy pasa¿er ma ID=' || v_new_passenger_id);

    -- Dodajemy rezerwacjê w locie=2, klasa=1 (Economy)
    DBMS_OUTPUT.PUT_LINE('--- TEST D7 STEP B: Dodanie rezerwacji (Flight=2, Class=1) dla pasa¿era='||v_new_passenger_id||' ---');
    reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => SYS.ODCINUMBERLIST(v_new_passenger_id),
       p_travel_class_id => 1  -- Economy
    );

    -- Zamykamy rezerwacje w locie=2 => automatyczne przydzielanie miejsc
    DBMS_OUTPUT.PUT_LINE('--- TEST D7 STEP C: Wywo³anie close_reservation(2) ---');
    reservation_management.close_reservation(p_flight_id => 2);
END;
/
-- SprawdŸmy teraz, jakie miejsca zosta³y przydzielone w locie=2
SELECT 
   r.Id,
   r.Passenger_id,
   (SELECT ps.SeatRow || CHR(64 + ps.SeatColumn)
      FROM PlaneSeat_Table ps
     WHERE REF(ps) = r.Seat
   ) AS seat_label
FROM Reservation_Table r
WHERE r.Flight_id = 2
ORDER BY r.Id;
