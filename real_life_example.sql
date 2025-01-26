--------------------------------------------------------------------------
-- [1] WSTAWIENIE DANYCH POCZ¥TKOWYCH
--     (Role, Klasy, Miejsca, Samoloty, Pasa¿erowie, CrewMember)
--     ZADBAMY OD RAZU O TO, ABY SCENARIUSZ PÓNIEJ DZIA£A£
--------------------------------------------------------------------------
SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== [1.1] Dodawanie Ról ===');
    INSERT INTO Role_Table VALUES (Role(1, 'Pilot'));
    INSERT INTO Role_Table VALUES (Role(2, 'CoPilot'));
    INSERT INTO Role_Table VALUES (Role(3, 'FlightAttendant'));
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('--- Role_Table ---');
    FOR r IN (SELECT * FROM Role_Table ORDER BY Id) LOOP
       DBMS_OUTPUT.PUT_LINE('    '||r.Id||': '||r.Role_name);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('=== [1.2] Dodawanie Klas Podró¿y ===');
    INSERT INTO TravelClass_Table VALUES (TravelClass(1, 'Economy','Tania klasa ekonomiczna'));
    INSERT INTO TravelClass_Table VALUES (TravelClass(2, 'Business','Biznesowa, dro¿sza'));
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('--- TravelClass_Table ---');
    FOR tc IN (SELECT * FROM TravelClass_Table ORDER BY Id) LOOP
       DBMS_OUTPUT.PUT_LINE('    '||tc.Id||': '||tc.Class_Name||' ('||tc.Description||')');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('=== [1.3] Dodawanie miejsc (PlaneSeat) ===');
    -- Zrobimy minimalne "demonstracyjne" miejsca dla 2 samolotów.
    -- Samolot #1 -> seatId: 101..104
    -- Samolot #2 -> seatId: 201..206 (trochê wiêcej)
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(101,1,1,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 150.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(102,1,2,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 150.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(103,2,1,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 150.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(104,2,2,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=2), 300.0)
    );

    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(201,1,1,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 120.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(202,1,2,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 120.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(203,2,1,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 120.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(204,2,2,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 120.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(205,1,3,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=1), 120.0)
    );
    INSERT INTO PlaneSeat_Table VALUES (
       PlaneSeat(206,2,3,(SELECT REF(t) FROM TravelClass_Table t WHERE t.Id=2), 320.0)
    );
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('--- PlaneSeat_Table count ---');
    DECLARE c NUMBER; BEGIN 
       SELECT COUNT(*) INTO c FROM PlaneSeat_Table;
       DBMS_OUTPUT.PUT_LINE('    Liczba miejsc='||c);
    END;
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('=== [1.4] Dodawanie Samolotów (Plane) z list¹ miejsc i wymaganych ról ===');
    -- Samolot #1: wymaga Pilot(1) + FlightAttendant(3)
    INSERT INTO Plane_Table VALUES (
       Plane(
         1,
         PlaneSeatList(
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=101),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=102),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=103),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=104)
         ),
         RoleList(
           (SELECT REF(r) FROM Role_Table r WHERE r.Id=1), -- Pilot
           (SELECT REF(r) FROM Role_Table r WHERE r.Id=3)  -- FlightAttendant
         )
       )
    );

    -- Samolot #2: wymaga Pilot(1) + CoPilot(2) + FlightAttendant(3)
    INSERT INTO Plane_Table VALUES (
       Plane(
         2,
         PlaneSeatList(
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=201),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=202),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=203),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=204),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=205),
           (SELECT REF(ps) FROM PlaneSeat_Table ps WHERE ps.Id=206)
         ),
         RoleList(
           (SELECT REF(r) FROM Role_Table r WHERE r.Id=1), -- Pilot
           (SELECT REF(r) FROM Role_Table r WHERE r.Id=2), -- CoPilot
           (SELECT REF(r) FROM Role_Table r WHERE r.Id=3)  -- FlightAttendant
         )
       )
    );
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('=== [1.5] Dodawanie przyk³adowych Lotnisk (Airport_Table) ===');
    INSERT INTO Airport_Table VALUES (
      Airport('WAW','Warsaw Chopin','Warszawa, Polska', TechnicalSupportList())
    );
    INSERT INTO Airport_Table VALUES (
      Airport('LHR','Heathrow','Londyn, UK', TechnicalSupportList())
    );
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('=== [1.6] Dodawanie Pasa¿erów (Passenger_Table) ===');
    -- #1 -> Jan (opiekun)
    -- #2 -> Ola (dziecko, Carer=1)
    INSERT INTO Passenger_Table VALUES (
      Passenger(1,'Jan','Kowalski',DATE '1990-01-01','jan@example.com','111111111','PASSJAN',NULL)
    );
    INSERT INTO Passenger_Table VALUES (
      Passenger(2,'Ola','Kowalska',DATE '2015-05-05','ola@example.com','222222222','PASSOLA',1)
    );
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('=== [1.7] Dodawanie cz³onków za³ogi (CrewMember_Table) ===');
    -- Mamy 4 cz³onków, ¿eby móc obs³u¿yæ dwa samoloty:
    -- #1 -> Pilot
    -- #2 -> FlightAttendant
    -- #3 -> Pilot + FlightAttendant
    -- #4 -> Pilot + CoPilot
    DBMS_OUTPUT.PUT_LINE('--- crew_management.add_crew_member(...) ---');
    crew_management.add_crew_member(
       p_first_name => 'Karol',
       p_last_name  => 'Pilot1',
       p_birth_date => DATE '1980-02-02',
       p_email      => 'karol.pilot1@example.com',
       p_phone      => '500100100',
       p_passport   => 'PPILOT1',
       p_role_ids   => SYS.ODCINUMBERLIST(1)  -- Pilot
    );
    crew_management.add_crew_member(
       p_first_name => 'Monika',
       p_last_name  => 'Steward1',
       p_birth_date => DATE '1990-03-03',
       p_email      => 'monika.stew1@example.com',
       p_phone      => '500200200',
       p_passport   => 'PSTEW1',
       p_role_ids   => SYS.ODCINUMBERLIST(3)  -- FlightAttendant
    );
    crew_management.add_crew_member(
       p_first_name => 'Artur',
       p_last_name  => 'MultiPilotStew',
       p_birth_date => DATE '1985-04-04',
       p_email      => 'artur.multi@example.com',
       p_phone      => '500300300',
       p_passport   => 'PMULTI',
       p_role_ids   => SYS.ODCINUMBERLIST(1,3) -- Pilot + FlightAttendant
    );
    crew_management.add_crew_member(
       p_first_name => 'Piotr',
       p_last_name  => 'PilotCoPilot',
       p_birth_date => DATE '1975-05-05',
       p_email      => 'piotr.double@example.com',
       p_phone      => '500400400',
       p_passport   => 'PCO',
       p_role_ids   => SYS.ODCINUMBERLIST(1,2) -- Pilot + CoPilot
    );
    COMMIT;

