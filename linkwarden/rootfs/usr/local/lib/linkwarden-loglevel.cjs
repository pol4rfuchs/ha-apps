'use strict';
// Preload for the Linkwarden web and worker processes (NODE_OPTIONS=--require). Linkwarden logs through console.*
// only and has no log level of its own, so the app's log_level option is applied here by dropping console calls
// below the configured level.
//
// The same wrapper keeps the log readable and free of secrets:
// - The worker prints the URL of the remote browser, which usually holds a token (for example Browserless), and an
//   access token is as good as a password. Query parameters that look like credentials, and user:password@ in front
//   of a host, are replaced before anything is written.
// - A page can make a library dump a whole style sheet or document into one message (jsdom does that when it cannot
//   parse a style block). Text longer than MAX_STRING characters is cut and says how much was left out. Text that
//   holds a stack trace (lines starting with "at ") gets the larger limit MAX_STACK, so the trace stays whole. At
//   the level debug nothing is cut. Error objects are left alone.
const RANK = { debug: 1, info: 2, warning: 4, error: 5 };
const wanted = RANK[String(process.env.LW_LOG_LEVEL || 'info').toLowerCase()];
const min = wanted === undefined ? RANK.info : wanted;
const noop = () => {};

const MAX_STRING = 1000;
const MAX_STACK = 5000;
const STACK_FRAME = /\n\s+at /;
const debugging = min <= RANK.debug;
const limitFor = (text) => (debugging ? Infinity : STACK_FRAME.test(text) ? MAX_STACK : MAX_STRING);

const SECRET_PARAM = /([?&](?:token|apikey|api_key|key|password|secret)=)[^&\s)"']+/gi;
const USERINFO = /(\b[a-z][a-z0-9+.-]*:\/\/)[^\s/@?#]+@/gi;
// The secrets are hidden first, then the text is shortened, so a cut can never expose or split a hidden value.
const tidy = (value) => {
  if (typeof value !== 'string') return value;
  const hidden = value.replace(SECRET_PARAM, '$1<hidden>').replace(USERINFO, '$1<hidden>@');
  const limit = limitFor(hidden);
  return hidden.length > limit ? `${hidden.slice(0, limit)}... (${hidden.length - limit} more characters)` : hidden;
};

const CALLS = { debug: RANK.debug, log: RANK.info, info: RANK.info, warn: RANK.warning, error: RANK.error };
for (const [name, rank] of Object.entries(CALLS)) {
  if (rank < min) {
    console[name] = noop;
  } else {
    const original = console[name].bind(console);
    console[name] = (...args) => original(...args.map(tidy));
  }
}
