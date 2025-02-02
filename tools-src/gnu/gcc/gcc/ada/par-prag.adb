------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                             P A R . P R A G                              --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$
--                                                                          --
--          Copyright (C) 1992-2001 Free Software Foundation, Inc.          --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNAT;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

--  Generally the parser checks the basic syntax of pragmas, but does not
--  do specialized syntax checks for individual pragmas, these are deferred
--  to semantic analysis time (see unit Sem_Prag). There are some pragmas
--  which require recognition and either partial or complete processing
--  during parsing, and this unit performs this required processing.

with Fname.UF; use Fname.UF;
with Osint;    use Osint;
with Stringt;  use Stringt;
with Stylesw;  use Stylesw;
with Uintp;    use Uintp;
with Uname;    use Uname;

separate (Par)

function Prag (Pragma_Node : Node_Id; Semi : Source_Ptr) return Node_Id is
   Pragma_Name : constant Name_Id    := Chars (Pragma_Node);
   Pragma_Sloc : constant Source_Ptr := Sloc (Pragma_Node);
   Arg_Count   : Nat;
   Arg_Node    : Node_Id;

   -----------------------
   -- Local Subprograms --
   -----------------------

   function Arg1 return Node_Id;
   function Arg2 return Node_Id;
   function Arg3 return Node_Id;
   function Arg4 return Node_Id;
   --  Obtain specified Pragma_Argument_Association. It is allowable to call
   --  the routine for the argument one past the last present argument, but
   --  that is the only case in which a non-present argument can be referenced.

   procedure Check_Arg_Count (Required : Int);
   --  Check argument count for pragma = Required.
   --  If not give error and raise Error_Resync.

   procedure Check_Arg_Is_String_Literal (Arg : Node_Id);
   --  Check the expression of the specified argument to make sure that it
   --  is a string literal. If not give error and raise Error_Resync.

   procedure Check_Arg_Is_On_Or_Off (Arg : Node_Id);
   --  Check the expression of the specified argument to make sure that it
   --  is an identifier which is either ON or OFF, and if not, then issue
   --  an error message and raise Error_Resync.

   procedure Check_No_Identifier (Arg : Node_Id);
   --  Checks that the given argument does not have an identifier. If an
   --  identifier is present, then an error message is issued, and
   --  Error_Resync is raised.

   procedure Check_Optional_Identifier (Arg : Node_Id; Id : Name_Id);
   --  Checks if the given argument has an identifier, and if so, requires
   --  it to match the given identifier name. If there is a non-matching
   --  identifier, then an error message is given and Error_Resync raised.

   procedure Check_Required_Identifier (Arg : Node_Id; Id : Name_Id);
   --  Same as Check_Optional_Identifier, except that the name is required
   --  to be present and to match the given Id value.

   ----------
   -- Arg1 --
   ----------

   function Arg1 return Node_Id is
   begin
      return First (Pragma_Argument_Associations (Pragma_Node));
   end Arg1;

   ----------
   -- Arg2 --
   ----------

   function Arg2 return Node_Id is
   begin
      return Next (Arg1);
   end Arg2;

   ----------
   -- Arg3 --
   ----------

   function Arg3 return Node_Id is
   begin
      return Next (Arg2);
   end Arg3;

   ----------
   -- Arg4 --
   ----------

   function Arg4 return Node_Id is
   begin
      return Next (Arg3);
   end Arg4;

   ---------------------
   -- Check_Arg_Count --
   ---------------------

   procedure Check_Arg_Count (Required : Int) is
   begin
      if Arg_Count /= Required then
         Error_Msg ("wrong number of arguments for pragma%", Pragma_Sloc);
         raise Error_Resync;
      end if;
   end Check_Arg_Count;

   ----------------------------
   -- Check_Arg_Is_On_Or_Off --
   ----------------------------

   procedure Check_Arg_Is_On_Or_Off (Arg : Node_Id) is
      Argx : constant Node_Id := Expression (Arg);

   begin
      if Nkind (Expression (Arg)) /= N_Identifier
        or else (Chars (Argx) /= Name_On
                   and then
                 Chars (Argx) /= Name_Off)
      then
         Error_Msg_Name_2 := Name_On;
         Error_Msg_Name_3 := Name_Off;

         Error_Msg
           ("argument for pragma% must be% or%", Sloc (Argx));
         raise Error_Resync;
      end if;
   end Check_Arg_Is_On_Or_Off;

   ---------------------------------
   -- Check_Arg_Is_String_Literal --
   ---------------------------------

   procedure Check_Arg_Is_String_Literal (Arg : Node_Id) is
   begin
      if Nkind (Expression (Arg)) /= N_String_Literal then
         Error_Msg
           ("argument for pragma% must be string literal",
             Sloc (Expression (Arg)));
         raise Error_Resync;
      end if;
   end Check_Arg_Is_String_Literal;

   -------------------------
   -- Check_No_Identifier --
   -------------------------

   procedure Check_No_Identifier (Arg : Node_Id) is
   begin
      if Chars (Arg) /= No_Name then
         Error_Msg_N ("pragma% does not permit named arguments", Arg);
         raise Error_Resync;
      end if;
   end Check_No_Identifier;

   -------------------------------
   -- Check_Optional_Identifier --
   -------------------------------

   procedure Check_Optional_Identifier (Arg : Node_Id; Id : Name_Id) is
   begin
      if Present (Arg) and then Chars (Arg) /= No_Name then
         if Chars (Arg) /= Id then
            Error_Msg_Name_2 := Id;
            Error_Msg_N ("pragma% argument expects identifier%", Arg);
         end if;
      end if;
   end Check_Optional_Identifier;

   -------------------------------
   -- Check_Required_Identifier --
   -------------------------------

   procedure Check_Required_Identifier (Arg : Node_Id; Id : Name_Id) is
   begin
      if Chars (Arg) /= Id then
         Error_Msg_Name_2 := Id;
         Error_Msg_N ("pragma% argument must have identifier%", Arg);
      end if;
   end Check_Required_Identifier;

   ----------
   -- Prag --
   ----------

