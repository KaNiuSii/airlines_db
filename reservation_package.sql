CREATE OR REPLACE PACKAGE Reservation_Management AS
    PROCEDURE Add_Reservation(
        passenger_list IN SYS.ODCINUMBERLIST, -- List of Passenger IDs
        flight_id IN NUMBER                  -- Flight ID
    );
END Reservation_Management;
/

CREATE OR REPLACE PACKAGE BODY Reservation_Management AS
    PROCEDURE Add_Reservation(
        passenger_list IN SYS.ODCINUMBERLIST,
        flight_id IN NUMBER
    ) IS
        flight_obj Flight; -- Variable to hold the Flight object
        reservation Reservation; -- Variable for creating reservations
        passenger_ref REF Passenger; -- REF for each passenger
        carer_ref REF Passenger; -- REF for the carer (if applicable)
        passenger_obj Passenger; -- Variable to hold passenger details
        carer_obj Passenger; -- Variable to hold carer details
        seat_list PlaneSeatList; -- Seats available in the Plane
        new_reservations ReservationList := ReservationList();
    BEGIN
        -- Retrieve the Flight object
        SELECT VALUE(f)
        INTO flight_obj
        FROM Flight_Table f
        WHERE f.Id = flight_id;

        -- Check for passengers and create reservations
        FOR i IN 1 .. passenger_list.COUNT LOOP
            -- Fetch the Passenger object
            SELECT REF(p)
            INTO passenger_ref
            FROM Passenger_Table p
            WHERE p.Id = passenger_list(i);

            -- Check if the passenger has a carer
            SELECT VALUE(p)
            INTO passenger_obj
            FROM Passenger_Table p
            WHERE p.Id = passenger_list(i);

            IF passenger_obj.Carer_id IS NOT NULL THEN
                -- Fetch the carer details
                SELECT REF(p)
                INTO carer_ref
                FROM Passenger_Table p
                WHERE p.Id = passenger_obj.Carer_id;

                -- Add a reservation for the passenger and the carer
                reservation := Reservation(
                    Id => NULL, -- Use sequence for ID
                    Flight_id => flight_id,
                    Passenger_id => passenger_list(i),
                    Requested_Class => NULL,
                    Seat => NULL
                );

                -- Add to reservation list
                new_reservations.EXTEND(1);
                new_reservations(new_reservations.LAST) := REF(reservation);
            ELSE
                -- Add a single reservation
                reservation := Reservation(
                    Id => NULL,
                    Flight_id => flight_id,
                    Passenger_id => passenger_list(i),
                    Requested_Class => NULL,
                    Seat => NULL
                );

                -- Add to reservation list
                new_reservations.EXTEND(1);
                new_reservations(new_reservations.LAST) := REF(reservation);
            END IF;
        END LOOP;

        -- Insert the new reservations into the Reservation_Table
        FORALL i IN INDICES OF new_reservations
            INSERT INTO Reservation_Table VALUES (DEREF(new_reservations(i)));
    END Add_Reservation;
END Reservation_Management;
/

BEGIN
    Reservation_Management.Add_Reservation(
        passenger_list => SYS.ODCINUMBERLIST(1, 2, 3),
        flight_id => 1
    );
END;
/

