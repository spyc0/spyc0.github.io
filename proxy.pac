function FindProxyForURL(url, host) {

if (shExpMatch(url, "*.t.co/*"))
        return "DIRECT";

if (shExpMatch(url, "*.t.co.com/*|"))
        return "DIRECT";

if (shExpMatch(url, "*.twitter.com/*|"))
        return "DIRECT";

if (shExpMatch(host, "*.google.com*"))
        return "DIRECT";

if (shExpMatch(host, "98.194.166.249"))
        return "DIRECT";
 
// DEFAULT RULE: All other traffic, use below proxies, in fail-over order.
    return "SOCKS5 98.194.166.249:9300; SOCKS5 98.194.166.249:9100; SOCKS4 98.194.166.249:9100; SOCKS5 98.194.166.249:9100";

}
