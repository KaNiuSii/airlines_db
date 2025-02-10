CREATE OR REPLACE PACKAGE crew_management AS
   ----------------------------------------------------------------------------
   -- Sta�e (konfiguracja / warto�ci domy�lne)
   ----------------------------------------------------------------------------
   c_min_rest_hours             CONSTANT NUMBER := 12;  -- Minimalna przerwa mi�dzy lotami
   c_max_flight_hours_per_week  CONSTANT NUMBER := 40;  -- Maksymalna liczba godzin w powietrzu/7 dni

   ----------------------------------------------------------------------------
   -- Typy (rekordy, kolekcje)
   ----------------------------------------------------------------------------
   TYPE crew_assignment_rec IS RECORD (
       crew_member_id NUMBER,
       role_id        NUMBER
   );

   TYPE crew_assignment_list IS TABLE OF crew_assignment_rec;

   ----------------------------------------------------------------------------
   -- 1) Procedura dodania cz�onka za�ogi
   ----------------------------------------------------------------------------
   PROCEDURE add_crew_member (
       p_first_name  IN VARCHAR2,
       p_last_name   IN VARCHAR2,
       p_birth_date  IN DATE,
       p_email       IN VARCHAR2,
       p_phone       IN VARCHAR2,
       p_passport    IN VARCHAR2,
       p_role_ids    IN SYS.ODCINUMBERLIST
   );

   ----------------------------------------------------------------------------
   -- 2) Funkcja sprawdzaj�ca dost�pno�� konkretnego za�oganta
   ----------------------------------------------------------------------------
   FUNCTION is_crew_available (
       p_crew_id         IN NUMBER,
       p_departure_time  IN TIMESTAMP,
       p_arrival_time    IN TIMESTAMP
   ) RETURN BOOLEAN;

   ----------------------------------------------------------------------------
   -- 3) Funkcja wyznaczaj�ca ca�� potrzebn� za�og� (crew_assignment_list),
   --    bazuj�c na li�cie wymaganych r�l, dacie wylotu/przylotu i lotnisku wylotu.
   ----------------------------------------------------------------------------
   FUNCTION find_available_crew (
       p_departure_time     IN TIMESTAMP,
       p_arrival_time       IN TIMESTAMP,
       p_departure_airport  IN CHAR,
       p_required_roles     IN RoleList
   ) RETURN crew_assignment_list;

   ----------------------------------------------------------------------------
   -- 4) Funkcja zwracaj�ca IATA lotniska zako�czenia ostatniego lotu
   --    danego za�oganta.
   ----------------------------------------------------------------------------
   FUNCTION get_last_flight_airport (
       p_crew_id IN NUMBER
   ) RETURN CHAR;

   ----------------------------------------------------------------------------
   -- 5) G��wna procedura przypisuj�ca za�og� do lotu:
   --    - wywo�uje find_available_crew,
   --    - zapisuje dane do CrewMemberAvailability_Table,
   --    - aktualizuje Number_of_hours_in_air u za�ogant�w.
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id  IN NUMBER
   );

END crew_management;
/

