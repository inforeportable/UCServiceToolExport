-- ==============================================================================
-- File Name    : hosxp_uc_export_money_main.sql
-- Description  : UC OPD Payment Processing & Classification Engine for HOSxP
-- Version      : 2.0 (Stable Release)
-- Modified Date: 2026-06-04 20:44
-- Compatible   : MariaDB 5.5+ / MySQL 5.5+
-- ==============================================================================
-- CHANGE LOGS & OPTIMIZATIONS:
--   • Step 01 : Optimized 'pttype' filtering performance using range scan patterns.
--   • Step 02 : Implemented Sorted Subquery (Derived Table) with row-count forcing
--               to prevent dynamic user-variable calculation displacement.
--   • Step 03 : Enforced standard ANSI SQL compliance using strict aggregate functions
--               MAX() to prevent invalid Non-Aggregate column evaluation.
--   • Step 04 : Formulated complex service classification rules & payment thresholds.
--   • Step 05 : Executed payment consolidation calculations (Header Level Updates).
--   • Step 06 : Generated final denormalized audit report tables & cache cleanup.
-- ==============================================================================

SET @start_date = DATE('2026-05-01');
SET @stop_date  = DATE('2026-05-31');
SET @h_name = (SELECT opdconfig.hospitalname FROM opdconfig);
SET @h_code = (SELECT opdconfig.hospitalcode FROM opdconfig);
SET @script_sql = 'script 2026-06-05 05:26' ;
                        
-- step 01 uc_export_money                    
DROP TABLE IF EXISTS uc_export_money;
                               
CREATE TABLE uc_export_money
SELECT ovst.vstdate,
       ovst.vsttime,
       ovst.vn,
       pttype.pttype,
       ovst.pttypeno,
       patient.hn,
       patient.cid,
       patient.pname,
       patient.fname,
       patient.lname,
       opdscreen.cc,
       items.icode,
       items.icode_name,
       items.qty,
       items.unitprice,
       items.sum_price,
       CONCAT('[', provider_type.provider_type_code, ']', provider_type.provider_type_name) AS provider_type_name,
       doctor.fname AS dfname,
       doctor.lname AS dlname
FROM ovst
     INNER JOIN pttype ON ovst.pttype = pttype.pttype
     INNER JOIN patient ON ovst.hn = patient.hn
     INNER JOIN opdscreen ON ovst.vn = opdscreen.vn
     INNER JOIN doctor ON ovst.doctor = doctor.code
     INNER JOIN provider_type ON doctor.provider_type_code = provider_type.provider_type_code
     INNER JOIN
     (
        SELECT opitemrece.vn,
               opitemrece.icode,
               opitemrece.qty,
               opitemrece.unitprice,
               opitemrece.sum_price,
               drugitems.`name` AS icode_name
        FROM opitemrece
             INNER JOIN drugitems ON opitemrece.icode = drugitems.icode
        UNION ALL
        SELECT opitemrece.vn,
               opitemrece.icode,
               opitemrece.qty,
               opitemrece.unitprice,
               opitemrece.sum_price,
               nondrugitems.`name` AS icode_name
        FROM opitemrece
             INNER JOIN nondrugitems ON opitemrece.icode = nondrugitems.icode
     ) AS items ON ovst.vn = items.vn
WHERE ovst.vstdate BETWEEN @start_date AND @stop_date
  AND ovst.hospmain = '10679'
  AND patient.nationality = '99'
  -- ปรับลดความยาวของ IN เพื่อเพิ่ม Performance บน 5.5
  AND ((ovst.pttype BETWEEN 60 AND 98) OR ovst.pttype = 89)
ORDER BY ovst.vstdate,
         ovst.vsttime,
         ovst.vn,
         items.sum_price;

-- step 02 uc_export_money_tranform
DROP TABLE IF EXISTS uc_export_money_tranform;
SET @curr = NULL;
SET @prev = NULL;
SET @rank = 0;
SET @vnid = 0;
SET @sums = 0;

