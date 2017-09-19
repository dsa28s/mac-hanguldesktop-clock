(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var UebersichtServer, args, cors_host, cors_port, cors_proxy, e, handleError, parseArgs, port, ref, ref1, ref2, ref3, ref4, ref5, server, settingsPath, widgetPath;

parseArgs = require('minimist');

UebersichtServer = require('./src/app.coffee');

cors_proxy = require('cors-anywhere');

handleError = function(e) {
  return console.log('Error:', e.message);
};

try {
  args = parseArgs(process.argv.slice(2));
  widgetPath = (ref = (ref1 = args.d) != null ? ref1 : args.dir) != null ? ref : './widgets';
  port = (ref2 = (ref3 = args.p) != null ? ref3 : args.port) != null ? ref2 : 41416;
  settingsPath = (ref4 = (ref5 = args.s) != null ? ref5 : args.settings) != null ? ref4 : './settings';
  server = UebersichtServer(Number(port), widgetPath, settingsPath, function() {
    return console.log('server started on port', port);
  });
  server.on('close', handleError);
  cors_host = '127.0.0.1';
  cors_port = 41417;
  cors_proxy.createServer({
    originWhitelist: ['http://127.0.0.1:' + port],
    requireHeader: ['origin'],
    removeHeaders: ['cookie']
  }).listen(cors_port, cors_host, function() {
    return console.log('CORS Anywhere on port', cors_port);
  });
} catch (error) {
  e = error;
  handleError(e);
}


},{"./src/app.coffee":8,"cors-anywhere":undefined,"minimist":undefined}],2:[function(require,module,exports){
'use strict';

const WebSocket = require('ws');

module.exports = function MessageBus(options) {
  const wss = new WebSocket.Server(options);

  function broadcast(data) {
    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    });
  }

  wss.on('connection', function connection(ws) {
    ws.on('message', broadcast);
  });

  return wss;
};

},{"ws":undefined}],3:[function(require,module,exports){
'use strict';

const path = require('path');
const fs = require('fs');

module.exports = function Settings(settingsDirPath) {
  const api = {};
  let settings;

  const fullSettingsDirPath = path.resolve(__dirname, settingsDirPath);
  const settingsFile = path.join(fullSettingsDirPath, 'WidgetSettings.json');

  initSettingsFile(fullSettingsDirPath);

  function initSettingsFile(dirPath) {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath);
    }
  }

  api.load = function load() {
    let persistedSettings = {};
    try {
      persistedSettings = require(settingsFile);
    } catch (e) { /* do nothing */ }

    return persistedSettings;
  };

  api.persist = function persist(newSettings) {
    if (newSettings !== settings) {
      fs.writeFile(settingsFile, JSON.stringify(newSettings), (err) => {
        if (err) {
          console.log(err);
        } else {
          settings = newSettings;
        }
      });
    }
  };

  return api;
};

},{"fs":undefined,"path":undefined}],4:[function(require,module,exports){
'use strict';

const WebSocket = typeof window !== 'undefined'
  ? window.WebSocket
  : require('ws');

let ws = null;
let isOpen = false;

const messageListeners = [];
const openListeners = [];

function handleWSOpen() {
  isOpen = true;
  openListeners.forEach((f) => f());
}

function handleWSCosed() {
  isOpen = false;
}

function handleMessage(data) {
  messageListeners.forEach((f) => f(data));
}

exports.open = function open(url) {
  ws = new WebSocket(url);

  if (ws.on) {
    ws.on('open', handleWSOpen);
    ws.on('close', handleWSCosed);
    ws.on('message', handleMessage);
  } else {
    ws.onopen = handleWSOpen;
    ws.onclose = handleWSCosed;
    ws.onmessage = (e) => handleMessage(e.data);
  }
};

exports.close = function close() {
  ws.close();
  ws = null;
};

exports.isOpen = function() {
  return ws && isOpen;
};

exports.onMessage = function onMessage(listener) {
  messageListeners.push(listener);
};

exports.onOpen = function onOpen(listener) {
  openListeners.push(listener);
};

exports.send = function send(data) {
  ws.send(data);
};


},{"ws":undefined}],5:[function(require,module,exports){
'use strict';

// middleware to serve the current state
module.exports = (store) => (req, res, next) => {
  if (req.url === '/state/') {
    res.end(JSON.stringify(store.getState()));
  } else {
    next();
  }
};

},{}],6:[function(require,module,exports){
'use strict';

const bundleWidget = require('./bundleWidget');
const fs = require('fs');

module.exports = function WidgetBundler() {
  const api = {};
  const bundles = {};

  api.push = function push(action, callback) {
    if (action && action.type) {
      action.type === 'added'
        ? addWidget(action.id, action.filePath, callback)
        : removeWidget(action.id, action.filePath, callback)
        ;
    }
  };

  api.close = function close() {
    for (var id in bundles) {
      bundles[id].close();
      delete bundles[id];
    }
  };

  function addWidget(id, filePath, emit) {
    if (!bundles[id]) {
      bundles[id] = WidgetBundle(id, filePath, (widget) => {
        emit({type: 'added', widget: widget});
      });
    }
  }

  function removeWidget(id, filePath, emit) {
    if (bundles[id]) {
      bundles[id].close();
      delete bundles[id];
      emit({type: 'removed', id: id});
    }
  }

  function WidgetBundle(id, filePath, callback) {
    const bundle = bundleWidget(id, filePath);
    const buildWidget = () => {
      const widget = {
        id: id,
        filePath: filePath,
      };

      fs.access(filePath, fs.R_OK, (couldNotRead) => {
        if (couldNotRead) return;
        bundle.bundle((err, srcBuffer) => {
          if (err) {
            widget.error = prettyPrintError(filePath, err);
          } else {
            widget.body = srcBuffer.toString();
          }

          callback(widget);
        });
      });
    };

    bundle.on('update', buildWidget);
    buildWidget();
    return bundle;
  }

  function prettyPrintError(filePath, error) {
    if (error.code === 'ENOENT') {
      return 'file not found';
    }
    let errStr = error.toString ? error.toString() : String(error.message);

    // coffeescipt errors will have [stdin] when prettyPrinted (because they are
    // parsed from stdin). So lets replace that with the real file path
    if (errStr.indexOf('[stdin]') > -1) {
      errStr = errStr.replace('[stdin]', filePath);
    } else {
      errStr = filePath + ': ' + errStr;
    }

    return errStr;
  }

  return api;
};

},{"./bundleWidget":9,"fs":undefined}],7:[function(require,module,exports){
'use strict';

function addWidget(widget) {
  return {
    type: 'WIDGET_ADDED',
    payload: widget,
  };
}

function removeWidget(id) {
  return {
    type: 'WIDGET_REMOVED',
    payload: id,
  };
}

exports.applyWidgetSettings = function applyWidgetSettings(id, settings) {
  return {
    type: 'WIDGET_SETTINGS_CHANGED',
    payload: { id: id, settings: settings },
  };
};

exports.get = function(widgetEvent) {
  switch (widgetEvent.type) {
    case 'added': return addWidget(widgetEvent.widget);
    case 'removed': return removeWidget(widgetEvent.id);
  };
};

},{}],8:[function(require,module,exports){
var CommandServer, MessageBus, Settings, StateServer, WidgetBundler, actions, connect, dispatchToRemote, fs, listenToRemote, path, reducer, redux, resolveWidget, serveClient, sharedSocket, watchDir;

connect = require('connect');

path = require('path');

fs = require('fs');

redux = require('redux');

MessageBus = require('./MessageBus');

watchDir = require('./directory_watcher.coffee');

WidgetBundler = require('./WidgetBundler.js');

Settings = require('./Settings');

StateServer = require('./StateServer');

CommandServer = require('./command_server.coffee');

serveClient = require('./serveClient');

sharedSocket = require('./SharedSocket');

actions = require('./actions');

reducer = require('./reducer');

resolveWidget = require('./resolveWidget');

dispatchToRemote = require('./dispatch');

listenToRemote = require('./listen');

module.exports = function(port, widgetPath, settingsPath, callback) {
  var action, bundler, dirWatcher, id, messageBus, ref, server, settings, store, value;
  store = redux.createStore(reducer, {
    widgets: {},
    settings: {},
    screens: []
  });
  listenToRemote(function(action) {
    return store.dispatch(action);
  });
  widgetPath = path.resolve(__dirname, widgetPath);
  if (fs.lstatSync(widgetPath).isSymbolicLink()) {
    widgetPath = fs.readlinkSync(widgetPath);
  }
  widgetPath = widgetPath.normalize();
  bundler = WidgetBundler(widgetPath);
  dirWatcher = watchDir(widgetPath, function(fileEvent) {
    return bundler.push(resolveWidget(fileEvent), function(widgetEvent) {
      var action;
      action = actions.get(widgetEvent);
      if (action) {
        store.dispatch(action);
        return dispatchToRemote(action);
      }
    });
  });
  settings = Settings(settingsPath);
  ref = settings.load();
  for (id in ref) {
    value = ref[id];
    action = actions.applyWidgetSettings(id, value);
    store.dispatch(action);
    dispatchToRemote(action);
  }
  store.subscribe(function() {
    return settings.persist(store.getState().settings);
  });
  messageBus = null;
  server = connect().use(CommandServer(widgetPath)).use(StateServer(store)).use(connect["static"](path.resolve(__dirname, './public'))).use(connect["static"](widgetPath)).use(serveClient).listen(port, '127.0.0.1', function() {
    messageBus = MessageBus({
      server: server
    });
    sharedSocket.open("ws://127.0.0.1:" + port);
    return typeof callback === "function" ? callback() : void 0;
  });
  return {
    close: function(cb) {
      dirWatcher.stop();
      bundler.close();
      server.close();
      sharedSocket.close();
      return messageBus.close(cb);
    },
    on: function(ev, handler) {
      return server.on(ev, handler);
    }
  };
};


},{"./MessageBus":2,"./Settings":3,"./SharedSocket":4,"./StateServer":5,"./WidgetBundler.js":6,"./actions":7,"./command_server.coffee":10,"./directory_watcher.coffee":11,"./dispatch":12,"./listen":13,"./reducer":14,"./resolveWidget":15,"./serveClient":16,"connect":undefined,"fs":undefined,"path":undefined,"redux":undefined}],9:[function(require,module,exports){

'use strict';

const browserify = require('browserify');
const watchify = require('./watchify');
const widgetify = require('./widgetify');
const coffeeify = require('coffeeify');
const babelify = require('babelify');
const jsxTransform = require('babel-plugin-transform-react-jsx');
const restSpreadTransform = require('babel-plugin-transform-object-rest-spread');
const es2015 = require('babel-preset-es2015');
const through = require('through2');

function wrapJSWidget() {
  let start = true;
  function write(chunk, enc, next) {
    if (start) {
      this.push('({');
      start = false;
    }
    next(null, chunk);
  }
  function end(next) {
    this.push('})');
    next();
  }

  return through(write, end);
}

module.exports = function bundleWidget(id, filePath) {
  const bundle = browserify(filePath, {
    detectGlobals: false,
    cache: {},
    packageCache: {},
  });


  bundle.plugin(watchify);
  bundle.require(filePath, { expose: id });
  bundle.external('run');

  if (filePath.match(/\.coffee$/)) {
    bundle.transform(coffeeify, {
      bare: true,
      header: false,
    });
  } else if (filePath.match(/\.jsx$/)) {
    bundle.transform(babelify, {
      presets: [es2015],
      plugins: [restSpreadTransform, [jsxTransform, { pragma: 'html' }]],
    });
  } else {
    bundle.transform(wrapJSWidget);
  }

  bundle.transform(widgetify, { id: id });
  return bundle;
};

},{"./watchify":17,"./widgetify":18,"babel-plugin-transform-object-rest-spread":undefined,"babel-plugin-transform-react-jsx":undefined,"babel-preset-es2015":undefined,"babelify":undefined,"browserify":undefined,"coffeeify":undefined,"through2":undefined}],10:[function(require,module,exports){
var spawn;

spawn = require('child_process').spawn;

module.exports = function(workingDir) {
  return function(req, res, next) {
    var command, shell;
    if (!(req.method === 'POST' && req.url === '/run/')) {
      return next();
    }
    shell = spawn('bash', [], {
      cwd: workingDir
    });
    command = '';
    req.on('data', function(chunk) {
      return command += chunk;
    });
    return req.on('end', function() {
      var setStatus;
      setStatus = function(status) {
        res.writeHead(status);
        return setStatus = function() {};
      };
      shell.stderr.on('data', function(d) {
        setStatus(500);
        return res.write(d);
      });
      shell.stdout.on('data', function(d) {
        setStatus(200);
        return res.write(d);
      });
      shell.on('error', function(err) {
        setStatus(500);
        return res.write(err.message);
      });
      shell.on('close', function() {
        setStatus(200);
        return res.end();
      });
      shell.stdin.write(command != null ? command : '');
      shell.stdin.write('\n');
      return shell.stdin.end();
    });
  };
};


},{"child_process":undefined}],11:[function(require,module,exports){
var fs, fsevents, paths;

paths = require('path');

fs = require('fs');

fsevents = require('fsevents');

module.exports = function(directoryPath, callback) {
  var api, findFiles, foundPaths, getPathType, init, registerFile, unregisterFiles;
  api = {};
  foundPaths = {};
  init = function() {
    var watcher;
    if (!fs.existsSync(directoryPath)) {
      throw new Error("could not find " + directoryPath);
    }
    watcher = fsevents(directoryPath);
    watcher.on('change', function(filePath, info) {
      switch (info.event) {
        case 'modified':
        case 'moved-in':
        case 'created':
          return findFiles(filePath, info.type, registerFile);
        case 'moved-out':
        case 'deleted':
          return unregisterFiles(filePath);
      }
    });
    watcher.start();
    console.log('watching', directoryPath);
    findFiles(directoryPath, 'directory', registerFile);
    return watcher;
  };
  registerFile = function(filePath) {
    filePath = filePath.normalize();
    foundPaths[filePath] = true;
    return callback({
      type: 'added',
      filePath: filePath.normalize(),
      rootPath: directoryPath
    });
  };
  unregisterFiles = function(path) {
    var filePath, i, len, ref, results;
    path = path.normalize();
    ref = Object.keys(foundPaths);
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      filePath = ref[i];
      if (filePath.indexOf(path) === 0) {
        results.push(callback({
          type: 'removed',
          filePath: filePath,
          rootPath: directoryPath
        }));
      }
    }
    return results;
  };
  findFiles = function(path, type, onFound) {
    if (type === 'file') {
      return onFound(path);
    } else {
      return fs.readdir(path, function(err, subPaths) {
        var fullPath, i, len, results, subPath;
        if (err) {
          return console.log(err);
        }
        results = [];
        for (i = 0, len = subPaths.length; i < len; i++) {
          subPath = subPaths[i];
          fullPath = paths.join(path, subPath);
          results.push(getPathType(fullPath, function(p, t) {
            return findFiles(p, t, onFound);
          }));
        }
        return results;
      });
    }
  };
  getPathType = function(path, callback) {
    return fs.stat(path, function(err, stat) {
      var type;
      if (err) {
        return console.log(err);
      }
      type = stat.isDirectory() ? 'directory' : 'file';
      return callback(path, type);
    });
  };
  return init();
};


},{"fs":undefined,"fsevents":undefined,"path":undefined}],12:[function(require,module,exports){
'use strict';

const ws = require('./SharedSocket');
const queuedMessages = [];

function drainQueuedMessages() {
  queuedMessages.forEach((m) => ws.send(m));
  queuedMessages.length = 0;
}

ws.onOpen(drainQueuedMessages);

module.exports = function dispatch(message) {
  const serializedMessage = JSON.stringify(message);

  if (ws.isOpen()) {
    ws.send(serializedMessage);
  } else {
    queuedMessages.push(serializedMessage);
  }
};

},{"./SharedSocket":4}],13:[function(require,module,exports){
'use strict';

const ws = require('./SharedSocket');
const listeners = [];

ws.onMessage(function handleMessage(data) {
  let message;
  try { message = JSON.parse(data); } catch (e) { null; }

  if (message) {
    listeners.forEach((f) => f(message));
  }
});

module.exports = function listen(callback) {
  listeners.push(callback);
};

},{"./SharedSocket":4}],14:[function(require,module,exports){
'use strict';

const defaultSettings = {
  showOnAllScreens: true,
  showOnMainScreen: false,
  showOnSelectedScreens: false,
  hidden: false,
  screens: [],
};

const handlers = {

  WIDGET_ADDED: (state, action) => {
    const widget = action.payload;
    const newWidgets = Object.assign({}, state.widgets, {
      [widget.id]: widget,
    });

    const settings = state.settings || {};
    const newSettings = settings[widget.id]
      ? state.settings
      : Object.assign({}, settings, { [widget.id]: defaultSettings });

    return Object.assign({},
      state,
      { widgets: newWidgets, settings: newSettings }
    );
  },

  WIDGET_REMOVED: (state, action) => {
    const id = action.payload;

    if (!state.widgets[id]) {
      return state;
    }

    const newWidgets = Object.assign({}, state.widgets);
    delete newWidgets[id];

    return Object.assign({}, state, { widgets: newWidgets });
  },

  WIDGET_SETTINGS_CHANGED: (state, action) => {
    const newSettings = Object.assign({},
      state.settings,
      { [action.payload.id]: action.payload.settings }
    );

    return Object.assign({}, state, { settings: newSettings });
  },

  WIDGET_SET_TO_ALL_SCREENS: (state, action) => {
    return updateSettings(state, action.payload, {
      showOnAllScreens: true,
      showOnSelectedScreens: false,
      showOnMainScreen: false,
      hidden: false,
      screens: [],
    });
  },

  WIDGET_SET_TO_SELECTED_SCREENS: (state, action) => {
    return updateSettings(state, action.payload, {
      showOnSelectedScreens: true,
      showOnAllScreens: false,
      showOnMainScreen: false,
      hidden: false,
    });
  },

  WIDGET_SET_TO_MAIN_SCREEN: (state, action) => {
    return updateSettings(state, action.payload, {
      showOnSelectedScreens: false,
      showOnAllScreens: false,
      showOnMainScreen: true,
      hidden: false,
      screens: [],
    });
  },

  WIDGET_SET_TO_HIDE: (state, action) => {
    return updateSettings(state, action.payload, {
      hidden: true,
    });
  },

  WIDGET_SET_TO_SHOW: (state, action) => {
    return updateSettings(state, action.payload, {
      hidden: false,
    });
  },

  SCREEN_SELECTED_FOR_WIDGET: (state, action) => {
    const settings = state.settings[action.payload.id];
    const newScreens = (settings.screens || []).slice();

    if (newScreens.indexOf(action.payload.screenId) === -1) {
      newScreens.push(action.payload.screenId);
    }

    return updateSettings(state, action.payload.id, {
      screens: newScreens,
    });
  },

  SCREEN_DESELECTED_FOR_WIDGET: (state, action) => {
    const newScreens = (state.settings[action.payload.id].screens || [])
      .filter((s) => s !== action.payload.screenId);

    return updateSettings(state, action.payload.id, {
      screens: newScreens,
    });
  },

  SCREENS_DID_CHANGE: (state, action) => {
    return Object.assign({}, state, {
      screens: action.payload,
    });
  },
};

function updateSettings(state, widgetId, patch) {
  const widgetSettings = state.settings[widgetId];
  const newSettings = Object.assign({},
    state.settings,
    { [widgetId]: Object.assign({}, widgetSettings, patch) }
  );

  return Object.assign({}, state, { settings: newSettings });
}

module.exports = function reduce(state, action) {
  let newState;

  const handler = handlers[action.type];
  if (handler) {
    newState = handler(state, action);
  } else {
    newState = state;
  }

  return newState;
};

},{}],15:[function(require,module,exports){
'use strict';

function isWidgetPath(filePath) {
  return (
    filePath.indexOf('/node_modules/') === -1 &&
    filePath.indexOf('/src/') === -1 &&
    filePath.indexOf('/lib/') === -1 &&
    /\.coffee$|\.js$|\.jsx$/.test(filePath)
  );
}

function widgetId(filePath, rootPath) {
  const fileParts = filePath
    .replace(rootPath, '')
    .split(/\/+/)
    .filter((part) => !!part);

  return fileParts.join('-')
    .replace(/\./g, '-')
    .replace(/\s/g, '_');
}

module.exports = function resolveWidget(fileEvent) {
  if (!isWidgetPath(fileEvent.filePath)) {
    return undefined;
  }

  return {
    id: widgetId(fileEvent.filePath, fileEvent.rootPath),
    filePath: fileEvent.filePath,
    type: fileEvent.type,
  };
};

},{}],16:[function(require,module,exports){
'use strict';

const fs = require('fs');
const path = require('path');
const stream = require('stream');

const indexHTML = fs.readFileSync(
  path.resolve(
    __dirname,
    path.join('public', 'index.html')
  )
);

module.exports = function serveClient(req, res, next) {
  const bufferStream = new stream.PassThrough();
  bufferStream.pipe(res);
  bufferStream.end(indexHTML);
};

},{"fs":undefined,"path":undefined,"stream":undefined}],17:[function(require,module,exports){
var through = require('through2');
var path = require('path');
var fs = require('fs');

module.exports = watchify;
module.exports.args = {
    cache: {}, packageCache: {}
};

function watchify (b, opts) {
    if (!opts) opts = {};
    var cache = b._options.cache;
    var pkgcache = b._options.packageCache;
    var delay = typeof opts.delay === 'number' ? opts.delay : 0;
    var changingDeps = {};
    var pending = false;
    var updating = false;
    var mtimes = {};

    var wopts = {persistent: true};
    if (opts.ignoreWatch) {
        wopts.ignored = opts.ignoreWatch !== true
            ? opts.ignoreWatch
            : '**/node_modules/**';
    }
    if (opts.poll || typeof opts.poll === 'number') {
        wopts.usePolling = true;
        wopts.interval = opts.poll !== true
            ? opts.poll
            : undefined;
    }

    if (cache) {
        b.on('reset', collect);
        collect();
    }

    function collect () {
        b.pipeline.get('deps').push(through.obj(function(row, enc, next) {
            var file = row.expose ? b._expose[row.id] : row.file;
            cache[file] = {
                source: row.source,
                deps: Object.assign({}, row.deps)
            };
            this.push(row);
            next();
        }));
    }

    b.on('file', function (file) {
        watchFile(file);
    });

    b.on('package', function (pkg) {
        var file = path.join(pkg.__dirname, 'package.json');
        if (fs.existsSync(file)) {
          watchFile(file);
        }
        if (pkgcache) pkgcache[file] = pkg;
    });

    b.on('reset', reset);
    reset();

    function reset () {
        var time = null;
        var bytes = 0;
        b.pipeline.get('record').on('end', function () {
            time = Date.now();
        });

        b.pipeline.get('wrap').push(through(write, end));
        function write (buf, enc, next) {
            bytes += buf.length;
            this.push(buf);
            next();
        }
        function end () {
            var delta = Date.now() - time;
            b.emit('time', delta);
            b.emit('bytes', bytes);
            b.emit('log', bytes + ' bytes written ('
                + (delta / 1000).toFixed(2) + ' seconds)'
            );
            this.push(null);
        }
    }

    var fwatchers = {};
    var fwatcherFiles = {};
    var ignoredFiles = {};

    b.on('transform', function (tr, mfile) {
        tr.on('file', function (dep) {
            watchFile(mfile, dep);
        });
    });
    b.on('bundle', function (bundle) {
        updating = true;
        bundle.on('error', onend);
        bundle.on('end', onend);
        function onend () { updating = false }
    });

    function watchFile (file, dep) {
        dep = dep || file;
        if (!fwatchers[file]) fwatchers[file] = [];
        if (!fwatcherFiles[file]) fwatcherFiles[file] = [];
        if (fwatcherFiles[file].indexOf(dep) >= 0) return;

        var w = b._watcher(dep, wopts);
        w.setMaxListeners(0);
        w.on('error', b.emit.bind(b, 'error'));
        w.on('change', function () {
            invalidate(file);
        });
        fwatchers[file].push(w);
        fwatcherFiles[file].push(dep);
    }

    function getMTime(filePath) {
        var mtime;

        try {
            fs.statSync(filePath).mtime.getTime();
        } catch (e) {
            if (e.code === 'ENOENT') {
                mtime = new Date().getTime();
            } else {
                throw(e);
            }
        }

        return mtime;
    }

    function invalidate (id) {
        var mtime = getMTime(id);
        if ((mtimes[id] || 0) >= mtime) return;
        mtimes[id] = mtime;

        if (cache) delete cache[id];
        if (pkgcache) delete pkgcache[id];
        changingDeps[id] = true;

        if (!updating && fwatchers[id]) {
            fwatchers[id].forEach(function (w) {
                w.close();
            });
            delete fwatchers[id];
            delete fwatcherFiles[id];
        }

        // wait for the disk/editor to quiet down first:
        if (pending) clearTimeout(pending);
        pending = setTimeout(notify, delay);
    }

    function notify () {
        if (updating) {
            pending = setTimeout(notify, delay);
        } else {
            pending = false;
            b.emit('update', Object.keys(changingDeps));
            changingDeps = {};
        }
    }

    b.close = function () {
        Object.keys(fwatchers).forEach(function (id) {
            fwatchers[id].forEach(function (w) { w.close() });
        });
    };

    b._watcher = function (file, opts) {
        return fs.watch(file, opts);
    };

    return b;
}

},{"fs":undefined,"path":undefined,"through2":undefined}],18:[function(require,module,exports){
var through = require('through2');
var esprima = require('esprima');
var escodegen = require('escodegen');
var stylus = require('stylus');
var nib = require('nib');
var ms = require('ms');

function addExports(node) {
  var widgetObjectExp = node.expression;

  node.expression = {
    type: 'AssignmentExpression',
    operator: '=',
    left: { type: 'Identifier', name: 'module.exports' },
    right: widgetObjectExp,
  };
}

function addId(widgetObjectExp, widetId) {
  var idProperty = {
    type: 'Property',
    key: { type: 'Identifier', name: 'id' },
    value: { type: 'Literal', value: widetId },
    computed: false,
  };

  widgetObjectExp.properties.push(idProperty);
}

function flattenStyle(styleProp, tree) {
  var preface = {
    type: 'Program',
    body: tree.body.slice(0, -1),
  };

  preface.body.push({
    type: 'ExpressionStatement',
    expression: styleProp.value,
  });

  return eval(escodegen.generate(preface));
}

function parseStyle(styleProp, widetId, tree) {
  var styleString;

  if (styleProp.value.type === 'Literal') {
    styleString = styleProp.value.value;
  } else {
    styleString = flattenStyle(styleProp, tree);
  }

  if (typeof styleString !== 'string') {
    return;
  }

  var scopedStyle = '#' + widetId
    + '\n  '
    + styleString.replace(/\n/g, '\n  ');

  var css = stylus(scopedStyle)
    .import('nib')
    .use(nib())
    .render();

  styleProp.key.name = 'css';
  styleProp.value.type = 'Literal';
  styleProp.value.value = css;
}

function parseRefreshFrequency(prop) {
  if (typeof prop.value.value === 'string') {
    prop.value.value = ms(prop.value.value);
  }
}

function parseWidgetProperty(prop, widgetId, tree) {
  switch (prop.key.name) {
    case 'style': parseStyle(prop, widgetId, tree); break;
    case 'refreshFrequency': parseRefreshFrequency(prop); break;
  }
}

function modifyAST(tree, widgetId) {
  var widgetObjectExp = getWidgetObjectExpression(tree);

  if (widgetObjectExp) {
    widgetObjectExp.properties.map(function(prop) {
      parseWidgetProperty(prop, widgetId, tree);
    });
    addId(widgetObjectExp, widgetId);
    addExports(tree.body[tree.body.length - 1]);
  }

  return tree;
}

function getWidgetObjectExpression(tree) {
  var lastStatement = tree.body[tree.body.length - 1];

  if (lastStatement && lastStatement.type === 'ExpressionStatement' ) {
    var widgetObjectExp = lastStatement.expression;
    if (widgetObjectExp.type === 'ObjectExpression') {
      return widgetObjectExp;
    }
  }

  return undefined;
}

module.exports = function(file, options) {
  var widgetId = options.id;
  var src = '';

  function write(buf, enc, next) { src += buf; next(); }
  function end(next) {
    var tree;
    try {
      tree = esprima.parse(src);
      if (tree) {
        this.push(escodegen.generate(modifyAST(tree, widgetId)));
      }
    } catch (e) {
      this.emit('error', e);
    }

    next();
  }

  return through(write, end);
};


},{"escodegen":undefined,"esprima":undefined,"ms":undefined,"nib":undefined,"stylus":undefined,"through2":undefined}]},{},[1]);
