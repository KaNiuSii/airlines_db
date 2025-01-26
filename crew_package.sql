CREATE OR REPLACE PACKAGE crew_management AS
   ----------------------------------------------------------------------------
   -- Sta�e
   ----------------------------------------------------------------------------
   c_min_rest_hours CONSTANT NUMBER := 12; -- Minimalna przerwa mi�dzy lotami
   c_max_flight_hours_per_week CONSTANT NUMBER := 40; -- Maksymalna liczba godzin w powietrzu w ci�gu 7 dni

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
   -- Procedura, kt�ra:
   --  1) Wywo�uje find_available_crew (dla zadanego lotu),
   --  2) Je�li znajdzie kompletn� za�og�, wpisuje przypisania do 
   --     CrewMemberAvailability_Table,
   --  3) Aktualizuje liczb� godzin w powietrzu (Number_of_hours_in_air) za�ogantom.
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id  IN NUMBER
   );

END crew_management;
/


CREATE OR REPLACE PACKAGE BODY crew_management AS

   ----------------------------------------------------------------------------
   -- Procedura dodania nowego cz�onka za�ogi
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

       -- Stw�rz list� referencji do r�l
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
             0  -- Number_of_hours_in_air pocz�tkowo 0
         )
       );

       DBMS_OUTPUT.PUT_LINE('Dodano nowego cz�onka za�ogi o ID=' || v_id);
   END add_crew_member;

   ----------------------------------------------------------------------------
   -- Funkcja sprawdza dost�pno�� za�oganta:
   --  - szuka ostatniego lotu, w kt�rym bra� udzia� (CrewMemberAvailability_Table),
   --  - sprawdza minimalny czas odpoczynku (c_min_rest_hours),
   --  - weryfikuje limit godzin w ci�gu 7 dni (c_max_flight_hours_per_week).
   ----------------------------------------------------------------------------
   FUNCTION is_crew_available (
       p_crew_id          IN NUMBER,
       p_departure_time   IN TIMESTAMP,
       p_arrival_time     IN TIMESTAMP
   ) RETURN BOOLEAN 
   IS
       v_last_flight_end   TIMESTAMP;
       v_weekly_hours      NUMBER;
   BEGIN
       ------------------------------------------------------------------------
       -- 1) Znajd� koniec ostatniego lotu, w kt�rym crew bra� udzia�
       ------------------------------------------------------------------------
       SELECT MAX(f.Arrival_datetime)
         INTO v_last_flight_end
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
              ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id = p_crew_id;

       -- Je�eli cokolwiek znale�li�my
       IF v_last_flight_end IS NOT NULL THEN
          -- Czy wype�niamy minimaln� przerw�?
          IF p_departure_time < v_last_flight_end + NUMTODSINTERVAL(c_min_rest_hours, 'HOUR') THEN
             RETURN FALSE;
          END IF;
       END IF;

       ------------------------------------------------------------------------
       -- 2) Sprawd�, ile godzin za�ogant wylata� w ci�gu ostatnich 7 dni
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

       -- Oszacuj liczb� godzin w locie, kt�ry chcemy doda�
       DECLARE
         v_new_flight_hours NUMBER;
       BEGIN
         v_new_flight_hours := EXTRACT(HOUR FROM (p_arrival_time - p_departure_time))
                               + EXTRACT(MINUTE FROM (p_arrival_time - p_departure_time)) / 60;

         IF v_weekly_hours + v_new_flight_hours > c_max_flight_hours_per_week THEN
             RETURN FALSE;
         END IF;
       END;

       RETURN TRUE;
   EXCEPTION
       WHEN NO_DATA_FOUND THEN
          -- Brak danych = za�ogant nie bra� jeszcze udzia�u w �adnym locie -> jest dost�pny
          RETURN TRUE;
   END is_crew_available;

   ----------------------------------------------------------------------------
   -- Funkcja zwraca IATA lotniska, na kt�rym za�ogant zako�czy� ostatni lot.
   -- Je�li brak danych, zwraca NULL.
   ----------------------------------------------------------------------------
   FUNCTION get_last_flight_airport (
       p_crew_id IN NUMBER
   ) RETURN CHAR 
   IS
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
   -- Funkcja znajduje dost�pnych za�ogant�w dla wszystkich wymaganych r�l.
   -- p_required_roles: to lista REF Role (zob. definicja RoleList).
   -- Zwraca list� (crew_assignment_list), gdzie ka�dy element ma:
   --   crew_member_id, role_id
   -- Uwaga: Logika "jedna osoba na jedn� rol�" � wychodzimy od roli i szukamy
   --        pierwszego dost�pnego kandydata.
   ----------------------------------------------------------------------------
   FUNCTION find_available_crew (
       p_departure_time     IN TIMESTAMP,
       p_arrival_time       IN TIMESTAMP,
       p_departure_airport  IN CHAR,
       p_required_roles     IN RoleList
   ) RETURN crew_assignment_list
   IS
       v_result           crew_assignment_list := crew_assignment_list();
       v_crew_rec         crew_assignment_rec;
   BEGIN
       -- Dla ka�dej wymaganej roli szukamy pierwszego dost�pnego za�oganta.
       FOR i IN 1..p_required_roles.COUNT LOOP
         DECLARE
            l_role_obj ROLE;
            v_role_id  NUMBER;
          BEGIN
            SELECT DEREF(p_required_roles(i))
              INTO l_role_obj
              FROM DUAL;
        
            v_role_id := l_role_obj.Id;
           -- Przeszukaj kandydat�w, kt�rzy maj� t� rol�
           FOR candidate IN (
               SELECT c.Id AS crew_member_id,
                      r.Id AS role_id
                 FROM CrewMember_Table c
                 CROSS JOIN TABLE(c.Roles_list) cr -- roles_list to jest RoleList
                 JOIN Role_Table r ON r.Id = DEREF(cr.COLUMN_VALUE).Id
                WHERE r.Id = v_role_id
           ) LOOP
               -- Sprawd� dost�pno�� kandydata
               IF is_crew_available(
                     p_crew_id        => candidate.crew_member_id,
                     p_departure_time => p_departure_time,
                     p_arrival_time   => p_arrival_time
                  )
               THEN
                  -- Sprawd� czy jest na odpowiednim lotnisku (lub nigdzie nie lata�)
                  DECLARE
                    v_last_airport CHAR(3);
                  BEGIN
                    v_last_airport := get_last_flight_airport(candidate.crew_member_id);

                    IF v_last_airport IS NULL 
                       OR v_last_airport = p_departure_airport
                    THEN
                       -- Mamy kandydata
                       v_crew_rec.crew_member_id := candidate.crew_member_id;
                       v_crew_rec.role_id        := candidate.role_id;
                       v_result.EXTEND;
                       v_result(v_result.COUNT) := v_crew_rec;
                       EXIT; -- Przestajemy szuka� kandydata dla tej roli
                    END IF;
                  END;
               END IF;
           END LOOP;
         END;
       END LOOP;

       -- Je�li nie znaleziono pe�nej obsady, zwracamy NULL.
       IF v_result.COUNT < p_required_roles.COUNT THEN
         RETURN NULL;
       END IF;

       RETURN v_result;
   END find_available_crew;

   ----------------------------------------------------------------------------
   -- Procedura, kt�ra:
   -- 1) Odczytuje lot (m.in. plane_id, departure, arrival, sk�d/dok�d),
   -- 2) Odczytuje z Plane_Table list� r�l wymaganych (Required_role_list),
   -- 3) find_available_crew(...) -> szuka za�ogi,
   -- 4) Je�eli znalaz�a si� pe�na obsada, to:
   --      - dopisuje do CrewMemberAvailability_Table wiersze
   --        (Crew_member_id, Flight_id, End_of_break itp.)
   --      - aktualizuje Number_of_hours_in_air
   -- 5) Je�eli si� nie uda znale�� za�ogi, rzuca b��d lub wypisuje komunikat.
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
         DBMS_OUTPUT.PUT_LINE('Samolot ID='||v_plane.Id||' nie ma zdefiniowanych wymaganych r�l.');
         RETURN;
       END IF;

       ----------------------------------------------------------------------------
       -- Krok 3: Znajd� dost�pnych kandydat�w
       ----------------------------------------------------------------------------
       v_assignments := find_available_crew(
                            p_departure_time     => v_flight.Departure_datetime,
                            p_arrival_time       => v_flight.Arrival_datetime,
                            p_departure_airport  => v_flight.IATA_from,
                            p_required_roles     => v_required_roles
                        );

       IF v_assignments IS NULL THEN
         DBMS_OUTPUT.PUT_LINE('Brak wystarczaj�cej liczby dost�pnych za�ogant�w do lotu '||p_flight_id);
         RETURN;
       END IF;

       DBMS_OUTPUT.PUT_LINE('Znaleziono za�og� dla lotu '||p_flight_id||'. Zapisuj� przypisania...');

       ----------------------------------------------------------------------------
       -- Krok 4: Wstaw do CrewMemberAvailability_Table + aktualizuj Number_of_hours_in_air
       ----------------------------------------------------------------------------
       DECLARE
         v_new_id NUMBER;
         v_flight_hours NUMBER := EXTRACT(HOUR FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))
                                + EXTRACT(MINUTE FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))/60;
       BEGIN
         FOR i IN 1..v_assignments.COUNT LOOP
           -- 4a) Wstaw do CrewMemberAvailability_Table
           SELECT NVL(MAX(Id), 0) + 1 INTO v_new_id FROM CrewMemberAvailability_Table;

           INSERT INTO CrewMemberAvailability_Table VALUES(
             CrewMemberAvailability(
               v_new_id,
               v_assignments(i).crew_member_id,
               p_flight_id,
               -- przyk�adowo: koniec przerwy to arrival + 12h; 
               -- mo�na tu zapisa� co� innego, w zale�no�ci od logiki
               v_flight.Arrival_datetime + NUMTODSINTERVAL(c_min_rest_hours, 'HOUR')
             )
           );

           -- 4b) Zwi�ksz Number_of_hours_in_air
           UPDATE CrewMember_Table
              SET Number_of_hours_in_air = Number_of_hours_in_air + v_flight_hours
            WHERE Id = v_assignments(i).crew_member_id;

           DBMS_OUTPUT.PUT_LINE(
             '-> Przypisano CrewMember='||v_assignments(i).crew_member_id
             ||' (rola='||v_assignments(i).role_id||') do lotu '||p_flight_id
           );
         END LOOP;
       END;

       DBMS_OUTPUT.PUT_LINE('Za�oga dla lotu '||p_flight_id||' zosta�a pomy�lnie przypisana.');
   END assign_crew_to_flight;

END crew_management;
/
