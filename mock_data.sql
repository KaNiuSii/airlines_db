-- --------------------------------------------------------------------------------
-- 1. Role_Table
-- --------------------------------------------------------------------------------
INSERT INTO Role_Table VALUES (Role(1, 'Pilot'));
INSERT INTO Role_Table VALUES (Role(2, 'Flight Attendant'));
INSERT INTO Role_Table VALUES (Role(3, 'Engineer'));
COMMIT;

-- --------------------------------------------------------------------------------
-- 2. TravelClass_Table
-- --------------------------------------------------------------------------------
INSERT INTO TravelClass_Table VALUES (TravelClass(1, 'Economy', 'Standard class with basic amenities.'));
INSERT INTO TravelClass_Table VALUES (TravelClass(2, 'Business', 'Premium class with additional amenities.'));
INSERT INTO TravelClass_Table VALUES (TravelClass(3, 'First Class', 'Luxury class with exclusive services.'));
COMMIT;

-- --------------------------------------------------------------------------------
-- 3. Plane + PlaneSeat_Table + Plane_Table
-- --------------------------------------------------------------------------------
DECLARE
    v_required_roles RoleList := RoleList();
    v_seat_list PlaneSeatList := PlaneSeatList();
    v_travel_class_ref REF TravelClass;
    v_seat_ref REF PlaneSeat;
BEGIN
    -- Zdefiniuj wymagane role dla samolotu
    SELECT REF(r) BULK COLLECT INTO v_required_roles
      FROM Role_Table r
     WHERE r.Id IN (1, 2, 3); -- Pilot, Flight Attendant, Engineer

    -- Za³ó¿my, ¿e dla uproszczenia *wszystkie* miejsca bêd¹ w klasie 'Economy' (Id=1)
    SELECT REF(tc)
      INTO v_travel_class_ref
      FROM TravelClass_Table tc
     WHERE tc.Id = 1;

    -- Wstawmy np. 4 rzêdy po 5 kolumn => 20 miejsc, wszystkie w Economy
    FOR row_num IN 1..4 LOOP
        FOR col_num IN 1..5 LOOP
            INSERT INTO PlaneSeat_Table VALUES (
                PlaneSeat(
                    Id              => row_num*10 + col_num,
                    SeatRow         => row_num,
                    SeatColumn      => col_num,
                    TravelClassRef  => v_travel_class_ref,
                    Price           => 100.0
                )
            );
            -- Pobierz REF do œwie¿o wstawionego miejsca
            SELECT REF(ps)
              INTO v_seat_ref
              FROM PlaneSeat_Table ps
             WHERE ps.Id = row_num*10 + col_num;

            -- Dodaj do lokalnej kolekcji seat_list
            v_seat_list.EXTEND;
            v_seat_list(v_seat_list.COUNT) := v_seat_ref;
        END LOOP;
    END LOOP;

    -- Teraz wstaw Plane do Plane_Table
    INSERT INTO Plane_Table VALUES (
        Plane(
          Id                  => 1,
          Seat_list           => v_seat_list,
          Required_role_list  => v_required_roles
        )
    );

    DBMS_OUTPUT.PUT_LINE('Plane ID=1 i 20 miejsc w klasie Economy - utworzone.');
    COMMIT;
END;
/
 
-- --------------------------------------------------------------------------------
-- 4. Airport_Table
-- --------------------------------------------------------------------------------
INSERT INTO Airport_Table VALUES (
    Airport('JFK', 'John F. Kennedy International Airport', 'New York, USA', TechnicalSupportList())
);
INSERT INTO Airport_Table VALUES (
    Airport('LAX', 'Los Angeles International Airport', 'Los Angeles, USA', TechnicalSupportList())
);
INSERT INTO Airport_Table VALUES (
    Airport('ORD', 'Chicago Hare International Airport', 'Chicago, USA', TechnicalSupportList())
);
COMMIT;

-- --------------------------------------------------------------------------------
-- 5. CrewMember_Table (5 osób: 2 pilotów, 2 stewards, 1 in¿ynier)
-- --------------------------------------------------------------------------------
DECLARE
    v_roles RoleList := RoleList();
BEGIN
    -- Pilot 1
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 1; -- Pilot
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          1, 'John', 'Doe', DATE '1985-01-01', 
          'john.doe@example.com', '123456789', 'P12345', 
          v_roles, 0
        )
    );

    -- Pilot 2
    v_roles := RoleList();
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 1;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          2, 'Jane', 'Smith', DATE '1990-02-01', 
          'jane.smith@example.com', '987654321', 'P98765',
          v_roles, 0
        )
    );

    -- Flight Attendant 1
    v_roles := RoleList();
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 2; -- Flight Attendant
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          3, 'Emily', 'Johnson', DATE '1995-03-01', 
          'emily.johnson@example.com','123123123','F12345',
          v_roles, 0
        )
    );

    -- Flight Attendant 2
    v_roles := RoleList();
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 2;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          4, 'Michael', 'Brown', DATE '1992-04-01',
          'michael.brown@example.com','456456456','F98765',
          v_roles, 0
        )
    );

    -- Engineer
    v_roles := RoleList();
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 3; -- Engineer
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(
          5, 'Robert', 'Taylor', DATE '1988-05-01',
          'robert.taylor@example.com','789789789','E12345',
          v_roles, 0
        )
    );
    COMMIT;
END;
/

-- --------------------------------------------------------------------------------
-- 6. TechnicalSupport_Table (3 lotniska x 3 zmiany = 9 wpisów)
-- --------------------------------------------------------------------------------
DECLARE
    v_airports SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('JFK','LAX','ORD');
    v_shift_start TIMESTAMP;
    v_shift_end   TIMESTAMP;
    v_new_id      NUMBER;
BEGIN
    FOR i IN 1..v_airports.COUNT LOOP
        FOR shift_num IN 1..3 LOOP
            -- Zrobimy zmiany 8h: 0-8, 8-16, 16-24
            v_shift_start := TRUNC(SYSDATE) + INTERVAL '8' HOUR * (shift_num-1);
            v_shift_end   := v_shift_start + INTERVAL '8' HOUR;

            SELECT NVL(MAX(Id),0)+1 INTO v_new_id 
              FROM TechnicalSupport_Table;

            INSERT INTO TechnicalSupport_Table VALUES (
                TechnicalSupport(
                  Id             => v_new_id,
                  Name           => 'TechSupport_'||v_airports(i)||'_'||shift_num,
                  Specialization => 'General',
                  Shift_start    => v_shift_start,
                  Shift_end      => v_shift_end,
                  Airport_IATA   => v_airports(i)
                )
            );
        END LOOP;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Technical support data populated (9 rows).');
END;
/
