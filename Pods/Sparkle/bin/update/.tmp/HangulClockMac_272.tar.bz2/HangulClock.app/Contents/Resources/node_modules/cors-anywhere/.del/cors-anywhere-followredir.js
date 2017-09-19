// © 2013 Rob W <gwnRob@gmail.com>
// Released under the MIT license

var httpProxy = require('http-proxy');
var net = require('net');
var url = require('url');
var regexp_tld = require('./regexp-top-level-domain');

var help_file = __dirname + '/help.txt';
var help_text;
function showUsage(headers, response) {
  headers['content-type'] = 'text/plain';
  if (help_text != null) {
    response.writeHead(200, headers);
    response.end(help_text);
  } else {
    require('fs').readFile(help_file, 'utf8', function(err, data) {
      if (err) {
        console.error(err);
        response.writeHead(500, headers);
        response.end();
      } else {
        help_text = data;
        showUsage(headers, response); // Recursive call, but since data is a string, the recursion will end
      }
    });
  }
}

function hasNoContent(hostname) {
  // Show 404 for non-requests. For instance when hostname is favicon.ico, robots.txt, ...
  return !(
    regexp_tld.test(hostname) ||
    net.isIPv4(hostname) ||
    net.isIPv6(hostname)
  );
}

// First argument: The response.headers object
// Second argument: The request object.
function withCORS(headers, request) {
  var origin = request.headers.origin || 'null';
  headers['access-control-allow-origin'] = origin === 'null' ? '*' : origin;
  if (request.headers['access-control-request-method']) {
    headers['access-control-allow-methods'] = request.headers['access-control-request-method'];
    delete req.headers['access-control-request-method'];
  }
  if (request.headers['access-control-request-headers']) {
    headers['access-control-allow-headers'] = request.headers['access-control-request-headers'];
    delete request.headers['access-control-request-headers'];
  }
  return headers;
}
function getProto(req) {
  return req.isSpdy ? 'https' : (req.connection.pair ? 'https' : 'http');
}
function _clone(obj) {
  var clone = {};
  Object.keys(clone).forEach(function(key) {
    clone[key] = obj[key];
  });
  return clone;
}
function isForbidden(host) {
  return /^localhost|0.0.0.0|::1|::|$/i.test(host);
}
function proxyRequest(req, res, proxy, full_url, proxyOptions, /*internal*/attempts) {
  if (isForbidden(proxyOptions.host)) {
    res.writeHead(403, 'Refused to visit', withCORS({'Location': full_url}, req));
    return;
  }
  // Hook res.writeHead method to set the correct header
  var base_host = getProto(req) + req.headers.host;
  var original_headers = _clone(req.headers);
  var res_writeHead = res.writeHead;
  res.writeHead = function(statusCode, reasonPhrase, headers) {
    if (typeof reasonPhrase === 'object') {
      headers = reasonPhrase;
      reasonPhrase = undefined;
    }
    if (!headers) headers = withCORS({}, req);
    else {
      withCORS(headers, req);
      
      // Handle redirects
      if (statusCode === 301 || statusCode === 302) {
        var location = headers.location || headers.Location;
        if (!location) {
          return res_writeHead.call(400, statusCode + ' without Location header', headers);
          return;
        }
        location = url.resolve(full_url, location);
        // Change state of req as if no request has occurred yet.
        res.writable = false;
        res.removeAllListeners();
        req.emit('aborted');
        req.removeAllListeners();
        req.url = location;
        req.headers = original_headers;

        res.writable = true;
        res.writeHead = res_writeHead;
        attempts = attempts ? attempts + 1 : 1;
        if (attempts > 5) { // "A user agent SHOULD NOT automatically redirect a request more than 5 times"
                            // --- http://tools.ietf.org/html/rfc2068#section-10.3
          res.writeHead(400, 'Maximum redirect count exceeded', headers);
        } else {
          var parsed = url.parse(location);
          proxyOptions = {
            host: parsed.hostname
          };
          proxyOptions.port = +parsed.port || (parsed.protocol === 'https:' ? 443 : 80);
          proxyRequest(req, res, proxy, location, proxyOptions, attempts);
        }
        return;
      }

      delete headers['set-cookie'];
      delete headers['set-cookie2'];
    }
    return res_writeHead.call(this, statusCode, reasonPhrase, headers);
  };

  // Finally, proxy the request
  proxy.proxyRequest(req, res, proxyOptions);
}