CREATE OR REPLACE PACKAGE BODY crew_management AS

   ----------------------------------------------------------------------------
   --  FUNKCJA: wyliczenie dodatkowej przerwy (rest period) 
   --           na podstawie godzin w powietrzu i liczby lot�w
   ----------------------------------------------------------------------------
   FUNCTION calculate_rest_period (
       p_flight_hours         IN NUMBER,
       p_recent_flights_count IN NUMBER
   ) 
      RETURN NUMBER 
   IS
   BEGIN
       -- Przyk�ad: je�li za�ogant przekracza 10h lotu lub zrobi� >=4 loty ostatnio,
       -- to wymagamy pe�nych 12h przerwy, w przeciwnym wypadku 2h.
       IF p_flight_hours > 10 OR p_recent_flights_count >= 4 THEN
           RETURN 12;
       ELSE
           RETURN 2;
       END IF;
   END calculate_rest_period;

   ----------------------------------------------------------------------------
   -- PROCEDURA: Dodanie nowego cz�onka za�ogi i przypisanie mu r�l
   ----------------------------------------------------------------------------
   PROCEDURE add_crew_member (
       p_first_name  IN VARCHAR2,
       p_last_name   IN VARCHAR2,
       p_birth_date  IN DATE,
       p_email       IN VARCHAR2,
       p_phone       IN VARCHAR2,
       p_passport    IN VARCHAR2,
       p_role_ids    IN SYS.ODCINUMBERLIST
   ) 
   IS
       v_id    NUMBER;
       v_roles RoleList := RoleList();
   BEGIN
       -- 1) Wygeneruj nowe ID
       SELECT NVL(MAX(Id), 0) + 1
         INTO v_id
         FROM CrewMember_Table;

       -- 2) Stw�rz list� referencji do r�l
       FOR i IN 1..p_role_ids.COUNT LOOP
           v_roles.EXTEND;
           SELECT REF(r)
             INTO v_roles(v_roles.LAST)
             FROM Role_Table r
            WHERE r.Id = p_role_ids(i);
       END LOOP;

       -- 3) Wstaw nowy rekord CrewMember do tabeli
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
             0  -- liczba godzin w powietrzu pocz�tkowo 0
         )
       );

       DBMS_OUTPUT.PUT_LINE('Dodano nowego cz�onka za�ogi o ID=' || v_id);
   END add_crew_member;

   ----------------------------------------------------------------------------
   -- FUNKCJA: Zwraca IATA lotniska, na kt�rym za�ogant zako�czy� ostatni lot
   ----------------------------------------------------------------------------
   FUNCTION get_last_flight_airport (
       p_crew_id IN NUMBER
   ) 
      RETURN CHAR 
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
           -- Nie znaleziono �adnego lotu dla danego za�oganta
           RETURN NULL;
   END get_last_flight_airport;

   ----------------------------------------------------------------------------
   -- FUNKCJA: Sprawdza, czy za�ogant jest dost�pny w zadanym przedziale czasowym
   ----------------------------------------------------------------------------
   FUNCTION is_crew_available (
       p_crew_id         IN NUMBER,
       p_departure_time  IN TIMESTAMP,
       p_arrival_time    IN TIMESTAMP
   ) 
      RETURN BOOLEAN 
   IS
       v_last_flight_end       TIMESTAMP;
       v_weekly_hours          NUMBER;
       v_recent_flight_hours   NUMBER := 0;
       v_temp_departure        TIMESTAMP;
       v_temp_arrival          TIMESTAMP;
   BEGIN
       ----------------------------------------------------------------------------
       -- 0) Znajd� koniec ostatniego lotu, w kt�rym uczestniczy� za�ogant
       ----------------------------------------------------------------------------
       SELECT MAX(f.Arrival_datetime)
         INTO v_last_flight_end
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
           ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id = p_crew_id;

       ----------------------------------------------------------------------------
       -- 1) Przeanalizuj loty z ostatniej doby,
       --    sprawdzaj�c czas lotu i przerwy (<8h) -- warunkowo sumujemy
       ----------------------------------------------------------------------------
       FOR flight_rec IN (
           SELECT f.Departure_datetime, f.Arrival_datetime
             FROM Flight_Table f
             JOIN CrewMemberAvailability_Table cma
               ON cma.Flight_id = f.Id
            WHERE cma.Crew_member_id  = p_crew_id
              AND f.Arrival_datetime >= SYSTIMESTAMP - INTERVAL '1' DAY
            ORDER BY f.Departure_datetime DESC
       ) LOOP
           -- Je�li przerwa przed tym lotem > 8h, przerywamy sumowanie
           IF v_last_flight_end IS NOT NULL 
              AND flight_rec.Departure_datetime > v_last_flight_end + NUMTODSINTERVAL(8, 'HOUR') 
           THEN
               EXIT;
           END IF;

           -- Dodaj czas trwania lotu do sumy
           v_temp_departure := flight_rec.Departure_datetime;
           v_temp_arrival   := flight_rec.Arrival_datetime;

           v_recent_flight_hours :=
               v_recent_flight_hours
               + EXTRACT(HOUR FROM (v_temp_arrival - v_temp_departure))
               + EXTRACT(MINUTE FROM (v_temp_arrival - v_temp_departure)) / 60;

           -- Zaktualizuj znacznik ko�ca ostatniego lotu
           v_last_flight_end := v_temp_arrival;
       END LOOP;

       -- Je�li w ci�gu ostatniego dnia za�ogant przekroczy� 10h latania => niedost�pny
       IF v_recent_flight_hours > 10 THEN
           RETURN FALSE;
       END IF;

       ----------------------------------------------------------------------------
       -- 2) Sprawd�, ile ��cznie godzin wylata� w ostatnich 7 dniach
       ----------------------------------------------------------------------------
       SELECT NVL(SUM(
                 EXTRACT(HOUR FROM (f.Arrival_datetime - f.Departure_datetime)) 
                 + EXTRACT(MINUTE FROM (f.Arrival_datetime - f.Departure_datetime)) / 60
                ), 0)
         INTO v_weekly_hours
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
           ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id    = p_crew_id
          AND f.Departure_datetime >= SYSTIMESTAMP - INTERVAL '7' DAY;

       -- Je�eli przekracza c_max_flight_hours_per_week (np. 40h) => niedost�pny
       IF v_weekly_hours >= c_max_flight_hours_per_week THEN
           RETURN FALSE;
       END IF;

       ----------------------------------------------------------------------------
       -- 3) Sprawd� w CrewMemberAvailability_Table, czy nie ma jeszcze trwaj�cej przerwy
       ----------------------------------------------------------------------------
       FOR availability_rec IN (
           SELECT End_of_break
             FROM CrewMemberAvailability_Table
            WHERE Crew_member_id = p_crew_id
              AND End_of_break > SYSTIMESTAMP
       ) LOOP
           -- Je�eli planowany wylot wypada przed ko�cem przerwy => niedost�pny
           IF p_departure_time < availability_rec.End_of_break THEN
               RETURN FALSE;
           END IF;
       END LOOP;

       ----------------------------------------------------------------------------
       -- Je�eli przeszed� wszystkie testy => za�ogant dost�pny
       ----------------------------------------------------------------------------
       RETURN TRUE;

   EXCEPTION
       WHEN NO_DATA_FOUND THEN
          -- Brak wpis�w -> nikt jeszcze nie przypisywa� za�oganta -> traktujemy jako dost�pnego
          RETURN TRUE;
   END is_crew_available;

   ----------------------------------------------------------------------------
   -- FUNKCJA: Znajd� za�ogant�w dla ka�dej z wymaganych r�l (RoleList)
   --          - weryfikuje is_crew_available, sprawdza lokalizacj� (get_last_flight_airport)
   ----------------------------------------------------------------------------
   FUNCTION find_available_crew (
       p_departure_time     IN TIMESTAMP,
       p_arrival_time       IN TIMESTAMP,
       p_departure_airport  IN CHAR,
       p_required_roles     IN RoleList
   ) 
      RETURN crew_assignment_list 
   IS
       v_result   crew_assignment_list := crew_assignment_list();
       v_crew_rec crew_assignment_rec;
   BEGIN
       -- Dla ka�dej wymaganej roli pr�bujemy znale�� jednego pasuj�cego za�oganta
       FOR i IN 1..p_required_roles.COUNT LOOP
           DECLARE
               l_role_obj ROLE;
               v_role_id  NUMBER;
           BEGIN
               -- Odczyt obiektu ROLE z referencji
               SELECT DEREF(p_required_roles(i))
                 INTO l_role_obj
                 FROM DUAL;

               v_role_id := l_role_obj.Id;

               -- Szukamy kandydat�w z dan� rol�
               FOR candidate IN (
                   SELECT c.Id AS crew_member_id,
                          r.Id AS role_id
                     FROM CrewMember_Table c
                          CROSS JOIN TABLE(c.Roles_list) cr
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
                       -- Sprawd�, czy za�ogant jest w odpowiednim porcie (lub brak danych => brak ostatniego lotu)
                       DECLARE
                           v_last_airport CHAR(3);
                       BEGIN
                           v_last_airport := get_last_flight_airport(candidate.crew_member_id);

                           IF v_last_airport IS NULL 
                              OR v_last_airport = p_departure_airport
                           THEN
                               v_crew_rec.crew_member_id := candidate.crew_member_id;
                               v_crew_rec.role_id        := candidate.role_id;

                               v_result.EXTEND;
                               v_result(v_result.COUNT) := v_crew_rec;

                               EXIT; -- Znale�li�my za�oganta do tej roli, nie szukamy dalej
                           END IF;
                       END;
                   END IF;
               END LOOP;
           END;
       END LOOP;

       -- Je�li nie uda�o si� pokry� wszystkich r�l => zwr�� NULL
       IF v_result.COUNT < p_required_roles.COUNT THEN
           RETURN NULL;
       END IF;

       RETURN v_result;
   END find_available_crew;

   ----------------------------------------------------------------------------
   -- PROCEDURA: Przydzielenie za�ogi do danego lotu 
   -- (znajduje dost�pnych za�ogant�w + zapis do CrewMemberAvailability_Table)
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id IN NUMBER
   ) 
   IS
       v_flight               Flight;
       v_plane                Plane;
       v_required_roles       RoleList;
       v_assignments          crew_assignment_list;
       v_flight_hours         NUMBER;
       v_recent_flights_count NUMBER := 0;
       v_end_of_break         TIMESTAMP;
   BEGIN
       ----------------------------------------------------------------------------
       -- KROK 1: Pobierz obiekt Flight
       ----------------------------------------------------------------------------
       BEGIN
           SELECT VALUE(f)
             INTO v_flight
             FROM Flight_Table f
            WHERE f.Id = p_flight_id;
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
               DBMS_OUTPUT.PUT_LINE('Brak Flight o Id='||p_flight_id);
               RETURN;
       END;

       ----------------------------------------------------------------------------
       -- KROK 2: Pobierz obiekt Plane i z niego RoleList (Required_role_list)
       ----------------------------------------------------------------------------
       BEGIN
           SELECT VALUE(p)
             INTO v_plane
             FROM Plane_Table p
            WHERE p.Id = v_flight.Plane_id;
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
               DBMS_OUTPUT.PUT_LINE('Brak samolotu (Plane) o Id='||v_flight.Plane_id);
               RETURN;
       END;

       v_required_roles := v_plane.Required_role_list;
       IF v_required_roles IS NULL OR v_required_roles.COUNT = 0 THEN
           DBMS_OUTPUT.PUT_LINE('Samolot ID='||v_plane.Id||' nie ma zdefiniowanych wymaganych r�l.');
           RETURN;
       END IF;

       ----------------------------------------------------------------------------
       -- KROK 3: Znajd� kompletn� za�og� (find_available_crew)
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
       -- KROK 4: Wstaw rekordy do CrewMemberAvailability_Table + aktualizuj liczb� godzin
       ----------------------------------------------------------------------------
       DECLARE
           v_new_id NUMBER;
       BEGIN
           -- Policz ��czny czas trwania tego lotu w godzinach
           v_flight_hours :=
               EXTRACT(HOUR FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))
               + EXTRACT(MINUTE FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime)) / 60;

           -- Policz liczb� ostatnich lot�w (poni�ej 10h) w ci�gu 1 dnia
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

           -- Aktualizacja dla ka�dego za�oganta
           FOR i IN 1..v_assignments.COUNT LOOP
               -- 4a) Wyznacz koniec przerwy wg regu�
               v_end_of_break := v_flight.Arrival_datetime 
                                 + NUMTODSINTERVAL(
                                       calculate_rest_period(v_flight_hours, v_recent_flights_count),
                                       'HOUR'
                                   );

               -- 4b) Dodaj wpis do CrewMemberAvailability_Table
               SELECT NVL(MAX(Id), 0) + 1
                 INTO v_new_id
                 FROM CrewMemberAvailability_Table;

               INSERT INTO CrewMemberAvailability_Table VALUES(
                 CrewMemberAvailability(
                    v_new_id,
                    v_assignments(i).crew_member_id,
                    p_flight_id,
                    v_end_of_break
                 )
               );

               -- 4c) Zwi�ksz Number_of_hours_in_air 
               UPDATE CrewMember_Table
                  SET Number_of_hours_in_air = Number_of_hours_in_air + v_flight_hours
                WHERE Id = v_assignments(i).crew_member_id;

               DBMS_OUTPUT.PUT_LINE(
                 '-> Przypisano CrewMember=' || v_assignments(i).crew_member_id
                 || ' (rola=' || v_assignments(i).role_id 
                 || ') do lotu ' || p_flight_id
               );
           END LOOP;
       END;

       DBMS_OUTPUT.PUT_LINE('Za�oga dla lotu ' || p_flight_id || ' zosta�a pomy�lnie przypisana.');
   END assign_crew_to_flight;

END crew_management;
/
