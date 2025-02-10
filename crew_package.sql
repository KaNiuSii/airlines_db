CREATE OR REPLACE PACKAGE crew_management AS
   ----------------------------------------------------------------------------
   -- Sta³e (konfiguracja / wartoœci domyœlne)
   ----------------------------------------------------------------------------
   c_min_rest_hours             CONSTANT NUMBER := 12;  -- Minimalna przerwa miêdzy lotami
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
   -- 1) Procedura dodania cz³onka za³ogi
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
   -- 2) Funkcja sprawdzaj¹ca dostêpnoœæ konkretnego za³oganta
   ----------------------------------------------------------------------------
   FUNCTION is_crew_available (
       p_crew_id         IN NUMBER,
       p_departure_time  IN TIMESTAMP,
       p_arrival_time    IN TIMESTAMP
   ) RETURN BOOLEAN;

   ----------------------------------------------------------------------------
   -- 3) Funkcja wyznaczaj¹ca ca³¹ potrzebn¹ za³ogê (crew_assignment_list),
   --    bazuj¹c na liœcie wymaganych ról, dacie wylotu/przylotu i lotnisku wylotu.
   ----------------------------------------------------------------------------
   FUNCTION find_available_crew (
       p_departure_time     IN TIMESTAMP,
       p_arrival_time       IN TIMESTAMP,
       p_departure_airport  IN CHAR,
       p_required_roles     IN RoleList
   ) RETURN crew_assignment_list;

   ----------------------------------------------------------------------------
   -- 4) Funkcja zwracaj¹ca IATA lotniska zakoñczenia ostatniego lotu
   --    danego za³oganta.
   ----------------------------------------------------------------------------
   FUNCTION get_last_flight_airport (
       p_crew_id IN NUMBER
   ) RETURN CHAR;

   ----------------------------------------------------------------------------
   -- 5) G³ówna procedura przypisuj¹ca za³ogê do lotu:
   --    - wywo³uje find_available_crew,
   --    - zapisuje dane do CrewMemberAvailability_Table,
   --    - aktualizuje Number_of_hours_in_air u za³ogantów.
   ----------------------------------------------------------------------------
   PROCEDURE assign_crew_to_flight (
       p_flight_id  IN NUMBER
   );

END crew_management;
/

