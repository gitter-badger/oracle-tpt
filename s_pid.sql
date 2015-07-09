--------------------------------------------------------------------------------
--
-- File name:   s_pid.sql
--
-- Purpose:     Display current Session Wait and SQL_ID info (10g+) by system PID
--
-- Author:      
-- Copyright:   
--
-- Usage:       @s_pid <os_pid>
--              @s_pid 52,110,225
--              @s "select spid from v$process where username = 'XYZ'"
--              @s &mypid
--
--------------------------------------------------------------------------------

col sw_event    head EVENT for a32 truncate
col sw_p1transl head P1TRANSL for a26
col sw_sid      head SID for 999999

col sw_p1       head P1 for a18 justify left word_wrap
col sw_p2       head P2 for a18 justify left word_wrap
col sw_p3       head P3 for a18 justify left word_wrap

col sw_blocking_session head BLOCKING_SID for a12

col s_sid  heading 'Session'                 format a12
col s_user heading 'User|OS User@Machine'    format a26
col s_prog heading 'Program|(Module:Action)' format a40
col s_let  heading 'Last  Call|elap. time'   format a10
col s_logt heading 'Logged in time'          format a14
col s_prms heading 'Parameters'              format a32
col s_wait heading 'Seconds in wait'         format a32
col event                                    format a16
col server                                   format a10
col sql_id                                   format a16

select t1.sid||','||t1.serial# as s_sid,
       sPID,
       t1.USERNAME||'('||t1.osuser||'@'||machine||')' as s_user,
--       t1.schemaname,
       t1.PROGRAM||'('||t1.module||' '||t1.action||')' as s_prog,
       status,
       server,
--       nvl(t1.lockwait, 'None') lockwait,
       to_char(to_date( '00:00:00', 'HH24:MI:SS' ) + numtodsinterval(last_call_et, 'second'), 'HH24:MI:SS') s_let,
       to_char(LOGON_TIME, 'dd.mm.yy hh24:mi') s_logt
from v$session t1, v$process t2
     where t1.paddr=t2.addr(+)
       and t2.spid in ( &1 )
order by status desc, s_let, s_user  desc;


select 
    sid sw_sid,
    sql_id,
    CASE WHEN state != 'WAITING' THEN 'WORKING'
         ELSE 'WAITING'
    END AS state, 
    CASE WHEN state != 'WAITING' THEN 'On CPU / runqueue'
         ELSE event
    END AS sw_event, 
    seq#, 
    seconds_in_wait sec_in_wait, 
    CASE WHEN blocking_session_status = 'VALID' THEN TO_CHAR(blocking_session)||CASE WHEN blocking_instance != USERENV('INSTANCE') THEN ' inst='||blocking_instance ELSE NULL END ELSE blocking_session_status END sw_blocking_session,
    CASE state WHEN 'WAITING' THEN NVL2(p1text,p1text||'= ',null)||CASE WHEN P1 < 536870912 THEN to_char(P1) ELSE '0x'||rawtohex(P1RAW) END ELSE null END SW_P1,
    CASE state WHEN 'WAITING' THEN NVL2(p2text,p2text||'= ',null)||CASE WHEN P2 < 536870912 THEN to_char(P2) ELSE '0x'||rawtohex(P2RAW) END ELSE null END SW_P2,
    CASE state WHEN 'WAITING' THEN NVL2(p3text,p3text||'= ',null)||CASE WHEN P3 < 536870912 THEN to_char(P3) ELSE '0x'||rawtohex(P3RAW) END ELSE null END SW_P3,
    CASE state WHEN 'WAITING' THEN 
        CASE 
            WHEN event like 'cursor:%' THEN
                '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))
                    WHEN event like 'enq%' AND state = 'WAITING' THEN 
                '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))||': '||
                chr(bitand(p1, -16777216)/16777215)||
                chr(bitand(p1,16711680)/65535)||
                ' mode '||bitand(p1, power(2,14)-1)
            WHEN event like 'latch%' AND state = 'WAITING' THEN 
                  '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))||': '||(
                        select name||'[par' 
                            from v$latch_parent 
                            where addr = hextoraw(trim(to_char(p1,rpad('0',length(rawtohex(addr)),'X'))))
                        union all
                        select name||'[c'||child#||']' 
                            from v$latch_children 
                            where addr = hextoraw(trim(to_char(p1,rpad('0',length(rawtohex(addr)),'X'))))
                  )
            WHEN event like 'library cache pin' THEN
                  '0x'||RAWTOHEX(p1raw)
        ELSE NULL END 
    ELSE NULL END AS sw_p1transl
FROM 
    v$session 
WHERE 
    sid IN (select sid
              from v$session t1, v$process t2
             where t1.paddr=t2.addr(+)
               and t2.spid in ( &1 )
           )
ORDER BY
    state,
    sw_event,
    p1,
    p2,
    p3
/
