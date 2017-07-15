function FindProxyForURL(url, host) 
  {
      // Your proxy server name and port
      var proxy_server = 'spyc0:9100';
      var no_proxy_server = "DIRECT";
     {
      // List of hosts to connect via the PROXY server
      var proxy_list = new Array(
          "http://google.co*",
          "https://google.co*",
          "*.google.co*",
          "*gstatic.com*",
          "*.googlevideo.co*",
//       "*facebook.com/*",
//       "*vimeo.com/*",
//       "*pinterest.com/*",
          "*youtube.com/*"
      );
      //Return proxy name for matched domains/hosts
      for (var i = 0; i < proxy_list.length; i++){
          var value = proxy_list[i];
          if (shExpMatch(url, value) ) {
              return "PROXY "+proxy_server;
          }
      }
      return no_proxy_server;
    }
    return no_proxy_server;
  }
