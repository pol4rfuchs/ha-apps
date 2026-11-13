'use strict';
// Preload for the Linkwarden web and worker processes (NODE_OPTIONS=--require). Linkwarden logs through console.*
// only and has no log level of its own, so the app's log_level option is applied here by dropping console calls
// below the configured level.
//
// The same wrapper keeps secrets out of the log: the worker prints the URL of the remote browser, which usually
// holds a token (for example Browserless), and an access token is as good as a password. Query parameters that
// look like credentials, and user:password@ in front of a host, are replaced before anything is written.
const RANK = { debug: 1, info: 2, warning: 4, error: 5 };
const wanted = RANK[String(process.env.LW_LOG_LEVEL || 'info').toLowerCase()];
const min = wanted === undefined ? RANK.info : wanted;
const noop = () => {};

const SECRET_PARAM = /([?&](?:token|apikey|api_key|key|password|secret)=)[^&\s)"']+/gi;
const USERINFO = /(\b[a-z][a-z0-9+.-]*:\/\/)[^\s/@?#]+@/gi;
const redact = (value) =>
  typeof value === 'string' ? value.replace(SECRET_PARAM, '$1<hidden>').replace(USERINFO, '$1<hidden>@') : value;

const CALLS = { debug: RANK.debug, log: RANK.info, info: RANK.info, warn: RANK.warning, error: RANK.error };
for (const [name, rank] of Object.entries(CALLS)) {
  if (rank < min) {
    console[name] = noop;
  } else {
    const original = console[name].bind(console);
    console[name] = (...args) => original(...args.map(redact));
  }
}