// Called on every request
var getHandler = exports.getHandler = function(options) {
  var corsAnywhere = {
    withCredentials: false,   // Toggle credentials/cookies
    requireHeader: null,      // Require a header to be set?
    removeHeaders: []         // Strip these request headers
  };
  if (options) {
    Object.keys(corsAnywhere).forEach(function(option) {
      if (Object.prototype.hasOwnProperty.call(options, option)) {
        corsAnywhere[option] = options[option];
      }
    });
  }

  return function(req, res, proxy) {
    var cors_headers = withCORS({}, req);
    if (req.method == 'OPTIONS') {
      // Pre-flight request. Reply successfully:
      res.writeHead(200, cors_headers);
      res.end();
      return;
    } else {
      // Actual request. First, extract the desired URL from the request:
      var full_url, host, hostname, port, path, match;
      match = req.url.match(/^\/(?:(https?:)?\/\/)?(([^\/?]+?)(?::(\d{0,5})(?=[\/?]|$))?)([\/?][\S\s]*|$)/i);
      //                            ^^^^^^^          ^^^^^^^^      ^^^^^^^                ^^^^^^^^^^^^
      //                          1:protocol       3:hostname     4:port                 5:path + query string
      //                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      //                                          2:host
      if (!match || (match[2].indexOf('.') === -1 && match[2].indexOf(':') === -1) || match[4] > 65535) {
        // Incorrect usage. Show how to do it correctly.
        showUsage(cors_headers, res);
        return;
      } else if (match[2] === 'iscorsneeded') {
        // Is CORS needed? This path is provided so that API consumers can test whether it's necessary
        // to use CORS. The server's reply is always No, because if they can read it, then CORS headers
        // are not necessary.
        res.writeHead(200, {'Content-Type': 'text/plain'});
        res.end('no');
        return;
      } else if (match[4] > 65535) {
        // Port is higher than 65535
        res.writeHead(400, 'Invalid port', cors_headers);
        res.end();
        return;
      } else if ( hasNoContent(match[3]) ) {
        // Don't even try to proxy invalid hosts
        res.writeHead(404, cors_headers);
        res.end();
        return;
      } else if (corsAnywhere.requireHeader != null && req.headers[corsAnywhere.requireHeader.toLowerCase()] == null) {
        res.writeHead(400, cors_headers);
        res.end('Missing ' + corsAnywhere.requireHeader + ' header!');
        return;
      } else {
        full_url = match[0].substr(1);
        host = match[2];
        hostname = match[3];
        // Read port from input:  :<port>  /  443 if https  /  80 by default
        port = match[4] ? +match[4] : (match[1] && match[1].toLowerCase() === 'https:' ? 443 : 80);
        path = match[5];
      }
      // Change the requested path:
      req.url = path;

      corsAnywhere.removeHeaders.forEach(function(header) {
        delete req.headers[header];
      });

      proxyRequest(req, res, proxy, full_url, {
        host: hostname,
        port: port
      });
    }
  };
};

// Create server with default and given values
// Creator still needs to call .listen()
var createServer = exports.createServer = function(options) {
  if (!options) options = {};

  // Default options:
  var httpProxyOptions = {
    changeOrigin: true,         // Change Host request header to match the requested URL instead of the proxy's URL.
    xforward: {
      enable: true            // Append X-Forwarded-* headers
    }
  };
  // Allow user to override defaults and add own options
  if (options.httpProxyOptions) {
    Object.keys(options.httpProxyOptions).forEach(function(option) {
      httpProxyOptions[option] = options.httpProxyOptions[option];
    });
  }

  var handler = getHandler(options);
  var server = httpProxy.createServer(httpProxyOptions, handler);

  // When the server fails, just show a 404 instead of Internal server error
  server.proxy.on('proxyError', function(err, req, res) {
    res.writeHead(404, {});
    res.end();
  });

  return server;
};