END;
/
--------------------------------------------------------------------------
-- [2] SCENARIUSZ: TWORZENIE LOTÓW + PRZYDZIA£ ZA£OGI
--------------------------------------------------------------------------
DECLARE
    v_cnt NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [2.1] Tworzymy Flight #1 (samolot #1) WAW->LHR, 2025-02-20 08:00->10:00 ===');
    flight_management.create_new_flight(
       p_plane_id       => 1, 
       p_departure_time => TIMESTAMP'2025-02-20 08:00:00', 
       p_arrival_time   => TIMESTAMP'2025-02-20 10:00:00',
       p_IATA_from      => 'WAW',
       p_IATA_to        => 'LHR'
    );

    SELECT COUNT(*) INTO v_cnt FROM Flight_Table;
    DBMS_OUTPUT.PUT_LINE('--- Flight_Table count = '||v_cnt);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [2.2] Próba Flight #2 (LHR->WAW) za wczeœnie, np. 2025-02-20 20:00->22:00 ===');
    DBMS_OUTPUT.PUT_LINE('--- To jest tylko 10h po 1. locie, za³oga potrzebuje 12h odpoczynku ---');
    flight_management.create_new_flight(
       p_plane_id       => 1,
       p_departure_time => TIMESTAMP'2025-02-20 20:00:00',
       p_arrival_time   => TIMESTAMP'2025-02-20 22:00:00',
       p_IATA_from      => 'LHR',
       p_IATA_to        => 'WAW'
    );

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [2.3] Ponawiamy Flight #2, tym razem 2025-02-20 22:30->2025-02-21 00:30 ===');
    DBMS_OUTPUT.PUT_LINE('--- Teraz minie 12,5h od poprzedniego l¹dowania (10:00 -> 22:30), wiêc za³oga mo¿e lecieæ ---');
    flight_management.create_new_flight(
       p_plane_id       => 1,
       p_departure_time => TIMESTAMP'2025-02-20 22:30:00',
       p_arrival_time   => TIMESTAMP'2025-02-21 00:30:00',
       p_IATA_from      => 'LHR',
       p_IATA_to        => 'WAW'
    );

    SELECT COUNT(*) INTO v_cnt FROM Flight_Table;
    DBMS_OUTPUT.PUT_LINE('--- Flight_Table count = '||v_cnt);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [2.4] Tworzymy Flight #3 (samolot #2) WAW->LHR, 2025-02-21 12:30->14:30 ===');
    DBMS_OUTPUT.PUT_LINE('--- Samolot #2 wymaga 3 ról: Pilot, CoPilot, FlightAttendant ---');
    DBMS_OUTPUT.PUT_LINE('--- Za³oga z lotu #2 wyl¹duje w WAW o 00:30, po 12h odpoczynku bêdzie wolna od 12:30. ---');
    flight_management.create_new_flight(
       p_plane_id       => 2,
       p_departure_time => TIMESTAMP'2025-02-21 12:30:00',
       p_arrival_time   => TIMESTAMP'2025-02-21 14:30:00',
       p_IATA_from      => 'WAW',
       p_IATA_to        => 'LHR'
    );

    SELECT COUNT(*) INTO v_cnt FROM Flight_Table;
    DBMS_OUTPUT.PUT_LINE('--- Flight_Table count = '||v_cnt);

