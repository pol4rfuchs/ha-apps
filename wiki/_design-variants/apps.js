window.APPS=[
{s:"ntfy",n:"ntfy",c:"Messaging",i:"🔔",a:"#34d399",d:"Self-hosted push notifications. HTTP API, UnifiedPush, iOS push via ntfy.sh relay.",t:["Push","HA Add-on"]},
{s:"ntfy-manager",n:"ntfy-manager",c:"Messaging",i:"🛎️",a:"#f59e0b",d:"Web admin console: topic reservations, message browser, ACL, SSE live monitor, tokens.",t:["ntfy","Admin UI"]},
{s:"teamspeak6",n:"teamspeak6",c:"Voice",i:"🎧",a:"#a3e635",d:"TeamSpeak 6 voice server. Persistence, update behavior, admin token, backup notes.",t:["TS6","Server"]},
{s:"ts6-manager",n:"ts6-manager",c:"Voice",i:"🎚️",a:"#facc15",d:"Web UI for TS6: WebQuery API, music bots, bot flows, persistence and security.",t:["TS6","Manager"]},
{s:"matrix-synapse",n:"matrix-synapse",c:"Matrix",i:"🧬",a:"#8b5cf6",d:"Full Matrix stack: Synapse, Element Web, Element Call, LiveKit, Ketesa admin UI, PostgreSQL.",t:["Matrix","Synapse"]},
{s:"matrix-auth-service",n:"matrix-auth-service",c:"Matrix",i:"🔑",a:"#a78bfa",d:"Matrix Authentication Service (OIDC/OAuth2): Element X QR login and MFA. Experimental.",t:["Matrix","MAS"]},
{s:"matrix-signal-bridge",n:"matrix-signal-bridge",c:"Matrix",i:"🌉",a:"#3b82f6",d:"mautrix-signal bridge for Synapse, isolated add-on, linked-device login.",t:["Matrix","Bridge"]},
{s:"matrix-telegram-bridge",n:"matrix-telegram-bridge",c:"Matrix",i:"✈️",a:"#14b8a6",d:"mautrix-telegram bridge, phone-number login, needs a my.telegram.org API ID.",t:["Matrix","Bridge"]},
{s:"matrix-whatsapp-bridge",n:"matrix-whatsapp-bridge",c:"Matrix",i:"💬",a:"#22c55e",d:"mautrix-whatsapp bridge for Synapse, isolated add-on, QR login.",t:["Matrix","Bridge"]},
{s:"navidrome",n:"navidrome",c:"Media",i:"🎵",a:"#f97316",d:"Self-hosted music server, Subsonic/Airsonic API: DSub, Symfonium, Feishin and more.",t:["Music","Subsonic"]},
{s:"intiface-central",n:"intiface-central",c:"Media",i:"🕹️",a:"#ec4899",d:"Buttplug/Intiface Central with browser WebGUI, MQTT bridge and HA entity auto-discovery.",t:["Intiface","MQTT"]},
{s:"nginx-proxy-manager",n:"nginx-proxy-manager",c:"Network",i:"🔀",a:"#06b6d4",d:"Reverse proxy with SSL automation, DNS-01, DuckDNS wildcards and MariaDB support.",t:["NPM","Proxy"]},
{s:"unbound",n:"unbound",c:"Network",i:"🛡️",a:"#2dd4bf",d:"Hardened recursive DNS resolver with web UI: blocklists, local records, DNSSEC. 11 CVEs fixed.",t:["DNS","Hardened"]},
{s:"unifi-os-control-center",n:"unifi-os-control-center",c:"Network",i:"📡",a:"#0ea5e9",d:"Experimental local-first UniFi OS monitoring: Ingress-only, read-only firewall analysis, alerts.",t:["UniFi","Monitoring"]},
{s:"searxng",n:"searxng",c:"Network",i:"🔎",a:"#6366f1",d:"Privacy-respecting metasearch. No tracking, no profiles. JSON API for HA automations.",t:["Search","Privacy"]},
{s:"forgejo",n:"forgejo",c:"Cloud & Dev",i:"🦊",a:"#f97316",d:"Self-hosted Git platform: repos, issues, PRs, CI/CD Actions, package registry, optional SSH.",t:["Git","Forge"]},
{s:"nextcloud",n:"nextcloud",c:"Cloud & Dev",i:"☁️",a:"#0082c9",d:"Full Nextcloud on the official image, unrestricted app store, MariaDB-backed.",t:["Cloud","Files"]},
{s:"restic-backup",n:"restic-backup",c:"Cloud & Dev",i:"💾",a:"#e11d48",d:"Scheduled encrypted restic backups of HA config/media/add-on data with ntfy alerting.",t:["Backup","restic"]},
{s:"hwinfo-thermalguard",n:"hwinfo-thermalguard",c:"Cloud & Dev",i:"🌡️",a:"#ef4444",d:"Windows gaming-PC Thermal Guard: HWiNFO, RemoteHWInfo, watchdog, ntfy push.",t:["HWiNFO","Windows"]}
];
window.CATS=[...new Set(APPS.map(a=>a.c))];
window.hexA=(h,a)=>{const n=parseInt(h.slice(1),16);return `rgba(${n>>16},${(n>>8)&255},${n&255},${a})`};
window.wireSearch=(inp,sel)=>{inp.addEventListener('input',()=>{const q=inp.value.toLowerCase();document.querySelectorAll(sel).forEach(e=>e.hidden=!e.textContent.toLowerCase().includes(q))})};
