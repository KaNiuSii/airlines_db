SET SERVEROUTPUT ON;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B1: create_new_flight z nieistniejacym samolotem (ID=999) ---');
  -- Ten lot powinien siê NIE udaæ, bo samolot nie istnieje:
  flight_management.create_new_flight(
       p_plane_id        => 999,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '3' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
-- Oczekujemy komunikatu "Flight cannot be scheduled due to constraints." 
-- Sprawdzamy, czy w Flight_Table coœ siê nie wstawi³o:
SELECT * FROM Flight_Table;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B2: create_new_flight LAX -> JFK ---');
  -- Ten lot powinien siê udaæ:
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

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B3: create_new_flight za wczesnie po poprzednim locie ---');

  -- Poprzedni lot wyl¹dowa³ (wg B2) w JFK, np. SYSTIMESTAMP +1 day +4h.
  -- Spróbujmy zrobiæ kolejny lot w JFK z wylotem niewiele póŸniej, np. +4h30min 
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
-- Oczekujemy, ¿e DBMS_OUTPUT powie "Flight cannot be scheduled..."
-- i w Flight_Table *nie* powstanie nowy wpis.

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B4: create_new_flight po 2h przerwie ---');
  -- Poprzedni lot z B2 l¹duje w JFK np. (SYSTIMESTAMP + 1 day + 4h).
  -- Aby minê³o 2h, start dajmy (SYSTIMESTAMP + 1 day + 6h).
  flight_management.create_new_flight(
       p_plane_id        => 1,
       p_departure_time  => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '6' HOUR,
       p_arrival_time    => SYSTIMESTAMP + INTERVAL '1' DAY + INTERVAL '8' HOUR,
       p_IATA_from       => 'JFK',
       p_IATA_to         => 'LAX'
  );
END;
/
-- To jenak siê nie uda poniewa¿ brakuje wolnego in¿yniera który móg³by lecieæ.

SELECT * FROM Flight_Table;
SELECT * FROM CrewMemberAvailability_Table;

-- Dlatego dodamy tak owego

-- Add Engineer
DECLARE
    v_roles RoleList := RoleList();
BEGIN
    -- Add Engineer
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 3;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(6, 'Nowy', 'Inzynier', DATE '1988-05-01', 'robert.taylor@example.com', '123321132', 'E74652', v_roles, 0)
    );
END;
/

-- powtarzamy operacje

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
-- To jenak siê nie uda poniewa¿ brakuje wolnego in¿yniera który móg³by lecieæ.

SELECT * FROM Flight_Table;
SELECT * FROM CrewMemberAvailability_Table;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST B5: Dostêpne samoloty na JFK ---');
  flight_management.print_available_planes_for_next_flight('JFK');
  DBMS_OUTPUT.PUT_LINE('--- TEST B5: Dostêpne samoloty na LAX ---');
  flight_management.print_available_planes_for_next_flight('LAX');
END;
/

DECLARE
  v_roles SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1);  -- rola = Pilot (ID=1)
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST C1: Dodanie nowego crew member ---');
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

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST C2: assign_crew_to_flight na istniej¹cy lot (np. ID=2) ---');
  crew_management.assign_crew_to_flight(2);
END;
/
-- Prawdopodobnie pojawi siê komunikat "Znaleziono za³ogê..." lub "Brak wystarczaj¹cej liczby dostêpnych za³ogantów..."
SELECT * FROM CrewMemberAvailability_Table WHERE Flight_id = 2;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D1: Dodawanie doroslego pasazera ---');
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
SELECT * FROM Passenger_Table;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D2: Dodanie dziecka bez opiekuna ---');
  reservation_management.add_passenger(
    p_first_name      => 'Tom',
    p_last_name       => 'Junior',
    p_date_of_birth   => ADD_MONTHS(SYSDATE, -6*12), -- 6 lat
    p_email           => 'tom.junior@example.com',
    p_phone           => '123123123',
    p_passport_number => 'XYZCHILD'
    -- p_carer_id => NULL
  );
END;
/
-- Powinien wyst¹piæ b³¹d: "Child under 12 must have a carer."
SELECT * FROM Passenger_Table;
-- Sprawdzamy, ¿e dziecko siê NIE wstawi³o.

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D3: Dodanie dziecka z opiekunem ID=1 ---');
  reservation_management.add_passenger(
    p_first_name      => 'Tom',
    p_last_name       => 'Junior',
    p_date_of_birth   => DATE '2018-07-05',  -- 6 lat
    p_email           => 'tom.junior@example.com',
    p_phone           => '123123123',
    p_passport_number => 'XYZCHILD',
    p_carer_id        => 1                  -- ID doros³ego
  );
END;
/
SELECT * FROM Passenger_Table ORDER BY Id;
-- Sprawdzamy, czy pojawi³ siê nowy pasa¿er (Tom Junior) i ma carer_id=1.

DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(1,2); -- Adam i Tom
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D4: add_reservation dla lotu ID=2, klasa 1 (Economy) ---');
   reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => v_passengers,
       p_travel_class_id => 1  -- Economy
   );
END;
/
SELECT * FROM Reservation_Table WHERE Flight_id = 2;

DECLARE
   v_passengers SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D5: zbyt wiele miejsc w Economy ---');
   FOR i IN 1..25 LOOP
     v_passengers.EXTEND;
     v_passengers(v_passengers.COUNT) := i+100; 
     -- Zak³adamy, ¿e mamy pasa¿erów z ID=101..125. W praktyce pewnie ich nie ma,
     -- ale test zademonstruje b³¹d "Not enough seats available".
   END LOOP;

   reservation_management.add_reservation(
       p_flight_id       => 2,
       p_passenger_ids   => v_passengers,
       p_travel_class_id => 1
   );