END;
/

--------------------------------------------------------------------------
-- [3] REZERWACJE + PRZYDZIA£ MIEJSC (OPIEKUN-DZIECKO)
--------------------------------------------------------------------------
DECLARE
    v_flight_id  NUMBER;
    v_new_res_id NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.1] Sprawdzamy ID nowszego lotu (Flight #3) - powinien byæ = 3 albo 4... ===');
    -- Tu, dla uproszczenia, weŸmy po prostu najwy¿szy ID:
    SELECT MAX(f.Id) INTO v_flight_id FROM Flight_Table f;
    DBMS_OUTPUT.PUT_LINE('    Najnowszy lot ma Id='||v_flight_id);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.2] Dodajemy 2 rezerwacje na ten lot: pasa¿er #1 (Jan - opiekun), pasa¿er #2 (Ola - dziecko) ===');
    SELECT NVL(MAX(r.Id),0)+1 INTO v_new_res_id FROM Reservation_Table;
    INSERT INTO Reservation_Table VALUES(
      Reservation(
        v_new_res_id,      -- np. 101
        v_flight_id,
        1,                 -- Jan
        (SELECT REF(tc) FROM TravelClass_Table tc WHERE tc.Id=1), -- Economy
        NULL
      )
    );
    SELECT NVL(MAX(r.Id),0)+1 INTO v_new_res_id FROM Reservation_Table;
    INSERT INTO Reservation_Table VALUES(
      Reservation(
        v_new_res_id,      -- np. 102
        v_flight_id,
        2,                 -- Ola
        (SELECT REF(tc) FROM TravelClass_Table tc WHERE tc.Id=1), -- Economy
        NULL
      )
    );
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('--- Rezerwacje na Flight_Id='||v_flight_id||' ---');
    FOR rr IN (
       SELECT r.Id, r.Passenger_id, r.Flight_id
         FROM Reservation_Table r
        WHERE r.Flight_id = v_flight_id
        ORDER BY r.Id
    ) LOOP
       DBMS_OUTPUT.PUT_LINE('    ResID='||rr.Id
          ||', Passenger='||rr.Passenger_id
          ||', Flight='||rr.Flight_id);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.3] Podejrzyjmy uk³ad miejsc samolotu #2 ===');
    flight_management.show_plane_seats_distribution(2);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.4] Próba rezerwacji miejsc - Z£A: (Jan -> 1A, Ola -> 2C) ===');
    DBMS_OUTPUT.PUT_LINE('--- Wed³ug caretaker_sits_next_to_child te miejsca nie s¹ obok siebie ---');
    -- Przyjmijmy seat label "1A" => row=1,col=1 i "2C" => row=2,col=3
    -- co jest zbyt daleko.
    flight_management.take_seat_at_flight(
      p_flight_id        => v_flight_id,
      p_reservation_list => SYS.ODCINUMBERLIST(101, 102),
      p_seat_list        => SYS.ODCIVARCHAR2LIST('1A','2C')
    );

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.5] Poprawna rezerwacja miejsc - (Jan -> 1A, Ola -> 2A), obok siebie w pionie ===');
    -- Zgodnie z definicj¹ caretaker_sits_next_to_child: 
    --  "same column, row differs by 1" => 1A ->(1,1), 2A->(2,1).
    flight_management.take_seat_at_flight(
      p_flight_id        => v_flight_id,
      p_reservation_list => SYS.ODCINUMBERLIST(101, 102),
      p_seat_list        => SYS.ODCIVARCHAR2LIST('1A','2A')
    );

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== [3.6] Podsumowanie rezerwacji i zajêtych miejsc w Flight_Table ===');

    DBMS_OUTPUT.PUT_LINE('--- Reservation_Table z seat ---');
    FOR rec IN (
      SELECT r.Id, r.Passenger_id, 
             DEREF(r.Seat).SeatRow as seat_row,
             DEREF(r.Seat).SeatColumn as seat_col
      FROM Reservation_Table r
      ORDER BY r.Id
    ) LOOP
      DBMS_OUTPUT.PUT_LINE('    ResID='||rec.Id||', Psg='||rec.Passenger_id
        ||', Seat('||rec.seat_row||','||rec.seat_col||')');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Flight_Table.List_taken_seats (dla Flight_Id='||v_flight_id||') ---');
    FOR seatRef IN (
      SELECT COLUMN_VALUE AS ref_seat
      FROM Flight_Table f, TABLE(f.List_taken_seats)
      WHERE f.Id = v_flight_id
    ) LOOP
       DECLARE
         s PlaneSeat;
       BEGIN
         SELECT DEREF(seatRef.ref_seat) INTO s FROM DUAL;
         DBMS_OUTPUT.PUT_LINE('    SeatId='||s.Id||' => (row='||s.SeatRow||',col='||s.SeatColumn||')');
       END;
    END LOOP;

END;
/