begin
   Error_Msg_Name_1 := Pragma_Name;

   --  Count number of arguments. This loop also checks if any of the arguments
   --  are Error, indicating a syntax error as they were parsed. If so, we
   --  simply return, because we get into trouble with cascaded errors if we
   --  try to perform our error checks on junk arguments.

   Arg_Count := 0;

   if Present (Pragma_Argument_Associations (Pragma_Node)) then
      Arg_Node := Arg1;

      while Arg_Node /= Empty loop
         Arg_Count := Arg_Count + 1;

         if Expression (Arg_Node) = Error then
            return Error;
         end if;

         Next (Arg_Node);
      end loop;
   end if;

   --  Remaining processing is pragma dependent

   case Get_Pragma_Id (Pragma_Name) is

      ------------
      -- Ada_83 --
      ------------

      --  This pragma must be processed at parse time, since we want to set
      --  the Ada 83 and Ada 95 switches properly at parse time to recognize
      --  Ada 83 syntax or Ada 95 syntax as appropriate.

      when Pragma_Ada_83 =>
         Ada_83 := True;
         Ada_95 := False;

      ------------
      -- Ada_95 --
      ------------

      --  This pragma must be processed at parse time, since we want to set
      --  the Ada 83 and Ada_95 switches properly at parse time to recognize
      --  Ada 83 syntax or Ada 95 syntax as appropriate.

      when Pragma_Ada_95 =>
         Ada_83 := False;
         Ada_95 := True;

      -----------
      -- Debug --
      -----------

      --  pragma Debug (PROCEDURE_CALL_STATEMENT);

      --  This has to be processed by the parser because of the very peculiar
      --  form of the second parameter, which is syntactically from a formal
      --  point of view a function call (since it must be an expression), but
      --  semantically we treat it as a procedure call (which has exactly the
      --  same syntactic form, so that's why we can get away with this!)

      when Pragma_Debug =>
         Check_Arg_Count (1);
         Check_No_Identifier (Arg1);

         declare
            Expr : constant Node_Id := New_Copy (Expression (Arg1));

         begin
            if Nkind (Expr) /= N_Indexed_Component
              and then Nkind (Expr) /= N_Function_Call
              and then Nkind (Expr) /= N_Identifier
              and then Nkind (Expr) /= N_Selected_Component
            then
               Error_Msg
                 ("argument of pragma% is not procedure call", Sloc (Expr));
               raise Error_Resync;
            else
               Set_Debug_Statement
                 (Pragma_Node, P_Statement_Name (Expr));
            end if;
         end;

      -------------------------------
      -- Extensions_Allowed (GNAT) --
      -------------------------------

      --  pragma Extensions_Allowed (Off | On)

      --  The processing for pragma Extensions_Allowed must be done at
      --  parse time, since extensions mode may affect what is accepted.

      when Pragma_Extensions_Allowed =>
         Check_Arg_Count (1);
         Check_No_Identifier (Arg1);
         Check_Arg_Is_On_Or_Off (Arg1);
         Opt.Extensions_Allowed := (Chars (Expression (Arg1)) = Name_On);

      ----------------
      -- List (2.8) --
      ----------------

      --  pragma List (Off | On)

      --  The processing for pragma List must be done at parse time,
      --  since a listing can be generated in parse only mode.

      when Pragma_List =>
         Check_Arg_Count (1);
         Check_No_Identifier (Arg1);
         Check_Arg_Is_On_Or_Off (Arg1);

         --  We unconditionally make a List_On entry for the pragma, so that
         --  in the List (Off) case, the pragma will print even in a region
         --  of code with listing turned off (this is required!)

         List_Pragmas.Increment_Last;
         List_Pragmas.Table (List_Pragmas.Last) :=
           (Ptyp => List_On, Ploc => Sloc (Pragma_Node));

         --  Now generate the list off entry for pragma List (Off)

         if Chars (Expression (Arg1)) = Name_Off then
            List_Pragmas.Increment_Last;
            List_Pragmas.Table (List_Pragmas.Last) :=
              (Ptyp => List_Off, Ploc => Semi);
         end if;

      ----------------
      -- Page (2.8) --
      ----------------

      --  pragma Page;

      --  Processing for this pragma must be done at parse time, since a
      --  listing can be generated in parse only mode with semantics off.

      when Pragma_Page =>
         Check_Arg_Count (0);
         List_Pragmas.Increment_Last;
         List_Pragmas.Table (List_Pragmas.Last) := (Page, Semi);

      -----------------------------
      -- Source_File_Name (GNAT) --
      -----------------------------

      --  There are five forms of this pragma:

      --  pragma Source_File_Name (
      --    [UNIT_NAME      =>] unit_NAME,
      --     BODY_FILE_NAME =>  STRING_LITERAL);

      --  pragma Source_File_Name (
      --    [UNIT_NAME      =>] unit_NAME,
      --     SPEC_FILE_NAME =>  STRING_LITERAL);

      --  pragma Source_File_Name (
      --     BODY_FILE_NAME  => STRING_LITERAL
      --  [, DOT_REPLACEMENT => STRING_LITERAL]
      --  [, CASING          => CASING_SPEC]);

      --  pragma Source_File_Name (
      --     SPEC_FILE_NAME  => STRING_LITERAL
      --  [, DOT_REPLACEMENT => STRING_LITERAL]
      --  [, CASING          => CASING_SPEC]);

      --  pragma Source_File_Name (
      --     SUBUNIT_FILE_NAME  => STRING_LITERAL
      --  [, DOT_REPLACEMENT    => STRING_LITERAL]
      --  [, CASING             => CASING_SPEC]);

      --  CASING_SPEC ::= Uppercase | Lowercase | Mixedcase

      --  Note: we process this during parsing, since we need to have the
      --  source file names set well before the semantic analysis starts,
      --  since we load the spec and with'ed packages before analysis.

      when Pragma_Source_File_Name => Source_File_Name : declare
         Unam  : Unit_Name_Type;
         Expr1 : Node_Id;
         Pat   : String_Ptr;
         Typ   : Character;
         Dot   : String_Ptr;
         Cas   : Casing_Type;
         Nast  : Nat;

         function Get_Fname (Arg : Node_Id) return Name_Id;
         --  Process file name from unit name form of pragma

         function Get_String_Argument (Arg : Node_Id) return String_Ptr;
         --  Process string literal value from argument

         procedure Process_Casing (Arg : Node_Id);
         --  Process Casing argument of pattern form of pragma

         procedure Process_Dot_Replacement (Arg : Node_Id);
         --  Process Dot_Replacement argument of patterm form of pragma

         ---------------
         -- Get_Fname --
         ---------------

         function Get_Fname (Arg : Node_Id) return Name_Id is
         begin
            String_To_Name_Buffer (Strval (Expression (Arg)));

            for J in 1 .. Name_Len loop
               if Is_Directory_Separator (Name_Buffer (J)) then
                  Error_Msg
                    ("directory separator character not allowed",
                     Sloc (Expression (Arg)) + Source_Ptr (J));
               end if;
            end loop;

            return Name_Find;
         end Get_Fname;

         -------------------------
         -- Get_String_Argument --
         -------------------------

         function Get_String_Argument (Arg : Node_Id) return String_Ptr is
            Str : String_Id;

         begin
            if Nkind (Expression (Arg)) /= N_String_Literal
              and then
               Nkind (Expression (Arg)) /= N_Operator_Symbol
            then
               Error_Msg_N
                 ("argument for pragma% must be string literal", Arg);
               raise Error_Resync;
            end if;

            Str := Strval (Expression (Arg));

            --  Check string has no wide chars

            for J in 1 .. String_Length (Str) loop
               if Get_String_Char (Str, J) > 255 then
                  Error_Msg
                    ("wide character not allowed in pattern for pragma%",
                     Sloc (Expression (Arg2)) + Text_Ptr (J) - 1);
               end if;
            end loop;

            --  Acquire string

            String_To_Name_Buffer (Str);
            return new String'(Name_Buffer (1 .. Name_Len));
         end Get_String_Argument;

         --------------------
         -- Process_Casing --
         --------------------

         procedure Process_Casing (Arg : Node_Id) is
            Expr : constant Node_Id := Expression (Arg);

         begin
            Check_Required_Identifier (Arg, Name_Casing);

            if Nkind (Expr) = N_Identifier then
               if Chars (Expr) = Name_Lowercase then
                  Cas := All_Lower_Case;
                  return;
               elsif Chars (Expr) = Name_Uppercase then
                  Cas := All_Upper_Case;
                  return;
               elsif Chars (Expr) = Name_Mixedcase then
                  Cas := Mixed_Case;
                  return;
               end if;
            end if;

            Error_Msg_N
              ("Casing argument for pragma% must be " &
               "one of Mixedcase, Lowercase, Uppercase",
               Arg);
         end Process_Casing;

         -----------------------------
         -- Process_Dot_Replacement --
         -----------------------------

         procedure Process_Dot_Replacement (Arg : Node_Id) is
         begin
            Check_Required_Identifier (Arg, Name_Dot_Replacement);
            Dot := Get_String_Argument (Arg);
         end Process_Dot_Replacement;

      --  Start of processing for Source_File_Name pragma

      begin
         --  We permit from 1 to 3 arguments

         if Arg_Count not in 1 .. 3 then
            Check_Arg_Count (1);
         end if;

         Expr1 := Expression (Arg1);

         --  If first argument is identifier or selected component, then
         --  we have the specific file case of the Source_File_Name pragma,
         --  and the first argument is a unit name.

         if Nkind (Expr1) = N_Identifier
           or else
             (Nkind (Expr1) = N_Selected_Component
               and then
              Nkind (Selector_Name (Expr1)) = N_Identifier)
         then
            Check_Arg_Count (2);

            Check_Optional_Identifier (Arg1, Name_Unit_Name);
            Unam := Get_Unit_Name (Expr1);

            Check_Arg_Is_String_Literal (Arg2);

            if Chars (Arg2) = Name_Spec_File_Name then
               Set_File_Name (Get_Spec_Name (Unam), Get_Fname (Arg2));

            elsif Chars (Arg2) = Name_Body_File_Name then
               Set_File_Name (Unam, Get_Fname (Arg2));

            else
               Error_Msg_N ("pragma% argument has incorrect identifier", Arg2);
               return Pragma_Node;
            end if;

         --  If the first argument is not an identifier, then we must have
         --  the pattern form of the pragma, and the first argument must be
         --  the pattern string with an appropriate name.

         else
            if Chars (Arg1) = Name_Spec_File_Name then
               Typ := 's';

            elsif Chars (Arg1) = Name_Body_File_Name then
               Typ := 'b';

            elsif Chars (Arg1) = Name_Subunit_File_Name then
               Typ := 'u';

            elsif Chars (Arg1) = Name_Unit_Name then
               Error_Msg_N
                 ("Unit_Name parameter for pragma% must be an identifier",
                  Arg1);
               raise Error_Resync;

            else
               Error_Msg_N ("pragma% argument has incorrect identifier", Arg1);
               raise Error_Resync;
            end if;

            Pat := Get_String_Argument (Arg1);

            --  Check pattern has exactly one asterisk

            Nast := 0;
            for J in Pat'Range loop
               if Pat (J) = '*' then
                  Nast := Nast + 1;
               end if;
            end loop;

            if Nast /= 1 then
               Error_Msg_N
                 ("file name pattern must have exactly one * character",
                  Arg2);
               return Pragma_Node;
            end if;

            --  Set defaults for Casing and Dot_Separator parameters

            Cas := All_Lower_Case;

            Dot := new String'(".");

            --  Process second and third arguments if present

            if Arg_Count > 1 then
               if Chars (Arg2) = Name_Casing then
                  Process_Casing (Arg2);

                  if Arg_Count = 3 then
                     Process_Dot_Replacement (Arg3);
                  end if;

               else
                  Process_Dot_Replacement (Arg2);

                  if Arg_Count = 3 then
                     Process_Casing (Arg3);
                  end if;
               end if;
            end if;

            Set_File_Name_Pattern (Pat, Typ, Dot, Cas);
         end if;
      end Source_File_Name;

      -----------------------------
      -- Source_Reference (GNAT) --
      -----------------------------

      --  pragma Source_Reference
      --    (INTEGER_LITERAL [, STRING_LITERAL] );

      --  Processing for this pragma must be done at parse time, since error
      --  messages needing the proper line numbers can be generated in parse
      --  only mode with semantic checking turned off, and indeed we usually
      --  turn off semantic checking anyway if any parse errors are found.

      when Pragma_Source_Reference => Source_Reference : declare
         Fname : Name_Id;

      begin
         if Arg_Count /= 1 then
            Check_Arg_Count (2);
            Check_No_Identifier (Arg2);
         end if;

         --  Check that this is first line of file. We skip this test if
         --  we are in syntax check only mode, since we may be dealing with
         --  multiple compilation units.

         if Get_Physical_Line_Number (Pragma_Sloc) /= 1
           and then Num_SRef_Pragmas (Current_Source_File) = 0
           and then Operating_Mode /= Check_Syntax
         then
            Error_Msg
              ("first % pragma must be first line of file", Pragma_Sloc);
            raise Error_Resync;
         end if;

         Check_No_Identifier (Arg1);

         if Arg_Count = 1 then
            if Num_SRef_Pragmas (Current_Source_File) = 0 then
               Error_Msg
                 ("file name required for first % pragma in file",
                  Pragma_Sloc);
               raise Error_Resync;

            else
               Fname := No_Name;
            end if;

         --  File name present

         else
            Check_Arg_Is_String_Literal (Arg2);
            String_To_Name_Buffer (Strval (Expression (Arg2)));
            Fname := Name_Find;

            if Num_SRef_Pragmas (Current_Source_File) > 0 then
               if Fname /= Full_Ref_Name (Current_Source_File) then
                  Error_Msg
                    ("file name must be same in all % pragmas", Pragma_Sloc);
                  raise Error_Resync;
               end if;
            end if;
         end if;

         if Nkind (Expression (Arg1)) /= N_Integer_Literal then
            Error_Msg
              ("argument for pragma% must be integer literal",
                Sloc (Expression (Arg1)));
            raise Error_Resync;

         --  OK, this source reference pragma is effective, however, we
         --  ignore it if it is not in the first unit in the multiple unit
         --  case. This is because the only purpose in this case is to
         --  provide source pragmas for subsequent use by gnatchop.

         else
            if Num_Library_Units = 1 then
               Register_Source_Ref_Pragma
                 (Fname,
                  Strip_Directory (Fname),
                  UI_To_Int (Intval (Expression (Arg1))),
                  Get_Physical_Line_Number (Pragma_Sloc) + 1);
            end if;
         end if;
      end Source_Reference;

      -------------------------
      -- Style_Checks (GNAT) --
      -------------------------

      --  pragma Style_Checks (On | Off | ALL_CHECKS | STRING_LITERAL);

      --  This is processed by the parser since some of the style
      --  checks take place during source scanning and parsing.

      when Pragma_Style_Checks => Style_Checks : declare
         A  : Node_Id;
         S  : String_Id;
         C  : Char_Code;
         OK : Boolean := True;

      begin
         --  Two argument case is only for semantics

         if Arg_Count = 2 then
            null;

         else
            Check_Arg_Count (1);
            Check_No_Identifier (Arg1);
            A := Expression (Arg1);

            if Nkind (A) = N_String_Literal then
               S   := Strval (A);

               declare
                  Slen    : Natural := Natural (String_Length (S));
                  Options : String (1 .. Slen);
                  J       : Natural;
                  Ptr     : Natural;

               begin
                  J := 1;
                  loop
                     C := Get_String_Char (S, Int (J));

                     if not In_Character_Range (C) then
                        OK := False;
                        Ptr := J;
                        exit;

                     else
                        Options (J) := Get_Character (C);
                     end if;

                     if J = Slen then
                        Set_Style_Check_Options (Options, OK, Ptr);
                        exit;

                     else
                        J := J + 1;
                     end if;
                  end loop;

                  if not OK then
                     Error_Msg
                       ("invalid style check option",
                        Sloc (Expression (Arg1)) + Source_Ptr (Ptr));
                     raise Error_Resync;
                  end if;
               end;

            elsif Nkind (A) /= N_Identifier then
               OK := False;

            elsif Chars (A) = Name_All_Checks then
               Stylesw.Set_Default_Style_Check_Options;

            elsif Chars (A) = Name_On then
               Style_Check := True;

            elsif Chars (A) = Name_Off then
               Style_Check := False;

            else
               OK := False;
            end if;

            if not OK then
               Error_Msg ("incorrect argument for pragma%", Sloc (A));
               raise Error_Resync;
            end if;
         end if;
      end Style_Checks;

      ---------------------
      -- Warnings (GNAT) --
      ---------------------

      --  pragma Warnings (On | Off, [LOCAL_NAME])

      --  The one argument case is processed by the parser, since it may
      --  control parser warnings as well as semantic warnings, and in any
      --  case we want to be absolutely sure that the range in the warnings
      --  table is set well before any semantic analysis is performed.

      when Pragma_Warnings =>
         if Arg_Count = 1 then
            Check_No_Identifier (Arg1);
            Check_Arg_Is_On_Or_Off (Arg1);

            if Chars (Expression (Arg1)) = Name_On then
               Set_Warnings_Mode_On (Pragma_Sloc);
            else
               Set_Warnings_Mode_Off (Pragma_Sloc);
            end if;
         end if;

      -----------------------
      -- All Other Pragmas --
      -----------------------

      --  For all other pragmas, checking and processing is handled
      --  entirely in Sem_Prag, and no further checking is done by Par.

      when Pragma_Abort_Defer              |
           Pragma_AST_Entry                |
           Pragma_All_Calls_Remote         |
           Pragma_Annotate                 |
           Pragma_Assert                   |
           Pragma_Asynchronous             |
           Pragma_Atomic                   |
           Pragma_Atomic_Components        |
           Pragma_Attach_Handler           |
           Pragma_CPP_Class                |
           Pragma_CPP_Constructor          |
           Pragma_CPP_Virtual              |
           Pragma_CPP_Vtable               |
           Pragma_C_Pass_By_Copy           |
           Pragma_Comment                  |
           Pragma_Common_Object            |
           Pragma_Complex_Representation   |
           Pragma_Component_Alignment      |
           Pragma_Controlled               |
           Pragma_Convention               |
           Pragma_Discard_Names            |
           Pragma_Eliminate                |
           Pragma_Elaborate                |
           Pragma_Elaborate_All            |
           Pragma_Elaborate_Body           |
           Pragma_Elaboration_Checks       |
           Pragma_Export                   |
           Pragma_Export_Exception         |
           Pragma_Export_Function          |
           Pragma_Export_Object            |
           Pragma_Export_Procedure         |
           Pragma_Export_Valued_Procedure  |
           Pragma_Extend_System            |
           Pragma_External                 |
           Pragma_External_Name_Casing     |
           Pragma_Finalize_Storage_Only    |
           Pragma_Float_Representation     |
           Pragma_Ident                    |
           Pragma_Import                   |
           Pragma_Import_Exception         |
           Pragma_Import_Function          |
           Pragma_Import_Object            |
           Pragma_Import_Procedure         |
           Pragma_Import_Valued_Procedure  |
           Pragma_Initialize_Scalars       |
           Pragma_Inline                   |
           Pragma_Inline_Always            |
           Pragma_Inline_Generic           |
           Pragma_Inspection_Point         |
           Pragma_Interface                |
           Pragma_Interface_Name           |
           Pragma_Interrupt_Handler        |
           Pragma_Interrupt_Priority       |
           Pragma_Java_Constructor         |
           Pragma_Java_Interface           |
           Pragma_License                  |
           Pragma_Link_With                |
           Pragma_Linker_Alias             |
           Pragma_Linker_Options           |
           Pragma_Linker_Section           |
           Pragma_Locking_Policy           |
           Pragma_Long_Float               |
           Pragma_Machine_Attribute        |
           Pragma_Main                     |
           Pragma_Main_Storage             |
           Pragma_Memory_Size              |
           Pragma_No_Return                |
           Pragma_No_Run_Time              |
           Pragma_Normalize_Scalars        |
           Pragma_Optimize                 |
           Pragma_Pack                     |
           Pragma_Passive                  |
           Pragma_Polling                  |
           Pragma_Preelaborate             |
           Pragma_Priority                 |
           Pragma_Propagate_Exceptions     |
           Pragma_Psect_Object             |
           Pragma_Pure                     |
           Pragma_Pure_Function            |
           Pragma_Queuing_Policy           |
           Pragma_Remote_Call_Interface    |
           Pragma_Remote_Types             |
           Pragma_Restrictions             |
           Pragma_Restricted_Run_Time      |
           Pragma_Ravenscar                |
           Pragma_Reviewable               |
           Pragma_Share_Generic            |
           Pragma_Shared                   |
           Pragma_Shared_Passive           |
           Pragma_Storage_Size             |
           Pragma_Storage_Unit             |
           Pragma_Stream_Convert           |
           Pragma_Subtitle                 |
           Pragma_Suppress                 |
           Pragma_Suppress_All             |
           Pragma_Suppress_Debug_Info      |
           Pragma_Suppress_Initialization  |
           Pragma_System_Name              |
           Pragma_Task_Dispatching_Policy  |
           Pragma_Task_Info                |
           Pragma_Task_Name                |
           Pragma_Task_Storage             |
           Pragma_Time_Slice               |
           Pragma_Title                    |
           Pragma_Unchecked_Union          |
           Pragma_Unimplemented_Unit       |
           Pragma_Unreserve_All_Interrupts |
           Pragma_Unsuppress               |
           Pragma_Use_VADS_Size            |
           Pragma_Volatile                 |
           Pragma_Volatile_Components      |
           Pragma_Weak_External            |
           Pragma_Validity_Checks          =>
         null;

   end case;

   return Pragma_Node;

   --------------------
   -- Error Handling --
   --------------------

exception
   when Error_Resync =>
      return Error;

end Prag;
