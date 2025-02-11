CREATE USER crew_user IDENTIFIED BY strong_password;
GRANT CREATE SESSION TO crew_user;
GRANT EXECUTE ON scott.crew_management TO crew_user;

CREATE USER flight_user IDENTIFIED BY strong_password;
GRANT CREATE SESSION TO flight_user;
GRANT EXECUTE ON scott.flight_management TO flight_user;
GRANT SELECT ON scott.v_flights_seatings TO flight_user;

CREATE USER reservation_user IDENTIFIED BY strong_password;
GRANT CREATE SESSION TO reservation_user;
GRANT EXECUTE ON scott.reservation_management TO reservation_user;