CREATE TABLE uc_export_money_tranform
SELECT 
    sorted_data.vstdate,
    sorted_data.vsttime,
    sorted_data.vn,
    sorted_data.pttype,
    sorted_data.pttypeno,
    sorted_data.hn,
    sorted_data.cid,
    sorted_data.pname,
    sorted_data.fname,
    sorted_data.lname,
    sorted_data.cc,
    sorted_data.icode,
    sorted_data.icode_name,
    sorted_data.qty,
    sorted_data.unitprice,
    sorted_data.sum_price,
    sorted_data.provider_type_name,
    sorted_data.dfname,
    sorted_data.dlname,
    -- ประมวลผลตัวแปรระบบหลังจากข้อมูลถูกเรียงลำดับเสร็จแล้วชัวร์ๆ
    @prev := CAST(@curr AS CHAR) AS prev,
    @curr := CAST(sorted_data.vn AS CHAR) AS curr,
    @rank := IF(@prev = @curr, @rank + 1, 1) AS icode_rid,
    @sums := IF(@rank <> 1,
                CAST(@sums AS DECIMAL(10,2)) + CAST(sorted_data.sum_price AS DECIMAL(10,2)),
                CAST(sorted_data.sum_price AS DECIMAL(10,2))) AS lag_sum_all,
    @vnid := IF(@prev = @curr, @vnid, @vnid + 1) AS vn_rid
FROM (
    -- Subquery บังคับ Sort ข้อมูลให้เสร็จสิ้นก่อนส่งค่าออกไปให้ตัวแปรข้างบนคำนวณ
    -- ใส่ LIMIT ไว้ท้ายสุดเพื่อป้องกันไม่ให้ Optimizer ของ MariaDB แอบข้ามการสลับลำดับ
    SELECT * FROM uc_export_money
    ORDER BY vstdate, vsttime, vn, sum_price
    LIMIT 99999999
) AS sorted_data;

-- step 03 uc_export_money_tranform_list
DROP TABLE IF EXISTS uc_export_money_tranform_list;

CREATE TABLE uc_export_money_tranform_list
SELECT @h_code AS hcode,
       @h_name AS hname,
       -- ใช้ MAX() ครอบคอลัมน์ที่ไม่ได้อยู่ใน GROUP BY เพื่อความปลอดภัยตามมาตรฐาน SQL
       MAX(uc_export_money_tranform.vstdate) AS vstdate,
       MAX(uc_export_money_tranform.vsttime) AS vsttime,
       MAX(uc_export_money_tranform.vn) AS vn,
       MAX(uc_export_money_tranform.pttype) AS pttype,
       MAX(uc_export_money_tranform.pttypeno) AS pttypeno,
       MAX(uc_export_money_tranform.hn) AS hn,
       MAX(uc_export_money_tranform.cid) AS cid,
       MAX(uc_export_money_tranform.pname) AS pname,
       MAX(uc_export_money_tranform.fname) AS fname,
       MAX(uc_export_money_tranform.lname) AS lname,
       MAX(uc_export_money_tranform.cc) AS cc,
       MAX(uc_export_money_tranform.icode) AS icode,
       MAX(uc_export_money_tranform.icode_name) AS icode_name,
       MAX(uc_export_money_tranform.qty) AS qty,
       MAX(uc_export_money_tranform.unitprice) AS unitprice,
       MAX(uc_export_money_tranform.sum_price) AS sum_price,
       MAX(uc_export_money_tranform.provider_type_name) AS provider_type_name,
       MAX(uc_export_money_tranform.dfname) AS dfname,
       MAX(uc_export_money_tranform.dlname) AS dlname,
       MAX(uc_export_money_tranform.prev) AS prev,
       MAX(uc_export_money_tranform.curr) AS curr,
       uc_export_money_tranform.icode_rid, -- อยู่ใน GROUP BY ไม่ต้องใส่ MAX
       MAX(uc_export_money_tranform.lag_sum_all) AS lag_sum_all,
       uc_export_money_tranform.vn_rid,    -- อยู่ใน GROUP BY ไม่ต้องใส่ MAX
       
       -- ส่วนคำนวณสรุปโรคและหัตถการ (Aggregate อยู่แล้ว คงเดิมไว้)
       MAX(CASE WHEN ovstdiag.diagtype = 1 THEN ovstdiag.icd10 ELSE NULL END) AS PDX,
       GROUP_CONCAT(DISTINCT ovstdiag.icd10 ORDER BY ovstdiag.diagtype) AS list_diag,
       GROUP_CONCAT(DISTINCT er_oper_code.name) AS list_proc,
       MAX(CASE WHEN er_oper_code.name IS NOT NULL THEN 1 ELSE 0 END) AS has_proc,
       GROUP_CONCAT(DISTINCT dttm.`name`) AS list_dent,
       MAX(CASE WHEN dttm.treatment = 'Y' THEN 1 ELSE 0 END) AS has_dent
