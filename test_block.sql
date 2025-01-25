SET SERVEROUTPUT ON;
SET DEFINE OFF;

--------------------------------
-- TEST #1: SUCCESS (no caretaker) for Flight #1
--------------------------------

DECLARE
   v_res_list  SYS.ODCINUMBERLIST   := SYS.ODCINUMBERLIST(1, 2);
   v_seat_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('1A','2A');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #1: SUCCESS (no caretaker) for Flight #1');
   flight_management.take_seat_at_flight(
      p_flight_id        => 1,
      p_reservation_list => v_res_list,
      p_seat_list        => v_seat_list
   );
END;
/


--------------------------------
-- TEST #2: FAILURE - mismatched list sizes
--------------------------------

DECLARE
   v_res_list  SYS.ODCINUMBERLIST   := SYS.ODCINUMBERLIST(1, 2, 3);
   v_seat_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('1A','1B');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #2: FAILURE - mismatched list sizes');
   flight_management.take_seat_at_flight(
      p_flight_id        => 1,
      p_reservation_list => v_res_list,
      p_seat_list        => v_seat_list
   );
END;
/


--------------------------------
-- TEST #3: FAILURE - duplicate seat label
--------------------------------

DECLARE
   v_res_list  SYS.ODCINUMBERLIST   := SYS.ODCINUMBERLIST(1, 2);
   -- Both want "1A"
   v_seat_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('1A','1A');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #3: FAILURE - duplicate seat label');
   flight_management.take_seat_at_flight(
      p_flight_id        => 1,
      p_reservation_list => v_res_list,
      p_seat_list        => v_seat_list
   );
END;
/


--------------------------------
-- TEST #4: FAILURE - seat already taken
-- (Assumes from Test #1 that seat "1A" is already assigned in flight #1)
--------------------------------

BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #4: FAILURE - seat already taken');
   -- Attempt to assign seat "1A" again for reservation #2 
   flight_management.take_seat_at_flight(
      p_flight_id        => 1,
      p_reservation_list => SYS.ODCINUMBERLIST(2),
      p_seat_list        => SYS.ODCIVARCHAR2LIST('1A')
   );
END;
/


--------------------------------
-- TEST #5: FAILURE - caretaker & child not seated together (Flight #2)
--------------------------------

DECLARE
   -- caretaker (reservation #3) => seat "1A"
   -- child (reservation #4) => seat "2A"
   -- Those are different rows => not adjacent by your adjacency rule
   v_res_list  SYS.ODCINUMBERLIST   := SYS.ODCINUMBERLIST(3, 4);
   v_seat_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('1A','2B');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #5: FAILURE - caretaker & child not seated together (Flight #2)');
   flight_management.take_seat_at_flight(
      p_flight_id        => 2,
      p_reservation_list => v_res_list,
      p_seat_list        => v_seat_list
   );
END;
/


--------------------------------
-- TEST #6: SUCCESS - caretaker & child next to each other (Flight #2)
--------------------------------

DECLARE
   -- caretaker (reservation #3) => seat "1A"
   -- child (reservation #4) => seat "1B"
   -- They share same row=1, col=1 vs col=2 => adjacency is true
   v_res_list  SYS.ODCINUMBERLIST   := SYS.ODCINUMBERLIST(3, 4);
   v_seat_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('1A','1B');
BEGIN
   DBMS_OUTPUT.PUT_LINE('Test #6: SUCCESS - caretaker & child next to each other (Flight #2)');
   flight_management.take_seat_at_flight(
      p_flight_id        => 2,
      p_reservation_list => v_res_list,
      p_seat_list        => v_seat_list
   );
END;
/

