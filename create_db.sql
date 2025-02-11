-- Czyszczenie
BEGIN
  FOR cur_rec IN (
    SELECT table_name AS object_name, 'TABLE' AS object_type 
    FROM user_tables
    WHERE table_name NOT LIKE '%LIST_TABLE'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE "' || cur_rec.object_name || '" CASCADE CONSTRAINTS';
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('FAILED: DROP TABLE "' || cur_rec.object_name || '"');
    END;
  END LOOP;

  FOR cur_rec IN (
    SELECT table_name AS object_name, 'TABLE' AS object_type 
    FROM user_tables
    WHERE table_name LIKE '%LIST_TABLE'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE "' || cur_rec.object_name || '"';
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('FAILED: DROP TABLE "' || cur_rec.object_name || '"');
    END;
  END LOOP;

  FOR cur_rec IN (
    SELECT type_name AS object_name, 'TYPE' AS object_type 
    FROM user_types
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TYPE "' || cur_rec.object_name || '" FORCE';
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('FAILED: DROP TYPE "' || cur_rec.object_name || '"');
    END;
  END LOOP;
END;
/
BEGIN
  FOR cur_rec IN (
    SELECT object_name, object_type 
    FROM user_objects
    WHERE object_type IN (
      'TABLE','VIEW','PACKAGE','PROCEDURE','FUNCTION','SEQUENCE','TRIGGER','TYPE'
    )
  ) LOOP
    BEGIN
      IF cur_rec.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE "' || cur_rec.object_name || '" CASCADE CONSTRAINTS';
      ELSIF cur_rec.object_type = 'TYPE' THEN
        EXECUTE IMMEDIATE 'DROP TYPE "' || cur_rec.object_name || '" FORCE';
      ELSE
        EXECUTE IMMEDIATE 'DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '"';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('FAILED: DROP ' || cur_rec.object_type || ' "' || cur_rec.object_name || '"');
    END;
  END LOOP;
END;
/

CREATE OR REPLACE TYPE TravelClass AS OBJECT (
    Id            INT,
    Class_Name    VARCHAR2(100),
    Description   VARCHAR2(255)
);
/

CREATE TABLE TravelClass_Table OF TravelClass;
/

ALTER TABLE TravelClass_Table 
  ADD CONSTRAINT PK_TravelClass 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE Role AS OBJECT (
    Id         INT,
    Role_name  VARCHAR2(100)
);
/

CREATE TABLE Role_Table OF Role;
/

ALTER TABLE Role_Table 
  ADD CONSTRAINT PK_Role 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE PlaneSeat AS OBJECT (
    Id              INT,
    SeatRow         INT,
    SeatColumn      INT,
    TravelClassRef  REF TravelClass,
    Price           FLOAT
);
/

CREATE TABLE PlaneSeat_Table OF PlaneSeat;
/

ALTER TABLE PlaneSeat_Table 
  ADD CONSTRAINT PK_PlaneSeat 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE PlaneSeatList AS TABLE OF REF PlaneSeat;
/

CREATE OR REPLACE TYPE RoleList AS TABLE OF REF Role;
/

CREATE OR REPLACE TYPE Plane AS OBJECT (
    Id                   INT,
    Seat_list            PlaneSeatList,
    Required_role_list   RoleList
);
/

CREATE TABLE Plane_Table OF Plane
    NESTED TABLE Seat_list STORE AS Plane_Seat_List_Table,
    NESTED TABLE Required_role_list STORE AS Plane_Role_List_Table;
/

ALTER TABLE Plane_Table 
  ADD CONSTRAINT PK_Plane 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE CrewMember AS OBJECT (
    Id                   INT,
    First_name           VARCHAR2(100),
    Last_name            VARCHAR2(100),
    Date_of_birth        DATE,
    Email                VARCHAR2(150),
    Phone                VARCHAR2(15),
    Passport_number      VARCHAR2(20),
    Roles_list           RoleList,
    Number_of_hours_in_air FLOAT
);
/

CREATE TABLE CrewMember_Table OF CrewMember
    NESTED TABLE Roles_list STORE AS Crew_Role_List_Table;
/

ALTER TABLE CrewMember_Table 
  ADD CONSTRAINT PK_CrewMember 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE CrewMemberAvailability AS OBJECT (
    Id             INT,
    Crew_member_id INT,
    Flight_id      INT,
    End_of_break   TIMESTAMP
);
/

CREATE TABLE CrewMemberAvailability_Table OF CrewMemberAvailability;
/

ALTER TABLE CrewMemberAvailability_Table 
  ADD CONSTRAINT PK_CrewMemberAvailability 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE Reservation AS OBJECT (
    Id              INT,
    Flight_id       INT,
    Passenger_id    INT,
    Requested_Class REF TravelClass,
    Seat            REF PlaneSeat
);
/

CREATE TABLE Reservation_Table OF Reservation;
/

ALTER TABLE Reservation_Table 
  ADD CONSTRAINT PK_Reservation 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE Flight AS OBJECT (
    Id                       INT,
    Plane_id                 INT,
    Departure_datetime       TIMESTAMP,
    Arrival_datetime         TIMESTAMP,
    IATA_from                CHAR(3),
    IATA_to                  CHAR(3),
    Reservation_closing_datetime TIMESTAMP,
    List_taken_seats         PlaneSeatList,
    Technical_support_after_arrival_ids SYS.ODCINUMBERLIST
);
/

CREATE TABLE Flight_Table OF Flight
    NESTED TABLE List_taken_seats STORE AS Flight_Taken_Seats_Table;
/

ALTER TABLE Flight_Table 
  ADD CONSTRAINT PK_Flight 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE Passenger AS OBJECT (
    Id              INT,
    First_name      VARCHAR2(100),
    Last_name       VARCHAR2(100),
    Date_of_birth   DATE,
    Email           VARCHAR2(150),
    Phone           VARCHAR2(15),
    Passport_number VARCHAR2(20),
    Carer_id        INT
);
/

CREATE TABLE Passenger_Table OF Passenger;
/

ALTER TABLE Passenger_Table 
  ADD CONSTRAINT PK_Passenger 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE TechnicalSupport AS OBJECT (
    Id             INT,
    Name           VARCHAR2(100),
    Specialization VARCHAR2(100),
    Shift_start    TIMESTAMP,
    Shift_end      TIMESTAMP,
    Airport_IATA   CHAR(3)
);
/

CREATE TABLE TechnicalSupport_Table OF TechnicalSupport;
/

ALTER TABLE TechnicalSupport_Table 
  ADD CONSTRAINT PK_TechnicalSupport 
  PRIMARY KEY (Id);
/

CREATE OR REPLACE TYPE TechnicalSupportList AS TABLE OF REF TechnicalSupport;
/

CREATE OR REPLACE TYPE Airport AS OBJECT (
    IATA                    CHAR(3),
    Name                    VARCHAR2(150),
    Location                VARCHAR2(255),
    Technical_Support_List  TechnicalSupportList
);
/

CREATE TABLE Airport_Table OF Airport
    NESTED TABLE Technical_Support_List STORE AS Airport_Technical_Support_Table;
/

ALTER TABLE Airport_Table 
  ADD CONSTRAINT PK_Airport 
  PRIMARY KEY (IATA);
/
