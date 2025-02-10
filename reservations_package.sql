CREATE OR REPLACE PACKAGE reservation_management AS

   ----------------------------------------------------------------------------
   -- 1) Dodanie pasa¿era
   ----------------------------------------------------------------------------
   PROCEDURE add_passenger (
       p_first_name      IN VARCHAR2,
       p_last_name       IN VARCHAR2,
       p_date_of_birth   IN DATE,
       p_email           IN VARCHAR2,
       p_phone           IN VARCHAR2,
       p_passport_number IN VARCHAR2,
       p_carer_id        IN INT DEFAULT NULL
   );

   ----------------------------------------------------------------------------
   -- 2) Dodanie rezerwacji (dla wielu pasa¿erów na ten sam flight+class)
   ----------------------------------------------------------------------------
   PROCEDURE add_reservation (
       p_flight_id       IN NUMBER,
       p_passenger_ids   IN SYS.ODCINUMBERLIST,
       p_travel_class_id IN INT
   );

   ----------------------------------------------------------------------------
   -- 3) Zamkniêcie rezerwacji (assign seats):
   --    - ka¿dy bez miejsca dostaje losowe miejsce
   --    - dziecko (carer_id != null) musi siedzieæ obok opiekuna
   ----------------------------------------------------------------------------
   PROCEDURE close_reservation (
       p_flight_id IN NUMBER
   );

END reservation_management;
/

