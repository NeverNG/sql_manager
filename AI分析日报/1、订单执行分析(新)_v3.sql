select 
tt2.deptname,
tt2.plannum, --计划项数
tt2.ycgnum, --已采购项数
tt2.zxbl, --执行比例
tt2.yqxs, --逾期项数
tt3.pjcgts --平均采购天数
 from (
select
  tt1.deptname,
  count(tt1.pk_praybill_b) plannum, --计划项数
  sum(tt1.sfycg) ycgnum, --已采购项数
  round(sum(tt1.sfycg)/ count(tt1.pk_praybill_b)*100,2) zxbl,--执行比例
  sum(case when tt1.jhzxxhsj>tt1.jhzxzq then 1 else 0 end) yqxs, --逾期项数
  round(sum(case when tt1.jhzxxhsj>tt1.jhzxzq then 1 else 0 end)/count(tt1.pk_praybill_b)*100,2) yqbl, --逾期比例
  --round(sum(jhzxxhsj)/count(tt1.pk_praybill_b),2) pjcgts, --平均采购天数
  yearmth
from
(select
    distinct prb.pk_praybill_b,
    prb.nastnum nastnum,
    case when dept.name = '辅料采购部' then '工程物资部' 
      when dept.name = '设备采购部' then '设备物资部'
      when dept.name = '辅料物资部' then '工程物资部' 
      else dept.name end deptname, --部门
    case when prb.naccumulatenum > 0 and orderb.forderstatus=3 then 1 else 0 end sfycg, --是否已采购
   case when regexp_like(bdm.def6,'^-?\d+(\.\d+)?$') then to_number(bdm.def6) else 0 end as jhzxzq, --计划执行周期
   to_date(nvl(orderb.dealdate,to_char(sysdate,'yyyy-MM-dd HH24:MI:SS')),'yyyy-MM-dd HH24:MI:SS') -to_date(prh.dmakedate,'yyyy-MM-dd HH24:MI:SS') jhzxxhsj, --计划执行消耗时间
   acmonth.yearmth yearmth,
   acmonth_2.BEGINDATE
from po_praybill_b prb
left join po_praybill prh
     on prb.pk_praybill = prh.pk_praybill
left join bd_material bdm
     on prb.pk_srcmaterial = bdm.pk_material
left join bd_psndoc psn
     on prb.pk_employee = psn.pk_psndoc
left join (select pk_psndoc, pk_dept
    from (select distinct job.pk_psndoc,
                          job.pk_dept,
                          ROW_NUMBER() OVER(PARTITION BY job.pk_psndoc ORDER BY job.begindate desc) RN
            from hi_psnjob job where ismainjob='Y'
          )
   where rn = 1) psnjob
   on psn.pk_psndoc = psnjob.pk_psndoc
left join org_dept dept
     on psnjob.pk_dept = dept.pk_dept
left join bd_billtype bilty--单据类型
     on prh.ctrantypeid = bilty.pk_billtypeid
left join (select 
    distinct csourcebid,
    pk_order,
    pk_order_b,
    vbillcode,
    forderstatus,
    dealdate from           
    (select  
    ROW_NUMBER() OVER(PARTITION BY csourcebid ORDER BY dealdate desc) rnnum,
    csourcebid,
    pk_order,
    pk_order_b,
    vbillcode,
    forderstatus,
    dealdate
    from (
    select po_order_b.csourcebid,
           po_order_b.pk_order,
           po_order_b.pk_order_b,
           po_order.vbillcode,
           po_order.forderstatus,
           max(dealdate) dealdate
      from po_order_b
      left outer join po_order
        on po_order_b.pk_order = po_order.pk_order
      left join pub_workflownote pw
        on pw.billno = po_order.vbillcode
     where po_order_b.dr = 0
       AND po_order.bislatest = 'Y'
          /*and po_order.forderstatus = '3'*/
       and po_order.bislatest = 'Y'
    /*and po_order.bfinalclose = 'N'*/
    /*and po_order_b.bstockclose <> 'Y'*/
     group by po_order_b.csourcebid,
              po_order_b.pk_order,
              po_order_b.pk_order_b,
              po_order.vbillcode,
              po_order.forderstatus
    )) where rnnum= 1) orderb
    on prb.pk_praybill_b = orderb.csourcebid

left join org_stockorg org
     on prb.vbdef1 = org.pk_stockorg
left join org_purchaseorg purchaseorg
on prb.pk_purchaseorg = purchaseorg.pk_purchaseorg
left join bd_accperiodmonth acmonth
on substr(prh.creationtime, 0, 10) between
(substr(acmonth.BEGINDATE, 0, 10)) and
(substr(acmonth.ENDDATE, 0, 10))
left join bd_accperiodmonth acmonth_2
on to_char(sysdate,'yyyy-MM-dd') between
(substr(acmonth_2.BEGINDATE, 0, 10)) and
(substr(acmonth_2.ENDDATE, 0, 10))
where prb.dr = 0
  and prh.dr = 0
  and prb.nastnum !=0 --数量不为0
  and prh.bislatest = 'Y'
  --and not((prh.fbillstatus = 5 or prb.browclose ='Y') and nvl(prb.naccumulatenum,0) =0)
  and not(prb.browclose ='Y' and prb.naccumulatenum = 0)
  and (prh.vbillcode!='QG2022031600010457' and bdm.code!='W130102010594')--23年8.28号王锴联系王鸿辉需求
  and (bdm.code  like 'W%' OR bdm.code  like 'S%'OR bdm.code  like 'X%' OR bdm.code  like 'Q%')
  --and (SUBSTR(prh.dmakedate, 0, 10)  between to_char(sysdate-7,'yyyy-MM-dd') and to_char(sysdate,'yyyy-MM-dd'))
  AND (SUBSTR(prh.creationtime, 0, 10) between substr(acmonth_2.BEGINDATE,0,10) and substr(acmonth_2.ENDDATE,0,10))
  and prb.vbdef1 != '~' 
  and bilty.billtypename='物资请购'
  and dept.name in (select name from bd_defdoc where dr = 0 and enablestate = 2
  and pk_defdoclist = '1001AZ10000000Y6ETNV' )--物资供应报表部门集
  and purchaseorg.code !='9182' --过滤采购组织是9182的数据
) tt1
where tt1.deptname not in('采购科','工程市场合同部','工程市场部','工程项目中心')
group by deptname,yearmth
) tt2
left join WHH_V_pjcgtsjcsJ_WH tt3
on tt2.deptname = tt3.deptname
and tt2.yearmth = tt3.yearmth
