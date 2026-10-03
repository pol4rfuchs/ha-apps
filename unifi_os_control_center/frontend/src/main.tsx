import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  AlertTriangle, Bell, Camera, CheckCircle2, ChevronRight, CircleGauge, Clipboard,
  CloudCog, Database, EthernetPort, FileDiff, Info, LayoutDashboard, Radio, RefreshCw, Router,
  Save, Search, Settings, ShieldCheck, Users, Wifi, X, XCircle, Zap
} from "lucide-react";
import "./styles.css";

type JsonObject = Record<string, unknown>;
type Health = { status: string; version: string; read_only: boolean };
type OperationsStatus = { last_poll_at:number|null; connection_ok:boolean; tracked_devices:number; offline_devices:number; device_health_initialized:boolean; offline_grace_polls:number };
type Config = { controller_configured: boolean; api_key_configured: boolean; verify_tls: boolean; read_only: boolean; allow_firewall_write:boolean; allow_firewall_delete:boolean; allow_policy_reorder:boolean; require_change_confirmation:boolean; create_prechange_snapshot:boolean; polling_interval: number; ntfy_enabled:boolean; ntfy_configured:boolean; ntfy_topic:string; notify_on_connection_failure:boolean; notify_on_connection_recovery:boolean; notify_on_new_client:boolean; notify_on_device_offline:boolean; notify_on_device_recovery:boolean; device_offline_grace_polls:number; notification_cooldown:number };
type FirewallWriteSafety = { firewall_model:string; zone_based_configured:boolean|null; global_read_only:boolean; allow_firewall_write:boolean; allow_firewall_delete:boolean; allow_policy_reorder:boolean; require_change_confirmation:boolean; create_prechange_snapshot:boolean; write_ready:boolean; blocked_reasons:string[]; workflow:string[]; implemented_operations:string[]; note:string };
type Page = "Overview"|"Gateways"|"Switches"|"WiFi"|"Clients"|"Firewall"|"Protect"|"Firmware"|"Backups"|"Alerts"|"Settings";
type AlertItem = { id:number; level:"error"|"success"|"info"; message:string; at:string; source?:string; acknowledged?:boolean };
type AlertStats = { total:number; open:number; acknowledged:number; by_level:Record<string,number>; by_source:Record<string,number> };
type FirewallCapabilities = { policies_read:boolean; zones_read:boolean; ordering_read:boolean; write_enabled:boolean; policy_count:number; zone_count:number; firewall_model?:"legacy"|"zone_based"|"unknown"; zone_based_configured?:boolean|null; errors:Record<string,string> };
type DiagnosticAttempt = { name:string; ok:boolean; status_code:number|null; count?:number; method?:string; url?:string; reason?:string; response_body?:unknown; response_headers?:Record<string,string>; data?:unknown };
type FirewallDiagnostics = { site_id:string; network_api_reported:string; unifi_os_reported:string; read_only:boolean; firewall_model:"legacy"|"zone_based"|"unknown"; zone_based_configured:boolean|null; detection_code?:string|null; detection_message?:string; attempts:DiagnosticAttempt[] };
type FirewallFinding = { code:string; severity:"critical"|"high"|"medium"|"low"|"info"; title:string; policy_name?:string; message:string; recommendation:string };
type FirewallAnalysis = { score:number; policy_count:number; zone_count:number; finding_count:number; severity_counts:Record<string,number>; weights:Record<string,number>; findings:FirewallFinding[]; limitations:string[] };
type FirewallSnapshot = { id:number; created_at:number; site_id:string; note:string; policy_count:number; zone_count:number; sha256:string };
type FirewallDiff = { summary:{added:number;removed:number;changed:number}; added:unknown[]; removed:unknown[]; changed:unknown[]; before_sha256?:string; after_sha256?:string };

const nav: Array<[React.ElementType, Page]> = [
  [LayoutDashboard,"Overview"],[Router,"Gateways"],[EthernetPort,"Switches"],[Wifi,"WiFi"],
  [Users,"Clients"],[ShieldCheck,"Firewall"],[Camera,"Protect"],[CloudCog,"Firmware"],
  [Database,"Backups"],[Bell,"Alerts"],[Settings,"Settings"]
];

function rows(value: unknown): JsonObject[] {
  if (Array.isArray(value)) return value.filter(v => v && typeof v === "object") as JsonObject[];
  if (value && typeof value === "object") {
    const obj = value as JsonObject;
    for (const key of ["data","items","results"]) if (Array.isArray(obj[key])) return rows(obj[key]);
  }
  return [];
}
function text(o: JsonObject, ...keys: string[]): string {
  for (const key of keys) { const v=o[key]; if (typeof v === "string" && v.trim()) return v; if (typeof v === "number") return String(v); }
  return "—";
}
function bool(o: JsonObject, ...keys: string[]): boolean { return keys.some(k => o[k] === true || o[k] === "true" || o[k] === 1); }
function deviceKind(o: JsonObject): string { return text(o,"type","modelCategory","category","deviceType","model").toLowerCase(); }
function siteId(o: JsonObject): string { return text(o,"id","_id","siteId","site_id"); }
function siteName(o: JsonObject): string { return text(o,"name","displayName","siteName","description"); }
function itemName(o: JsonObject): string { return text(o,"name","displayName","hostname","model","macAddress","mac"); }
function itemOnline(o: JsonObject, client=false): boolean { return client || bool(o,"online","connected","isOnline","active"); }

