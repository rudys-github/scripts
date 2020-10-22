rem =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
rem Program: FrgnKeys.sql
rem Type   : PL/SQL script
rem Input  : table_name  varchar2(30) (no wildcards)
rem        : schema_name varchar2(30) (no wildcards)
rem Output : 'schema_name'.'table_name'.sql SQL script
rem Date   : 01-03-96
rem Author : Ruud de Gunst, Quality Pro Database Technology bv
rem Purpose: Generating a SQL ddl script for disabling/enabling
rem          foreign key constraints referencing a given table.
rem =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

set pagesize     0
set linesize   256
set verify     off
set feedback   off
set numwidth    15
set space        1
set long     32676
set trimspool   on

set serveroutput on size 999999

prompt
prompt Create disable/enable or drop/create ddl scripts for
prompt foreign key constraints
accept table prompt '  referenced table    (wildcards %_): '
accept owner prompt '  owned by            (no wildcards): '
accept destr prompt '  [D]estructive or [N]on-destructive: '
prompt

set termout off

column tab     new_value low_table
column own     new_value low_owner
column dst     new_value low_destr
column dst_str new_value destr_string

select lower('&&owner')           own
      ,lower('&&table')           tab
      ,lower(nvl('&&destr', 'n')) dst
      ,decode (
          upper('&&destr')
         ,'D', 'Dropping/Creating'
         ,'N', 'Disabling/Enabling'
         ,'Disabling/Enabling'
       )                          dst_str
from   dual
;

set termout on

prompt
prompt Spooling to file &&low_owner..&&low_table..frgn.sql
prompt Creating SQL script for &&destr_string fk constraints
prompt referencing &&owner..&&table ...
prompt

declare
  /*
   = Begin Cursor Declaration
  */
  cursor cSelPriUnqKeys (
     cPriUnqOwner varchar2
    ,cPriUnqTable varchar2
  )
  is
    select
       con1.owner           owner
      ,con1.table_name      table_name
      ,con1.constraint_name constraint_name
    from
       sys.dba_constraints con1
    where con1.owner              = cPriUnqOwner
    and   con1.table_name      like cPriUnqTable
    and   con1.constraint_type   in ('P', 'U')
    and   exists (
      select
         1
      from
         sys.dba_constraints con2
      where con2.r_owner           = con1.owner
      and   con2.r_constraint_name = con1.constraint_name
    )
  ;

  /*
   = End Cursor Declaration
   =
   = Begin Variable Declaration
  */

  cursor1HDL          integer := dbms_sql.open_cursor;
  cursor2HDL          integer := dbms_sql.open_cursor;
  cursor3HDL          integer := dbms_sql.open_cursor;
  cursor4HDL          integer := dbms_sql.open_cursor;
  nr_of_rows          integer;
  vSeparator          varchar2(24);
  iOwner              varchar2(30);
  iTable              varchar2(30);
  iDestr              varchar2(1);
  vFrgnKeyOwner       varchar2(30);
  vFrgnKeyTable       varchar2(30);
  vFrgnKeyColumn      varchar2(30);
  vFrgnKeyConstraint  varchar2(30);
  vFrgnKeyStatus      varchar2(8);
  vFrgnDeleteRule     varchar2(24);
  vStatement          varchar2(32676);
  vLine               integer := 0;
  i                   integer;

  /*
   = End Variable Declaration
   =
   = Begin Procedural Declaration
  */
  procedure insert_command_string
  is
  begin
    vLine := vLine + 1;

    dbms_sql.bind_variable (
       cursor4HDL
      ,':counter'
      ,vLine
    );

    dbms_sql.bind_variable (
       cursor4HDL
      ,':owner_name'
      ,iOwner
    );

    dbms_sql.bind_variable (
       cursor4HDL
      ,':table_name'
      ,iTable
    );

    dbms_sql.bind_variable (
       cursor4HDL
      ,':frgn_stat'
      ,vStatement
    );

    nr_of_rows := dbms_sql.execute(cursor4HDL);

    vStatement := null;
  end;

  /*
   = End Procedural Declaration
  */


