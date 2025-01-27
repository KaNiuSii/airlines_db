CREATE OR REPLACE PACKAGE reservation_management AS
    -- Adds a passenger to the database
    PROCEDURE add_passenger (
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_date_of_birth   IN DATE,
        p_email           IN VARCHAR2,
        p_phone           IN VARCHAR2,
        p_passport_number IN VARCHAR2,
        p_carer_id        IN INT DEFAULT NULL
    );

    -- Adds reservations for a flight
    PROCEDURE add_reservation (
        p_flight_id       IN NUMBER,
        p_passenger_ids   IN SYS.ODCINUMBERLIST,
        p_travel_class_id IN INT
    );

    -- Closes reservations for a flight and assigns random seats
    PROCEDURE close_reservation (
        p_flight_id IN NUMBER
    );

END reservation_management;
/

CREATE OR REPLACE PACKAGE BODY reservation_management AS
    PROCEDURE add_passenger (
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_date_of_birth   IN DATE,
        p_email           IN VARCHAR2,
        p_phone           IN VARCHAR2,
        p_passport_number IN VARCHAR2,
        p_carer_id        IN INT DEFAULT NULL
    ) IS
        v_new_id INT;
    BEGIN
        IF MONTHS_BETWEEN(SYSDATE, p_date_of_birth) / 12 < 12 AND p_carer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Child under 12 must have a carer.');
        END IF;

        SELECT NVL(MAX(Id), 0) + 1 INTO v_new_id FROM Passenger_Table;

        INSERT INTO Passenger_Table (Id, First_name, Last_name, Date_of_birth, Email, Phone, Passport_number, Carer_id)
        VALUES (v_new_id, p_first_name, p_last_name, p_date_of_birth, p_email, p_phone, p_passport_number, p_carer_id);

        DBMS_OUTPUT.PUT_LINE('Passenger added with ID: ' || v_new_id);
    END add_passenger;

    PROCEDURE add_reservation (
        p_flight_id       IN NUMBER,
        p_passenger_ids   IN SYS.ODCINUMBERLIST,
        p_travel_class_id IN INT
    ) IS
        v_reservation_id INT;                      -- For generating reservation IDs
        v_class_ref      REF TravelClass;          -- REF to the TravelClass object
        v_is_child       NUMBER;                  -- To check if a passenger is a child
        v_has_carer      NUMBER;                  -- To check if a child has a carer
        v_total_seats    NUMBER;                   -- Total seats available in the class
        v_taken_seats    NUMBER;                   -- Seats already taken in the class
        v_class_id       NUMBER;                   -- ID of the travel class
    BEGIN
        -- Validate passenger list
        IF p_passenger_ids IS NULL OR p_passenger_ids.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Passenger list cannot be empty.');
        END IF;
        
        v_class_id := p_travel_class_id;  -- Assign the travel class ID
    
        -- Fetch the REF TravelClass based on the ID
        SELECT REF(tc)
        INTO v_class_ref
        FROM TravelClass_Table tc
        WHERE tc.Id = v_class_id;
    
        -- Validate the TravelClass REF
        IF v_class_ref IS NULL THEN
            RAISE_APPLICATION_ERROR(-20005, 'Invalid travel class reference for the flight.');
        END IF;
    
        -- Check total seat availability for the travel class
        SELECT COUNT(*)
        INTO v_total_seats
        FROM PlaneSeat_Table ps
        WHERE ps.TravelClassRef.Id = v_class_id; -- Compare TravelClassRef with ID
    
        -- Check total seats already taken for the flight
        SELECT COUNT(*)
        INTO v_taken_seats
        FROM Reservation_Table r
        WHERE r.Flight_id = p_flight_id
          AND r.Requested_Class.Id = v_class_id; -- Compare Requested_Class REF with ID
    
        -- Ensure enough seats are available
        IF v_total_seats - v_taken_seats < p_passenger_ids.COUNT THEN
            RAISE_APPLICATION_ERROR(-20003, 'Not enough seats available in the selected travel class.');
        END IF;
    
        -- Validate passengers and assign reservations
        FOR i IN 1 .. p_passenger_ids.COUNT LOOP
            -- Check if the passenger is a child
            SELECT CASE
                       WHEN MONTHS_BETWEEN(SYSDATE, Date_of_birth) / 12 < 12 THEN 1
                       ELSE 0
                   END
            INTO v_is_child
            FROM Passenger_Table
            WHERE Id = p_passenger_ids(i); -- Compare Passenger_Table.Id with the current passenger ID
    
            -- Ensure a child has a carer in the list
            IF v_is_child = 1 THEN
                SELECT COUNT(*)
                INTO v_has_carer
                FROM Passenger_Table
                WHERE Id IN (SELECT COLUMN_VALUE FROM TABLE(p_passenger_ids)) -- Ensure ID matches a carer in the list
                  AND Id = (SELECT Carer_id
                            FROM Passenger_Table
                            WHERE Id = p_passenger_ids(i)); -- Match child with their carer ID
    
                IF v_has_carer = 0 THEN
                    RAISE_APPLICATION_ERROR(-20004, 'Child with ID ' || p_passenger_ids(i) || ' must be accompanied by a carer.');
                END IF;
            END IF;
    
            -- Assign a new reservation ID
            SELECT NVL(MAX(Id), 0) + 1
            INTO v_reservation_id
            FROM Reservation_Table;
    
            -- Insert the reservation
            INSERT INTO Reservation_Table (Id, Flight_id, Passenger_id, Requested_Class, Seat)
            VALUES (v_reservation_id, p_flight_id, p_passenger_ids(i), v_class_ref, NULL);
    
            DBMS_OUTPUT.PUT_LINE('Reservation added for Passenger ID: ' || p_passenger_ids(i));
        END LOOP;
    END add_reservation;


    PROCEDURE close_reservation (
      p_flight_id IN NUMBER
  ) IS
      v_reservations   SYS.ODCINUMBERLIST    := SYS.ODCINUMBERLIST();
      v_seats          SYS.ODCIVARCHAR2LIST  := SYS.ODCIVARCHAR2LIST();

      v_plane_id       NUMBER;
      -- Do zbierania info rezerwacji do obs³ugi w pêtli
      CURSOR c_unassigned IS
         SELECT r.Id AS reservation_id,
                DEREF(r.Requested_Class).Id AS class_id
           FROM Reservation_Table r
          WHERE r.Flight_id = p_flight_id
            AND r.Seat IS NULL
          ORDER BY r.Id;  -- np. rosn¹co

      ------------------------------------------------------------------------
      -- Funkcja pomocnicza do zbudowania labela typu '3A'
      ------------------------------------------------------------------------
      FUNCTION build_seat_label(
         p_row IN NUMBER,
         p_col IN NUMBER
      ) RETURN VARCHAR2
      IS
      BEGIN
         RETURN p_row || CHR(64 + p_col);  -- np. row=3, col=1 => '3A'
      END;

  BEGIN
      DBMS_OUTPUT.PUT_LINE('--- close_reservation: auto-assign seats for Flight='||p_flight_id||' ---');

      ------------------------------------------------------------------------
      -- 1) Odczytaj plane_id (który samolot realizuje ten lot)
      ------------------------------------------------------------------------
      SELECT f.Plane_id
        INTO v_plane_id
        FROM Flight_Table f
       WHERE f.Id = p_flight_id;

      ------------------------------------------------------------------------
      -- 2) Pêtla po rezerwacjach (które nie maj¹ jeszcze Seat)
      ------------------------------------------------------------------------
      FOR rec IN c_unassigned LOOP
         -- Dla ka¿dej rezerwacji musimy znaleŸæ *pierwszy wolny seat* w plane'ie
         -- (tak naprawdê kolejnoœæ jest dowolna, mo¿na i "losowo").
         -- Wybieramy najni¿szy seatrow/seatcolumn dostêpny w danej klasie.

         DECLARE
            v_found_seat_label   VARCHAR2(10) := NULL;
            v_temp_row           NUMBER;
            v_temp_col           NUMBER;
         BEGIN
            FOR seat_rec IN (
                SELECT ps.SeatRow     AS seat_row,
                       ps.SeatColumn  AS seat_col
                  FROM PlaneSeat_Table ps
                 WHERE ps.TravelClassRef.Id = rec.class_id
                   AND ps.Id IN (
                       -- Musimy upewniæ siê, ¿e seat nie jest ju¿ w Flight_Table.List_taken_seats
                       -- => skorzystamy z LEFT JOIN lub subselect, ¿eby sprawdziæ wolne
                       SELECT ps2.Id 
                         FROM PlaneSeat_Table ps2
                         WHERE ps2.Id = ps.Id
                           AND ps2.Id NOT IN (
                               SELECT DEREF(fls.COLUMN_VALUE).Id
                                 FROM Flight_Table ft,
                                      TABLE(ft.List_taken_seats) fls
                                WHERE ft.Id = p_flight_id
                           )
                   )
                   -- Mo¿na sortowaæ np. po seatRow, seatColumn rosn¹co:
                 ORDER BY ps.SeatRow, ps.SeatColumn
            ) LOOP
                -- Pierwszy wolny => bierzemy i wychodzimy
                v_found_seat_label := build_seat_label(seat_rec.seat_row, seat_rec.seat_col);
                EXIT;
            END LOOP;

            IF v_found_seat_label IS NULL THEN
               -- Brak wolnych miejsc w odpowiedniej klasie
               DBMS_OUTPUT.PUT_LINE('No more free seats in class '||rec.class_id
                                     ||' for reservation '||rec.reservation_id
                                     ||'. Skipping...');
            ELSE
               -- Dodajemy równolegle do tablic: v_reservations, v_seats
               v_reservations.EXTEND;
               v_reservations(v_reservations.COUNT) := rec.reservation_id;

               v_seats.EXTEND;
               v_seats(v_seats.COUNT) := v_found_seat_label;

               DBMS_OUTPUT.PUT_LINE(' -> Reservation '
                  || rec.reservation_id
                  || ' => seat "'||v_found_seat_label||'"');
            END IF;
         END;
      END LOOP;

      ------------------------------------------------------------------------
      -- 3) Jeœli zebraliœmy jakiekolwiek przydzia³y, wywo³ujemy take_seat_at_flight
      ------------------------------------------------------------------------
      IF v_reservations.COUNT > 0 THEN
         DBMS_OUTPUT.PUT_LINE('--- Calling take_seat_at_flight for all unassigned seats... ---');
         flight_management.take_seat_at_flight(
            p_flight_id        => p_flight_id,
            p_reservation_list => v_reservations,
            p_seat_list        => v_seats
         );
      ELSE
         DBMS_OUTPUT.PUT_LINE('No seats assigned. Either no unassigned reservations or no free seats found.');
      END IF;

      DBMS_OUTPUT.PUT_LINE('--- close_reservation end ---');
  END close_reservation;

END reservation_management;
/
