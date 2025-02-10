SET SERVEROUTPUT ON;


CREATE OR REPLACE PACKAGE flight_management AS

    /******************************************************************************
     * 1) Funkcje/Procedury dotycz¹ce planowania lotu
     ******************************************************************************/
    PROCEDURE can_schedule_flight (
        p_IATA_code       IN CHAR,
        p_plane_id        IN NUMBER,
        p_departure_time  IN TIMESTAMP,
        p_result          OUT BOOLEAN
    );
    
    FUNCTION check_technical_support (
        p_IATA_code IN CHAR,
        p_time      IN TIMESTAMP,
        p_flight_id IN NUMBER
    ) RETURN TIMESTAMP;
    
    PROCEDURE create_new_flight (
        p_plane_id        IN NUMBER,
        p_departure_time  IN TIMESTAMP,
        p_arrival_time    IN TIMESTAMP,
        p_IATA_from       IN CHAR,
        p_IATA_to         IN CHAR
    );

    PROCEDURE print_available_planes_for_next_flight(
        IATA_code IN CHAR
    );

    /******************************************************************************
     * 2) Funkcje pomocnicze do miejsc w samolocie / rezerwacji
     ******************************************************************************/
    FUNCTION seat_is_taken (
        p_flight_id  IN NUMBER,
        p_seat_label IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION caretaker_sits_next_to_child (
        p_seat_label_carer  IN VARCHAR2,
        p_seat_label_child  IN VARCHAR2
    ) RETURN BOOLEAN;

    /******************************************************************************
     * 3) Procedura przypisywania miejsca
     *    - przyjmuje 1 rezerwacjê, 1 miejsce w danym locie
     ******************************************************************************/
    PROCEDURE assign_seat_for_reservation (
        p_flight_id      IN NUMBER,
        p_reservation_id IN NUMBER,
        p_seat_label     IN VARCHAR2
    );

    /******************************************************************************
     * 4) Dodatkowe rzeczy
     ******************************************************************************/
    FUNCTION find_adjacent_seats (
        p_flight_id IN NUMBER,
        p_class_id  IN NUMBER
    ) RETURN SYS.ODCIVARCHAR2LIST;

    PROCEDURE show_plane_seats_distribution (
        plane_id NUMBER
    );

END flight_management;
/

CREATE OR REPLACE PACKAGE BODY flight_management AS

    /******************************************************************************
     *                 Sekcja prywatna
     ******************************************************************************/
    -- Funkcja parse_seat_label: "12B" => (row=12, col=2) wewnêtrznie
    FUNCTION parse_seat_label (
        seat_label IN VARCHAR2
    )
        RETURN VARCHAR2
    IS
        l_num   VARCHAR2(5);
        l_alpha VARCHAR2(5);
        l_row   NUMBER;
        l_col   NUMBER;
    BEGIN
        -- Wyodrêbnij cyfry (rz¹d) i literê (kolumna)
        l_num   := REGEXP_SUBSTR(seat_label, '^\d+');      -- np. "12"
        l_alpha := REGEXP_SUBSTR(seat_label, '[A-Z]+$');   -- np. "B"

        IF l_num IS NULL OR l_alpha IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Niepoprawny format etykiety miejsca: ' || seat_label);
        END IF;

        l_row := TO_NUMBER(l_num);
        l_col := ASCII(l_alpha) - ASCII('A') + 1;

        RETURN l_row || '|' || l_col;  -- np. "12|2"
    END parse_seat_label;

    /******************************************************************************
     *                     1) Procedura can_schedule_flight
     ******************************************************************************/
    PROCEDURE can_schedule_flight (
        p_IATA_code       IN CHAR,
        p_plane_id        IN NUMBER,
        p_departure_time  IN TIMESTAMP,
        p_result          OUT BOOLEAN
    ) IS
        last_arrival_time    TIMESTAMP;
        next_available_time  TIMESTAMP;
        flight_count         NUMBER;
        maintenance_start    TIMESTAMP;
    BEGIN
        p_result := FALSE;  -- domyœlnie

        -- Szukamy ostatniego lotu dla samolotu p_plane_id
        SELECT 
            MAX(f.Arrival_datetime),
            MAX(f.Arrival_datetime + INTERVAL '2' HOUR)
        INTO 
            last_arrival_time, 
            next_available_time
        FROM Flight_Table f
        WHERE f.Plane_id = p_plane_id;

        IF last_arrival_time IS NULL THEN
            -- Brak wczeœniejszych lotów -> mo¿na planowaæ pierwszy lot
            p_result := TRUE;
        ELSE
            -- Sprawdzamy, czy czas planowanego wylotu > next_available_time
            IF next_available_time <= p_departure_time THEN
                -- Czy samolot faktycznie wyl¹dowa³ na p_IATA_code?
                SELECT COUNT(*)
                  INTO flight_count
                  FROM Flight_Table f
                 WHERE f.Plane_id         = p_plane_id
                   AND f.IATA_to          = p_IATA_code
                   AND f.Arrival_datetime = last_arrival_time;

                IF flight_count > 0 THEN
                    -- Sprawdzamy, czy obs³uga techniczna zd¹¿y
                    maintenance_start := check_technical_support(
                        p_IATA_code => p_IATA_code,
                        p_time      => last_arrival_time + INTERVAL '2' HOUR,
                        p_flight_id => p_plane_id
                    );

                    IF maintenance_start <= p_departure_time THEN
                        p_result := TRUE;
                    END IF;
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            p_result := FALSE;
    END can_schedule_flight;

    /******************************************************************************
     *                     2) Funkcja check_technical_support
     ******************************************************************************/
    FUNCTION check_technical_support (
        p_IATA_code IN CHAR,
        p_time      IN TIMESTAMP,
        p_flight_id IN NUMBER
    ) RETURN TIMESTAMP IS
        v_support_count   NUMBER;
        v_shift_start     TIMESTAMP;
    BEGIN
        SELECT COUNT(*)
          INTO v_support_count
          FROM TechnicalSupport_Table ts
         WHERE ts.Airport_IATA = p_IATA_code
           -- Za³ó¿my, ¿e shift_start <= p_time < shift_end
           AND ts.Shift_start <= p_time
           AND ts.Shift_end   >  p_time
           AND ts.Id NOT IN (
               SELECT COLUMN_VALUE
                 FROM TABLE(
                      SELECT f.Technical_support_after_arrival_ids
                        FROM Flight_Table f
                       WHERE f.Arrival_datetime <= p_time
                         AND f.Arrival_datetime + INTERVAL '2' HOUR > p_time
                         AND f.IATA_to = p_IATA_code
                 )
           );

        IF v_support_count >= 3 THEN
            RETURN p_time; -- wystarczy
        ELSE
            SELECT MIN(ts.Shift_start)
              INTO v_shift_start
              FROM TechnicalSupport_Table ts
             WHERE ts.Airport_IATA = p_IATA_code;

            RETURN GREATEST(p_time, v_shift_start);
        END IF;
    END check_technical_support;

    /******************************************************************************
     *                     3) Procedura create_new_flight
     ******************************************************************************/
    PROCEDURE create_new_flight(
       p_plane_id        IN NUMBER,
       p_departure_time  IN TIMESTAMP,
       p_arrival_time    IN TIMESTAMP,
       p_IATA_from       IN CHAR,
       p_IATA_to         IN CHAR
   ) IS
       can_schedule BOOLEAN;
       v_new_flight_id NUMBER;
       v_technical_support SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
       v_crew_count NUMBER;
   BEGIN
       can_schedule_flight(
           p_IATA_code      => p_IATA_from,
           p_plane_id       => p_plane_id,
           p_departure_time => p_departure_time,
           p_result         => can_schedule
       );

       IF can_schedule THEN
           SELECT NVL(MAX(Id),0)+1 INTO v_new_flight_id FROM Flight_Table;
           
           -- Pobierz dostêpnych cz³onków wsparcia
           SELECT ts.Id BULK COLLECT INTO v_technical_support
             FROM TechnicalSupport_Table ts
            WHERE ts.Airport_IATA = p_IATA_from
              AND ts.Shift_start <= p_departure_time - INTERVAL '2' HOUR
              AND ts.Shift_end   >  p_departure_time - INTERVAL '2' HOUR
              AND ROWNUM         <= 3;

           INSERT INTO Flight_Table (
               Id,
               Plane_id,
               Departure_datetime,
               Arrival_datetime,
               IATA_from,
               IATA_to,
               Reservation_closing_datetime,
               List_taken_seats,
               Technical_support_after_arrival_ids
           ) VALUES (
               v_new_flight_id,
               p_plane_id,
               p_departure_time,
               p_arrival_time,
               p_IATA_from,
               p_IATA_to,
               p_departure_time - INTERVAL '2' HOUR,
               PlaneSeatList(),
               v_technical_support
           );

           BEGIN
              crew_management.assign_crew_to_flight(v_new_flight_id);
              
              SELECT COUNT(*)
                INTO v_crew_count
                FROM CrewMemberAvailability_Table cma
               WHERE cma.Flight_id = v_new_flight_id;

              IF v_crew_count = 0 THEN
                 DELETE FROM Flight_Table WHERE Id = v_new_flight_id;
                 DBMS_OUTPUT.PUT_LINE('Cannot create flight '||v_new_flight_id
                                      ||' - no crew assigned. Flight removed.');
              ELSE
                 DBMS_OUTPUT.PUT_LINE('Crew assigned successfully for flight '||v_new_flight_id);
              END IF;
              DBMS_OUTPUT.PUT_LINE('Flight created: ID='||v_new_flight_id);
           EXCEPTION
              WHEN OTHERS THEN
                 DBMS_OUTPUT.PUT_LINE('No crew_management logic found or other error. Flight remains.');
           END;

       ELSE
           DBMS_OUTPUT.PUT_LINE('Flight cannot be scheduled due to constraints.');
       END IF;
   END create_new_flight;

    /******************************************************************************
     *                     4) Procedura print_available_planes_for_next_flight
     ******************************************************************************/
    PROCEDURE print_available_planes_for_next_flight(IATA_code IN CHAR) IS
        found_planes INT := 0;

        CURSOR FlightsCursor IS
            SELECT 
                f.Plane_id,
                MAX(f.Arrival_datetime) AS Last_Arrival,
                MAX(f.Arrival_datetime + INTERVAL '2' HOUR) AS Next_Available_Time
            FROM 
                Flight_Table f
            WHERE 
                NOT EXISTS (
                    SELECT 1
                    FROM Flight_Table f2
                    WHERE f2.Plane_id = f.Plane_id
                    AND f2.Arrival_datetime > f.Arrival_datetime
                )
                AND f.IATA_to = IATA_code
            GROUP BY 
                f.Plane_id;
    BEGIN
        FOR flight IN FlightsCursor LOOP
            found_planes := found_planes + 1;
            DBMS_OUTPUT.PUT_LINE('IATA: ' || IATA_code || 
                                 ', Plane ID: ' || flight.Plane_id || 
                                 ', Last Arrival: ' || TO_CHAR(flight.Last_Arrival, 'YYYY-MM-DD HH24:MI:SS') || 
                                 ', Next Available Time: ' || TO_CHAR(flight.Next_Available_Time, 'YYYY-MM-DD HH24:MI:SS'));
        END LOOP;

        IF found_planes < 1 THEN
            DBMS_OUTPUT.PUT_LINE('No planes found for this IATA: ' || IATA_code);
        END IF;
    END print_available_planes_for_next_flight;

    /******************************************************************************
     *                     5) seat_is_taken
     ******************************************************************************/
    FUNCTION seat_is_taken (
        p_flight_id  IN NUMBER,
        p_seat_label IN VARCHAR2
    ) RETURN BOOLEAN
    IS
        l_rowcol     VARCHAR2(20);
        l_sep        PLS_INTEGER;
        l_row        NUMBER;
        l_col        NUMBER;
        count_taken  NUMBER;
    BEGIN
        l_rowcol := parse_seat_label(p_seat_label);
        l_sep    := INSTR(l_rowcol,'|');
        l_row    := TO_NUMBER(SUBSTR(l_rowcol,1,l_sep-1));
        l_col    := TO_NUMBER(SUBSTR(l_rowcol,l_sep+1));

        SELECT COUNT(*)
          INTO count_taken
          FROM Flight_Table f,
               TABLE(f.List_taken_seats) fls,
               PlaneSeat_Table ps
         WHERE f.Id = p_flight_id
           AND DEREF(fls.COLUMN_VALUE).Id = ps.Id
           AND ps.SeatRow    = l_row
           AND ps.SeatColumn = l_col;

        RETURN (count_taken > 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END seat_is_taken;

    /******************************************************************************
     *              6) caretaker_sits_next_to_child
     ******************************************************************************/
    FUNCTION caretaker_sits_next_to_child (
        p_seat_label_carer  IN VARCHAR2,
        p_seat_label_child  IN VARCHAR2
    ) RETURN BOOLEAN
    IS
        l_c1   VARCHAR2(20);
        l_sep1 PLS_INTEGER;
        r1     NUMBER;  -- row
        c1     NUMBER;  -- col

        l_c2   VARCHAR2(20);
        l_sep2 PLS_INTEGER;
        r2     NUMBER;
        c2     NUMBER;
    BEGIN
        l_c1  := parse_seat_label(p_seat_label_carer);
        l_sep1:= INSTR(l_c1,'|');
        r1    := TO_NUMBER(SUBSTR(l_c1,1,l_sep1-1));
        c1    := TO_NUMBER(SUBSTR(l_c1,l_sep1+1));

        l_c2  := parse_seat_label(p_seat_label_child);
        l_sep2:= INSTR(l_c2,'|');
        r2    := TO_NUMBER(SUBSTR(l_c2,1,l_sep2-1));
        c2    := TO_NUMBER(SUBSTR(l_c2,l_sep2+1));

        RETURN (ABS(r1 - r2) <= 1) AND (ABS(c1 - c2) <= 1);
    END caretaker_sits_next_to_child;

    /******************************************************************************
     * 7) PROCEDURA: assign_seat_for_reservation
     *    - Jedna rezerwacja, jedna etykieta siedzenia
     *    - Wymusza s¹siedztwo z opiekunem, jeœli pasa¿er jest dzieckiem
     ******************************************************************************/
    PROCEDURE assign_seat_for_reservation (
        p_flight_id      IN NUMBER,
        p_reservation_id IN NUMBER,
        p_seat_label     IN VARCHAR2
    )
    IS
        v_flight        Flight;
        v_old_seat_ref  REF PlaneSeat;
        v_seat_ref      REF PlaneSeat;

        l_rowcol  VARCHAR2(10);
        l_sep     PLS_INTEGER;
        l_row     NUMBER;
        l_col     NUMBER;

        v_req_class      REF TravelClass;
        v_seat_class     REF TravelClass;
        v_passenger_id   INT;
        v_carer_id       INT;
        v_carer_seat_ref REF PlaneSeat;
        v_carer_seat_lbl VARCHAR2(20);
    BEGIN
        ----------------------------------------------------------------------------
        -- 1) SprawdŸ, czy lot istnieje
        ----------------------------------------------------------------------------
        BEGIN
            SELECT VALUE(f) INTO v_flight
              FROM Flight_Table f
             WHERE f.Id = p_flight_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20011, 'Lot o ID='||p_flight_id||' nie istnieje.');
        END;

        ----------------------------------------------------------------------------
        -- 2) SprawdŸ, czy rezerwacja istnieje i pobierz dane pasa¿era
        ----------------------------------------------------------------------------
        BEGIN
            SELECT r.Requested_Class,
                   r.Passenger_id
              INTO v_req_class,
                   v_passenger_id
              FROM Reservation_Table r
             WHERE r.Id = p_reservation_id
               AND r.Flight_id = p_flight_id; -- Wa¿ne: rezerwacja musi byæ na ten flight
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'Brak rezerwacji ID='||p_reservation_id||' dla lotu='||p_flight_id);
        END;

        ----------------------------------------------------------------------------
        -- 3) SprawdŸ, czy miejsce jest ju¿ zajête
        ----------------------------------------------------------------------------
        IF seat_is_taken(p_flight_id, p_seat_label) THEN
            RAISE_APPLICATION_ERROR(-20013, 'Miejsce '||p_seat_label||' jest ju¿ zajête w locie='||p_flight_id);
        END IF;

        ----------------------------------------------------------------------------
        -- 4) SprawdŸ, czy klasa wybranego fotela = klasa ¿¹dana w rezerwacji
        ----------------------------------------------------------------------------
        --    Najpierw znajdŸ (row, col) z etykiety
        ----------------------------------------------------------------------------
        l_rowcol := parse_seat_label(p_seat_label);
        l_sep    := INSTR(l_rowcol, '|');
        l_row    := TO_NUMBER(SUBSTR(l_rowcol, 1, l_sep - 1));
        l_col    := TO_NUMBER(SUBSTR(l_rowcol, l_sep + 1));

        BEGIN
            SELECT ps.TravelClassRef
              INTO v_seat_class
              FROM PlaneSeat_Table ps
             WHERE ps.SeatRow    = l_row
               AND ps.SeatColumn = l_col;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20014, 'Nie znaleziono fotela '||p_seat_label||' w PlaneSeat_Table.');
        END;

        IF v_req_class IS NOT NULL AND v_req_class != v_seat_class THEN
            RAISE_APPLICATION_ERROR(-20015, 'Miejsce '||p_seat_label||' nale¿y do innej klasy ni¿ rezerwacja ID='||p_reservation_id);
        END IF;

        ----------------------------------------------------------------------------
        -- 5) SprawdŸ, czy pasa¿er jest dzieckiem i jeœli tak, czy opiekun ma przydzielone miejsce
        ----------------------------------------------------------------------------
        SELECT Carer_id
          INTO v_carer_id
          FROM Passenger_Table
         WHERE Id = v_passenger_id;

        -- Je¿eli mamy Carer_id -> dziecko
        IF v_carer_id IS NOT NULL THEN
            -- Musimy znaleŸæ rezerwacjê opiekuna na TEN SAM lot:
            DECLARE
                v_carer_res_id  NUMBER;
            BEGIN
                SELECT r.Id
                  INTO v_carer_res_id
                  FROM Reservation_Table r
                  WHERE r.Passenger_id = v_carer_id
                    AND r.Flight_id    = p_flight_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(
                        -20016, 
                        'Pasa¿er (ID='||v_passenger_id||') to dziecko, ale opiekun (ID='||v_carer_id||') nie ma rezerwacji na ten lot.'
                    );
            END;

            -- Znajdujemy seat opiekuna
            BEGIN
                SELECT r.Seat
                  INTO v_carer_seat_ref
                  FROM Reservation_Table r
                 WHERE r.Passenger_id = v_carer_id
                   AND r.Flight_id    = p_flight_id
                   AND r.Seat IS NOT NULL;  -- fotel MUSI byæ ju¿ przydzielony
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(
                        -20017,
                        'Dziecko (ID='||v_passenger_id||'): opiekun (ID='||v_carer_id||') nie ma jeszcze przydzielonego miejsca!'
                    );
            END;

            -- Pobierz label fotela opiekuna
            BEGIN
                SELECT (ps.SeatRow || CHR(64 + ps.SeatColumn))
                  INTO v_carer_seat_lbl
                  FROM PlaneSeat_Table ps
                 WHERE REF(ps) = v_carer_seat_ref;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20018,'Nie znaleziono fotela opiekuna w PlaneSeat_Table (b³êdny REF?).');
            END;

            -- SprawdŸ, czy wskazane miejsce jest s¹siednie do opiekuna
            IF NOT caretaker_sits_next_to_child(v_carer_seat_lbl, p_seat_label) THEN
                RAISE_APPLICATION_ERROR(
                    -20019,
                    'Dziecko musi siedzieæ obok opiekuna ('||v_carer_seat_lbl||'), a wybrano '||p_seat_label
                );
            END IF;
        END IF;

        ----------------------------------------------------------------------------
        -- 6) Jeœli wszystko OK, wstawiamy do List_taken_seats i update Reservation.Seat
        ----------------------------------------------------------------------------
        -- 6a) ZnajdŸ REF do fotela
        BEGIN
            SELECT REF(ps)
              INTO v_seat_ref
              FROM PlaneSeat_Table ps
             WHERE ps.SeatRow = l_row
               AND ps.SeatColumn = l_col;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20014, 'Brak fotela w PlaneSeat_Table (REF).');
        END;

        -- 6b) Usuñ ewentualnie stare przypisanie fotela w rezerwacji (jeœli by³o)
        BEGIN
            SELECT r.Seat
              INTO v_old_seat_ref
              FROM Reservation_Table r
             WHERE r.Id = p_reservation_id;
            
            IF v_old_seat_ref IS NOT NULL THEN
                -- Skasuj z List_taken_seats w locie p_flight_id
                DELETE FROM THE(
                    SELECT f.List_taken_seats FROM Flight_Table f WHERE f.Id = p_flight_id
                )
                WHERE COLUMN_VALUE = v_old_seat_ref;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- nie by³o starego siedzenia
        END;

        -- 6c) Dodaj do nested table w Flight_Table
        INSERT INTO THE(
            SELECT f.List_taken_seats
              FROM Flight_Table f
             WHERE f.Id = p_flight_id
        )
        VALUES (v_seat_ref);

        -- 6d) Update rezerwacji
        UPDATE Reservation_Table r
           SET r.Seat = v_seat_ref
         WHERE r.Id   = p_reservation_id;

        DBMS_OUTPUT.PUT_LINE('Zarezerwowano miejsce '||p_seat_label
                             ||' dla rezerwacji='||p_reservation_id
                             ||' w locie='||p_flight_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('B³¹d w assign_seat_for_reservation: ' || SQLERRM);
            RAISE; 
    END assign_seat_for_reservation;

    /******************************************************************************
     * 8) find_adjacent_seats
     ******************************************************************************/
    FUNCTION find_adjacent_seats (
        p_flight_id IN NUMBER,
        p_class_id  IN NUMBER
    ) RETURN SYS.ODCIVARCHAR2LIST
    IS
        v_seats SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
        v_plane_id NUMBER;
    BEGIN
        SELECT Plane_id
          INTO v_plane_id
          FROM Flight_Table
         WHERE Id = p_flight_id;

        FOR seat_pair IN (
            SELECT 
                ps1.SeatRow AS row1, 
                ps1.SeatColumn AS col1,
                ps2.SeatRow AS row2, 
                ps2.SeatColumn AS col2
            FROM PlaneSeat_Table ps1
                 JOIN PlaneSeat_Table ps2
                   ON ps1.SeatRow    = ps2.SeatRow
                  AND ps1.SeatColumn = ps2.SeatColumn - 1
            WHERE ps1.TravelClassRef.Id = p_class_id
              AND ps2.TravelClassRef.Id = p_class_id
              AND ps1.Id NOT IN (
                  SELECT DEREF(fls.COLUMN_VALUE).Id
                    FROM Flight_Table f, TABLE(f.List_taken_seats) fls
                   WHERE f.Id = p_flight_id
              )
              AND ps2.Id NOT IN (
                  SELECT DEREF(fls.COLUMN_VALUE).Id
                    FROM Flight_Table f, TABLE(f.List_taken_seats) fls
                   WHERE f.Id = p_flight_id
              )
            ORDER BY ps1.SeatRow, ps1.SeatColumn
        ) LOOP
            v_seats.EXTEND(2);
            v_seats(v_seats.COUNT - 1) := seat_pair.row1 || CHR(64 + seat_pair.col1);
            v_seats(v_seats.COUNT)     := seat_pair.row2 || CHR(64 + seat_pair.col2);
        END LOOP;

        RETURN v_seats;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('find_adjacent_seats() - B³¹d: '||SQLERRM);
            RETURN SYS.ODCIVARCHAR2LIST();
    END find_adjacent_seats;

    /******************************************************************************
     * 9) show_plane_seats_distribution – podgl¹d miejsc w samolocie (Plane.seat_list)
     ******************************************************************************/
    PROCEDURE show_plane_seats_distribution (
        plane_id NUMBER
    ) IS
        plane_obj  Plane;
        seat_refs  PlaneSeatList;
        seat_ref   REF PlaneSeat;
        seat       PlaneSeat;
        current_row  INT := -1;
        seat_display VARCHAR2(500);
    BEGIN
        SELECT VALUE(p)
          INTO plane_obj
          FROM Plane_Table p
         WHERE p.Id = plane_id;

        seat_refs := plane_obj.seat_list;

        IF seat_refs IS NOT NULL THEN
            FOR i IN 1..seat_refs.COUNT LOOP
                seat_ref := seat_refs(i);

                SELECT DEREF(seat_ref)
                  INTO seat
                  FROM DUAL;

                IF seat.seatRow != current_row THEN
                    IF current_row != -1 THEN
                       DBMS_OUTPUT.PUT_LINE(seat_display);
                    END IF;
                    current_row := seat.seatRow;
                    seat_display := '';
                END IF;

                seat_display := seat_display
                                || seat.seatRow
                                || CHR(64 + seat.seatColumn)
                                || ' ';
            END LOOP;

            IF current_row != -1 THEN
                DBMS_OUTPUT.PUT_LINE(seat_display);
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Brak miejsc w samolocie ID=' || plane_id);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Samolot o ID='||plane_id||' nie istnieje.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('B³¹d w show_plane_seats_distribution: ' || SQLERRM);
    END show_plane_seats_distribution;

END flight_management;
/

