-- 1. Populate Role_Table
INSERT INTO Role_Table VALUES (Role(1, 'Pilot'));
INSERT INTO Role_Table VALUES (Role(2, 'Flight Attendant'));
INSERT INTO Role_Table VALUES (Role(3, 'Engineer'));

-- 2. Populate TravelClass_Table
INSERT INTO TravelClass_Table VALUES (TravelClass(1, 'Economy', 'Standard class with basic amenities.'));
INSERT INTO TravelClass_Table VALUES (TravelClass(2, 'Business', 'Premium class with additional amenities.'));
INSERT INTO TravelClass_Table VALUES (TravelClass(3, 'First Class', 'Luxury class with exclusive services.'));

-- 3. Create Plane and Populate PlaneSeatList
DECLARE
    v_required_roles RoleList := RoleList();
    v_seat_list PlaneSeatList := PlaneSeatList();
    v_travel_class_ref REF TravelClass;
    v_seat_ref REF PlaneSeat;
BEGIN
    -- Define Required Roles for Plane
    SELECT REF(r) BULK COLLECT INTO v_required_roles
      FROM Role_Table r
     WHERE r.Id IN (1, 2, 3); -- Pilot, Flight Attendant, Engineer

    -- Fetch the reference for Economy Class
    SELECT REF(tc)
      INTO v_travel_class_ref
      FROM TravelClass_Table tc
     WHERE tc.Id = 1;

    -- Insert PlaneSeats into PlaneSeat_Table and Populate Seat List
    FOR row_num IN 1..4 LOOP
        FOR col_num IN 1..5 LOOP
            -- Insert the PlaneSeat object into PlaneSeat_Table
            INSERT INTO PlaneSeat_Table VALUES (
                PlaneSeat(
                    Id              => row_num * 10 + col_num,
                    SeatRow         => row_num,
                    SeatColumn      => col_num,
                    TravelClassRef  => v_travel_class_ref,
                    Price           => 100.0
                )
            );

            -- Fetch the REF for the inserted PlaneSeat
            SELECT REF(ps)
              INTO v_seat_ref
              FROM PlaneSeat_Table ps
             WHERE ps.Id = row_num * 10 + col_num;

            -- Add the REF PlaneSeat to the Seat List
            v_seat_list.EXTEND;
            v_seat_list(v_seat_list.COUNT) := v_seat_ref;
        END LOOP;
    END LOOP;

    -- Insert the Plane into Plane_Table
    INSERT INTO Plane_Table VALUES (
        Plane(Id => 1, 
              Seat_list => v_seat_list, 
              Required_role_list => v_required_roles)
    );

    DBMS_OUTPUT.PUT_LINE('Plane and seats created successfully.');
END;
/

-- 4. Populate Airport_Table
INSERT INTO Airport_Table VALUES (
    Airport('JFK', 'John F. Kennedy International Airport', 'New York, USA', TechnicalSupportList())
);
INSERT INTO Airport_Table VALUES (
    Airport('LAX', 'Los Angeles International Airport', 'Los Angeles, USA', TechnicalSupportList())
);
INSERT INTO Airport_Table VALUES (
    Airport('ORD', 'Chicago Hare International Airport', 'Chicago, USA', TechnicalSupportList())
);

-- 5. Populate CrewMember_Table
DECLARE
    v_roles RoleList := RoleList();
BEGIN
    -- Add Pilot 1
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 1;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(1, 'John', 'Doe', DATE '1985-01-01', 'john.doe@example.com', '123456789', 'P12345', v_roles, 0)
    );

    -- Add Pilot 2
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 1;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(2, 'Jane', 'Smith', DATE '1990-02-01', 'jane.smith@example.com', '987654321', 'P98765', v_roles, 0)
    );

    -- Add Flight Attendant 1
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 2;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(3, 'Emily', 'Johnson', DATE '1995-03-01', 'emily.johnson@example.com', '123123123', 'F12345', v_roles, 0)
    );

    -- Add Flight Attendant 2
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 2;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(4, 'Michael', 'Brown', DATE '1992-04-01', 'michael.brown@example.com', '456456456', 'F98765', v_roles, 0)
    );

    -- Add Engineer
    SELECT REF(r) BULK COLLECT INTO v_roles FROM Role_Table r WHERE r.Id = 3;
    INSERT INTO CrewMember_Table VALUES (
        CrewMember(5, 'Robert', 'Taylor', DATE '1988-05-01', 'robert.taylor@example.com', '789789789', 'E12345', v_roles, 0)
    );
END;
/

-- 6. Populate TechnicalSupport_Table
DECLARE
    v_airports SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('JFK', 'LAX', 'ORD');
    v_shift_start TIMESTAMP;
    v_shift_end TIMESTAMP;
    v_new_id NUMBER;
BEGIN
    FOR i IN 1..v_airports.COUNT LOOP
        -- Dodanie 3 cz³onków obs³ugi technicznej na ka¿d¹ zmianê dla ka¿dego lotniska
        FOR shift_number IN 1..3 LOOP
            -- Ustawienia zmian (8-godzinne zmiany: 00:00-08:00, 08:00-16:00, 16:00-00:00)
            v_shift_start := TRUNC(SYSDATE) + INTERVAL '8' HOUR * (shift_number - 1);
            v_shift_end := TRUNC(SYSDATE) + INTERVAL '8' HOUR * shift_number;

            -- Wygenerowanie nowego ID
            SELECT NVL(MAX(Id), 0) + 1 INTO v_new_id FROM TechnicalSupport_Table;

            -- Wstawienie danych do tabeli
            INSERT INTO TechnicalSupport_Table VALUES (
                v_new_id,
                'TechSupport_' || v_airports(i) || '_' || shift_number,
                '',
                v_shift_start,
                v_shift_end,
                v_airports(i) -- Przypisanie do konkretnego lotniska
            );
        END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Technical support data populated successfully.');
END;
/