FROM uc_export_money_tranform
     INNER JOIN ovstdiag ON uc_export_money_tranform.vn = ovstdiag.vn
     LEFT OUTER JOIN doctor_operation ON uc_export_money_tranform.vn = doctor_operation.vn
     LEFT OUTER JOIN er_oper_code ON doctor_operation.er_oper_code = er_oper_code.er_oper_code
     LEFT OUTER JOIN dtmain ON uc_export_money_tranform.vn = dtmain.vn
     LEFT OUTER JOIN dttm ON dtmain.tmcode = dttm.code 
     
WHERE (dtmain.vn IS NULL OR (dtmain.vn IS NOT NULL AND dttm.treatment = 'Y'))     
GROUP BY uc_export_money_tranform.vn_rid, uc_export_money_tranform.icode_rid
HAVING MAX(CASE WHEN ovstdiag.diagtype = 1 THEN ovstdiag.icd10 ELSE NULL END) IS NOT NULL
   AND GROUP_CONCAT(DISTINCT ovstdiag.icd10 ORDER BY ovstdiag.diagtype) IS NOT NULL;

-- step 4 uc_export_money_tranform_list_head
DROP TABLE IF EXISTS uc_export_money_tranform_list_head;

SET @cwel = 0;
SET @cucs = 0;
SET @service_group = NULL;
SET @service_group_max_cost = 0;

