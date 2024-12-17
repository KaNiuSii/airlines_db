-- czyszczenie
BEGIN
  FOR cur_rec IN (SELECT object_name, object_type 
                  FROM   user_objects
                  WHERE  object_type IN ('TABLE', 'VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION', 'SEQUENCE', 'TRIGGER', 'TYPE')) LOOP
    BEGIN
      IF cur_rec.object_type = 'TABLE' THEN
        IF instr(cur_rec.object_name, 'STORE') = 0 then
          EXECUTE IMMEDIATE 'DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '" CASCADE CONSTRAINTS';
        END IF;
      ELSIF cur_rec.object_type = 'TYPE' THEN
        EXECUTE IMMEDIATE 'DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '" FORCE';
      ELSE
        EXECUTE IMMEDIATE 'DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '"';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('FAILED: DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '"');
    END;
  END LOOP;
END;

-- typy
CREATE OR REPLACE TYPE Seat AS OBJECT (
    Row_num NUMBER,
    Column_num VARCHAR2(5),
    Class VARCHAR2(20),
    Name VARCHAR2(50),
    Price NUMBER,
    CONSTRUCTOR FUNCTION Seat (Row_num NUMBER, Column_num VARCHAR2, Class VARCHAR2, Price NUMBER) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY Seat AS 
    CONSTRUCTOR FUNCTION Seat (Row_num NUMBER, Column_num VARCHAR2, Class VARCHAR2, Price NUMBER) RETURN SELF AS RESULT IS
    BEGIN
        SELF.Row_num := Row_num;
        SELF.Column_num := Column_num;
        SELF.Class := Class;
        SELF.Name := Row_num || ' ' || Column_num || ' ' || Class;
        SELF.Price := Price;
        RETURN;
    END;
END;
/

CREATE OR REPLACE TYPE Crew_Role AS OBJECT (
    Id NUMBER,
    Role_name VARCHAR2(50)
);
/

CREATE OR REPLACE TYPE Crew_Role_VARRAY AS VARRAY(10) OF Crew_Role;
/

CREATE OR REPLACE TYPE Seat_TABLE AS TABLE OF Seat;
/

CREATE OR REPLACE TYPE Plane AS OBJECT (
    Id NUMBER,
    Seat_list Seat_TABLE,
    required_role_list Crew_Role_VARRAY
);
/

CREATE OR REPLACE TYPE Passenger AS OBJECT (
    Id NUMBER,
    First_name VARCHAR2(50),
    Last_name VARCHAR2(50),
    Date_of_birth DATE,
    Email VARCHAR2(100),
    Phone VARCHAR2(20),
    Passport_number VARCHAR2(50)
);
/

CREATE OR REPLACE TYPE Crew_Member AS OBJECT (
    Id NUMBER,
    First_name VARCHAR2(50),
    Last_name VARCHAR2(50),
    Date_of_birth DATE,
    Email VARCHAR2(100),
    Phone VARCHAR2(20),
    Passport_number VARCHAR2(50),
    Roles_list Crew_Role_VARRAY,
    Number_of_hours_in_air NUMBER
);
/

CREATE OR REPLACE TYPE Role_to_Crew AS OBJECT (
    This_crew_member REF Crew_Member,
    Role_of_this_member REF Crew_Role
);
/

CREATE OR REPLACE TYPE Role_to_Crew_TABLE AS TABLE OF Role_to_Crew;
/

CREATE OR REPLACE TYPE Seat_REF_TABLE AS TABLE OF REF Seat;
/

CREATE OR REPLACE TYPE Flight AS OBJECT (
    Id NUMBER,
    Plane_id REF Plane,
    Departure_datetime TIMESTAMP,
    Arrival_datetime TIMESTAMP,
    IATA_from VARCHAR2(3),
    IATA_to VARCHAR2(3),
    Role_to_crew_list Role_to_Crew_TABLE,
    Reservation_closing_datetime TIMESTAMP,
    List_taken_seats Seat_REF_TABLE
);
/

CREATE OR REPLACE TYPE Reservation AS OBJECT (
    Id NUMBER,
    Flight_id REF Flight,
    Passenger_id REF Passenger,
    Seat_id REF Seat
);
/

-- Tabele obiektowych
CREATE TABLE Seats OF Seat;
CREATE TABLE Planes OF Plane NESTED TABLE Seat_list STORE AS Plane_Seats;
CREATE TABLE Passengers OF Passenger;
CREATE TABLE Crew_Roles OF Crew_Role;
CREATE TABLE Crew_Members OF Crew_Member;
CREATE TABLE Flights OF Flight NESTED TABLE Role_to_crew_list STORE AS Flight_Role_Crew,
                                NESTED TABLE List_taken_seats STORE AS Flight_Seats;
CREATE TABLE Reservations OF Reservation;

-- Dodaj referencje
ALTER TABLE Reservations ADD CONSTRAINT fk_flight_id FOREIGN KEY (Flight_id) REFERENCES Flights;
ALTER TABLE Reservations ADD CONSTRAINT fk_passenger_id FOREIGN KEY (Passenger_id) REFERENCES Passengers;
ALTER TABLE Reservations ADD CONSTRAINT fk_seat_id FOREIGN KEY (Seat_id) REFERENCES Seats;

-- test package
CREATE OR REPLACE PACKAGE Airline_Management AS
    PROCEDURE Add_Flight(p_Flight IN Flight);
    PROCEDURE Add_Reservation(p_Reservation IN Reservation);
    FUNCTION Get_Seat_Info(p_Seat_Id IN NUMBER) RETURN VARCHAR2;
END Airline_Management;
/

CREATE OR REPLACE PACKAGE BODY Airline_Management AS
    PROCEDURE Add_Flight(p_Flight IN Flight) IS
    BEGIN
        INSERT INTO Flights VALUES p_Flight;
    END;

    PROCEDURE Add_Reservation(p_Reservation IN Reservation) IS
    BEGIN
        INSERT INTO Reservations VALUES p_Reservation;
    END;

    FUNCTION Get_Seat_Info(p_Seat_Id IN NUMBER) RETURN VARCHAR2 IS
        v_Seat Seat;
    BEGIN
        SELECT VALUE(s)
        INTO v_Seat
        FROM Seats s
        WHERE s.Row_num = p_Seat_Id;
        RETURN v_Seat.Name || ' - Price: ' || v_Seat.Price;
    END;
END Airline_Management;
/

-- Inserty
DECLARE
    v_Seat Seat;
    v_Passenger Passenger;
BEGIN
    -- Insert fotela
    v_Seat := Seat(10, 'A', 'Business', 500);
    INSERT INTO Seats VALUES (v_Seat);

    -- Insert pasa¿er
    v_Passenger := Passenger(1, 'Jan', 'Kowalski', TO_DATE('1990-05-05', 'YYYY-MM-DD'), 'jan.kowalski@example.com', '123456789', 'AB123456');
    INSERT INTO Passengers VALUES (v_Passenger);

    COMMIT;
END;
/

-- Selecty
SELECT * FROM Seats;
SELECT * FROM Passengers;
SELECT * FROM Reservations;
SELECT * FROM Flights;
