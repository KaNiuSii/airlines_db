CREATE OR REPLACE PACKAGE crew_management AS
   ----------------------------------------------------------------------------
   -- Sta³e
   ----------------------------------------------------------------------------
   c_min_rest_hours CONSTANT NUMBER := 12; -- Minimalna przerwa miêdzy lotami
   c_max_flight_hours_per_week CONSTANT NUMBER := 40; -- Maksymalna liczba godzin w powietrzu w ci¹gu 7 dni

   ----------------------------------------------------------------------------
   -- Typy
   ----------------------------------------------------------------------------
   TYPE crew_assignment_rec IS RECORD (
       crew_member_id NUMBER,
       role_id        NUMBER
   );
   TYPE crew_assignment_list IS TABLE OF crew_assignment_rec;

   ----------------------------------------------------------------------------
   -- Procedury/Funkcje
   ----------------------------------------------------------------------------
   PROCEDURE add_crew_member (
       p_first_name   IN VARCHAR2,
       p_last_name    IN VARCHAR2,
       p_birth_date   IN DATE,
       p_email        IN VARCHAR2,
       p_phone        IN VARCHAR2,
       p_passport     IN VARCHAR2,
       p_role_ids     IN SYS.ODCINUMBERLIST
   );

   FUNCTION is_crew_available (
       p_crew_id          IN NUMBER,
       p_departure_time   IN TIMESTAMP,
       p_arrival_time     IN TIMESTAMP
   ) RETURN BOOLEAN;

   FUNCTION find_available_crew (
       p_departure_time   IN TIMESTAMP,
       p_arrival_time     IN TIMESTAMP,
       p_departure_airport IN CHAR,
       p_required_roles   IN RoleList
   ) RETURN crew_assignment_list;

   FUNCTION get_last_flight_airport (
       p_crew_id IN NUMBER
   ) RETURN CHAR;

   ----------------------------------------------------------------------------
   -- Procedura, która:
   --  1) Wywo³uje find_available_crew (dla zadanego lotu),
   --  2) Jeœli znajdzie kompletn¹ za³ogê, wpisuje przypisania do 
   --     CrewMemberAvailability_Table,
   --  3) Aktualizuje liczbê godzin w powietrzu (Number_of_hours_in_air) za³ogantom.
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id  IN NUMBER
   );

END crew_management;
/