CREATE TABLE uc_export_money_tranform_list_head
SELECT 
    @start_date AS start_date,
    @stop_date AS stop_date,
    CAST(NOW() AS CHAR) AS export_date,
    MAX(uc_export_money_tranform_list.hcode) AS hcode,
    MAX(uc_export_money_tranform_list.hname) AS hname,
    CAST(MAX(uc_export_money_tranform_list.vstdate) AS CHAR) AS vstdate,
    CAST(MAX(uc_export_money_tranform_list.vsttime) AS CHAR) AS vsttime,
    uc_export_money_tranform_list.vn, -- คอลัมน์หลักที่เป็นตัว GROUP BY ไม่ต้องใส่ MAX
    MAX(uc_export_money_tranform_list.pttype) AS pttype,
    MAX(uc_export_money_tranform_list.pttypeno) AS pttypeno,
    MAX(uc_export_money_tranform_list.hn) AS hn,
    MAX(uc_export_money_tranform_list.cid) AS cid,
    MAX(uc_export_money_tranform_list.pname) AS pname,
    MAX(uc_export_money_tranform_list.fname) AS fname,
    MAX(uc_export_money_tranform_list.lname) AS lname,
    MAX(uc_export_money_tranform_list.cc) AS cc,
    MAX(uc_export_money_tranform_list.provider_type_name) AS provider_type_name,
    MAX(uc_export_money_tranform_list.dfname) AS dfname,
    MAX(uc_export_money_tranform_list.dlname) AS dlname,
    MAX(uc_export_money_tranform_list.pdx) AS pdx,
    
    -- ส่วนคำนวณนับและรวมยอดเงิน (เป็นคำสั่ง Aggregate อยู่แล้ว คงไว้เหมือนเดิม)
    COUNT(uc_export_money_tranform_list.icode_rid) AS count_items,
    SUM(uc_export_money_tranform_list.sum_price) AS sum_itmes,
    MAX(uc_export_money_tranform_list.lag_sum_all) AS max_lag_cost,
    MAX(uc_export_money_tranform_list.list_diag) AS list_diag,
    MAX(uc_export_money_tranform_list.list_proc) AS list_proc,
    MAX(uc_export_money_tranform_list.list_dent) AS list_dent,
    
    -- คำนวณตัวแปรสิทธิ์สวัสดิการข้าราชการ/บัตรทองทั่วไป
    @cwel := MAX(CASE WHEN uc_export_money_tranform_list.pttype IN (60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,80,81,82,83,84,85,86,87,88,90,91,92,93,94,95,96,97,98) THEN 1 ELSE 0 END) AS c_wel,
    
    -- คำนวณตัวแปรสิทธิ์ 89
    @cucs := MAX(CASE WHEN uc_export_money_tranform_list.pttype IN (89) THEN 1 ELSE 0 END) AS c_ucs,

    -- คำนวณกลุ่มบริการ (Service Group)
    @service_group := 
      CASE
         WHEN MAX(uc_export_money_tranform_list.has_dent) = 1 THEN
            CASE
               WHEN MAX(CASE WHEN (uc_export_money_tranform_list.pttype BETWEEN 60 AND 99) AND (uc_export_money_tranform_list.pttype <> 89 ) THEN 1 ELSE 0 END) = 1 THEN 'G'
               WHEN MAX(CASE WHEN uc_export_money_tranform_list.pttype = 89 THEN 1 ELSE 0 END) = 1 THEN 'F'
               ELSE NULL
            END
         WHEN MAX(uc_export_money_tranform_list.has_dent) = 0 THEN
            CASE
               -- ครอบ MAX() ตรงฟังก์ชันย่อยเพื่อให้ปลอดภัยจากหลัก Group By
               WHEN SUBSTRING(MAX(uc_export_money_tranform_list.provider_type_name), 2, 2) = '01' THEN 'E'
               WHEN SUBSTRING(MAX(uc_export_money_tranform_list.provider_type_name), 2, 2) <> '01' THEN 'D'
               ELSE NULL
            END
         ELSE NULL
      END AS service_group,
      
    -- คำนวณเพดานราคาสูงสุด (Service Group Max Cost)
    @service_group_max_cost := 
      CASE
         WHEN MAX(uc_export_money_tranform_list.has_dent) = 1 THEN
            CASE
               WHEN MAX(CASE WHEN (uc_export_money_tranform_list.pttype BETWEEN 60 AND 99) AND (uc_export_money_tranform_list.pttype <> 89 ) THEN 1 ELSE 0 END) = 1 THEN 200 
               WHEN MAX(CASE WHEN uc_export_money_tranform_list.pttype = 89 THEN 1 ELSE 0 END) = 1 THEN 170 
               ELSE NULL
            END
         WHEN MAX(uc_export_money_tranform_list.has_dent) = 0 THEN
            CASE
               -- ครอบ MAX() ตรงฟังก์ชันย่อยเพื่อให้ปลอดภัยจากหลัก Group By
               WHEN SUBSTRING(MAX(uc_export_money_tranform_list.provider_type_name), 2, 2) = '01' THEN 150 
               WHEN SUBSTRING(MAX(uc_export_money_tranform_list.provider_type_name), 2, 2) <> '01' THEN 35  
               ELSE NULL
            END
         ELSE NULL
      END AS service_group_max_cost,          
      
    CAST(0 AS DECIMAL(10,2)) AS pay_real,

@script_sql as script_sql
                                                                                                
