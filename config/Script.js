// Universal Global Enhancement Script for Mihomo (v1.18+ / v1.19+)
// Compatible with Clash Verge Rev / Mihomo Party / Sparkle / FlClash (Windows / macOS / Linux)
// Focus: Minimize AI Streaming TTFT (Antigravity, Codex, Claude Code, Cursor) WITHOUT altering subscription rules or group structure.

var OPTIONS = {
  // Set false ONLY if your local ISP AND proxy nodes both have reliable native IPv6 routing
  disableIPv6: true,
  // TCP Keep-Alive (seconds): prevents NAT / transit relays from silently dropping idle HTTP/2 & gRPC streams between chat turns
  keepAliveIdle: 30,
  keepAliveInterval: 15,
  // Auto-tune existing url-test / fallback / load-balance groups & proxy-providers (anti-jitter + fast dead-node circuit breaker)
  tuneAutoGroups: true,
  autoGroupInterval: 180,
  autoGroupTolerance: 50,
  autoGroupTimeout: 2500,
  autoGroupMaxFailed: 2,
  // Inject Chrome uTLS fingerprint on TCP+TLS nodes & proxy-providers that do not explicitly specify one
  injectUtlsFingerprint: true,
  // Optional: set true to prepend 1 subscription-independent rule rejecting overseas UDP:443 (QUIC) for instant HTTP/2 fallback
  rejectOverseasQuic: false
};

var DUMMY_INFO_RE = /剩余流量|套餐到期|距离下次|流量重置|官网|群组|说明|网址|失联|过期|邀请|节点故障|请更新|Balance\s*:|Website\s*:|Telegram\s*:|Traffic\s*:|Expire\s*:|\b\d+(\.\d+)?\s*(B|KB|MB|GB|TB|KiB|MiB|GiB|TiB)\b|\b20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}\b/i;