CREATE OR REPLACE PACKAGE BODY crew_management AS
    FUNCTION find_available_crew (
        p_departure_time     IN TIMESTAMP,
        p_arrival_time       IN TIMESTAMP,
        p_departure_airport  IN CHAR,
        p_required_roles     IN RoleList
    ) RETURN crew_assignment_list IS
        v_result           crew_assignment_list := crew_assignment_list();
        v_crew_rec         crew_assignment_rec;
    BEGIN
        -- Dla ka¿dej wymaganej roli szukamy dostêpnego za³oganta
        FOR i IN 1..p_required_roles.COUNT LOOP
            DECLARE
                l_role_obj ROLE;
                v_role_id  NUMBER;
            BEGIN
                SELECT DEREF(p_required_roles(i))
                  INTO l_role_obj
                  FROM DUAL;
    
                v_role_id := l_role_obj.Id;
    
                FOR candidate IN (
                    SELECT c.Id AS crew_member_id,
                           r.Id AS role_id
                      FROM CrewMember_Table c
                      CROSS JOIN TABLE(c.Roles_list) cr
                      JOIN Role_Table r ON r.Id = DEREF(cr.COLUMN_VALUE).Id
                     WHERE r.Id = v_role_id
                ) LOOP
                    -- SprawdŸ dostêpnoœæ kandydata
                    IF is_crew_available(
                         p_crew_id        => candidate.crew_member_id,
                         p_departure_time => p_departure_time,
                         p_arrival_time   => p_arrival_time
                    ) THEN
                        -- SprawdŸ lokalizacjê za³oganta
                        DECLARE
                            v_last_airport CHAR(3);
                        BEGIN
                            v_last_airport := get_last_flight_airport(candidate.crew_member_id);
    
                            IF v_last_airport IS NULL 
                               OR v_last_airport = p_departure_airport THEN
                                v_crew_rec.crew_member_id := candidate.crew_member_id;
                                v_crew_rec.role_id        := candidate.role_id;
                                v_result.EXTEND;
                                v_result(v_result.COUNT) := v_crew_rec;
                                EXIT;
                            END IF;
                        END;
                    END IF;
                END LOOP;
            END;
        END LOOP;
    
        IF v_result.COUNT < p_required_roles.COUNT THEN
            RETURN NULL;
        END IF;
    
        RETURN v_result;
    END find_available_crew;
    
    FUNCTION get_last_flight_airport (
        p_crew_id IN NUMBER
    ) RETURN CHAR IS
        v_airport CHAR(3);
    BEGIN
        SELECT f.IATA_to
          INTO v_airport
          FROM Flight_Table f
          JOIN CrewMemberAvailability_Table cma
               ON cma.Flight_id = f.Id
         WHERE cma.Crew_member_id = p_crew_id
           AND f.Arrival_datetime = (
               SELECT MAX(f2.Arrival_datetime)
                 FROM Flight_Table f2
                 JOIN CrewMemberAvailability_Table cma2
                   ON cma2.Flight_id = f2.Id
                WHERE cma2.Crew_member_id = p_crew_id
           );
    
        RETURN v_airport;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_last_flight_airport;


   ----------------------------------------------------------------------------
   -- Procedura dodania nowego cz³onka za³ogi
   ----------------------------------------------------------------------------
   PROCEDURE add_crew_member (
       p_first_name   IN VARCHAR2,
       p_last_name    IN VARCHAR2,
       p_birth_date   IN DATE,
       p_email        IN VARCHAR2,
       p_phone        IN VARCHAR2,
       p_passport     IN VARCHAR2,
       p_role_ids     IN SYS.ODCINUMBERLIST
   ) IS
       v_id   NUMBER;
       v_roles RoleList := RoleList();
   BEGIN
       -- Wygeneruj nowe ID
       SELECT NVL(MAX(Id), 0) + 1 INTO v_id FROM CrewMember_Table;

       -- Stwórz listê referencji do ról
       FOR i IN 1..p_role_ids.COUNT LOOP
           v_roles.EXTEND;
           SELECT REF(r)
             INTO v_roles(v_roles.LAST)
             FROM Role_Table r
            WHERE r.Id = p_role_ids(i);
       END LOOP;

       -- Wstaw nowego CrewMember do tabeli
       INSERT INTO CrewMember_Table VALUES (
         CrewMember(
             v_id,
             p_first_name,
             p_last_name,
             p_birth_date,
             p_email,
             p_phone,
             p_passport,
             v_roles,
             0  -- Number_of_hours_in_air pocz¹tkowo 0
         )
       );

       DBMS_OUTPUT.PUT_LINE('Dodano nowego cz³onka za³ogi o ID=' || v_id);
   END add_crew_member;

   ----------------------------------------------------------------------------
   -- Funkcja okreœlaj¹ca czas przerwy na podstawie regu³ biznesowych
   ----------------------------------------------------------------------------
   FUNCTION calculate_rest_period (
       p_flight_hours          IN NUMBER,
       p_recent_flights_count  IN NUMBER
   ) RETURN NUMBER IS
   BEGIN
       IF p_flight_hours > 10 OR p_recent_flights_count >= 4 THEN
           RETURN 12; -- Pe³na przerwa
       ELSE
           RETURN 2; -- Minimalna przerwa
       END IF;
   END calculate_rest_period;

   ----------------------------------------------------------------------------
   -- Funkcja sprawdzaj¹ca dostêpnoœæ za³oganta
   ----------------------------------------------------------------------------
   FUNCTION is_crew_available (
       p_crew_id          IN NUMBER,
       p_departure_time   IN TIMESTAMP,
       p_arrival_time     IN TIMESTAMP
   ) RETURN BOOLEAN 
   IS
       v_last_flight_end   TIMESTAMP;
       v_weekly_hours      NUMBER;
       v_recent_flight_hours NUMBER := 0;
       v_temp_departure     TIMESTAMP;
       v_temp_arrival       TIMESTAMP;
   BEGIN
       ------------------------------------------------------------------------
       -- 0) ZnajdŸ koniec ostatniego lotu, w którym crew bra³ udzia³
       ------------------------------------------------------------------------
       SELECT MAX(f.Arrival_datetime)
         INTO v_last_flight_end
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
              ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id = p_crew_id;

       ------------------------------------------------------------------------
       -- 1) SprawdŸ, czy ostatnie loty (przerwa < 8h) trwa³y > 10h ³¹cznie
       ------------------------------------------------------------------------
       FOR flight_rec IN (
           SELECT f.Departure_datetime, f.Arrival_datetime
             FROM Flight_Table f
             JOIN CrewMemberAvailability_Table cma
                  ON cma.Flight_id = f.Id
            WHERE cma.Crew_member_id = p_crew_id
              AND f.Arrival_datetime >= SYSTIMESTAMP - INTERVAL '1' DAY
            ORDER BY f.Departure_datetime DESC
       ) LOOP
           -- Jeœli przerwa miêdzy lotami jest wiêksza ni¿ 8h, przerwij pêtlê
           IF v_last_flight_end IS NOT NULL AND 
              flight_rec.Departure_datetime > v_last_flight_end + NUMTODSINTERVAL(8, 'HOUR') THEN
              EXIT;
           END IF;

           -- Dodaj czas trwania lotu
           v_temp_departure := flight_rec.Departure_datetime;
           v_temp_arrival := flight_rec.Arrival_datetime;

           v_recent_flight_hours := v_recent_flight_hours + 
               EXTRACT(HOUR FROM (v_temp_arrival - v_temp_departure)) +
               EXTRACT(MINUTE FROM (v_temp_arrival - v_temp_departure)) / 60;

           -- Zaktualizuj czas ostatniego lotu
           v_last_flight_end := v_temp_arrival;
       END LOOP;

       IF v_recent_flight_hours > 10 THEN
           RETURN FALSE;
       END IF;

       ------------------------------------------------------------------------
       -- 3) SprawdŸ, ile godzin za³ogant wylata³ w ci¹gu ostatnich 7 dni
       ------------------------------------------------------------------------
       SELECT NVL(SUM(
                EXTRACT(HOUR FROM (f.Arrival_datetime - f.Departure_datetime)) +
                EXTRACT(MINUTE FROM (f.Arrival_datetime - f.Departure_datetime)) / 60
              ), 0)
         INTO v_weekly_hours
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
              ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id = p_crew_id
          AND f.Departure_datetime >= SYSTIMESTAMP - INTERVAL '7' DAY;

       ------------------------------------------------------------------------
       -- 4) SprawdŸ planowane przerwy w CrewMemberAvailability_Table
       ------------------------------------------------------------------------
       FOR availability_rec IN (
           SELECT End_of_break
             FROM CrewMemberAvailability_Table
            WHERE Crew_member_id = p_crew_id
              AND End_of_break > SYSTIMESTAMP
       ) LOOP
           IF p_departure_time < availability_rec.End_of_break THEN
               RETURN FALSE;
           END IF;
       END LOOP;

       RETURN TRUE;
   EXCEPTION
       WHEN NO_DATA_FOUND THEN
          RETURN TRUE; -- Brak danych oznacza dostêpnoœæ
   END is_crew_available;

   ----------------------------------------------------------------------------
   -- Procedura przydzielaj¹ca za³ogê do lotu
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id  IN NUMBER
   ) 
   IS
       v_flight          Flight;
       v_plane           Plane;
       v_required_roles  RoleList;
       v_assignments     crew_assignment_list;
       v_duration_hours  NUMBER;
       v_end_of_break    TIMESTAMP;
       v_recent_flights_count NUMBER := 0;
   BEGIN
       ----------------------------------------------------------------------------
       -- Krok 1: odczytaj obiekt Flight
       ----------------------------------------------------------------------------
       BEGIN
         SELECT VALUE(f)
           INTO v_flight
           FROM Flight_Table f
          WHERE f.Id = p_flight_id;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           DBMS_OUTPUT.PUT_LINE('Brak Flight o Id='||p_flight_id||'.');
           RETURN;
       END;

       ----------------------------------------------------------------------------
       -- Krok 2: odczytaj obiekt Plane (wraz z Required_role_list)
       ----------------------------------------------------------------------------
       BEGIN
         SELECT VALUE(p)
           INTO v_plane
           FROM Plane_Table p
          WHERE p.Id = v_flight.Plane_id;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           DBMS_OUTPUT.PUT_LINE('Brak samolotu (Plane) o Id='||v_flight.Plane_id||'.');
           RETURN;
       END;

       v_required_roles := v_plane.Required_role_list;
       IF v_required_roles IS NULL OR v_required_roles.COUNT = 0 THEN
         DBMS_OUTPUT.PUT_LINE('Samolot ID='||v_plane.Id||' nie ma zdefiniowanych wymaganych ról.');
         RETURN;
       END IF;

       ----------------------------------------------------------------------------
       -- Krok 3: ZnajdŸ dostêpnych kandydatów
       ----------------------------------------------------------------------------
       v_assignments := find_available_crew(
                            p_departure_time     => v_flight.Departure_datetime,
                            p_arrival_time       => v_flight.Arrival_datetime,
                            p_departure_airport  => v_flight.IATA_from,
                            p_required_roles     => v_required_roles
                        );

       IF v_assignments IS NULL THEN
         DBMS_OUTPUT.PUT_LINE('Brak wystarczaj¹cej liczby dostêpnych za³ogantów do lotu '||p_flight_id);
         RETURN;
       END IF;

       DBMS_OUTPUT.PUT_LINE('Znaleziono za³ogê dla lotu '||p_flight_id||'. Zapisujê przypisania...');

       ----------------------------------------------------------------------------
       -- Krok 4: Wstaw do CrewMemberAvailability_Table + aktualizuj Number_of_hours_in_air
       ----------------------------------------------------------------------------
       DECLARE
         v_new_id NUMBER;
         v_flight_hours NUMBER := EXTRACT(HOUR FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))
                                + EXTRACT(MINUTE FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))/60;
       BEGIN
         -- Policzenie liczby ostatnich lotów poni¿ej 10h w ci¹gu dnia
         SELECT COUNT(*)
           INTO v_recent_flights_count
           FROM Flight_Table f
           JOIN CrewMemberAvailability_Table cma
                ON cma.Flight_id = f.Id
          WHERE cma.Crew_member_id = ANY (
            SELECT crew_member_id FROM TABLE(v_assignments)
          )
            AND EXTRACT(HOUR FROM (f.Arrival_datetime - f.Departure_datetime)) < 10
            AND f.Departure_datetime >= SYSTIMESTAMP - INTERVAL '1' DAY;

         FOR i IN 1..v_assignments.COUNT LOOP
           -- 4a) Oblicz dynamiczny czas koñca przerwy na podstawie regu³
           v_end_of_break := v_flight.Arrival_datetime + NUMTODSINTERVAL(
               calculate_rest_period(v_flight_hours, v_recent_flights_count),
               'HOUR'
           );

           -- 4b) Wstaw do CrewMemberAvailability_Table
           SELECT NVL(MAX(Id), 0) + 1 INTO v_new_id FROM CrewMemberAvailability_Table;

           INSERT INTO CrewMemberAvailability_Table VALUES(
             CrewMemberAvailability(
               v_new_id,
               v_assignments(i).crew_member_id,
               p_flight_id,
               v_end_of_break
             )
           );

           -- 4c) Zwiêksz Number_of_hours_in_air
           UPDATE CrewMember_Table
              SET Number_of_hours_in_air = Number_of_hours_in_air + v_flight_hours
            WHERE Id = v_assignments(i).crew_member_id;

           DBMS_OUTPUT.PUT_LINE(
             '-> Przypisano CrewMember='||v_assignments(i).crew_member_id
             ||' (rola='||v_assignments(i).role_id||') do lotu '||p_flight_id
           );
         END LOOP;
       END;

       DBMS_OUTPUT.PUT_LINE('Za³oga dla lotu '||p_flight_id||' zosta³a pomyœlnie przypisana.');
   END assign_crew_to_flight;

END crew_management;

/
