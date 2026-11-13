'use strict';
// Preload for the Linkwarden web and worker processes (NODE_OPTIONS=--require). Linkwarden has no log level of
// its own and logs through console.* only, so the app's log_level option is applied here by dropping console
// calls below the configured level.
const RANK = { debug: 1, info: 2, warning: 4, error: 5 };
const wanted = RANK[String(process.env.LW_LOG_LEVEL || 'info').toLowerCase()];
const min = wanted === undefined ? RANK.info : wanted;
const noop = () => {};

const CALLS = { debug: RANK.debug, log: RANK.info, info: RANK.info, warn: RANK.warning, error: RANK.error };
for (const [name, rank] of Object.entries(CALLS)) {
  if (rank < min) console[name] = noop;
}
