function FindProxyForURL(url, host) {

if (shExpMatch(url, "*.t.co/*"))
        return "DIRECT";

if (shExpMatch(url, "*.t.co.com/*|"))
        return "DIRECT";

if (shExpMatch(url, "*.twitter.com/*|"))
        return "DIRECT";

if (shExpMatch(host, "*.google.com*"))
        return "DIRECT";
 
// DEFAULT RULE: All other traffic, use below proxies, in fail-over order.
    return "SOCKS5 10.0.0.20:9100; SOCKS5 127.0.0.1:9050; SOCKS4 10.0.0.20:9100; SOCKS5 127.0.0.1:9050";

}
