'use strict';
// Preload for the ts6 backend (NODE_OPTIONS=--require). The upstream backend
// logs through console.* only and has no log level of its own, so the add-on's
// log_level option is applied here by dropping console calls below the
// configured level. Levels follow the add-on option list.
const RANK = { trace: 0, debug: 1, info: 2, notice: 3, warning: 4, error: 5, fatal: 6 };
const wanted = RANK[String(process.env.LOG_LEVEL || 'info').toLowerCase()];
const min = wanted === undefined ? RANK.info : wanted;
const noop = () => {};

const CALLS = { trace: RANK.trace, debug: RANK.debug, log: RANK.info, info: RANK.info, warn: RANK.warning, error: RANK.error };
for (const [name, rank] of Object.entries(CALLS)) {
  if (rank < min) console[name] = noop;
}