FROM uc_export_money_tranform_list
GROUP BY uc_export_money_tranform_list.vn
ORDER BY MAX(uc_export_money_tranform_list.vstdate), 
         uc_export_money_tranform_list.vn;

-- step 5 update uc_export_money_tranform_list_head.pay_real

UPDATE uc_export_money_tranform_list_head
SET uc_export_money_tranform_list_head.pay_real = 
    CAST(
        IF(
            (uc_export_money_tranform_list_head.max_lag_cost <= uc_export_money_tranform_list_head.service_group_max_cost)
            AND uc_export_money_tranform_list_head.service_group = 'E',
            
            -- เงื่อนไขเป็นจริง: จ่ายตามยอดสะสมจริง (ใช้ในกรณีกลุ่ม E ที่ยอดไม่เกินเพดาน)
            CAST(uc_export_money_tranform_list_head.max_lag_cost AS DECIMAL(10,2)),   
            
            -- เงื่อนไขเป็นเท็จ: จ่ายขาดตามราคาเพดานสูงสุดของกลุ่มนั้นๆ ทันที
            CAST(uc_export_money_tranform_list_head.service_group_max_cost AS DECIMAL(10,2))
        ) 
    AS DECIMAL(10,2));

-- step 6 clear uc_export_money_tranform_list_head_descr
DROP TABLE IF EXISTS uc_export_money_tranform_list_head_descr;

CREATE TABLE uc_export_money_tranform_list_head_descr
SELECT 
    -- ดึงข้อมูลตัวแปรเริ่มต้นและวันที่ส่งออก (จากตาราง Head)
    head.start_date,
    head.stop_date,
    CAST(head.export_date AS CHAR) AS export_date,
    
    -- ดึงข้อมูลสถานพยาบาลและข้อมูลคนไข้ (ดึงจากตาราง รายละเอียด ที่ผ่านการเคลียร์ Group By มาแล้ว)
    list.hcode,
    list.hname,
    CAST(list.vstdate AS CHAR) AS vstdate,
    CAST(list.vsttime AS CHAR) AS vsttime,
    list.vn,
    list.pttype,
    list.pttypeno,
    list.hn,
    list.cid,
    list.pname,
    list.fname,
    list.lname,
    list.cc,
    
    -- รายการเวชภัณฑ์และค่าใช้จ่ายรายชิ้น (Itemized details)
    list.icode,
    list.icode_name,
    list.qty,
    list.unitprice,
    list.sum_price,
    list.provider_type_name,
    list.dfname,
    list.dlname,
    
    -- ข้อมูลตัวแปรระบบสะสมลำดับ (ที่คำนวณถูกต้องแล้วจาก Subquery)
    list.prev,
    list.curr,
    list.icode_rid,
    list.lag_sum_all,
    list.vn_rid,
    
    -- ข้อมูลสรุปโรคและหัตถการราย Visit
    list.PDX,
    list.list_diag,
    list.list_proc,
    list.has_proc,
    list.list_dent,
    list.has_dent,
    
    -- ข้อมูลสรุปยอดเงินและกลุ่มการจ่ายเงินที่คำนวณเสร็จสมบูรณ์ (จากตาราง Head)
    head.count_items,
    head.sum_itmes,
    head.max_lag_cost,
    head.c_wel,
    head.c_ucs,
    head.service_group,
    head.service_group_max_cost,
    head.pay_real,
		@script_sql as script_sql
FROM uc_export_money_tranform_list AS list
     INNER JOIN uc_export_money_tranform_list_head AS head 
        ON list.vn = head.vn
ORDER BY head.service_group DESC,
         head.vstdate,
         head.vn; 
                                           
-- ทำลายตารางชั่วคราวทิ้ง เพื่อคืนพื้นที่และหน่วยความจำให้ระบบฐานข้อมูลโรงพยาบาล
DROP TABLE IF EXISTS uc_export_money;
DROP TABLE IF EXISTS uc_export_money_tranform;
DROP TABLE IF EXISTS uc_export_money_tranform_list;
