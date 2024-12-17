-- passenger Management
CREATE OR REPLACE PACKAGE Passenger_Management AS
    PROCEDURE Add_Passenger(p_Passenger IN Passenger);
    FUNCTION Is_Passenger_Exists(p_Passport_number VARCHAR2) RETURN BOOLEAN;
END Passenger_Management;
/

CREATE OR REPLACE PACKAGE BODY Passenger_Management AS
    FUNCTION Is_Passenger_Exists(p_Passport_number VARCHAR2) RETURN BOOLEAN IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count
        FROM Passengers
        WHERE Passport_number = p_Passport_number;
        
        RETURN v_Count > 0;
    END;

    PROCEDURE Add_Passenger(p_Passenger IN Passenger) IS
    BEGIN
        IF Is_Passenger_Exists(p_Passenger.Passport_number) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Passenger already exists with this passport number');
        END IF;

        INSERT INTO Passengers VALUES p_Passenger;
        COMMIT;
    END;
END Passenger_Management;
/

-- flight Management
CREATE OR REPLACE PACKAGE Flight_Management AS
    PROCEDURE Add_Flight(p_Flight IN Flight);
    FUNCTION Is_Flight_Exists(p_Id NUMBER, p_Date TIMESTAMP) RETURN BOOLEAN;
END Flight_Management;
/

CREATE OR REPLACE PACKAGE BODY Flight_Management AS
    FUNCTION Is_Flight_Exists(p_Id NUMBER, p_Date TIMESTAMP) RETURN BOOLEAN IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count
        FROM Flights
        WHERE Id = p_Id AND TRUNC(Departure_datetime) = TRUNC(p_Date);
        
        RETURN v_Count > 0;
    END;

    PROCEDURE Add_Flight(p_Flight IN Flight) IS
    BEGIN
        IF Is_Flight_Exists(p_Flight.Id, p_Flight.Departure_datetime) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Flight already exists for this date');
        END IF;

        INSERT INTO Flights VALUES p_Flight;
        COMMIT;
    END;
END Flight_Management;
/

-- reservation Management
CREATE OR REPLACE PACKAGE Reservation_Management AS
    PROCEDURE Add_Reservation(p_Reservation IN Reservation);
    FUNCTION Is_Seat_Taken(p_Flight_id REF Flight, p_Seat_id REF Seat) RETURN BOOLEAN;
    FUNCTION Is_Reservation_Time_Valid(p_Flight_id REF Flight) RETURN BOOLEAN;
END Reservation_Management;
/

CREATE OR REPLACE PACKAGE BODY Reservation_Management AS
    FUNCTION Is_Seat_Taken(p_Flight_id REF Flight, p_Seat_id REF Seat) RETURN BOOLEAN IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count
        FROM Reservations
        WHERE Flight_id = p_Flight_id AND Seat_id = p_Seat_id;

        RETURN v_Count > 0;
    END;

    FUNCTION Is_Reservation_Time_Valid(p_Flight_id REF Flight) RETURN BOOLEAN IS
        v_Departure TIMESTAMP;
    BEGIN
        SELECT f.Departure_datetime
        INTO v_Departure
        FROM Flights f
        WHERE REF(f) = p_Flight_id;
    
        RETURN SYSTIMESTAMP < v_Departure - INTERVAL '2' HOUR;
    END;

    PROCEDURE Add_Reservation(p_Reservation IN Reservation) IS
    BEGIN
        IF Is_Seat_Taken(p_Reservation.Flight_id, p_Reservation.Seat_id) THEN
            RAISE_APPLICATION_ERROR(-20003, 'This seat is already taken for the flight');
        END IF;

        IF NOT Is_Reservation_Time_Valid(p_Reservation.Flight_id) THEN
            RAISE_APPLICATION_ERROR(-20004, 'Reservations must be made at least 2 hours before departure');
        END IF;

        INSERT INTO Reservations VALUES p_Reservation;
        COMMIT;
    END;
END Reservation_Management;
/

-- crew Managemen
CREATE OR REPLACE PACKAGE Crew_Management AS
    FUNCTION Is_Crew_Qualified(p_Crew_id REF Crew_Member, p_Plane_id REF Plane) RETURN BOOLEAN;
END Crew_Management;
/

CREATE OR REPLACE PACKAGE BODY Crew_Management AS
    FUNCTION Is_Crew_Qualified(p_Crew_id REF Crew_Member, p_Plane_id REF Plane) RETURN BOOLEAN IS
        v_Count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_Count
        FROM Crew_Members c, TABLE(c.Roles_list) r
        WHERE REF(c) = p_Crew_id;

        -- logika sprawdzania kwalifikacji :p
        RETURN v_Count > 0;
    END;
END Crew_Management;
/