function App(){
  const [page,setPage]=useState<Page>("Overview");
  const [health,setHealth]=useState<Health|null>(null); const [config,setConfig]=useState<Config|null>(null);
  const [sites,setSites]=useState<JsonObject[]>([]); const [site,setSite]=useState("");
  const [devices,setDevices]=useState<JsonObject[]>([]); const [clients,setClients]=useState<JsonObject[]>([]);
  const [loading,setLoading]=useState(true); const [testing,setTesting]=useState(false); const [error,setError]=useState(""); const [notice,setNotice]=useState("");
  const [query,setQuery]=useState(""); const [searchOpen,setSearchOpen]=useState(false);
  const [selected,setSelected]=useState<JsonObject|null>(null); const [selectedKind,setSelectedKind]=useState("Inventory item");
  const [alerts,setAlerts]=useState<AlertItem[]>([]);
  const [alertStats,setAlertStats]=useState<AlertStats|null>(null);
  const [operations,setOperations]=useState<OperationsStatus|null>(null);
  const [firewallPolicies,setFirewallPolicies]=useState<JsonObject[]>([]);
  const [firewallZones,setFirewallZones]=useState<JsonObject[]>([]);
  const [firewallCapabilities,setFirewallCapabilities]=useState<FirewallCapabilities|null>(null);
  const [firewallLoading,setFirewallLoading]=useState(false);
  const [firewallError,setFirewallError]=useState("");
  const [firewallDiagnostics,setFirewallDiagnostics]=useState<FirewallDiagnostics|null>(null);
  const [firewallAnalysis,setFirewallAnalysis]=useState<FirewallAnalysis|null>(null);
  const [firewallSnapshots,setFirewallSnapshots]=useState<FirewallSnapshot[]>([]);
  const [firewallDiff,setFirewallDiff]=useState<FirewallDiff|null>(null);
  const [firewallWriteSafety,setFirewallWriteSafety]=useState<FirewallWriteSafety|null>(null);

  async function api<T>(path:string,init?:RequestInit):Promise<T>{ const r=await fetch(path,{cache:"no-store",...init,headers:{"Content-Type":"application/json",...(init?.headers||{})}}); const d=await r.json().catch(()=>({})); if(!r.ok){const detail=(d as {detail?:unknown}).detail;throw new Error(typeof detail==="string"?detail:detail?JSON.stringify(detail):`${r.status} ${r.statusText}`)} return d as T; }
  async function loadAlerts(){
    const [data,stats]=await Promise.all([
      api<{items:Array<{id:number;created_at:number;level:string;source:string;message:string;acknowledged:number}>}>("api/alerts"),
      api<AlertStats>("api/alerts/stats")
    ]);
    setAlerts((data.items||[]).map(item=>({id:item.id,level:(item.level==="error"||item.level==="success"?item.level:"info"),message:item.message,source:item.source,at:new Date(item.created_at*1000).toLocaleString(),acknowledged:Boolean(item.acknowledged)})));
    setAlertStats(stats);
  }
  async function loadBase(){
    setLoading(true); setError("");
    try{
      const [h,c,s,ops]=await Promise.all([api<Health>("api/health"),api<Config>("api/config/status"),api<unknown>("api/unifi/sites"),api<OperationsStatus>("api/operations/status")]);
      setHealth(h); setConfig(c); setOperations(ops); await loadAlerts(); const list=rows(s); setSites(list); const chosen=site || (list[0] ? siteId(list[0]) : ""); setSite(chosen);
      if(chosen) await loadSite(chosen);
    }catch(e){const msg=e instanceof Error?e.message:"Backend request failed";setError(msg);}
    finally{setLoading(false);}
  }
  async function loadSite(id:string){
    if(!id) return; setLoading(true); setError("");
    try{ const [d,c]=await Promise.all([api<unknown>(`api/unifi/sites/${encodeURIComponent(id)}/devices`),api<unknown>(`api/unifi/sites/${encodeURIComponent(id)}/clients`)]); setDevices(rows(d)); setClients(rows(c)); }
    catch(e){const msg=e instanceof Error?e.message:"Site request failed";setError(msg);}
    finally{setLoading(false);}
  }
  useEffect(()=>{void loadBase();},[]);
  useEffect(()=>{if(page==="Firewall"&&site) void loadFirewall(site);},[page,site]);
  async function test(){setTesting(true);setNotice("");setError("");try{const d=await api<{site_count:number}>("api/unifi/test");setNotice(`Connection successful · ${d.site_count} site(s)`);await loadAlerts();}catch(e){const msg=e instanceof Error?e.message:"Connection failed";setError(msg);await loadAlerts().catch(()=>undefined);}finally{setTesting(false)}}
  async function testNotification(){setTesting(true);setNotice("");setError("");try{await api<{ok:boolean}>("api/notifications/test",{method:"POST",body:"{}"});setNotice("ntfy test notification sent");await loadAlerts();}catch(e){const msg=e instanceof Error?e.message:"ntfy test failed";setError(msg);await loadAlerts().catch(()=>undefined);}finally{setTesting(false)}}
  async function clearAlerts(){try{await api<{ok:boolean}>("api/alerts",{method:"DELETE"});setAlerts([]);}catch(e){setError(e instanceof Error?e.message:"Could not clear alerts")}}
  async function acknowledgeAlert(id:number){try{await api<{ok:boolean}>(`api/alerts/${id}/acknowledge`,{method:"POST",body:"{}"});await loadAlerts();}catch(e){setError(e instanceof Error?e.message:"Could not acknowledge alert")}}
  async function acknowledgeAllAlerts(){try{await api<{ok:boolean}>("api/alerts/acknowledge-all",{method:"POST",body:"{}"});await loadAlerts();}catch(e){setError(e instanceof Error?e.message:"Could not acknowledge alerts")}}
  async function deleteAlert(id:number){try{await api<{ok:boolean}>(`api/alerts/${id}`,{method:"DELETE"});await loadAlerts();}catch(e){setError(e instanceof Error?e.message:"Could not delete alert")}}
  async function loadFirewall(id:string){
    setFirewallLoading(true); setFirewallError(""); setFirewallDiagnostics(null); setFirewallAnalysis(null); setFirewallDiff(null);
    try{
      const diagnostics=await api<FirewallDiagnostics>(`api/unifi/sites/${encodeURIComponent(id)}/firewall/diagnostics`);
      setFirewallDiagnostics(diagnostics);
      const policyAttempt=diagnostics.attempts.find(a=>a.name==="policies_paged"&&a.ok)||diagnostics.attempts.find(a=>a.name==="policies_unpaged"&&a.ok);
      const zoneAttempt=diagnostics.attempts.find(a=>a.name==="zones_paged"&&a.ok)||diagnostics.attempts.find(a=>a.name==="zones_unpaged"&&a.ok);
      setFirewallPolicies(rows(policyAttempt?.data)); setFirewallZones(rows(zoneAttempt?.data));
      try{setFirewallCapabilities(await api<FirewallCapabilities>(`api/unifi/sites/${encodeURIComponent(id)}/firewall/capabilities`))}catch{setFirewallCapabilities(null)}
      try{const snap=await api<{items:FirewallSnapshot[]}>(`api/unifi/sites/${encodeURIComponent(id)}/firewall/snapshots`);setFirewallSnapshots(snap.items||[])}catch{setFirewallSnapshots([])}
      try{setFirewallWriteSafety(await api<FirewallWriteSafety>(`api/unifi/sites/${encodeURIComponent(id)}/firewall/write-safety`))}catch{setFirewallWriteSafety(null)}
      if(diagnostics.firewall_model==="zone_based"){
        try{setFirewallAnalysis(await api<FirewallAnalysis>(`api/unifi/sites/${encodeURIComponent(id)}/firewall/analysis`))}catch{setFirewallAnalysis(null)}
      }
      const failed=diagnostics.attempts.filter(a=>!a.ok);
      if(diagnostics.firewall_model==="legacy"){
        setFirewallError("");
      }else if(failed.length===diagnostics.attempts.length){
        const msg=`All firewall API diagnostic attempts failed. Open Diagnostics for the UniFi response body.`;
        setFirewallError(msg);
      }
    }catch(e){
      const msg=e instanceof Error?e.message:"Firewall diagnostics request failed";
      setFirewallError(msg);
    }finally{setFirewallLoading(false)}
  }

  async function createFirewallSnapshot(note:string){
    if(!site)return;
    setFirewallLoading(true);setFirewallError("");
    try{
      await api(`api/unifi/sites/${encodeURIComponent(site)}/firewall/snapshots`,{method:"POST",body:JSON.stringify({note})});
      const snap=await api<{items:FirewallSnapshot[]}>(`api/unifi/sites/${encodeURIComponent(site)}/firewall/snapshots`);setFirewallSnapshots(snap.items||[]);
      
    }catch(e){const msg=e instanceof Error?e.message:"Snapshot creation failed";setFirewallError(msg)}finally{setFirewallLoading(false)}
  }
  async function compareFirewallSnapshots(before:number,after:number){
    if(!site)return;
    setFirewallLoading(true);setFirewallError("");
    try{setFirewallDiff(await api<FirewallDiff>(`api/unifi/sites/${encodeURIComponent(site)}/firewall/snapshots/${before}/diff/${after}`))}
    catch(e){const msg=e instanceof Error?e.message:"Snapshot comparison failed";setFirewallError(msg)}finally{setFirewallLoading(false)}
  }

  function chooseSite(id:string){setSite(id);setSelected(null);void loadSite(id)}
  function openItem(item:JsonObject,kind:string){setSelected(item);setSelectedKind(kind)}

  const gateways=useMemo(()=>devices.filter(d=>/(gateway|udm|ucg|uxg|router)/.test(deviceKind(d))),[devices]);
  const switches=useMemo(()=>devices.filter(d=>/(switch|usw)/.test(deviceKind(d))),[devices]);
  const wifi=useMemo(()=>devices.filter(d=>/(access point|u6|u7|uap|wifi|\bap\b)/.test(deviceKind(d))),[devices]);
  const searchable=useMemo(()=>[...devices,...clients].filter(o=>JSON.stringify(o).toLowerCase().includes(query.toLowerCase())),[devices,clients,query]);

  return <div className="shell">
    <aside><div className="brand"><div className="brand-mark"><Radio/></div><div><b>UniFi OS</b><span>Control Center</span></div></div>
      <nav>{nav.map(([Icon,label])=><button className={page===label?"active":""} key={label} onClick={()=>{setPage(label);setSelected(null)}}><Icon size={18}/><span>{label}</span>{label==="Alerts"&&alerts.length>0&&<em>{Math.min(alerts.length,99)}</em>}</button>)}</nav>
      <div className="sidebar-foot"><div className={`gateway-dot ${error?"bad":""}`}/><div><b>Local Gateway</b><span>{error?"Attention required":health?.status==="ok"?"Control plane online":"Connecting…"}</span></div></div>
    </aside>
    <main><header><div><h1>{page}</h1><p>{subtitle(page)}</p></div><div className="header-actions">
      <button className="icon-btn" title="Search" onClick={()=>setSearchOpen(v=>!v)}><Search size={18}/></button>
      <button className="icon-btn" title="Alerts" onClick={()=>setPage("Alerts")}><Bell size={18}/>{alerts.some(a=>a.level==="error")&&<i/>}</button>
      <button className="refresh" onClick={()=>void loadBase()}><RefreshCw size={17} className={loading?"spin":""}/>Refresh</button>
      <button className="refresh primary" onClick={test}><RefreshCw size={17} className={testing?"spin":""}/>{testing?"Testing…":"Test connection"}</button>
    </div></header>

    {searchOpen&&<section className="search-panel card"><Search size={18}/><input autoFocus value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search devices and clients…"/><span>{query?`${searchable.length} results`:"Type to search"}</span></section>}
    <section className="status-strip"><div><span className={`live-dot ${error?"bad":""}`}/>{error?"ATTENTION REQUIRED":"SYSTEM OPERATIONAL"}</div><div>API <b>{config?.api_key_configured?"CONNECTED":"NOT CONFIGURED"}</b></div><div>MODE <b>{config?.read_only?"READ ONLY":"CONTROL"}</b></div><div>POLL <b>{config?.polling_interval??"—"}s</b></div><div>VERSION <b>{health?.version??"—"}</b></div></section>
    {(error||notice)&&<div className={`banner ${error?"error":"success"}`}>{error?<XCircle size={18}/>:<CheckCircle2 size={18}/>}<span>{error||notice}</span><button onClick={()=>{setError("");setNotice("")}}><X size={16}/></button></div>}
    {sites.length>1&&<div className="site-picker"><label>Site</label><select value={site} onChange={e=>chooseSite(e.target.value)}>{sites.map(s=><option key={siteId(s)} value={siteId(s)}>{siteName(s)}</option>)}</select></div>}

    {searchOpen&&query ? <SearchResults items={searchable} onOpen={o=>openItem(o,"Search result")}/> : renderPage(page,{sites,devices,clients,gateways,switches,wifi,config,operations,loading,setPage,alerts,setAlerts,alertStats,openItem,firewallPolicies,firewallZones,firewallCapabilities,firewallLoading,firewallError,firewallDiagnostics,firewallAnalysis,firewallSnapshots,firewallDiff,firewallWriteSafety,testNotification,clearAlerts,acknowledgeAlert,acknowledgeAllAlerts,deleteAlert,reloadFirewall:()=>site&&void loadFirewall(site),createFirewallSnapshot,compareFirewallSnapshots})}
    </main>
    {selected&&<DetailDrawer item={selected} kind={selectedKind} onClose={()=>setSelected(null)}/>} 
  </div>
}

function subtitle(page:Page){ const map:Record<Page,string>={Overview:"Live status from your selected UniFi site.",Gateways:"Gateway inventory and current state.",Switches:"Switch inventory and PoE-capable infrastructure.",WiFi:"Wireless access points and radio inventory.",Clients:"Currently reported wired and wireless clients.",Firewall:"Firewall policies, analysis, snapshots, capabilities, and diagnostics.",Protect:"Protect availability for this console.",Firmware:"Installed firmware inventory from reported UniFi devices.",Backups:"Home Assistant backup status and future snapshot scope.",Alerts:"Connection and runtime events collected during this session.",Settings:"Effective app configuration supplied by Home Assistant."}; return map[page]; }

type PageData={alertStats:AlertStats|null;operations:OperationsStatus|null;sites:JsonObject[];devices:JsonObject[];clients:JsonObject[];gateways:JsonObject[];switches:JsonObject[];wifi:JsonObject[];config:Config|null;loading:boolean;setPage:(p:Page)=>void;alerts:AlertItem[];setAlerts:React.Dispatch<React.SetStateAction<AlertItem[]>>;openItem:(o:JsonObject,k:string)=>void;firewallPolicies:JsonObject[];firewallZones:JsonObject[];firewallCapabilities:FirewallCapabilities|null;firewallLoading:boolean;firewallError:string;firewallDiagnostics:FirewallDiagnostics|null;firewallAnalysis:FirewallAnalysis|null;firewallSnapshots:FirewallSnapshot[];firewallDiff:FirewallDiff|null;firewallWriteSafety:FirewallWriteSafety|null;testNotification:()=>Promise<void>;clearAlerts:()=>Promise<void>;acknowledgeAlert:(id:number)=>Promise<void>;acknowledgeAllAlerts:()=>Promise<void>;deleteAlert:(id:number)=>Promise<void>;reloadFirewall:()=>void;createFirewallSnapshot:(note:string)=>Promise<void>;compareFirewallSnapshots:(before:number,after:number)=>Promise<void>};
function renderPage(page:Page,d:PageData){
  if(d.loading&&!d.devices.length&&!d.clients.length) return <Loading/>;
  if(page==="Overview") return <Overview {...d}/>;
  if(page==="Gateways") return <Inventory title="Gateways" items={d.gateways} icon={Router} onOpen={o=>d.openItem(o,"Gateway")}/>;
  if(page==="Switches") return <Inventory title="UniFi Switches" items={d.switches} icon={EthernetPort} onOpen={o=>d.openItem(o,"UniFi switch")} emptyTitle="No UniFi switch detected" emptyText="Your TP-Link switch is not exposed by the UniFi Network API and therefore cannot appear here."/>;
  if(page==="WiFi") return <Inventory title="Wireless Access Points" items={d.wifi} icon={Wifi} onOpen={o=>d.openItem(o,"Access point")}/>;
  if(page==="Clients") return <Inventory title="Clients" items={d.clients} icon={Users} client onOpen={o=>d.openItem(o,"Client")}/>;
  if(page==="Firewall") return <FirewallPage policies={d.firewallPolicies} zones={d.firewallZones} capabilities={d.firewallCapabilities} loading={d.firewallLoading} error={d.firewallError} diagnostics={d.firewallDiagnostics} analysis={d.firewallAnalysis} snapshots={d.firewallSnapshots} diff={d.firewallDiff} writeSafety={d.firewallWriteSafety} onReload={d.reloadFirewall} onCreateSnapshot={d.createFirewallSnapshot} onCompare={d.compareFirewallSnapshots} onOpen={o=>d.openItem(o,"Firewall policy")}/>;
  if(page==="Protect") return <ModulePage icon={Camera} title="UniFi Protect" state="Not connected" text="No dedicated Protect API adapter is active yet. Network inventory remains fully functional." items={["Detect Protect availability","Read camera/NVR inventory","No recording or camera actions in v0.2.x"]}/>;
  if(page==="Firmware") return <Inventory title="Firmware inventory" items={d.devices.filter(o=>text(o,"version","firmwareVersion","firmware")!=="—")} icon={CloudCog} onOpen={o=>d.openItem(o,"Firmware record")} emptyTitle="No firmware data reported" emptyText="The current device response does not expose firmware versions."/>;
  if(page==="Backups") return <ModulePage icon={Database} title="Backup and snapshots" state="HA hot backup enabled" text="The app participates in Home Assistant backups. Full UniFi console restore is not claimed." items={["App configuration and SQLite data","Future firewall policy snapshots","Controlled diff and rollback only"]}/>;
  if(page==="Alerts") return <AlertsPage alerts={d.alerts} stats={d.alertStats} config={d.config} clear={d.clearAlerts} acknowledge={d.acknowledgeAlert} acknowledgeAll={d.acknowledgeAllAlerts} remove={d.deleteAlert} testNotification={d.testNotification}/>;
  if(page==="Settings") return <SettingsPage config={d.config} testNotification={d.testNotification}/>;
  return <Empty icon={Info} title="Module available" text="This read-only module has no additional data yet."/>;
}

function ModulePage({icon:Icon,title,state,text,items}:{icon:React.ElementType;title:string;state:string;text:string;items:string[]}){
  return <section className="card module-page"><div className="module-hero"><div className="metric-icon"><Icon size={22}/></div><div><h2>{title}</h2><p>{text}</p></div><span className="pill neutral">{state}</span></div><div className="legacy-boundary"><b>Current scope</b>{items.map(item=><span key={item}>{item}</span>)}</div></section>
}

function Overview(d:PageData){return <>
  <section className="metrics"><Metric icon={CircleGauge} label="API Health" value={d.operations?.connection_ok?"Online":"Checking"} detail={`${d.sites.length} site(s) available`}/><Metric icon={Users} label="Clients" value={String(d.clients.length)} detail="Reported by UniFi API"/><Metric icon={EthernetPort} label="Device health" value={d.operations?.device_health_initialized?`${d.operations.offline_devices} offline`:"Initializing"} detail={`${d.operations?.tracked_devices??0} explicitly tracked`}/><Metric icon={Zap} label="Mode" value={d.config?.read_only?"Read only":"Control"} detail="Write gate enforced in backend"/></section>
  <section className="grid overview-grid"><div className="card span-2"><div className="card-head"><div><h2>Infrastructure</h2><p>Live inventory from the selected site</p></div></div><div className="quick-grid"><Quick icon={Router} label="Gateways" value={d.gateways.length} onClick={()=>d.setPage("Gateways")}/><Quick icon={EthernetPort} label="Switches" value={d.switches.length} onClick={()=>d.setPage("Switches")}/><Quick icon={Wifi} label="Access points" value={d.wifi.length} onClick={()=>d.setPage("WiFi")}/><Quick icon={Users} label="Clients" value={d.clients.length} onClick={()=>d.setPage("Clients")}/></div></div>
  <div className="card"><div className="card-head"><div><h2>Sites</h2><p>Available UniFi sites</p></div></div><div className="list">{d.sites.map(s=><button className="list-row clickable" key={siteId(s)} onClick={()=>d.openItem(s,"Site")}><div className="node-icon"><Radio size={18}/></div><div><b>{siteName(s)}</b><span>{siteId(s)}</span></div><i className="good"/><ChevronRight size={16}/></button>)}</div></div></section>
</>}
function Metric({label,value,detail,icon:Icon}:{label:string;value:string;detail:string;icon:React.ElementType}){return <div className="metric card"><div className="metric-icon"><Icon size={19}/></div><div><span>{label}</span><strong>{value}</strong><small>{detail}</small></div></div>}
function Quick({icon:Icon,label,value,onClick}:{icon:React.ElementType;label:string;value:number;onClick:()=>void}){return <button className="quick" onClick={onClick}><div className="metric-icon"><Icon size={20}/></div><div><strong>{value}</strong><span>{label}</span></div><span className="arrow">→</span></button>}

function Inventory({title,items,icon:Icon,client=false,emptyTitle,emptyText,onOpen}:{title:string;items:JsonObject[];icon:React.ElementType;client?:boolean;emptyTitle?:string;emptyText?:string;onOpen:(o:JsonObject)=>void}){
  const [filter,setFilter]=useState(""); const [state,setState]=useState<"all"|"online"|"reported">("all");
  const filtered=useMemo(()=>items.filter(o=>{
    const matches=!filter||JSON.stringify(o).toLowerCase().includes(filter.toLowerCase());
    const online=itemOnline(o,client); return matches&&(state==="all"||(state==="online"&&online)||(state==="reported"&&!online));
  }),[items,filter,state,client]);
  return <section className="card inventory"><div className="card-head"><div><h2>{title}</h2><p>{filtered.length} of {items.length} item(s)</p></div><div className="table-tools"><div className="mini-search"><Search size={15}/><input value={filter} onChange={e=>setFilter(e.target.value)} placeholder="Filter…"/></div><select value={state} onChange={e=>setState(e.target.value as typeof state)}><option value="all">All states</option><option value="online">Online</option><option value="reported">Reported</option></select></div></div>{items.length===0?<Empty icon={Icon} title={emptyTitle||`No ${title.toLowerCase()} found`} text={emptyText||"The selected site did not return matching records."}/>:filtered.length===0?<Empty icon={Search} title="No matching records" text="Adjust the filter or status selection."/>:<div className="table-wrap"><table><thead><tr><th>Name</th><th>Model / Type</th><th>IP address</th><th>MAC address</th><th>Status</th><th/></tr></thead><tbody>{filtered.map((o,i)=><tr className="click-row" key={text(o,"id","_id","mac")+i} onClick={()=>onOpen(o)}><td><div className="table-name"><Icon size={17}/><b>{itemName(o)}</b></div></td><td>{text(o,"model","type","modelCategory","deviceType")}</td><td>{text(o,"ipAddress","ip","ip_address","lastIp")}</td><td>{text(o,"macAddress","mac","mac_address")}</td><td><span className={`pill ${itemOnline(o,client)?"ok":"neutral"}`}>{itemOnline(o,client)?"Online":"Reported"}</span></td><td><button className="row-open" type="button" aria-label={`Open details for ${itemName(o)}`} onClick={e=>{e.stopPropagation();onOpen(o)}}><span>{client?"Details":"Open"}</span><ChevronRight size={16}/></button></td></tr>)}</tbody></table></div>}</section>}

function FirewallPage({policies,zones,capabilities,diagnostics,analysis,snapshots,diff,writeSafety,loading,error,onReload,onCreateSnapshot,onCompare,onOpen}:{policies:JsonObject[];zones:JsonObject[];capabilities:FirewallCapabilities|null;diagnostics:FirewallDiagnostics|null;analysis:FirewallAnalysis|null;snapshots:FirewallSnapshot[];diff:FirewallDiff|null;writeSafety:FirewallWriteSafety|null;loading:boolean;error:string;onReload:()=>void;onCreateSnapshot:(note:string)=>Promise<void>;onCompare:(before:number,after:number)=>Promise<void>;onOpen:(o:JsonObject)=>void}){
  const [tab,setTab]=useState<"policies"|"zones"|"analysis"|"snapshots"|"changes"|"capabilities"|"diagnostics">("policies");
  const [filter,setFilter]=useState("");
  const [note,setNote]=useState("");
  const [before,setBefore]=useState<number|"">("");
  const [after,setAfter]=useState<number|"">("");
  const filtered=useMemo(()=>policies.filter(o=>!filter||JSON.stringify(o).toLowerCase().includes(filter.toLowerCase())),[policies,filter]);
  const legacy=diagnostics?.firewall_model==="legacy";
  const zoneBased=diagnostics?.firewall_model==="zone_based";
  async function create(){await onCreateSnapshot(note);setNote("")}
  return <section className="card inventory">
    <div className="card-head"><div><h2>Firewall</h2><p>Official UniFi Network API · analysis and snapshots milestone</p></div><button className="secondary" onClick={onReload}><RefreshCw size={16} className={loading?"spin":""}/>Reload firewall</button></div>
    <div className="tabs"><button className={tab==="policies"?"active":""} onClick={()=>setTab("policies")}>Policies <span>{policies.length}</span></button><button className={tab==="zones"?"active":""} onClick={()=>setTab("zones")}>Zones <span>{zones.length}</span></button><button className={tab==="analysis"?"active":""} onClick={()=>setTab("analysis")}>Analysis <span>{analysis?.finding_count??0}</span></button><button className={tab==="snapshots"?"active":""} onClick={()=>setTab("snapshots")}>Snapshots <span>{snapshots.length}</span></button><button className={tab==="changes"?"active":""} onClick={()=>setTab("changes")}>Changes</button><button className={tab==="capabilities"?"active":""} onClick={()=>setTab("capabilities")}>Capabilities</button><button className={tab==="diagnostics"?"active":""} onClick={()=>setTab("diagnostics")}>Diagnostics</button></div>
    {legacy&&<div className="firewall-model legacy"><AlertTriangle size={20}/><div><b>Legacy firewall model detected</b><span>This UniFi site has not been migrated to Zone-Based Firewall. Policies, analysis, and snapshots from the official API are unavailable until migration.</span><small>Detected from UniFi code: {diagnostics?.detection_code}</small></div><span className="pill warn">Migration required</span></div>}
    {zoneBased&&<div className="firewall-model zone"><CheckCircle2 size={20}/><div><b>Zone-Based Firewall detected</b><span>Read-only analysis and local policy snapshots are available. Controlled-write safety gates are present. No mutation is exposed until all gates pass.</span></div><span className="pill ok">Available</span></div>}
    {error&&<div className="inline-error"><AlertTriangle size={18}/><div><b>Firewall operation unavailable</b><span>{error}</span></div></div>}
    {loading&&policies.length===0&&zones.length===0?<Loading/>:tab==="policies"?<>
      <div className="table-tools firewall-tools"><div className="mini-search"><Search size={15}/><input value={filter} onChange={e=>setFilter(e.target.value)} placeholder="Filter policies…"/></div><span className="pill neutral">Read only</span></div>
      {legacy?<LegacyFirewallEmpty subject="policies"/>:policies.length===0?<Empty icon={ShieldCheck} title="No firewall policies returned" text="The Zone-Based Firewall API is available, but no policies were returned for this site."/>:<div className="table-wrap"><table><thead><tr><th>Name</th><th>Action</th><th>Enabled</th><th>Logging</th><th>Index</th><th/></tr></thead><tbody>{filtered.map((o,i)=><tr className="click-row" key={text(o,"id")+i} onClick={()=>onOpen(o)}><td><b>{text(o,"name","description")}</b></td><td>{firewallAction(o)}</td><td><span className={`pill ${bool(o,"enabled")?"ok":"neutral"}`}>{bool(o,"enabled")?"Enabled":"Disabled"}</span></td><td>{bool(o,"loggingEnabled","logging_enabled")?"On":"Off"}</td><td>{text(o,"index","order")}</td><td><button className="row-open" onClick={e=>{e.stopPropagation();onOpen(o)}}>Details<ChevronRight size={16}/></button></td></tr>)}</tbody></table></div>}
    </>:tab==="zones"?
      legacy?<LegacyFirewallEmpty subject="zones"/>:zones.length===0?<Empty icon={ShieldCheck} title="No firewall zones returned" text="The Zone-Based Firewall API is available, but no zones were returned for this site."/>:<div className="table-wrap"><table><thead><tr><th>Name</th><th>Networks</th><th>Origin</th><th>Configurable</th></tr></thead><tbody>{zones.map((o,i)=><tr key={text(o,"id")+i}><td><b>{text(o,"name")}</b></td><td>{Array.isArray(o.networkIds)?o.networkIds.length:"—"}</td><td>{nestedText(o,"metadata","origin")}</td><td>{nestedBool(o,"metadata","configurable")?"Yes":"No"}</td></tr>)}</tbody></table></div>:
      tab==="analysis"?<FirewallAnalysisView analysis={analysis} legacy={legacy}/>:
      tab==="snapshots"?<FirewallSnapshotsView snapshots={snapshots} diff={diff} legacy={legacy} note={note} setNote={setNote} before={before} setBefore={setBefore} after={after} setAfter={setAfter} onCreate={create} onCompare={onCompare} loading={loading}/>:
      tab==="changes"?<FirewallChangesView safety={writeSafety} legacy={legacy}/>:tab==="capabilities"?<div className="cap-grid"><Capability label="Firewall model" note={legacy?"Legacy":zoneBased?"Zone based":"Unknown"}/><Capability label="Zone-Based configured" ok={diagnostics?.zone_based_configured===true} note={legacy?"Not configured":"Unknown"}/><Capability label="Policies read" ok={capabilities?.policies_read} note={legacy?"Unavailable on legacy model":undefined}/><Capability label="Zones read" ok={capabilities?.zones_read} note={legacy?"Unavailable on legacy model":undefined}/><Capability label="Ordering read" ok={capabilities?.ordering_read} note={legacy?"Unavailable on legacy model":undefined}/><Capability label="Write operations" ok={false} note={writeSafety?.write_ready?"Safety gates passed":"Blocked by safety gates"}/><Capability label="Policy count" value={capabilities?.policy_count}/><Capability label="Zone count" value={capabilities?.zone_count}/></div>:<DiagnosticsView diagnostics={diagnostics}/>} 
  </section>
}

function FirewallChangesView({safety,legacy}:{safety:FirewallWriteSafety|null;legacy:boolean}){
  if(!safety)return <Loading/>;
  return <div className="change-safety"><div className={`firewall-model ${safety.write_ready?"zone":"legacy"}`}><ShieldCheck size={20}/><div><b>{safety.write_ready?"Write safety gates passed":"Firewall changes are blocked"}</b><span>{safety.note}</span></div><span className={`pill ${safety.write_ready?"ok":"warn"}`}>{safety.write_ready?"Ready":"Blocked"}</span></div><div className="cap-grid"><Capability label="Global read-only" ok={!safety.global_read_only} note={safety.global_read_only?"Enabled":"Disabled"}/><Capability label="Firewall writes" ok={safety.allow_firewall_write}/><Capability label="Policy deletion" ok={safety.allow_firewall_delete}/><Capability label="Policy reorder" ok={safety.allow_policy_reorder}/><Capability label="Confirmation" ok={safety.require_change_confirmation}/><Capability label="Pre-change snapshot" ok={safety.create_prechange_snapshot}/></div>{safety.blocked_reasons.length>0&&<div className="limitations"><b>Blocked reasons</b>{safety.blocked_reasons.map(r=><p key={r}>• {r}</p>)}</div>}<div className="legacy-boundary"><b>Mandatory mutation workflow</b>{safety.workflow.map(step=><span key={step}>{step}</span>)}</div>{legacy&&<p className="muted">Your current legacy firewall cannot use official policy mutation endpoints. No legacy fallback is attempted.</p>}</div>
}

function FirewallAnalysisView({analysis,legacy}:{analysis:FirewallAnalysis|null;legacy:boolean}){
  if(legacy)return <LegacyFirewallEmpty subject="policies"/>;
  if(!analysis)return <Empty icon={CircleGauge} title="No firewall analysis available" text="Reload the firewall module after Zone-Based policies become available."/>;
  return <div className="analysis-view"><div className="analysis-summary"><div className={`score score-${analysis.score>=80?"good":analysis.score>=60?"warn":"bad"}`}><span>Firewall health score</span><strong>{analysis.score}</strong><small>100 = no current findings</small></div><div className="analysis-metrics"><MetricMini label="Policies" value={analysis.policy_count}/><MetricMini label="Zones" value={analysis.zone_count}/><MetricMini label="Critical" value={analysis.severity_counts.critical||0}/><MetricMini label="High" value={analysis.severity_counts.high||0}/></div></div>{analysis.findings.length===0?<Empty icon={CheckCircle2} title="No current findings" text="The conservative analysis checks did not identify broad, duplicate, or undocumented policies."/>:<div className="finding-list">{analysis.findings.map((f,i)=><div className={`finding ${f.severity}`} key={`${f.code}-${i}`}><div className="finding-head"><span className={`severity ${f.severity}`}>{f.severity}</span><b>{f.title}</b></div><p>{f.message}</p>{f.policy_name&&<small>Policy: {f.policy_name}</small>}<em>{f.recommendation}</em></div>)}</div>}<details className="limitations"><summary>Analysis boundaries</summary>{analysis.limitations.map(item=><p key={item}>{item}</p>)}</details></div>
}

function MetricMini({label,value}:{label:string;value:number}){return <div className="metric-mini"><span>{label}</span><b>{value}</b></div>}

function FirewallSnapshotsView({snapshots,diff,legacy,note,setNote,before,setBefore,after,setAfter,onCreate,onCompare,loading}:{snapshots:FirewallSnapshot[];diff:FirewallDiff|null;legacy:boolean;note:string;setNote:(v:string)=>void;before:number|"";setBefore:(v:number|"")=>void;after:number|"";setAfter:(v:number|"")=>void;onCreate:()=>Promise<void>;onCompare:(before:number,after:number)=>Promise<void>;loading:boolean}){
  if(legacy)return <LegacyFirewallEmpty subject="policies"/>;
  return <div className="snapshot-view"><div className="snapshot-create"><div><h3>Create policy snapshot</h3><p>Stores policies and zones in the app database. It does not create a full UniFi console backup.</p></div><input value={note} maxLength={500} onChange={e=>setNote(e.target.value)} placeholder="Optional note…"/><button className="refresh primary" disabled={loading} onClick={()=>void onCreate()}><Save size={16}/>Create snapshot</button></div>{snapshots.length===0?<Empty icon={Database} title="No firewall snapshots" text="Create the first snapshot after Zone-Based Firewall policies are available."/>:<><div className="snapshot-compare"><select value={before} onChange={e=>setBefore(e.target.value?Number(e.target.value):"")}><option value="">Before snapshot</option>{snapshots.map(s=><option key={s.id} value={s.id}>#{s.id} · {new Date(s.created_at*1000).toLocaleString()}</option>)}</select><select value={after} onChange={e=>setAfter(e.target.value?Number(e.target.value):"")}><option value="">After snapshot</option>{snapshots.map(s=><option key={s.id} value={s.id}>#{s.id} · {new Date(s.created_at*1000).toLocaleString()}</option>)}</select><button className="secondary" disabled={!before||!after||before===after||loading} onClick={()=>before&&after&&void onCompare(before,after)}><FileDiff size={16}/>Compare</button></div><div className="table-wrap"><table><thead><tr><th>ID</th><th>Created</th><th>Policies</th><th>Zones</th><th>Note</th><th>SHA-256</th></tr></thead><tbody>{snapshots.map(s=><tr key={s.id}><td>#{s.id}</td><td>{new Date(s.created_at*1000).toLocaleString()}</td><td>{s.policy_count}</td><td>{s.zone_count}</td><td>{s.note||"—"}</td><td><code>{s.sha256.slice(0,12)}…</code></td></tr>)}</tbody></table></div></>}{diff&&<div className="diff-card"><h3>Snapshot diff</h3><div className="analysis-metrics"><MetricMini label="Added" value={diff.summary.added}/><MetricMini label="Removed" value={diff.summary.removed}/><MetricMini label="Changed" value={diff.summary.changed}/></div><details><summary>Raw diff JSON</summary><pre>{JSON.stringify(diff,null,2)}</pre></details></div>}</div>
}

function LegacyFirewallEmpty({subject}:{subject:"policies"|"zones"}){
  return <div className="legacy-empty"><ShieldCheck size={34}/><h3>Zone-Based Firewall is not configured</h3><p>The current site uses the legacy firewall model, so official {subject} cannot be listed through the UniFi Network API.</p><div className="legacy-boundary"><b>Control Center behavior</b><span>No fallback to undocumented legacy endpoints</span><span>No firewall changes performed</span><span>Technical diagnostics remain available</span></div></div>
}

function DiagnosticsView({diagnostics}:{diagnostics:FirewallDiagnostics|null}){
  if(!diagnostics)return <Empty icon={Info} title="No diagnostics collected" text="Reload the firewall module to run read-only API diagnostics."/>;
  return <div className="diagnostics"><div className="diag-summary"><Setting label="Network API" value={diagnostics.network_api_reported}/><Setting label="UniFi OS" value={diagnostics.unifi_os_reported}/><Setting label="Site ID" value={diagnostics.site_id}/><Setting label="Mode" value={diagnostics.read_only?"Read only":"Control"}/></div><div className="diag-list">{diagnostics.attempts.map(a=><details className={`diag-attempt ${a.ok?"ok":"bad"}`} key={a.name} open={!a.ok&&diagnostics.firewall_model!=="legacy"}><summary><span>{a.name.replaceAll("_"," ")}</span><b>{a.ok?`HTTP ${a.status_code} · ${a.count??0} rows`:`HTTP ${a.status_code??"—"} ${a.reason??"Failed"}`}</b></summary><div className="diag-body">{a.method&&<Setting label="Method" value={a.method}/>} {a.url&&<Setting label="Request URL" value={a.url}/>}<h4>Response body</h4><pre>{JSON.stringify(a.response_body??a.data??null,null,2)}</pre>{a.response_headers&&<><h4>Selected headers</h4><pre>{JSON.stringify(a.response_headers,null,2)}</pre></>}</div></details>)}</div></div>
}

function firewallAction(o:JsonObject):string{const a=o.action;if(typeof a==="string")return a;if(a&&typeof a==="object")return text(a as JsonObject,"type","action","name");return "—"}
function nestedText(o:JsonObject,parent:string,key:string):string{const v=o[parent];return v&&typeof v==="object"?text(v as JsonObject,key):"—"}
function nestedBool(o:JsonObject,parent:string,key:string):boolean{const v=o[parent];return !!(v&&typeof v==="object"&&bool(v as JsonObject,key))}
function Capability({label,ok,value,note}:{label:string;ok?:boolean;value?:number;note?:string}){return <div className="cap-item"><span>{label}</span>{typeof value==="number"?<b>{value}</b>:<b className={ok?"cap-ok":"cap-no"}>{ok?"Available":note||"Unavailable"}</b>}</div>}

function DetailDrawer({item,kind,onClose}:{item:JsonObject;kind:string;onClose:()=>void}){
  const [copied,setCopied]=useState(false);
  const entries=Object.entries(item).filter(([,v])=>v!==null&&v!==undefined&&typeof v!=="object").slice(0,30);
  async function copy(){await navigator.clipboard.writeText(JSON.stringify(item,null,2));setCopied(true);setTimeout(()=>setCopied(false),1500)}
  return <div className="drawer-backdrop" onMouseDown={onClose}><aside className="detail-drawer" onMouseDown={e=>e.stopPropagation()}><div className="drawer-head"><div><span>{kind}</span><h2>{itemName(item)}</h2></div><button onClick={onClose}><X/></button></div><div className="drawer-actions"><button onClick={copy}><Clipboard size={16}/>{copied?"Copied":"Copy raw JSON"}</button></div><div className="detail-list">{entries.map(([k,v])=><div className="detail-row" key={k}><span>{k}</span><b>{String(v)}</b></div>)}</div><details><summary>Raw API record</summary><pre>{JSON.stringify(item,null,2)}</pre></details></aside></div>}
function AlertsPage({alerts,stats,config,clear,acknowledge,acknowledgeAll,remove,testNotification}:{alerts:AlertItem[];stats:AlertStats|null;config:Config|null;clear:()=>Promise<void>;acknowledge:(id:number)=>Promise<void>;acknowledgeAll:()=>Promise<void>;remove:(id:number)=>Promise<void>;testNotification:()=>Promise<void>}){
  const [level,setLevel]=useState<"all"|"error"|"success"|"info">("all");
  const [state,setState]=useState<"all"|"open"|"acknowledged">("all");
  const [source,setSource]=useState("all");
  const sources=useMemo(()=>Array.from(new Set(alerts.map(a=>a.source||"unknown"))).sort(),[alerts]);
  const filtered=alerts.filter(a=>(level==="all"||a.level===level)&&(state==="all"||(state==="open"&&!a.acknowledged)||(state==="acknowledged"&&a.acknowledged))&&(source==="all"||(a.source||"unknown")===source));
  const openCount=stats?.open??alerts.filter(a=>!a.acknowledged).length;
  return <section className="card inventory"><div className="card-head"><div><h2>Persistent alerts</h2><p>{openCount} open · {stats?.total??alerts.length} total · stored in SQLite</p></div><div className="table-tools"><select value={level} onChange={e=>setLevel(e.target.value as typeof level)}><option value="all">All severities</option><option value="error">Errors</option><option value="success">Success</option><option value="info">Info</option></select><select value={state} onChange={e=>setState(e.target.value as typeof state)}><option value="all">All states</option><option value="open">Open</option><option value="acknowledged">Acknowledged</option></select><select value={source} onChange={e=>setSource(e.target.value)}><option value="all">All sources</option>{sources.map(item=><option key={item} value={item}>{item}</option>)}</select><a className="secondary export-link" href="api/alerts/export?format=json">Export JSON</a><a className="secondary export-link" href="api/alerts/export?format=csv">Export CSV</a><button className="secondary" disabled={!config?.ntfy_enabled} onClick={()=>void testNotification()}><Bell size={16}/>Test ntfy</button>{openCount>0&&<button className="secondary" onClick={()=>void acknowledgeAll()}>Acknowledge all</button>}{alerts.length>0&&<button className="secondary" onClick={()=>void clear()}>Clear all</button>}</div></div>{stats&&<div className="analysis-metrics alert-stats"><MetricMini label="Open" value={stats.open}/><MetricMini label="Acknowledged" value={stats.acknowledged}/><MetricMini label="Errors" value={stats.by_level.error||0}/><MetricMini label="Sources" value={Object.keys(stats.by_source||{}).length}/></div>}{!config?.ntfy_enabled&&<div className="notice warning"><Info size={18}/><div><b>ntfy is disabled</b><span>Enable ntfy in the Home Assistant app configuration to send alerts to topic {config?.ntfy_topic||"ha-alerts"}.</span></div></div>}{filtered.length===0?<Empty icon={Bell} title="No matching alerts" text="Adjust the severity, state, or source filter."/>:<div className="alert-list">{filtered.map(a=><div className={`alert-row ${a.level} ${a.acknowledged?"acknowledged":""}`} key={a.id}>{a.level==="error"?<AlertTriangle/>:a.level==="success"?<CheckCircle2/>:<Info/>}<div><b>{a.message}</b><span>{a.source?`${a.source} · `:""}{a.at}{a.acknowledged?" · Acknowledged":""}</span></div><div className="alert-actions">{!a.acknowledged&&<button className="secondary" onClick={()=>void acknowledge(a.id)}>Acknowledge</button>}<button className="icon-btn" title="Delete alert" onClick={()=>void remove(a.id)}><X size={15}/></button></div></div>)}</div>}</section>}

function SettingsPage({config,testNotification}:{config:Config|null;testNotification:()=>Promise<void>}){return <section className="settings-grid"><div className="card settings-card"><h2>Connection</h2><Setting label="Controller URL" value={config?.controller_configured?"Configured":"Missing"}/><Setting label="API key" value={config?.api_key_configured?"Configured and masked":"Missing"}/><Setting label="TLS verification" value={config?.verify_tls?"Enabled":"Disabled"}/></div><div className="card settings-card"><h2>Runtime</h2><Setting label="Read-only gate" value={config?.read_only?"Enabled":"Disabled"}/><Setting label="Polling interval" value={`${config?.polling_interval??"—"} seconds`}/><p className="hint"><Info size={16}/>Change these values in the Home Assistant app configuration, then restart the app.</p></div><div className="card settings-card"><h2>ntfy notifications</h2><Setting label="Status" value={config?.ntfy_enabled?"Enabled":"Disabled"}/><Setting label="Topic" value={config?.ntfy_topic||"—"}/><Setting label="Connection failure" value={config?.notify_on_connection_failure?"Enabled":"Disabled"}/><Setting label="Connection recovery" value={config?.notify_on_connection_recovery?"Enabled":"Disabled"}/><Setting label="New client" value={config?.notify_on_new_client?"Enabled":"Disabled"}/><Setting label="Device offline" value={config?.notify_on_device_offline?"Enabled":"Disabled"}/><Setting label="Device recovery" value={config?.notify_on_device_recovery?"Enabled":"Disabled"}/><Setting label="Offline grace" value={`${config?.device_offline_grace_polls??"—"} poll(s)`}/><Setting label="Cooldown" value={`${config?.notification_cooldown??"—"} seconds`}/><button className="secondary" disabled={!config?.ntfy_enabled} onClick={()=>void testNotification()}><Bell size={16}/>Send test to {config?.ntfy_topic||"ha-alerts"}</button></div></section>}
function Setting({label,value}:{label:string;value:string}){return <div className="setting"><span>{label}</span><b>{value}</b></div>}
function SearchResults({items,onOpen}:{items:JsonObject[];onOpen:(o:JsonObject)=>void}){return <Inventory title="Search results" items={items} icon={Search} client onOpen={onOpen}/>}
function Loading(){return <div className="loading card"><RefreshCw className="spin"/><b>Loading UniFi data…</b></div>}
function Empty({icon:Icon,title,text}:{icon:React.ElementType;title:string;text:string}){return <div className="empty"><Icon size={32}/><h3>{title}</h3><p>{text}</p></div>}

createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);