CREATE OR REPLACE PACKAGE BODY reservation_management AS

    ----------------------------------------------------------------------------
    --                 PROCEDURA: add_passenger
    ----------------------------------------------------------------------------
    PROCEDURE add_passenger (
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_date_of_birth   IN DATE,
        p_email           IN VARCHAR2,
        p_phone           IN VARCHAR2,
        p_passport_number IN VARCHAR2,
        p_carer_id        IN INT DEFAULT NULL
    ) 
    IS
        v_new_id INT;
    BEGIN
        -- Walidacja: jeœli <12 lat, musi mieæ carer_id
        IF MONTHS_BETWEEN(SYSDATE, p_date_of_birth) / 12 < 12 
           AND p_carer_id IS NULL 
        THEN
            RAISE_APPLICATION_ERROR(-20001, 'Child under 12 must have a carer.');
        END IF;

        -- Generujemy nowe ID
        SELECT NVL(MAX(Id), 0) + 1 
          INTO v_new_id
          FROM Passenger_Table;

        INSERT INTO Passenger_Table (
            Id, 
            First_name, 
            Last_name, 
            Date_of_birth, 
            Email, 
            Phone, 
            Passport_number, 
            Carer_id
        ) VALUES (
            v_new_id, 
            p_first_name, 
            p_last_name, 
            p_date_of_birth, 
            p_email, 
            p_phone, 
            p_passport_number, 
            p_carer_id
        );

        DBMS_OUTPUT.PUT_LINE('Passenger added with ID: ' || v_new_id);
    END add_passenger;

    ----------------------------------------------------------------------------
    --                 PROCEDURA: add_reservation
    ----------------------------------------------------------------------------
    PROCEDURE add_reservation (
        p_flight_id       IN NUMBER,
        p_passenger_ids   IN SYS.ODCINUMBERLIST,
        p_travel_class_id IN INT
    ) 
    IS
        v_reservation_id  INT;
        v_class_ref       REF TravelClass;
        v_class_id        NUMBER := p_travel_class_id;

        v_total_seats     NUMBER;
        v_taken_seats     NUMBER;
        v_is_child        NUMBER;
        v_has_carer       NUMBER;
    BEGIN
        -- Walidacja listy pasa¿erów
        IF p_passenger_ids IS NULL OR p_passenger_ids.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Passenger list cannot be empty.');
        END IF;

        -- Pobierz REF do TravelClass (na podstawie ID)
        SELECT REF(tc)
          INTO v_class_ref
          FROM TravelClass_Table tc
         WHERE tc.Id = v_class_id;

        IF v_class_ref IS NULL THEN
            RAISE_APPLICATION_ERROR(-20005, 'Invalid travel class reference for the flight.');
        END IF;

        -- Liczba wszystkich miejsc w tej klasie
        SELECT COUNT(*)
          INTO v_total_seats
          FROM PlaneSeat_Table ps
         WHERE ps.TravelClassRef.Id = v_class_id;

        -- Liczba miejsc ju¿ zarezerwowanych w tej klasie dla danego lotu
        SELECT COUNT(*)
          INTO v_taken_seats
          FROM Reservation_Table r
         WHERE r.Flight_id = p_flight_id
           AND r.Requested_Class.Id = v_class_id;

        -- Czy mamy wystarczaj¹c¹ liczbê wolnych miejsc w danej klasie
        IF (v_total_seats - v_taken_seats) < p_passenger_ids.COUNT THEN
            RAISE_APPLICATION_ERROR(-20003, 'Not enough seats available in the selected travel class.');
        END IF;

        -- Dodaj rezerwacje
        FOR i IN 1 .. p_passenger_ids.COUNT LOOP
            -- SprawdŸ, czy pasa¿er jest dzieckiem
            SELECT CASE 
                     WHEN MONTHS_BETWEEN(SYSDATE, Date_of_birth)/12 < 12 THEN 1 
                     ELSE 0 
                   END
              INTO v_is_child
              FROM Passenger_Table
             WHERE Id = p_passenger_ids(i);

            -- Jeœli dziecko -> sprawdŸ, czy carer jest w p_passenger_ids
            IF v_is_child = 1 THEN
                SELECT COUNT(*)
                  INTO v_has_carer
                  FROM Passenger_Table
                 WHERE Id IN (SELECT COLUMN_VALUE FROM TABLE(p_passenger_ids))
                   AND Id = (SELECT Carer_id
                              FROM Passenger_Table
                             WHERE Id = p_passenger_ids(i));
                IF v_has_carer = 0 THEN
                    RAISE_APPLICATION_ERROR(
                        -20004,
                        'Child with ID ' || p_passenger_ids(i) || ' must be accompanied by a carer.'
                    );
                END IF;
            END IF;

            -- Wygeneruj ID rezerwacji
            SELECT NVL(MAX(Id), 0) + 1
              INTO v_reservation_id
              FROM Reservation_Table;

            -- Wstaw rezerwacjê (Seat = NULL)
            INSERT INTO Reservation_Table (
                Id, 
                Flight_id, 
                Passenger_id, 
                Requested_Class, 
                Seat
            ) VALUES (
                v_reservation_id,
                p_flight_id,
                p_passenger_ids(i),
                v_class_ref,
                NULL
            );

            DBMS_OUTPUT.PUT_LINE('Reservation added for Passenger ID: ' || p_passenger_ids(i));
        END LOOP;
    END add_reservation;

    ----------------------------------------------------------------------------
    --                 PROCEDURA: close_reservation
    ----------------------------------------------------------------------------
    PROCEDURE close_reservation (
        p_flight_id IN NUMBER
    ) 
    IS
        ----------------------------------------------------------------------------
        -- Lokalne typy i zmienne
        ----------------------------------------------------------------------------
        CURSOR c_unassigned IS
            SELECT r.Id AS reservation_id,
                   r.Passenger_id,
                   DEREF(r.Requested_Class).Id AS class_id
              FROM Reservation_Table r
             WHERE r.Flight_id = p_flight_id
               AND r.Seat IS NULL
             ORDER BY r.Id;  -- mo¿na losowo, ale robimy rosn¹co

        TYPE t_unassigned IS RECORD (
            reservation_id NUMBER,
            passenger_id   NUMBER,
            class_id       NUMBER
        );

        v_row    t_unassigned;
        v_plane_id NUMBER;

        ----------------------------------------------------------------------------
        -- Funkcja pomocnicza do "losowego" wolnego miejsca w danej klasie
        ----------------------------------------------------------------------------
        FUNCTION get_random_seat(
            p_flight_id  IN NUMBER,
            p_class_id   IN NUMBER
        ) RETURN VARCHAR2
        IS
            v_seat_label  VARCHAR2(10);
        BEGIN
            SELECT (ps.SeatRow || CHR(64 + ps.SeatColumn))  -- np. '12B'
              INTO v_seat_label
              FROM PlaneSeat_Table ps
             WHERE ps.TravelClassRef.Id = p_class_id
               AND ps.Id NOT IN (
                   SELECT DEREF(fls.COLUMN_VALUE).Id
                     FROM Flight_Table f2,
                          TABLE(f2.List_taken_seats) fls
                    WHERE f2.Id = p_flight_id
               )
             ORDER BY DBMS_RANDOM.VALUE  -- Losowa kolejnoœæ
             FETCH FIRST 1 ROWS ONLY;

            RETURN v_seat_label;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL; -- brak wolnych miejsc
        END get_random_seat;

        ----------------------------------------------------------------------------
        -- Funkcja zwracaj¹ca parê losowych s¹siednich miejsc
        ----------------------------------------------------------------------------
        FUNCTION get_random_adjacent_seats(
            p_flight_id  IN NUMBER,
            p_class_id   IN NUMBER
        ) 
            RETURN SYS.ODCIVARCHAR2LIST
        IS
            v_list       SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
            v_seat_pair  VARCHAR2(50);
            seat1        VARCHAR2(10);
            seat2        VARCHAR2(10);
        BEGIN
            -- Wybieramy pary s¹siaduj¹cych miejsc w jednym ³añcuchu "3A|3B"
            SELECT ( ps1.SeatRow || CHR(64 + ps1.SeatColumn) 
                     || '|' 
                     || ps2.SeatRow || CHR(64 + ps2.SeatColumn) )
              BULK COLLECT INTO v_list
              FROM PlaneSeat_Table ps1
                   JOIN PlaneSeat_Table ps2 
                     ON  ps1.SeatRow      = ps2.SeatRow
                     AND ps1.SeatColumn   = ps2.SeatColumn - 1
             WHERE ps1.TravelClassRef.Id = p_class_id
               AND ps2.TravelClassRef.Id = p_class_id
               AND ps1.Id NOT IN (
                   SELECT DEREF(fls.COLUMN_VALUE).Id
                     FROM Flight_Table f2
                          , TABLE(f2.List_taken_seats) fls
                    WHERE f2.Id = p_flight_id
               )
               AND ps2.Id NOT IN (
                   SELECT DEREF(fls.COLUMN_VALUE).Id
                     FROM Flight_Table f3
                          , TABLE(f3.List_taken_seats) fls
                    WHERE f3.Id = p_flight_id
               );
        
            -- Jeœli mamy co najmniej jedn¹ parê, bierzemy pierwsz¹ z brzegu
            IF v_list.COUNT >= 1 THEN
               -- Przyk³ad v_list(1) = '3A|3B'
               v_seat_pair := v_list(1);
        
               -- Rozdzielamy na seat1 i seat2
               seat1 := SUBSTR(v_seat_pair, 1, INSTR(v_seat_pair, '|') - 1);
               seat2 := SUBSTR(v_seat_pair, INSTR(v_seat_pair, '|') + 1);
        
               -- Zwracamy 2-elementow¹ listê
               RETURN SYS.ODCIVARCHAR2LIST(seat1, seat2);
            ELSE
               -- Brak wolnych par
               RETURN NULL;
            END IF;
        END get_random_adjacent_seats;


        ----------------------------------------------------------------------------
        -- Funkcja zwraca seat_label rodzica (jeœli ma assigned Seat).
        ----------------------------------------------------------------------------
        FUNCTION get_parent_seat(
            p_flight_id  IN NUMBER,
            p_carer_id   IN NUMBER
        ) RETURN VARCHAR2
        IS
            v_seat_label  VARCHAR2(10);
        BEGIN
            SELECT ps.SeatRow || CHR(64 + ps.SeatColumn)
              INTO v_seat_label
              FROM Reservation_Table r
                   JOIN PlaneSeat_Table ps ON REF(ps) = r.Seat
             WHERE r.Flight_id    = p_flight_id
               AND r.Passenger_id = p_carer_id;
            
            RETURN v_seat_label;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;  -- opiekun nie ma miejsca
        END get_parent_seat;


    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- close_reservation start for Flight=' || p_flight_id || ' ---');

        ----------------------------------------------------------------------------
        -- 1) Ustalenie, który samolot jest w tym locie
        ----------------------------------------------------------------------------
        SELECT f.Plane_id
          INTO v_plane_id
          FROM Flight_Table f
         WHERE f.Id = p_flight_id;

        ----------------------------------------------------------------------------
        -- 2) Zapêtlamy wszystkie rezerwacje bez przydzielonego miejsca
        ----------------------------------------------------------------------------
        FOR r_unassigned IN c_unassigned LOOP
            -- r_unassigned ma (reservation_id, passenger_id, class_id)
            -- SprawdŸ, czy pasa¿er jest dzieckiem
            DECLARE
                v_is_child NUMBER;
                v_carer_id NUMBER;
            BEGIN
                SELECT CASE 
                         WHEN MONTHS_BETWEEN(SYSDATE, p.Date_of_birth)/12 < 12 
                              THEN 1 ELSE 0 
                       END,
                       p.Carer_id
                  INTO v_is_child, v_carer_id
                  FROM Passenger_Table p
                 WHERE p.Id = r_unassigned.passenger_id;

                IF v_is_child = 0 THEN
                    ----------------------------------------------------------------------------
                    -- (A) DOROS£Y lub dziecko powy¿ej 12 -> daj pojedyncze losowe miejsce
                    ----------------------------------------------------------------------------
                    DECLARE
                        v_label VARCHAR2(10);
                    BEGIN
                        v_label := get_random_seat(p_flight_id, r_unassigned.class_id);
                        IF v_label IS NOT NULL THEN
                            flight_management.assign_seat_for_reservation(
                                p_flight_id      => p_flight_id,
                                p_reservation_id => r_unassigned.reservation_id,
                                p_seat_label     => v_label
                            );
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('No free seats found for reservation=' 
                                                 || r_unassigned.reservation_id);
                        END IF;
                    END;

                ELSE
                    ----------------------------------------------------------------------------
                    -- (B) DZIECKO --> sprawdŸ, czy opiekun ma ju¿ miejsce
                    ----------------------------------------------------------------------------
                    DECLARE
                        v_parent_seat  VARCHAR2(10);
                        v_parent_label VARCHAR2(10);
                        v_random_label VARCHAR2(10);
                        v_adj_pair     SYS.ODCIVARCHAR2LIST;
                        v_parent_res_id NUMBER;
                    BEGIN
                        -- ZnajdŸ seat opiekuna (o ile w ogóle jest)
                        v_parent_seat := get_parent_seat(p_flight_id, v_carer_id);

                        IF v_parent_seat IS NOT NULL THEN
                            ----------------------------------------------------------------------------
                            -- (B1) Opiekun ma ju¿ miejsce => daj dziecku fotel obok
                            ----------------------------------------------------------------------------
                            -- ZnajdŸ listê wolnych foteli obok parent_seat
                            -- (w tym przyk³adzie definicja "obok" = ten sam col, rz¹d +/-1
                            --  ale w "flight_management" jest caretaker_sits_next_to_child).
                            -- Mo¿emy wyszukaæ wszystkie wolne fotele i sprawdziæ adjacency w PL/SQL
                            --  lub wy³uskaæ z bazy. Tutaj zrobimy to "rêcznie":

                            DECLARE
                                v_all_free_seats SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
                                v_label VARCHAR2(10);
                            BEGIN
                                -- Pobierz wszystkie wolne miejsca w danej klasie, w losowej kolejnoœci
                                FOR seat_rec IN (
                                    SELECT (ps.SeatRow || CHR(64 + ps.SeatColumn)) as label
                                      FROM PlaneSeat_Table ps
                                     WHERE ps.TravelClassRef.Id = r_unassigned.class_id
                                       AND ps.Id NOT IN (
                                           SELECT DEREF(fls.COLUMN_VALUE).Id
                                             FROM Flight_Table f2,
                                                  TABLE(f2.List_taken_seats) fls
                                            WHERE f2.Id = p_flight_id
                                       )
                                     ORDER BY DBMS_RANDOM.VALUE
                                ) LOOP
                                    -- SprawdŸ, czy seat_rec.label jest obok v_parent_seat
                                    IF flight_management.caretaker_sits_next_to_child(
                                         p_seat_label_carer => v_parent_seat,
                                         p_seat_label_child => seat_rec.label
                                       )
                                    THEN
                                        v_label := seat_rec.label;
                                        EXIT;
                                    END IF;
                                END LOOP;

                                IF v_label IS NOT NULL THEN
                                    flight_management.assign_seat_for_reservation(
                                        p_flight_id      => p_flight_id,
                                        p_reservation_id => r_unassigned.reservation_id,
                                        p_seat_label     => v_label
                                    );
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('No adjacent seat found for child reservation='
                                                        || r_unassigned.reservation_id
                                                        || ' next to parent='||v_parent_seat
                                                       );
                                END IF;
                            END;

                        ELSE
                            ----------------------------------------------------------------------------
                            -- (B2) Opiekun te¿ nie ma miejsca => spróbujmy przydzieliæ
                            --      *parê* losowych s¹siaduj¹cych foteli
                            ----------------------------------------------------------------------------
                            v_adj_pair := get_random_adjacent_seats(
                                p_flight_id => p_flight_id,
                                p_class_id  => r_unassigned.class_id
                            );

                            IF v_adj_pair IS NOT NULL AND v_adj_pair.COUNT = 2 THEN
                                -- ZnajdŸ rezerwacjê opiekuna (dla tego lotu)
                                SELECT r.Id
                                  INTO v_parent_res_id
                                  FROM Reservation_Table r
                                 WHERE r.Flight_id    = p_flight_id
                                   AND r.Passenger_id = v_carer_id
                                   AND r.Seat IS NULL
                                   AND ROWNUM = 1;
                                 
                                IF v_parent_res_id IS NOT NULL THEN
                                    -- Przydziel w dowolnej kolejnoœci: (child, parent) vs (parent, child)
                                    -- Lepiej tak, aby child, parent = v_adj_pair(1), v_adj_pair(2).
                                    -- Zrób to przez assign_seat_for_reservation
                                    flight_management.assign_seat_for_reservation(
                                        p_flight_id      => p_flight_id,
                                        p_reservation_id => r_unassigned.reservation_id,  -- child
                                        p_seat_label     => v_adj_pair(1)
                                    );
                                    flight_management.assign_seat_for_reservation(
                                        p_flight_id      => p_flight_id,
                                        p_reservation_id => v_parent_res_id,              -- parent
                                        p_seat_label     => v_adj_pair(2)
                                    );
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('Parent does not have an unassigned reservation! '
                                                        || ' Child reservation='||r_unassigned.reservation_id);
                                END IF;
                            ELSE
                                -- Brak wolnych par?
                                DBMS_OUTPUT.PUT_LINE('No free adjacent seats for child/carer pair, child='
                                                     || r_unassigned.reservation_id);
                            END IF;
                        END IF;  -- v_parent_seat IS NOT NULL
                    END;
                END IF;  -- v_is_child
            END;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('--- close_reservation end for Flight=' || p_flight_id || ' ---');
    END close_reservation;

END reservation_management;
/