END;
/
-- Oczekujemy RAISE_APPLICATION_ERROR(-20003, 'Not enough seats available...').
SELECT * FROM Reservation_Table WHERE Flight_id = 2;
-- Sprawdzamy, ¿e siê nic nowego nie wstawi³o.

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D6: upgrade_travel_class na rezerwacji ID=? ---');
  reservation_management.upgrade_travel_class(
       p_reservation_id => 1,  -- lub wstaw odpowiednie ID
       p_new_class_id   => 2   -- Business
  );
END;
/
SELECT r.Id, r.Flight_id, r.Requested_Class.Id as class_id
FROM Reservation_Table r
WHERE r.Id = 1; -- sprawdzamy, czy klasa siê zmieni³a

DECLARE
   v_res  SYS.ODCINUMBERLIST     := SYS.ODCINUMBERLIST();
   v_seat SYS.ODCIVARCHAR2LIST   := SYS.ODCIVARCHAR2LIST();
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D7a: seat_is_taken - siedzisko juz zajete ---');

   -- 1) Najpierw *rêcznie* przypiszmy rezerwacji 1 seat "2A"
   v_res.EXTEND;  v_res(1) := 1;   -- rezerwacja 1
   v_seat.EXTEND; v_seat(1) := '2A';

   flight_management.take_seat_at_flight(
      p_flight_id         => 2,
      p_reservation_list  => v_res,
      p_seat_list         => v_seat
   );

   -- 2) Teraz spróbujmy *ponownie* u¿yæ "2A" dla innej rezerwacji, np. ID=2
   v_res(1)  := 2;    -- zmieniamy tylko ID rezerwacji
   v_seat(1) := '2A'; -- seat ten sam

   flight_management.take_seat_at_flight(
      p_flight_id         => 2,
      p_reservation_list  => v_res,
      p_seat_list         => v_seat
   );
   -- powinien wyœwietliæ komunikat: "Seat 2A is already taken..."
END;
/
SELECT Id, Seat
FROM Reservation_Table
WHERE Flight_id = 2;

----
-- D7b
----

--Jeœli rezerwacja ID=2 ma Requested_Class.Id = 1 (Economy), a my wska¿emy seat z Business (ID=2).
--Musimy mieæ w PlaneSeat_Table jakieœ miejsca w klasie 2, a w mocku mamy na razie wszystkie w Economy.
--Wiêc do testu dopiszmy np. wiersz w PlaneSeat_Table z kolumn¹ TravelClassRef => (REF Business)

DECLARE
    v_class_ref   REF TravelClass;
BEGIN
    -- Najpierw weŸmy REF do TravelClass(2) = 'Business'
    SELECT REF(tc)
      INTO v_class_ref
      FROM TravelClass_Table tc
     WHERE tc.Id = 2;

    INSERT INTO PlaneSeat_Table VALUES (
      PlaneSeat(
        Id             => 999,   -- unikalny
        SeatRow        => 1,
        SeatColumn     => 10,    -- kolumna 10, dziwna, ale do testu
        TravelClassRef => v_class_ref,
        Price          => 500.0
      )
    );
END;
/

-- Teraz seat "1J" (bo 'A'=1, 'B'=2, ... 'J'=10). 
-- Spróbujmy zarezerwowaæ ten seat w rezerwacji ID=2, która jest Economy:

DECLARE
   v_res  SYS.ODCINUMBERLIST     := SYS.ODCINUMBERLIST(2);   -- rezerwacja 2 (Economy)
   v_seat SYS.ODCIVARCHAR2LIST   := SYS.ODCIVARCHAR2LIST('1J');
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- TEST D7b: siedzisko w innej klasie (Business zamiast Economy) ---');
   flight_management.take_seat_at_flight(
      p_flight_id         => 2,
      p_reservation_list  => v_res,
      p_seat_list         => v_seat
   );
END;
/
-- Powinno byæ: "Seat 1J does not match the requested travel class..."
-- a rezerwacja ID=2 dalej Seat = NULL
SELECT Id, Seat FROM Reservation_Table WHERE Id=2;

DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','2B');
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D7c: caretaker adjacency error ---');
  flight_management.take_seat_at_flight(
    p_flight_id         => 2,
    p_reservation_list  => v_res,
    p_seat_list         => v_seat
  );
END;
/
-- Oczekujemy "Caretaker ... wanted seats next to them... Aborting."
SELECT Id, Seat FROM Reservation_Table WHERE Id IN (1,2);
-- Pozostan¹ stare wartoœci Seat

DECLARE
   v_res  SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST(1,2);
   v_seat SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST('2A','3A');
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D7d: caretaker adjacency success ---');
  flight_management.take_seat_at_flight(
    p_flight_id         => 2,
    p_reservation_list  => v_res,
    p_seat_list         => v_seat
  );
END;
/
SELECT Id, Seat FROM Reservation_Table WHERE Id IN (1,2);
-- Powinny byæ przypisane: 1->2A, 2->3A.
-- Dodatkowo w Flight_Table.List_taken_seats widaæ, ¿e dosz³y REFy do tych siedzeñ.

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- TEST D8: close_reservation(2) ---');
  reservation_management.close_reservation(p_flight_id => 2);
END;
/
SELECT Id, Seat FROM Reservation_Table WHERE Flight_id = 2;
-- Zobaczymy, czy automatycznie przydzieli³o miejsca (losowo).




