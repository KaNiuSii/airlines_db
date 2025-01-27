   SET SERVEROUTPUT ON;


CREATE OR REPLACE PACKAGE flight_management AS
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
   PROCEDURE print_available_planes_for_next_flight(IATA_code IN CHAR);
   ----------------------------------------------------------------------------
   -- Types for the grouping function
   ----------------------------------------------------------------------------
   TYPE t_id_tuple IS RECORD (
      reservation_id INT,
      carer_id       INT
   );
   TYPE t_tuple_list IS TABLE OF t_id_tuple;          
   TYPE t_list_of_lists IS TABLE OF t_tuple_list;     

   ----------------------------------------------------------------------------
   -- Existing caretaker grouping function
   ----------------------------------------------------------------------------
   FUNCTION find_reservation_groups (
      p_reservation_list IN SYS.ODCINUMBERLIST
   )
      RETURN t_list_of_lists;
    
    
   ----------------------------------------------------------------------------
   -- Existing seat display procedure
   ----------------------------------------------------------------------------
   PROCEDURE show_plane_seats_distribution (
      plane_id NUMBER
   );

   ----------------------------------------------------------------------------
   -- NEW procedure: actually assign seats to reservations in a flight 
   -- following the 6-step flow
   ----------------------------------------------------------------------------
   PROCEDURE take_seat_at_flight (
      p_flight_id         IN NUMBER,
      p_reservation_list  IN SYS.ODCINUMBERLIST,  -- parallel list of reservation IDs
      p_seat_list         IN SYS.ODCIVARCHAR2LIST -- parallel list of seat labels
   );

   ----------------------------------------------------------------------------
   -- OPTIONAL: We expose helper functions for seat availability + adjacency
   -- You could also keep them private in the BODY if you prefer.
   ----------------------------------------------------------------------------
   FUNCTION seat_is_taken (
      p_flight_id IN NUMBER,
      p_seat_label IN VARCHAR2
   )
      RETURN BOOLEAN;

   FUNCTION caretaker_sits_next_to_child (
      p_seat_label_carer  IN VARCHAR2,
      p_seat_label_child  IN VARCHAR2
   )
      RETURN BOOLEAN;

END flight_management;
/