function hasProcessRules(rules) {
  if (!Array.isArray(rules)) return false;
  for (var i = 0; i < rules.length; i++) {
    var r = String(rules[i] || "").trim();
    if (/^PROCESS-(NAME|PATH)/i.test(r) || /\(PROCESS-(NAME|PATH),/i.test(r)) {
      return true;
    }
  }
  return false;
}

function main(config, profileName) {
  if (!config || typeof config !== "object") return config;

  // Remove deprecated / invalid legacy keys that cause Mihomo v1.19+ warnings
  if ("prepend-rules" in config) delete config["prepend-rules"];
  if ("global-client-fingerprint" in config) delete config["global-client-fingerprint"];

  // 1. Core Transport, Connection Pool Keep-Alive & Loader Tuning
  config["log-level"] = config["log-level"] === "silent" ? "silent" : "warning";
  if (OPTIONS.disableIPv6) {
    config["ipv6"] = false;
  }
  if (!config["allow-lan"]) {
    config["bind-address"] = "127.0.0.1";
  }

  config["unified-delay"] = true;
  config["tcp-concurrent"] = true;
  config["disable-keep-alive"] = false;
  config["keep-alive-idle"] = OPTIONS.keepAliveIdle;
  config["keep-alive-interval"] = OPTIONS.keepAliveInterval;
  config["geodata-loader"] = "standard";
  config["etag-support"] = true;

  // Adaptive process matching: eliminates per-socket OS process-table scans (e.g. Win32 GetExtendedTcpTable) when unused
  config["find-process-mode"] = hasProcessRules(config["rules"]) ? "strict" : "off";

  // Persist selected nodes & Fake-IP cache across profile switches and core reloads
  config["profile"] = Object.assign({}, config["profile"] || {}, {
    "store-selected": true,
    "store-fake-ip": true
  });

  // TUN UDP NAT session efficiency (merged beneath client UI TUN settings)
  if (config["tun"] && typeof config["tun"] === "object") {
    config["tun"]["endpoint-independent-nat"] = true;
    if (!config["tun"]["udp-timeout"]) {
      config["tun"]["udp-timeout"] = 60;
    }
  }

  // 2. Per-Proxy & Proxy-Provider uTLS Fingerprint + Health-Check Tuning
  if (OPTIONS.injectUtlsFingerprint && Array.isArray(config["proxies"])) {
    var utlsTypes = { "vless": true, "vmess": true, "trojan": true, "anytls": true, "http": true };
    for (var i = 0; i < config["proxies"].length; i++) {
      var px = config["proxies"][i];
      if (!px || typeof px !== "object") continue;
      var pType = String(px["type"] || "").toLowerCase();
      var tlsEnabled = px["tls"] === true || pType === "trojan" || pType === "anytls";
      if (utlsTypes[pType] && tlsEnabled && !px["client-fingerprint"]) {
        px["client-fingerprint"] = "chrome";
      }
    }
  }

  if (config["proxy-providers"] && typeof config["proxy-providers"] === "object") {
    var provKeys = Object.keys(config["proxy-providers"]);
    for (var k = 0; k < provKeys.length; k++) {
      var prov = config["proxy-providers"][provKeys[k]];
      if (!prov || typeof prov !== "object") continue;
      if (OPTIONS.tuneAutoGroups) {
        var hc = (prov["health-check"] && typeof prov["health-check"] === "object") ? prov["health-check"] : {};
        hc["enable"] = true;
        if (!hc["url"] || /^http:\/\//i.test(String(hc["url"]))) {
          hc["url"] = "https://www.gstatic.com/generate_204";
        }
        if (!hc["interval"] || hc["interval"] > 300) {
          hc["interval"] = OPTIONS.autoGroupInterval;
        }
        hc["timeout"] = OPTIONS.autoGroupTimeout;
        if (typeof hc["lazy"] === "undefined") {
          hc["lazy"] = true;
        }
        prov["health-check"] = hc;
      }
      if (OPTIONS.injectUtlsFingerprint) {
        var ov = (prov["override"] && typeof prov["override"] === "object") ? prov["override"] : {};
        if (!ov["client-fingerprint"]) {
          ov["client-fingerprint"] = "chrome";
        }
        prov["override"] = ov;
      }
    }
  }

  // 3. Health-Check & Fast Circuit-Breaker Tuning on Existing Auto Groups (preserves all group names & structure)
  if (OPTIONS.tuneAutoGroups && Array.isArray(config["proxy-groups"])) {
    for (var gIdx = 0; gIdx < config["proxy-groups"].length; gIdx++) {
      var grp = config["proxy-groups"][gIdx];
      if (!grp || typeof grp !== "object") continue;
      if (grp.type === "url-test" || grp.type === "fallback" || grp.type === "load-balance") {
        if (Array.isArray(grp.proxies) && grp.proxies.length > 1) {
          var cleanProxies = [];
          for (var pIdx = 0; pIdx < grp.proxies.length; pIdx++) {
            var pName = grp.proxies[pIdx];
            if (pName && !DUMMY_INFO_RE.test(String(pName))) {
              cleanProxies.push(pName);
            }
          }
          if (cleanProxies.length > 0) {
            grp.proxies = cleanProxies;
          }
        }
        if (!grp.url || /^http:\/\//i.test(String(grp.url))) {
          grp.url = "https://www.gstatic.com/generate_204";
        }
        if (!grp.interval || grp.interval > 300) {
          grp.interval = OPTIONS.autoGroupInterval;
        }
        if (grp.type === "url-test" && (!grp.tolerance || grp.tolerance < 30)) {
          grp.tolerance = OPTIONS.autoGroupTolerance;
        }
        grp.timeout = OPTIONS.autoGroupTimeout;
        grp["max-failed-times"] = OPTIONS.autoGroupMaxFailed;
        if (typeof grp.lazy === "undefined") {
          grp.lazy = true;
        }
      }
    }
  }

  // 4. Safe Lightweight Domain Sniffer (override-destination: false never mutates custom hosts / --resolve IPs)
  config["sniffer"] = {
    "enable": true,
    "force-dns-mapping": true,
    "parse-pure-ip": true,
    "override-destination": false,
    "sniff": {
      "HTTP": {
        "ports": [80],
        "override-destination": false
      },
      "TLS": {
        "ports": [443]
      },
      "QUIC": {
        "ports": [443]
      }
    },
    "skip-domain": [
      "Mijia Cloud",
      "+.push.apple.com",
      "+.apple.com",
      "ssh.github.com"
    ],
    "skip-dst-address": [
      "127.0.0.0/8",
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
      "100.64.0.0/10",
      "169.254.0.0/16"
    ]
  };

  // 5. Static Zero-RTT Hosts Preload (DoH bootstrap & Windows NCSI probe constant)
  config["hosts"] = Object.assign({}, config["hosts"] || {}, {
    "dns.alidns.com": ["223.5.5.5", "223.6.6.6"],
    "doh.pub": ["1.12.12.12", "120.53.53.53"],
    "dns.msftncsi.com": "131.107.255.255"
  });

  // 6. Low-Latency Orthogonal Dual-Carrier Fake-IP DNS (DoQ 0-RTT/1-RTT + IP-literal DoH + 8192 ARC Cache)
  var existingFilter = (config["dns"] && Array.isArray(config["dns"]["fake-ip-filter"]))
    ? config["dns"]["fake-ip-filter"]
    : [];
  var baseFilter = [
    "localhost",
    "+.localhost",
    "*.lan",
    "*.local",
    "*.localdomain",
    "*.home.arpa",
    "*.arpa",
    "+.internal",
    "host.docker.internal",
    "gateway.docker.internal",
    "+.tailscale.com",
    "+.ts.net",
    "dns.msftncsi.com",
    "+.msftncsi.com",
    "+.msftconnecttest.com",
    "captive.apple.com",
    "mesu.apple.com",
    "swscan.apple.com",
    "swdist.apple.com",
    "connectivitycheck.gstatic.com",
    "connectivitycheck.platform.hicloud.com",
    "connect.rom.miui.com",
    "+.market.xiaomi.com",
    "wifi.vivo.com.cn",
    "nmcheck.gnome.org",
    "network-test.debian.org",
    "time.*.com",
    "time.*.gov",
    "time.*.apple.com",
    "ntp.*.com",
    "pool.ntp.org",
    "+.pool.ntp.org",
    "+.stun.*.*",
    "+.stun.*.*.*",
    "+.stun.*.*.*.*",
    "localhost.ptlogin2.qq.com",
    "localhost.sec.qq.com"
  ];
  var mergedFilter = [];
  var seen = {};
  var combined = baseFilter.concat(existingFilter);
  for (var f = 0; f < combined.length; f++) {
    var item = combined[f];
    if (item && !seen[item]) {
      seen[item] = true;
      mergedFilter.push(item);
    }
  }

  config["dns"] = {
    "enable": true,
    "ipv6": !OPTIONS.disableIPv6,
    "prefer-h3": false,
    "cache-algorithm": "arc",
    "cache-max-size": 8192,
    "enhanced-mode": "fake-ip",
    "fake-ip-range": "198.18.0.1/16",
    "use-hosts": true,
    "use-system-hosts": true,
    "respect-rules": false,
    "default-nameserver": [
      "223.5.5.5",
      "119.29.29.29"
    ],
    "proxy-server-nameserver": [
      "quic://223.5.5.5:853",
      "https://120.53.53.53/dns-query",
      "223.5.5.5",
      "119.29.29.29"
    ],
    "nameserver": [
      "quic://223.5.5.5:853",
      "https://223.5.5.5/dns-query",
      "https://120.53.53.53/dns-query",
      "119.29.29.29"
    ],
    "fallback": [],
    "fake-ip-filter": mergedFilter
  };

  // Optional subscription-independent QUIC reject (off by default to leave rules 100% untouched)
  if (OPTIONS.rejectOverseasQuic && Array.isArray(config["rules"])) {
    var quicRule = "AND,((NETWORK,UDP),(DST-PORT,443),(NOT,((GEOIP,CN,no-resolve)))),REJECT";
    if (config["rules"][0] !== quicRule) {
      config["rules"] = [quicRule].concat(config["rules"]);
    }
  }

  return config;
}