begin
  /*
   = Setting initial values.
  */
  iOwner := upper('&&owner');
  iTable := upper('&&table');
  iDestr := upper('&&destr');

  /*
   = Drop table frgnkey_strings.
  */
  begin
    dbms_sql.parse (
       cursor1HDL
      ,'drop table frgnkey_strings
       '
      ,dbms_sql.v7
    );

    nr_of_rows := dbms_sql.execute(cursor1HDL);
  exception
    /*
     = Doesn't matter if the table exists or not
    */
    when others then
      null;
  end;

  /*
   = Create table frgnkey_strings.
  */
  dbms_sql.parse (
     cursor1HDL
    ,'create table frgnkey_strings (
         counter         number
        ,owner           varchar2(30)
        ,table_name      varchar2(30)
        ,frgnkey_string  long
      )
     '
    ,dbms_sql.v7
  );

  nr_of_rows := dbms_sql.execute(cursor1HDL);

  /*
   = Create unique index on frgnkey_strings.
  */
  dbms_sql.parse (
     cursor1HDL
    ,'create unique index pk_frgnkey_strings
      on frgnkey_strings (
         counter
        ,owner
        ,table_name
      )
     '
    ,dbms_sql.v7
  );

  nr_of_rows := dbms_sql.execute(cursor1HDL);

  dbms_sql.close_cursor (cursor1HDL);

  /*
   = Select referencing foreign key constraints.
  */
  dbms_sql.parse (
     cursor2HDL
    ,'select distinct
        con1.owner
      , con1.table_name
      , con1.constraint_name
      , decode (
          con1.status
        , ''ENABLED'', ''enable''
        , ''disable''
        )
      , decode (
          con1.delete_rule
        , ''CASCADE'', ''on delete cascade''
        , ''SET NULL'', ''on delete set null''
        , ''--''
        )
      from
        sys.dba_constraints  con1
      where con1.constraint_type    = ''R''
      and   con1.status             = decode ( ''' || iDestr || '''
                                      , ''N'', ''ENABLED''
                                      , con1.status
                                      )
      and   exists (
        select
          1
        from
          sys.dba_constraints con2
        where con1.r_owner           = con2.owner
        and   con1.r_constraint_name = con2.constraint_name
        and   con2.owner             = :puk_owner
        and   con2.table_name        = :puk_table
        and   con2.constraint_name   = :puk_constraint
      )
      order by
         con1.constraint_name
     '
    ,dbms_sql.v7
  );

  dbms_sql.define_column (
     cursor2HDL
    ,1
    ,vFrgnKeyOwner
    ,30
  );

  dbms_sql.define_column (
     cursor2HDL
    ,2
    ,vFrgnKeyTable
    ,30
  );

  dbms_sql.define_column (
     cursor2HDL
    ,3
    ,vFrgnKeyConstraint
    ,30
  );

  dbms_sql.define_column (
     cursor2HDL
    ,4
    ,vFrgnKeyStatus
    ,8
  );

  dbms_sql.define_column (
     cursor2HDL
    ,5
    ,vFrgnDeleteRule
    ,24
  );


  /*
   = Select referenced or referencing columns
   = in foreign key constraint.
  */
  dbms_sql.parse (
     cursor3HDL
    ,'select
         ccl.owner
        ,ccl.table_name
        ,ccl.column_name
      from
         sys.dba_cons_columns ccl
      where ccl.owner           = :cons_owner
      and   ccl.table_name      = :cons_table
      and   ccl.constraint_name = :cons_constraint
      order by
         ccl.position
     '
    ,dbms_sql.v7
  );

  dbms_sql.define_column (
     cursor3HDL
    ,1
    ,vFrgnKeyOwner
    ,30
  );

  dbms_sql.define_column (
     cursor3HDL
    ,2
    ,vFrgnKeyTable
    ,30
  );

  dbms_sql.define_column (
     cursor3HDL
    ,3
    ,vFrgnKeyColumn
    ,30
  );

  /*
   = Insert through dynamic SQL
  */
  dbms_sql.parse (
     cursor4HDL
    ,'insert into frgnkey_strings (
         counter
        ,owner
        ,table_name
        ,frgnkey_string
      ) values (
         :counter
        ,:owner_name
        ,:table_name
        ,:frgn_stat
      )
     '
    ,dbms_sql.v7
  );

  vStatement := 
  'rem =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
  || chr(10) ||
  'rem              Output of foreign key disable/enable utility'
  || chr(10) ||
  'rem                 Copyright: Ruud de Gunst, March 1996'
  || chr(10) ||
  'rem                       ' || to_char(sysdate, 'Month DD, YYYY HH24:MI')
  || chr(10) ||
  'rem =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
  ;

  insert_command_string;

  /*
   = Get Foreign Key DDL
  */
  <<pu_key_constraints>>
  for rSelPriUnqKeys in cSelPriUnqKeys(iOwner, iTable)
  loop
    dbms_sql.bind_variable (
       cursor2HDL
      ,':puk_owner'
      ,rSelPriUnqKeys.owner
    );

    dbms_sql.bind_variable (
       cursor2HDL
      ,':puk_table'
      ,rSelPriUnqKeys.table_name
    );

    dbms_sql.bind_variable (
       cursor2HDL
      ,':puk_constraint'
      ,rSelPriUnqKeys.constraint_name
    );

    nr_of_rows := dbms_sql.execute (cursor2HDL);

    i := 0;

    <<frgn_key_constraints>>
    while dbms_sql.fetch_rows (cursor2HDL) > 0
    loop
      dbms_sql.column_value (
         cursor2HDL
        ,1
        ,vFrgnKeyOwner
      );

      dbms_sql.column_value (
         cursor2HDL
        ,2
        ,vFrgnKeyTable
      );

      dbms_sql.column_value (
         cursor2HDL
        ,3
        ,vFrgnKeyConstraint
      );

      dbms_sql.column_value (
         cursor2HDL
        ,4
        ,vFrgnKeyStatus
      );

      dbms_sql.column_value (
         cursor2HDL
        ,5
        ,vFrgnDeleteRule
      );

      if iDestr = 'N'
      then
        vStatement :=
           chr(10) ||
          'rem -disable- rem prompt' || chr(10) ||
          'rem -disable- rem prompt Disable Foreign Key on ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -disable- rem prompt' || chr(10) ||
          'rem -disable- rem alter table ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -disable- rem disable constraint ' ||
           vFrgnKeyConstraint || chr(10) ||
          'rem -disable- rem ;'
          || chr(10) || chr(10) ||
          'rem -enable- rem prompt' || chr(10) ||
          'rem -enable- rem prompt Enable Foreign Key on ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -enable- rem prompt' || chr(10) ||
          'rem -enable- rem alter table ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -enable- rem enable constraint ' ||
           vFrgnKeyConstraint || chr(10) ||
          'rem -enable- rem ;'
        ; 

        insert_command_string;
      else
        -- &&destr = 'D'
        /*
         = Bind variables for retrieving the constraint_columns
         = belonging to the referencing foreign key constraint.
        */
        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_owner'
          ,vFrgnKeyOwner
        );

        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_table'
          ,vFrgnKeyTable
        );

        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_constraint'
          ,vFrgnKeyConstraint
        );

        nr_of_rows := dbms_sql.execute(cursor3HDL);

        vStatement :=
           chr(10) ||
          'rem -drop- rem prompt' || chr(10) ||
          'rem -drop- rem prompt Drop Foreign Key on ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -drop- rem prompt' || chr(10) ||
          'rem -drop- rem alter table ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -drop- rem drop constraint ' ||
           vFrgnKeyConstraint || chr(10) ||
          'rem -drop- rem ;'
          || chr(10) || chr(10) ||
          'rem -create- rem prompt' || chr(10) ||
          'rem -create- rem prompt Create Foreign Key on ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -create- rem prompt' || chr(10) ||
          'rem -create- rem alter table ' ||
           vFrgnKeyOwner || '.' || vFrgnKeyTable || chr(10) ||
          'rem -create- rem add (' || chr(10) ||
          'rem -create- rem   constraint ' || vFrgnKeyConstraint || chr(10) ||
          'rem -create- rem   foreign key ('
        ;

        vSeparator := 
          chr(10) || 'rem -create- rem      '
        ;

        <<referencing_columns>>
        while dbms_sql.fetch_rows (cursor3HDL) > 0
        loop
          dbms_sql.column_value (
             cursor3HDL
            ,3
            ,vFrgnKeyColumn
          );

          vStatement := vStatement ||
            vSeparator || vFrgnKeyColumn
          ;

          vSeparator := 
            chr(10) || 'rem -create- rem     ,'
          ;
        end loop referencing_columns;

        vStatement := vStatement
          || chr(10) ||
          'rem -create- rem   )'
        ;

        /*
         = Bind variables for retrieving the constraint_columns
         = belonging to the referenced primary key constraint.
        */
        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_owner'
          ,rSelPriUnqKeys.owner
        );

        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_table'
          ,rSelPriUnqKeys.table_name
        );

        dbms_sql.bind_variable (
           cursor3HDL
          ,':cons_constraint'
          ,rSelPriUnqKeys.constraint_name
        );

        nr_of_rows := dbms_sql.execute(cursor3HDL);

        if dbms_sql.fetch_rows (cursor3HDL) > 0
        then
          dbms_sql.column_value (
             cursor3HDL
            ,1
            ,vFrgnKeyOwner
          );

          dbms_sql.column_value (
             cursor3HDL
            ,2
            ,vFrgnKeyTable
          );

          dbms_sql.column_value (
             cursor3HDL
            ,3
            ,vFrgnKeyColumn
          );

          vStatement := vStatement
            || chr(10) ||
            'rem -create- rem   references ' ||
            vFrgnKeyOwner || '.' || vFrgnKeyTable || ' (' || chr(10) ||
            'rem -create- rem      ' || vFrgnKeyColumn
          ;

          vSeparator := 
            chr(10) || 'rem -create- rem     ,'
          ;

         <<referenced_columns>>
          while dbms_sql.fetch_rows (cursor3HDL) > 0
          loop
            dbms_sql.column_value (
               cursor3HDL
              ,3
              ,vFrgnKeyColumn
            );

            vStatement := vStatement ||
              vSeparator || vFrgnKeyColumn
            ;

            vSeparator := 
              chr(10) || 'rem -create- rem     ,'
            ;
          end loop referenced_columns;

          vStatement := vStatement
            || chr(10) ||
            'rem -create- rem   )' || chr(10) ||
            'rem -create- rem   ' || vFrgnDeleteRule || chr(10) || 
            'rem -create- rem   ' || vFrgnKeyStatus || chr(10) || 
            'rem -create- rem )' || chr(10) ||
            'rem -create- rem ;'
          ;

          insert_command_string;
        end if;
      end if;

      i := i + 1;
    end loop frgn_key_constraints;
  end loop pu_key_constraints;
  
  if i = 0
  then
    vStatement :=
      chr(10) || chr(10) ||
      'No foreign keys referencing ' ||
       iOwner || '.' || iTable || ' !' || chr(10);
       raise no_data_found;
  end if;
  
  if dbms_sql.is_open (cursor1HDL)
  then
    dbms_sql.close_cursor (cursor1HDL);
  end if;
  if dbms_sql.is_open (cursor2HDL)
  then
    dbms_sql.close_cursor (cursor2HDL);
  end if;
  if dbms_sql.is_open (cursor3HDL)
  then
    dbms_sql.close_cursor (cursor3HDL);
  end if;
  if dbms_sql.is_open (cursor4HDL)
  then
    dbms_sql.close_cursor (cursor4HDL);
  end if;
