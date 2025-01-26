SET SERVEROUTPUT ON;

BEGIN
    flight_management.print_available_planes_for_next_flight('WAW');
    flight_management.print_available_planes_for_next_flight('KRK');
    flight_management.print_available_planes_for_next_flight('WRO');
    flight_management.print_available_planes_for_next_flight('GDN');
    flight_management.print_available_planes_for_next_flight('POZ');
    flight_management.print_available_planes_for_next_flight('KTW');
END;

DECLARE
    can_schedule BOOLEAN;
BEGIN
    flight_management.can_schedule_flight(
        p_IATA_code       => 'WRO',
        p_plane_id        => 2,
        p_departure_time  => TO_TIMESTAMP('2025-02-03 12:30:00', 'YYYY-MM-DD HH24:MI:SS'),
        p_result          => can_schedule
    );

    IF can_schedule THEN
        DBMS_OUTPUT.PUT_LINE('Flight can be scheduled.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flight cannot be scheduled.');
    END IF;
END;
/

BEGIN
    flight_management.create_new_flight(
        p_plane_id        => 2,
        p_departure_time  => TO_TIMESTAMP('2025-02-03 12:30:00', 'YYYY-MM-DD HH24:MI:SS'),
        p_arrival_time    => TO_TIMESTAMP('2025-02-03 15:30:00', 'YYYY-MM-DD HH24:MI:SS'),
        p_IATA_from       => 'WRO',
        p_IATA_to         => 'KRK'
    );
END;
/

DECLARE
    can_schedule crew_management.crew_assignment_list;
    required_roles plane_table.required_role_list%TYPE;
BEGIN
    -- Pobierz wymagan¹ listê ról do zmiennej
    SELECT pt.required_role_list 
    INTO required_roles
    FROM plane_table pt
    WHERE pt.id = 1;

    -- Wywo³aj funkcjê z u¿yciem zmiennej
    can_schedule := crew_management.find_available_crew(
        p_flight_id => 8,
        p_departure_time => TO_TIMESTAMP('25/02/03 18:30:00,000000000', 'YY/MM/DD HH24:MI:SS,FF9'),
        p_arrival_time => TO_TIMESTAMP('25/02/04 22:30:00,000000000', 'YY/MM/DD HH24:MI:SS,FF9'),
        p_departure_airport => 'KTW',
        p_required_roles => required_roles
    );
    -- Wyœwietl wynik
    IF can_schedule IS NOT NULL THEN
        -- Iteracja i wyœwietlanie elementów listy
        FOR i IN 1..can_schedule.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Crew Member ID: ' || can_schedule(i).crew_member_id || 
                                 ', Role ID: ' || can_schedule(i).role_id);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No available crew found for the specified flight.');
    END IF;
END;
/

select pt.required_role_list from plane_table pt where pt.id = 1;

select ft.id, ft.IATA_to, ft.arrival_datetime from flight_table ft where ft.id in (select max(ftx.id) from flight_table ftx);

SELECT f.Id, f.Plane_id, f.Arrival_datetime, ts.Shift_end
FROM Flight_Table f
JOIN Airport_Table a ON f.IATA_to = a.IATA
JOIN TABLE(a.Technical_Support_List) ts_list ON 1=1
JOIN TechnicalSupport_Table ts ON ts_list.COLUMN_VALUE = REF(ts)
WHERE f.IATA_to = 'WAW';