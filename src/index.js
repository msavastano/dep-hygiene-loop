'use strict';

// The application is deliberately trivial. The point of this repo is the LOOP
// machinery around it (see README.md), not the code in this file.
//
// We pull in two real runtime dependencies pinned to deliberately stale
// versions so `npm outdated` and `npm audit` produce genuine findings for the
// dependency-hygiene loop to act on.
const express = require('express');
const _ = require('lodash');

const app = express();

// One route returning JSON. `npm test` asserts this responds (the loop's
// stop condition is "all tests pass and lint is clean").
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'dep-hygiene-loop',
    // Trivial use of lodash so it is a genuine runtime dependency, not dead weight.
    deps: _.uniq(['express', 'lodash', 'express']),
  });
});

// Only bind a port when run directly (`npm start`). When required by the test
// suite we export the app so supertest can drive it without opening a socket.
if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(`dep-hygiene-loop listening on http://localhost:${port}`);
  });
}

module.exports = app;