CREATE OR REPLACE PACKAGE BODY crew_management AS

   ----------------------------------------------------------------------------
   --  FUNKCJA: wyliczenie dodatkowej przerwy (rest period) 
   --           na podstawie godzin w powietrzu i liczby lotów
   ----------------------------------------------------------------------------
   FUNCTION calculate_rest_period (
       p_flight_hours         IN NUMBER,
       p_recent_flights_count IN NUMBER
   ) 
      RETURN NUMBER 
   IS
   BEGIN
       -- Przyk³ad: jeœli za³ogant przekracza 10h lotu lub zrobi³ >=4 loty ostatnio,
       -- to wymagamy pe³nych 12h przerwy, w przeciwnym wypadku 2h.
       IF p_flight_hours > 10 OR p_recent_flights_count >= 4 THEN
           RETURN 12;
       ELSE
           RETURN 2;
       END IF;
   END calculate_rest_period;

   ----------------------------------------------------------------------------
   -- PROCEDURA: Dodanie nowego cz³onka za³ogi i przypisanie mu ról
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

       -- 2) Stwórz listê referencji do ról
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
             0  -- liczba godzin w powietrzu pocz¹tkowo 0
         )
       );

       DBMS_OUTPUT.PUT_LINE('Dodano nowego cz³onka za³ogi o ID=' || v_id);
   END add_crew_member;

   ----------------------------------------------------------------------------
   -- FUNKCJA: Zwraca IATA lotniska, na którym za³ogant zakoñczy³ ostatni lot
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
           -- Nie znaleziono ¿adnego lotu dla danego za³oganta
           RETURN NULL;
   END get_last_flight_airport;

   ----------------------------------------------------------------------------
   -- FUNKCJA: Sprawdza, czy za³ogant jest dostêpny w zadanym przedziale czasowym
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
       -- 0) ZnajdŸ koniec ostatniego lotu, w którym uczestniczy³ za³ogant
       ----------------------------------------------------------------------------
       SELECT MAX(f.Arrival_datetime)
         INTO v_last_flight_end
         FROM Flight_Table f
         JOIN CrewMemberAvailability_Table cma
           ON cma.Flight_id = f.Id
        WHERE cma.Crew_member_id = p_crew_id;

       ----------------------------------------------------------------------------
       -- 1) Przeanalizuj loty z ostatniej doby,
       --    sprawdzaj¹c czas lotu i przerwy (<8h) -- warunkowo sumujemy
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
           -- Jeœli przerwa przed tym lotem > 8h, przerywamy sumowanie
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

           -- Zaktualizuj znacznik koñca ostatniego lotu
           v_last_flight_end := v_temp_arrival;
       END LOOP;

       -- Jeœli w ci¹gu ostatniego dnia za³ogant przekroczy³ 10h latania => niedostêpny
       IF v_recent_flight_hours > 10 THEN
           RETURN FALSE;
       END IF;

       ----------------------------------------------------------------------------
       -- 2) SprawdŸ, ile ³¹cznie godzin wylata³ w ostatnich 7 dniach
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

       -- Je¿eli przekracza c_max_flight_hours_per_week (np. 40h) => niedostêpny
       IF v_weekly_hours >= c_max_flight_hours_per_week THEN
           RETURN FALSE;
       END IF;

       ----------------------------------------------------------------------------
       -- 3) SprawdŸ w CrewMemberAvailability_Table, czy nie ma jeszcze trwaj¹cej przerwy
       ----------------------------------------------------------------------------
       FOR availability_rec IN (
           SELECT End_of_break
             FROM CrewMemberAvailability_Table
            WHERE Crew_member_id = p_crew_id
              AND End_of_break > SYSTIMESTAMP
       ) LOOP
           -- Je¿eli planowany wylot wypada przed koñcem przerwy => niedostêpny
           IF p_departure_time < availability_rec.End_of_break THEN
               RETURN FALSE;
           END IF;
       END LOOP;

       ----------------------------------------------------------------------------
       -- Je¿eli przeszed³ wszystkie testy => za³ogant dostêpny
       ----------------------------------------------------------------------------
       RETURN TRUE;

   EXCEPTION
       WHEN NO_DATA_FOUND THEN
          -- Brak wpisów -> nikt jeszcze nie przypisywa³ za³oganta -> traktujemy jako dostêpnego
          RETURN TRUE;
   END is_crew_available;

   ----------------------------------------------------------------------------
   -- FUNKCJA: ZnajdŸ za³ogantów dla ka¿dej z wymaganych ról (RoleList)
   --          - weryfikuje is_crew_available, sprawdza lokalizacjê (get_last_flight_airport)
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
       -- Dla ka¿dej wymaganej roli próbujemy znaleŸæ jednego pasuj¹cego za³oganta
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

               -- Szukamy kandydatów z dan¹ rol¹
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
                   )
                   THEN
                       -- SprawdŸ, czy za³ogant jest w odpowiednim porcie (lub brak danych => brak ostatniego lotu)
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

                               EXIT; -- ZnaleŸliœmy za³oganta do tej roli, nie szukamy dalej
                           END IF;
                       END;
                   END IF;
               END LOOP;
           END;
       END LOOP;

       -- Jeœli nie uda³o siê pokryæ wszystkich ról => zwróæ NULL
       IF v_result.COUNT < p_required_roles.COUNT THEN
           RETURN NULL;
       END IF;

       RETURN v_result;
   END find_available_crew;

   ----------------------------------------------------------------------------
   -- PROCEDURA: Przydzielenie za³ogi do danego lotu 
   -- (znajduje dostêpnych za³ogantów + zapis do CrewMemberAvailability_Table)
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
           DBMS_OUTPUT.PUT_LINE('Samolot ID='||v_plane.Id||' nie ma zdefiniowanych wymaganych ról.');
           RETURN;
       END IF;

       ----------------------------------------------------------------------------
       -- KROK 3: ZnajdŸ kompletn¹ za³ogê (find_available_crew)
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
       -- KROK 4: Wstaw rekordy do CrewMemberAvailability_Table + aktualizuj liczbê godzin
       ----------------------------------------------------------------------------
       DECLARE
           v_new_id NUMBER;
       BEGIN
           -- Policz ³¹czny czas trwania tego lotu w godzinach
           v_flight_hours :=
               EXTRACT(HOUR FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime))
               + EXTRACT(MINUTE FROM (v_flight.Arrival_datetime - v_flight.Departure_datetime)) / 60;

           -- Policz liczbê ostatnich lotów (poni¿ej 10h) w ci¹gu 1 dnia
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

           -- Aktualizacja dla ka¿dego za³oganta
           FOR i IN 1..v_assignments.COUNT LOOP
               -- 4a) Wyznacz koniec przerwy wg regu³
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

               -- 4c) Zwiêksz Number_of_hours_in_air 
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

       DBMS_OUTPUT.PUT_LINE('Za³oga dla lotu ' || p_flight_id || ' zosta³a pomyœlnie przypisana.');
   END assign_crew_to_flight;

END crew_management;
/
