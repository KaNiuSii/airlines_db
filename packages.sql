   SET SERVEROUTPUT ON;


create or replace package flight_management as
   procedure show_plane_seats_distribution (
      plane_id number
   );

   procedure take_seat_at_flight (
      reservation_list in sys.odcinumberlist, -- List of Reservation IDs
      seat_list        in sys.odcivarchar2list -- List of Seat IDs
   );
end flight_management;
/


create or replace package body flight_management as

   procedure show_plane_seats_distribution (
      plane_id number
   ) is
      plane_obj    plane;         -- Variable to hold the Plane object
      seat_refs    planeseatlist; -- Nested table of REF PlaneSeat
      seat_ref     ref planeseat; -- REF variable for PlaneSeat
      seat         planeseat;     -- Variable to hold the dereferenced PlaneSeat
      current_row  int := -1;     -- Keeps track of the current row
      seat_display varchar2(500); -- To build the seat display for a row
   begin
      -- Retrieve the Plane object by ID
      select value(p)
        into plane_obj
        from plane_table p
       where p.id = plane_id;

      -- Assign the nested table of seat references
      seat_refs := plane_obj.seat_list;

      -- Loop through the nested table
      if seat_refs is not null then
         for i in 1..seat_refs.count loop
            seat_ref := seat_refs(i);

            -- Dereference the seat
            select deref(seat_ref)
              into seat
              from dual;

            -- Check if we are on a new row
            if seat.seatrow != current_row then
               -- Print the previous row (if exists) and reset for the new row
               if current_row != -1 then
                  dbms_output.put_line(seat_display);
               end if;

               -- Start a new row
               current_row := seat.seatrow;
               seat_display := '';
            end if;

            -- Append the seat (e.g., 1A) to the current row display
            seat_display := seat_display
                            || seat.seatrow
                            || chr(64 + seat.seatcolumn)
                            || ' ';
         end loop;

         -- Print the final row
         if current_row != -1 then
            dbms_output.put_line(seat_display);
         end if;
      else
         dbms_output.put_line('No seats found for Plane ID ' || plane_id);
      end if;
   exception
      when no_data_found then
         dbms_output.put_line('No plane found with ID ' || plane_id);
      when others then
         dbms_output.put_line('An error occurred: ' || sqlerrm);
   end show_plane_seats_distribution;


   procedure take_seat_at_flight (
      reservation_list in sys.odcinumberlist,
      seat_list        in sys.odcivarchar2list
   ) is
      reservation_obj  reservation;  -- Variable to hold the reservation
      new_seat         ref planeseat;
      seat_row         int;
      seat_column      char(1);
      seat_column_int  int;
      seat_taken_count int;
      v_flight_id      number;

      -- Added local variables to handle string parsing safely
      seat_list_entry  varchar2(100);
      seat_row_str     varchar2(99);
   begin
      if reservation_list.count != seat_list.count then
         raise_application_error(
            -20001,
            'Reservation and seat lists must have the same length.'
         );
      end if;

      for i in 1..reservation_list.count loop
         /*
            1) Trim the seat string (remove any leading/trailing spaces).
            2) Extract all but the last character as the row portion.
            3) Extract the last character as the column portion.
            4) Convert the row portion to a number.
         */
         seat_list_entry := trim(seat_list(i));  -- handle spaces/newlines
         seat_row_str := substr(
            seat_list_entry,
            1,
            length(seat_list_entry) - 1
         );
         seat_column := substr(
            seat_list_entry,
            -1
         );
         seat_column_int := ascii(upper(seat_column)) - 64;
         -- Safely convert the row portion to a number
         seat_row := to_number ( seat_row_str );

         -- Fetch the reservation
         select value(r)
           into reservation_obj
           from reservation_table r
          where r.id = reservation_list(i);

         -- If seat is currently assigned, remove it
         if reservation_obj.seat is not null then
            reservation_obj.seat := null;
            update reservation_table
               set
               seat = null
             where id = reservation_list(i);
         end if;

         -- Get a REF to the new seat
         select ref(s)
           into new_seat
           from planeseat_table s
          where s.seatrow = seat_row
            and s.seatcolumn = seat_column_int;

         -- Find the flight_id for this reservation
         select flight_id
           into v_flight_id
           from reservation_table
          where id = reservation_list(i);

         -- Check if this seat is already in that flight's list
         select count(*)
           into seat_taken_count
           from flight_table f
          where f.id = v_flight_id
            and new_seat member of f.list_taken_seats;

         if seat_taken_count > 0 then
            raise_application_error(
               -20002,
               'Seat '
               || seat_list(i)
               || ' is already taken.'
            );
         end if;

         -- Assign the new seat
         update reservation_table
            set
            seat = new_seat
          where id = reservation_list(i);

         -- Add this seat to the flight's list of taken seats
         update flight_table
            set
            list_taken_seats = list_taken_seats multiset union planeseatlist(new_seat)
          where id = v_flight_id;
      end loop;
   end take_seat_at_flight;

end flight_management;

begin
   flight_management.show_plane_seats_distribution(plane_id => 1);
end;
/

begin
   flight_management.take_seat_at_flight(
      reservation_list => sys.odcinumberlist(
         1,
         2
      ),
      seat_list        => sys.odcivarchar2list(
         '1A',
         '1A'
      )
   );
end;
/

select *
  from flight_table;