exception
  when no_data_found then
    if dbms_sql.is_open (cursor1HDL)
    then
      dbms_sql.close_cursor (cursor1HDL);
    end if;
    if dbms_sql.is_open (cursor2HDL)
    then
      dbms_sql.close_cursor (cursor2HDL);
    end if;
    if dbms_sql.is_open (cursor3HDL)
    then
      dbms_sql.close_cursor (cursor3HDL);
    end if;
    if dbms_sql.is_open (cursor4HDL)
    then
      dbms_sql.close_cursor (cursor4HDL);
    end if;
    dbms_output.put_line(vStatement);
  when others then
    if dbms_sql.is_open (cursor1HDL)
    then
      dbms_sql.close_cursor (cursor1HDL);
    end if;
    if dbms_sql.is_open (cursor2HDL)
    then
      dbms_sql.close_cursor (cursor2HDL);
    end if;
    if dbms_sql.is_open (cursor3HDL)
    then
      dbms_sql.close_cursor (cursor3HDL);
    end if;
    if dbms_sql.is_open (cursor4HDL)
    then
      dbms_sql.close_cursor (cursor4HDL);
    end if;
    raise;
end;
/

select
   frgnkey_string
from
   frgnkey_strings
where owner         = upper('&&owner')
and   table_name like upper('&&table')
order by
   counter

spool &&low_owner..&&low_table..frgn.sql
/
spool off

set termout off

drop table frgnkey_strings
/

set termout on

prompt
prompt Output spooled to file &&low_owner..&&low_table..frgn.sql
prompt

clear breaks
clear columns

set pagesize    24
set linesize    80
set verify      on
set feedback     6
set numwidth    13
set space        1
set trimspool  off