CREATE OR REPLACE PACKAGE BODY flight_management AS
    ----------------------------------------------------------------------------
    -- Procedura sprawdzaj¹ca, czy lot mo¿e byæ zaplanowany
    ----------------------------------------------------------------------------
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
        -- Domyœlnie ustawiamy FALSE
        p_result := FALSE;

        -- Pobieramy ostatni czas przylotu i wyznaczamy potencjalny czas, od kiedy samolot mo¿e startowaæ
        SELECT 
            MAX(f.Arrival_datetime)               AS Last_Arrival,
            MAX(f.Arrival_datetime + INTERVAL '2' HOUR) AS Next_Available_Time
        INTO 
            last_arrival_time, 
            next_available_time
        FROM Flight_Table f
        WHERE f.Plane_id = p_plane_id;

        -- Sprawdzamy, czy w ogóle znaleziono jakikolwiek lot samolotu (last_arrival_time IS NULL => brak lotów)
        IF last_arrival_time IS NULL THEN
            -- Brak wczeœniejszych lotów — przyjmujemy, ¿e mo¿na zaplanowaæ pierwszy lot
            -- (o ile logika biznesowa na to pozwala; np. zak³adamy, ¿e samolot stoi ju¿ na p_IATA_code)
            p_result := TRUE;

        ELSE
            -- Samolot mia³ ju¿ jakieœ loty, wiêc sprawdzamy, czy obecny wylot jest ? next_available_time
            IF next_available_time <= p_departure_time THEN
                -- Sprawdzamy, czy samolot wyl¹dowa³ rzeczywiœcie na p_IATA_code
                SELECT COUNT(*)
                  INTO flight_count
                  FROM Flight_Table f
                 WHERE f.Plane_id       = p_plane_id
                   AND f.IATA_to        = p_IATA_code
                   AND f.Arrival_datetime = last_arrival_time;

                IF flight_count > 0 THEN
                    -- SprawdŸ dostêpnoœæ obs³ugi technicznej
                    maintenance_start := check_technical_support(
                        p_IATA_code => p_IATA_code,
                        p_time      => last_arrival_time + INTERVAL '2' HOUR,
                        p_flight_id => p_plane_id
                    );

                    IF maintenance_start <= p_departure_time THEN
                        p_result := TRUE;
                    ELSE
                        p_result := FALSE;
                    END IF;
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Na wszelki wypadek w razie innego b³êdu ustawiæ FALSE lub LOG
            p_result := FALSE;
    END can_schedule_flight;

    ----------------------------------------------------------------------------
    -- Funkcja sprawdzaj¹ca dostêpnoœæ obs³ugi technicznej
    ----------------------------------------------------------------------------
    FUNCTION check_technical_support (
        p_IATA_code IN CHAR,
        p_time      IN TIMESTAMP,
        p_flight_id IN NUMBER
    ) RETURN TIMESTAMP IS
        v_shift_start TIMESTAMP;
        v_shift_end   TIMESTAMP;
        v_support_count NUMBER;
        v_next_available TIMESTAMP := p_time;
    BEGIN
        -- Sprawdzamy, ilu cz³onków obs³ugi technicznej jest dostêpnych i nie s¹ ju¿ zajêci przy innych samolotach
        SELECT COUNT(*)
          INTO v_support_count
          FROM TechnicalSupport_Table ts
         WHERE ts.Airport_IATA = p_IATA_code
           AND MOD(EXTRACT(HOUR FROM ts.Shift_start) + 24, 24) <= MOD(EXTRACT(HOUR FROM p_time) + 24, 24)
           AND MOD(EXTRACT(HOUR FROM ts.Shift_end) + 24, 24) > MOD(EXTRACT(HOUR FROM p_time) + 24, 24)
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

        -- Jeœli dostêpnych jest przynajmniej 3 cz³onków obs³ugi, zwracamy czas rozpoczêcia maintenance
        IF v_support_count >= 3 THEN
            RETURN p_time;
        ELSE
            -- Znajdujemy najbli¿szy czas, kiedy bêdzie dostêpna obs³uga techniczna
            SELECT MIN(ts.Shift_start)
              INTO v_shift_start
              FROM TechnicalSupport_Table ts
             WHERE ts.Airport_IATA = p_IATA_code;

            RETURN GREATEST(p_time, v_shift_start);
        END IF;
    END check_technical_support;

    ----------------------------------------------------------------------------
    -- Procedura tworz¹ca nowy lot
    ----------------------------------------------------------------------------
    PROCEDURE create_new_flight(
       p_plane_id        IN NUMBER,
       p_departure_time  IN TIMESTAMP,
       p_arrival_time    IN TIMESTAMP,
       p_IATA_from       IN CHAR,
       p_IATA_to         IN CHAR
   ) IS
       can_schedule BOOLEAN;
       v_new_flight_id NUMBER;
       V_CREW_COUNT NUMBER;
       v_technical_support SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
   BEGIN
       can_schedule_flight(
           p_IATA_code      => p_IATA_from,
           p_plane_id       => p_plane_id,
           p_departure_time => p_departure_time,
           p_result         => can_schedule
       );

       IF can_schedule THEN
           SELECT NVL(MAX(Id),0)+1 INTO v_new_flight_id FROM Flight_Table;
           
           -- Pobierz dostêpnych cz³onków obs³ugi technicznej
           SELECT ts.Id BULK COLLECT INTO v_technical_support
           FROM TechnicalSupport_Table ts
           WHERE ts.Airport_IATA = p_IATA_from
             AND MOD(EXTRACT(HOUR FROM ts.Shift_start) + 24, 24) <= MOD(EXTRACT(HOUR FROM p_departure_time - INTERVAL '2' HOUR) + 24, 24)
             AND MOD(EXTRACT(HOUR FROM ts.Shift_end) + 24, 24) > MOD(EXTRACT(HOUR FROM p_departure_time - INTERVAL '2' HOUR) + 24, 24)
             AND ROWNUM <= 3; -- Wybierz trzech cz³onków

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
           DBMS_OUTPUT.PUT_LINE('Flight created: ID='||v_new_flight_id);

           -- Tutaj przydzielamy za³ogê
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

       ELSE
           DBMS_OUTPUT.PUT_LINE('Flight cannot be scheduled due to constraints.');
       END IF;
   END create_new_flight;



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
            ) -- Ensure this is the last flight for the plane
            AND f.IATA_to = IATA_code -- Match only the queried airport
        GROUP BY 
            f.Plane_id;
    BEGIN
        -- Iterate through the results
        FOR flight IN FlightsCursor LOOP
            found_planes := found_planes + 1;
            DBMS_OUTPUT.PUT_LINE('IATA: ' || IATA_code || ' Plane ID: ' || flight.Plane_id || 
                                 ', Last Arrival: ' || TO_CHAR(flight.Last_Arrival, 'YYYY-MM-DD HH24:MI:SS') || 
                                 ', Next Available Time: ' || TO_CHAR(flight.Next_Available_Time, 'YYYY-MM-DD HH24:MI:SS'));
        END LOOP;

        -- Handle case when no planes match
        IF found_planes < 1 THEN
            DBMS_OUTPUT.PUT_LINE('No planes found for this IATA: ' || IATA_code);
        END IF;
    END print_available_planes_for_next_flight;


    
   FUNCTION find_reservation_groups (
      p_reservation_list IN SYS.ODCINUMBERLIST
   )
      RETURN t_list_of_lists
   IS
      temp_tuple    t_id_tuple;
      current_list  t_tuple_list;
      merged_something BOOLEAN := TRUE;

      -- This is our top-level "list of groups"
      reservation_relationships t_list_of_lists := t_list_of_lists();

      ----------------------------------------------------------------------------
      -- A small local procedure to merge two lists
      ----------------------------------------------------------------------------
      PROCEDURE merge_two_lists(
         io_list1 IN OUT t_tuple_list,
         io_list2 IN OUT t_tuple_list
      ) IS
      BEGIN
         IF io_list2.COUNT > 0 THEN
            FOR i IN 1 .. io_list2.COUNT LOOP
               io_list1.EXTEND;
               io_list1(io_list1.COUNT) := io_list2(i);
            END LOOP;
            io_list2.DELETE;  -- Empty out list2
         END IF;
      END merge_two_lists;

   BEGIN
      ----------------------------------------------------------------------------
      -- Step 1: Build a sub-list for each reservation in p_reservation_list
      ----------------------------------------------------------------------------
      IF p_reservation_list IS NULL OR p_reservation_list.COUNT = 0 THEN
         -- No input IDs => return empty
         RETURN reservation_relationships;
      END IF;

      FOR i IN 1 .. p_reservation_list.COUNT LOOP
         current_list := t_tuple_list();

         FOR rec IN (
            SELECT rt.Id        AS reservation_id,
                   pt.Carer_id  AS carer_id
              FROM Reservation_Table rt
              LEFT JOIN Passenger_Table pt
                     ON rt.Passenger_id = pt.Id
             WHERE rt.Id = p_reservation_list(i)
         ) LOOP
            temp_tuple.reservation_id := rec.reservation_id;
            temp_tuple.carer_id       := rec.carer_id;
            current_list.EXTEND;
            current_list(current_list.COUNT) := temp_tuple;
         END LOOP;

         reservation_relationships.EXTEND;
         reservation_relationships(reservation_relationships.COUNT) := current_list;
      END LOOP;

      ----------------------------------------------------------------------------
      -- Step 2: Repeatedly merge any two sub-lists if they share a caretaker link
      ----------------------------------------------------------------------------
      WHILE merged_something LOOP
         merged_something := FALSE;

         FOR i IN 1 .. reservation_relationships.COUNT - 1 LOOP
            IF reservation_relationships(i).COUNT = 0 THEN
               CONTINUE;
            END IF;

            FOR j IN i+1 .. reservation_relationships.COUNT LOOP
               IF reservation_relationships(j).COUNT = 0 THEN
                  CONTINUE;
               END IF;

               DECLARE
                  found_match BOOLEAN := FALSE;
               BEGIN
                  -- Check if group i and group j share a caretaker link
                  FOR k IN 1 .. reservation_relationships(i).COUNT LOOP
                     FOR l IN 1 .. reservation_relationships(j).COUNT LOOP
                        IF    reservation_relationships(i)(k).carer_id
                              = reservation_relationships(j)(l).reservation_id
                           OR reservation_relationships(j)(l).carer_id
                              = reservation_relationships(i)(k).reservation_id
                        THEN
                           found_match := TRUE;
                           EXIT;  -- exit the l-loop
                        END IF;
                     END LOOP;
                     EXIT WHEN found_match;  -- exit the k-loop
                  END LOOP;

                  IF found_match THEN
                     merge_two_lists(
                        io_list1 => reservation_relationships(i),
                        io_list2 => reservation_relationships(j)
                     );
                     merged_something := TRUE;
                  END IF;
               END;
            END LOOP;  -- j
         END LOOP;      -- i
      END LOOP;          -- while

      ----------------------------------------------------------------------------
      -- Step 3: De-duplicate within each group
      --         (keep exactly one row per reservation_id, prefer non-null carer)
      ----------------------------------------------------------------------------
      FOR i IN 1 .. reservation_relationships.COUNT LOOP
         IF reservation_relationships(i).COUNT < 2 THEN
            CONTINUE;  -- no duplicates if 0 or 1 item
         END IF;

         DECLARE
            new_list t_tuple_list := t_tuple_list();

            TYPE map_t IS TABLE OF t_id_tuple INDEX BY PLS_INTEGER;
            best_map map_t;
         BEGIN
            -- pick "best" record for each reservation_id
            FOR k IN 1 .. reservation_relationships(i).COUNT LOOP
               DECLARE
                  r_id INT := reservation_relationships(i)(k).reservation_id;
                  c_id INT := reservation_relationships(i)(k).carer_id;
               BEGIN
                  IF NOT best_map.EXISTS(r_id) THEN
                     best_map(r_id) := reservation_relationships(i)(k);
                  ELSE
                     -- prefer the one with non-null carer_id
                     IF best_map(r_id).carer_id IS NULL
                        AND c_id IS NOT NULL
                     THEN
                        best_map(r_id) := reservation_relationships(i)(k);
                     END IF;
                  END IF;
               END;
            END LOOP;

            -- rebuild sub-list from best_map
            FOR r_id IN best_map.FIRST .. best_map.LAST LOOP
               IF best_map.EXISTS(r_id) THEN
                  new_list.EXTEND;
                  new_list(new_list.COUNT) := best_map(r_id);
               END IF;
            END LOOP;

            reservation_relationships(i) := new_list;
         END;
      END LOOP;

      ----------------------------------------------------------------------------
      -- Step 4: Sort the groups so multi-reservation groups come first
      ----------------------------------------------------------------------------
      DECLARE
         tmp_list t_tuple_list;
      BEGIN
         FOR i IN 1 .. reservation_relationships.COUNT - 1 LOOP
            FOR j IN i+1 .. reservation_relationships.COUNT LOOP
               IF reservation_relationships(i).COUNT < reservation_relationships(j).COUNT THEN
                  tmp_list := reservation_relationships(i);
                  reservation_relationships(i) := reservation_relationships(j);
                  reservation_relationships(j) := tmp_list;
               END IF;
            END LOOP;
         END LOOP;
      END;

      ----------------------------------------------------------------------------
      -- Step 5: Return the final nested collection
      ----------------------------------------------------------------------------
      RETURN reservation_relationships;

   EXCEPTION
      WHEN OTHERS THEN
         -- In a real scenario, you might raise or log the error differently
         DBMS_OUTPUT.PUT_LINE('find_reservation_groups() - Error: ' || SQLERRM);
         RETURN t_list_of_lists();  -- return empty on error
   END find_reservation_groups;


   PROCEDURE show_plane_seats_distribution (
      plane_id NUMBER
   ) IS
      plane_obj    Plane;         -- Variable to hold the Plane object
      seat_refs    PlaneSeatList; -- Nested table of REF PlaneSeat
      seat_ref     REF PlaneSeat; -- REF variable for PlaneSeat
      seat         PlaneSeat;     -- Variable to hold the dereferenced PlaneSeat
      current_row  INT := -1;     -- Keeps track of the current row
      seat_display VARCHAR2(500); -- To build the seat display for a row
   BEGIN
      -- Retrieve the Plane object by ID
      SELECT VALUE(p)
        INTO plane_obj
        FROM Plane_Table p
       WHERE p.Id = plane_id;

      -- Assign the nested table of seat references
      seat_refs := plane_obj.seat_list;

      -- Loop through the nested table
      IF seat_refs IS NOT NULL THEN
         FOR i IN 1..seat_refs.COUNT LOOP
            seat_ref := seat_refs(i);

            -- Dereference the seat
            SELECT DEREF(seat_ref)
              INTO seat
              FROM DUAL;

            -- Check if we are on a new row
            IF seat.seatRow != current_row THEN
               -- Print the previous row (if exists) and reset for new row
               IF current_row != -1 THEN
                  DBMS_OUTPUT.PUT_LINE(seat_display);
               END IF;

               current_row := seat.seatRow;
               seat_display := '';
            END IF;

            -- Append the seat (e.g., 1A) to the current row display
            seat_display := seat_display
                            || seat.seatRow
                            || CHR(64 + seat.seatColumn)
                            || ' ';
         END LOOP;

         -- Print the final row
         IF current_row != -1 THEN
            DBMS_OUTPUT.PUT_LINE(seat_display);
         END IF;
      ELSE
         DBMS_OUTPUT.PUT_LINE('No seats found for Plane ID ' || plane_id);
      END IF;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         DBMS_OUTPUT.PUT_LINE('No plane found with ID ' || plane_id);
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
   END show_plane_seats_distribution;
    
   ----------------------------------------------------------------------------
   --    Convert e.g. "2A" => (row=2, col=1)
   ----------------------------------------------------------------------------
   FUNCTION parse_seat_label (
      seat_label IN VARCHAR2
   )
      RETURN VARCHAR2 
   IS
      -- We'll return "row|col" as a string for simplicity: e.g. "2|1"
      -- Adjust if your seat labels differ in format
      l_num   VARCHAR2(5);
      l_alpha VARCHAR2(5);
      l_row   NUMBER;
      l_col   NUMBER;
   BEGIN
      -- For seat_label like "12B" => row=12, col='B' => 2
      -- Using REGEXP to separate digits vs trailing letters
      l_num   := REGEXP_SUBSTR(seat_label, '^\d+');   -- leading digits
      l_alpha := REGEXP_SUBSTR(seat_label, '[A-Z]+$'); -- trailing letters

      IF l_num IS NULL OR l_alpha IS NULL THEN
         RAISE_APPLICATION_ERROR(-20001, 'Invalid seat label: ' || seat_label);
      END IF;

      l_row := TO_NUMBER(l_num);
      l_col := ASCII(l_alpha) - ASCII('A') + 1;

      RETURN l_row || '|' || l_col;
   END parse_seat_label;

   FUNCTION seat_is_taken (
      p_flight_id  IN NUMBER,
      p_seat_label IN VARCHAR2
   )
      RETURN BOOLEAN
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

      -- We'll assume we can find the seat in PlaneSeat_Table by row/col
      -- Then we check if it's in flight's List_taken_seats
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
         -- Means flight or seat not found => obviously it's not "taken" in that flight
         RETURN FALSE;
   END seat_is_taken;

   ----------------------------------------------------------------------------
   -- 4) HELPER: caretaker_sits_next_to_child
   --    Check if 2 seat labels are "next to each other." 
   --    Here we define "next to" as same row + columns differ by 1.
   ----------------------------------------------------------------------------
   FUNCTION caretaker_sits_next_to_child (
      p_seat_label_carer  IN VARCHAR2,
      p_seat_label_child  IN VARCHAR2
   )
      RETURN BOOLEAN
   IS
      l_c1   VARCHAR2(20);
      l_sep1 PLS_INTEGER;
      r1     NUMBER;  -- row of caretaker
      c1     NUMBER;  -- col of caretaker

      l_c2   VARCHAR2(20);
      l_sep2 PLS_INTEGER;
      r2     NUMBER;  -- row of child
      c2     NUMBER;  -- col of child
   BEGIN
      l_c1  := parse_seat_label(p_seat_label_carer);
      l_sep1:= INSTR(l_c1,'|');
      r1    := TO_NUMBER(SUBSTR(l_c1,1,l_sep1-1));
      c1    := TO_NUMBER(SUBSTR(l_c1,l_sep1+1));

      l_c2  := parse_seat_label(p_seat_label_child);
      l_sep2:= INSTR(l_c2,'|');
      r2    := TO_NUMBER(SUBSTR(l_c2,1,l_sep2-1));
      c2    := TO_NUMBER(SUBSTR(l_c2,l_sep2+1));

      -- "next to each other" = same column, rows differ by 1
      RETURN (c1 = c2) AND (ABS(r1 - r2) = 1);
   END caretaker_sits_next_to_child;

   ----------------------------------------------------------------------------
   -- 5) The main procedure: take_seat_at_flight 
   ----------------------------------------------------------------------------
   PROCEDURE take_seat_at_flight (
      p_flight_id         IN NUMBER,
      p_reservation_list  IN SYS.ODCINUMBERLIST,
      p_seat_list         IN SYS.ODCIVARCHAR2LIST
   )
   IS
      ----------------------------------------------------------------------------
      -- We'll store the desired seat for each reservation in a local RECORD
      ----------------------------------------------------------------------------
      TYPE seat_request_rec IS RECORD (
         reservation_id INT,
         seat_label     VARCHAR2(50)
      );
      TYPE seat_request_tab IS TABLE OF seat_request_rec;
      v_requests seat_request_tab := seat_request_tab();

      ----------------------------------------------------------------------------
      -- We'll need flight & plane objects if we actually do the final assignment
      ----------------------------------------------------------------------------
      v_flight Flight;
      v_plane  Plane;

      ----------------------------------------------------------------------------
      -- caretaker grouping result
      ----------------------------------------------------------------------------
      v_groups t_list_of_lists;
      
      l_rowcol  VARCHAR2(10);
      l_sep     VARCHAR2(10);
      l_row     NUMBER;
      l_col     NUMBER;
      v_requested_class REF TravelClass;
      v_seat_class REF TravelClass;
   BEGIN
      ----------------------------------------------------------------------------
      -- Step 1) Check list lengths & no duplicates
      ----------------------------------------------------------------------------
      IF p_reservation_list IS NULL OR p_seat_list IS NULL THEN
         DBMS_OUTPUT.PUT_LINE('One of the input lists is NULL. Aborting.');
         RETURN;
      END IF;

      IF p_reservation_list.COUNT <> p_seat_list.COUNT THEN
         DBMS_OUTPUT.PUT_LINE('Mismatch in number of reservation IDs vs seat labels. Aborting.');
         RETURN;
      END IF;

      -- Check for duplicates in each list
      DECLARE
         l_res_set   SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
         l_seat_set  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
      BEGIN
         FOR i IN 1..p_reservation_list.COUNT LOOP
            -- if p_reservation_list(i) is already in l_res_set => duplicate
            IF l_res_set.exists(p_reservation_list(i)) THEN
               DBMS_OUTPUT.PUT_LINE('Duplicate reservation ID ' || p_reservation_list(i));
               RETURN;
            END IF;
            -- Using .EXTEND can be tricky for ODCINUMBERLIST. We'll track them in a map or something simpler:
            l_res_set.EXTEND;
            l_res_set(l_res_set.COUNT) := p_reservation_list(i);

            -- seat labels: we can do a simple linear search if seat_list is small 
            FOR j IN 1..l_seat_set.COUNT LOOP
               IF l_seat_set(j) = p_seat_list(i) THEN
                  DBMS_OUTPUT.PUT_LINE('Duplicate seat label ' || p_seat_list(i));
                  RETURN;
               END IF;
            END LOOP;
            l_seat_set.EXTEND;
            l_seat_set(l_seat_set.COUNT) := p_seat_list(i);
         END LOOP;
      END;

      ----------------------------------------------------------------------------
      -- Step 2) Check if the seats are already taken
      ----------------------------------------------------------------------------
      FOR i IN 1..p_seat_list.COUNT LOOP
         IF seat_is_taken(p_flight_id, p_seat_list(i)) THEN
            DBMS_OUTPUT.PUT_LINE('Seat '||p_seat_list(i)||' is already taken in flight '||p_flight_id||'. Aborting.');
            RETURN;
         END IF;
      END LOOP;

      ----------------------------------------------------------------------------
      -- Step 3) Remember the seat each reservation wants
      ----------------------------------------------------------------------------
      FOR i IN 1..p_reservation_list.COUNT LOOP
         v_requests.EXTEND;
         v_requests(v_requests.COUNT).reservation_id := p_reservation_list(i);
         v_requests(v_requests.COUNT).seat_label     := p_seat_list(i);
      END LOOP;
      ----------------------------------------------------------------------------
    -- Step 3b) Validate travel class for each reservation
    ----------------------------------------------------------------------------
        FOR i IN 1..p_reservation_list.COUNT LOOP
            -- Fetch the requested travel class for the reservation
            SELECT Requested_Class
            INTO v_requested_class
            FROM Reservation_Table
            WHERE Id = p_reservation_list(i);
    
            -- Parse seat row and column from label
            l_rowcol := parse_seat_label(p_seat_list(i));
            l_sep    := INSTR(l_rowcol, '|');
            l_row    := TO_NUMBER(SUBSTR(l_rowcol, 1, l_sep - 1));
            l_col    := TO_NUMBER(SUBSTR(l_rowcol, l_sep + 1));
    
            -- Fetch the travel class of the selected seat
            SELECT TravelClassRef
            INTO v_seat_class
            FROM PlaneSeat_Table ps
            WHERE ps.SeatRow = l_row AND ps.SeatColumn = l_col;
    
            -- Validate travel class
            IF v_requested_class != v_seat_class THEN
                DBMS_OUTPUT.PUT_LINE('Seat ' || p_seat_list(i) || ' does not match the requested travel class for reservation ' || p_reservation_list(i) || '. Aborting.');
                RETURN;
            END IF;
        END LOOP;
        
      ----------------------------------------------------------------------------
      -- Step 4) Invoke caretaker grouping
      ----------------------------------------------------------------------------
      v_groups := find_reservation_groups(p_reservation_list);

      ----------------------------------------------------------------------------
      -- Step 5) Check if caretaker wants to sit next to the carried passenger
      --         We'll loop through each group. If we find a caretaker-child pair,
      --         we see if they chose adjacent seats.
      ----------------------------------------------------------------------------
      FOR grp_idx IN 1..v_groups.COUNT LOOP
         IF v_groups(grp_idx).COUNT < 2 THEN
            CONTINUE;  -- no caretaker-child pairs in a single-person group
         END IF;

         -- For each pair in the group, check caretaker and child
         FOR i IN 1..v_groups(grp_idx).COUNT LOOP
            FOR j IN i+1..v_groups(grp_idx).COUNT LOOP
               IF v_groups(grp_idx)(i).carer_id = v_groups(grp_idx)(j).reservation_id THEN
                  -- we have a caretaker-child relationship
                  DECLARE
                     l_carer_label  VARCHAR2(50) := '[not found]';
                     l_child_label  VARCHAR2(50) := '[not found]';
                  BEGIN
                     -- find seat labels in v_requests
                     FOR r IN 1..v_requests.COUNT LOOP
                        IF v_requests(r).reservation_id = v_groups(grp_idx)(i).reservation_id THEN
                           -- caretaker seat
                           l_carer_label := v_requests(r).seat_label;
                        ELSIF v_requests(r).reservation_id = v_groups(grp_idx)(j).reservation_id THEN
                           -- child seat
                           l_child_label := v_requests(r).seat_label;
                        END IF;
                     END LOOP;

                     IF NOT caretaker_sits_next_to_child(l_carer_label, l_child_label) THEN
                        DBMS_OUTPUT.PUT_LINE('Caretaker of reservation '
                           || v_groups(grp_idx)(j).reservation_id
                           || ' wanted seats next to them, but seat "'
                           || l_carer_label || '" not next to "'
                           || l_child_label || '". Aborting.');
                        RETURN;
                     END IF;
                  END;
               ELSIF v_groups(grp_idx)(j).carer_id = v_groups(grp_idx)(i).reservation_id THEN
                  -- caretaker-child in the other direction
                  DECLARE
                     l_carer_label  VARCHAR2(50) := '[not found]';
                     l_child_label  VARCHAR2(50) := '[not found]';
                  BEGIN
                     FOR r IN 1..v_requests.COUNT LOOP
                        IF v_requests(r).reservation_id = v_groups(grp_idx)(j).reservation_id THEN
                           l_carer_label := v_requests(r).seat_label;
                        ELSIF v_requests(r).reservation_id = v_groups(grp_idx)(i).reservation_id THEN
                           l_child_label := v_requests(r).seat_label;
                        END IF;
                     END LOOP;

                     IF NOT caretaker_sits_next_to_child(l_carer_label, l_child_label) THEN
                        DBMS_OUTPUT.PUT_LINE('Caretaker of reservation '
                           || v_groups(grp_idx)(i).reservation_id
                           || ' wanted seats next to them, but seat "'
                           || l_carer_label || '" not next to "'
                           || l_child_label || '". Aborting.');
                        RETURN;
                     END IF;
                  END;
               END IF;
            END LOOP;
         END LOOP;
      END LOOP;

      ----------------------------------------------------------------------------
      -- Step 6) Perform taking seats (the actual assignment)
      ----------------------------------------------------------------------------
      DBMS_OUTPUT.PUT_LINE('All checks passed. Proceeding to assign seats...');

      ----------------------------------------------------------------------------
      -- 6a) Fetch flight object, plane object (to do the final seat referencing)
      ----------------------------------------------------------------------------
      BEGIN
         SELECT VALUE(f) INTO v_flight
           FROM Flight_Table f
          WHERE f.Id = p_flight_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Flight '||p_flight_id||' not found. Aborting.');
            RETURN;
      END;

      BEGIN
         SELECT VALUE(p) INTO v_plane
           FROM Plane_Table p
          WHERE p.Id = v_flight.Plane_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Plane '||v_flight.Plane_id||' not found. Aborting.');
            RETURN;
      END;

      ----------------------------------------------------------------------------
      -- 6b) For each (reservation, seat_label) => find the seat REF => 
      --     Insert into flight's nested table => Update Reservation.Seat
      ----------------------------------------------------------------------------
      DECLARE
         v_seat_ref REF PlaneSeat;
         l_rowcol   VARCHAR2(20);
         l_sep      PLS_INTEGER;
         l_row      NUMBER;
         l_col      NUMBER;
      BEGIN
         FOR i IN 1..v_requests.COUNT LOOP
            l_rowcol := parse_seat_label(v_requests(i).seat_label);
            l_sep    := INSTR(l_rowcol,'|');
            l_row    := TO_NUMBER(SUBSTR(l_rowcol,1,l_sep-1));
            l_col    := TO_NUMBER(SUBSTR(l_rowcol,l_sep+1));

            BEGIN
               SELECT REF(ps)
                 INTO v_seat_ref
                 FROM PlaneSeat_Table ps
                WHERE ps.SeatRow    = l_row
                  AND ps.SeatColumn = l_col;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  DBMS_OUTPUT.PUT_LINE('No seat in PlaneSeat_Table for label '
                     || v_requests(i).seat_label || '. Skipping assignment.');
                  CONTINUE;
            END;

            -- Insert into flight's nested table
            INSERT INTO THE (
               SELECT f.List_taken_seats
                 FROM Flight_Table f
                WHERE f.Id = p_flight_id
            )
            VALUES (v_seat_ref);

            -- Update the reservation's seat
            UPDATE Reservation_Table r
               SET r.Seat = v_seat_ref
             WHERE r.Id   = v_requests(i).reservation_id;

            DBMS_OUTPUT.PUT_LINE('Assigned seat '||v_requests(i).seat_label
               ||' to reservation '||v_requests(i).reservation_id);
         END LOOP;

         DBMS_OUTPUT.PUT_LINE('Seat assignment for flight '||p_flight_id||' completed successfully.');
      END;

   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error in take_seat_at_flight: ' || SQLERRM);
   END take_seat_at_flight;
END flight_management;
/
