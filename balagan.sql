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



select * from flight_table;

SELECT f.Id, f.Plane_id, f.Arrival_datetime, ts.Shift_end
FROM Flight_Table f
JOIN Airport_Table a ON f.IATA_to = a.IATA
JOIN TABLE(a.Technical_Support_List) ts_list ON 1=1
JOIN TechnicalSupport_Table ts ON ts_list.COLUMN_VALUE = REF(ts)
WHERE f.IATA_to = 'WAW';