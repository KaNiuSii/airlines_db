   SET SERVEROUTPUT ON;


create or replace package flight_management as
   procedure show_plane_seats_distribution (
      plane_id number
   );
   procedure take_seat_at_plane (
      reservation_list in sys.odcinumberlist, -- List of Reservation IDs
      seat_list        in sys.odcinumberlist         -- List of Seat IDs
   );
end flight_management;
/

create or replace package body flight_management as
   procedure show_plane_seats_distribution (
      plane_id number
   ) is
      plane_obj    plane; -- Variable to hold the Plane object
      seat_refs    planeseatlist; -- Nested table of REF PlaneSeat
      seat_ref     ref planeseat; -- REF variable for PlaneSeat
      seat         planeseat; -- Variable to hold the dereferenced PlaneSeat
      current_row  int := -1; -- Keeps track of the current row
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

   procedure take_seat_at_plane (
      reservation_list in sys.odcinumberlist,
      seat_list        in sys.odcinumberlist
   ) is
      reservation_obj reservation; -- Variable to hold the reservation
      current_seat    ref planeseat; -- Current seat reference of the reservation
      new_seat        ref planeseat; -- New seat reference to be assigned
   begin
        -- Iterate over reservations and seats
      for i in 1..reservation_list.count loop
            -- Fetch the reservation object
         select value(r)
           into reservation_obj
           from reservation_table r
          where r.id = reservation_list(i);

            -- Check if the reservation already has a seat
         if reservation_obj.seat is not null then
                -- Release the current seat
            reservation_obj.seat := null;

                -- Update the reservation table
            update reservation_table r
               set
               r.seat = null
             where r.id = reservation_list(i);
         end if;

            -- Assign the new seat
         select ref(s)
           into new_seat
           from planeseat_table s
          where s.seatrow = seat_list(i); -- Assuming seat_list contains row identifiers

         reservation_obj.seat := new_seat;

            -- Update the reservation table with the new seat
         update reservation_table r
            set
            r.seat = new_seat
          where r.id = reservation_list(i);
      end loop;
   exception
      when no_data_found then
         dbms_output.put_line('Reservation or seat not found.');
      when others then
         dbms_output.put_line('An error occurred: ' || sqlerrm);
   end take_seat_at_plane;
end flight_management;
/



begin
   flight_management.show_plane_seats_distribution(plane_id => 2);
end;
/

begin
   flight_management.take_seat_at_plane(
      reservation_list => sys.odcinumberlist(
         1,
         2
      ),
      seat_list        => sys.odcinumberlist(
         101,
         102
      ) -- Assuming seat IDs
   );
end;
/