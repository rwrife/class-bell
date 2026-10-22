-- Class Bell v1 fixture: pre-history snapshot with an alias-only roster.
PRAGMA user_version = 1;
CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id = 1), json TEXT NOT NULL);
INSERT INTO state (id, json) VALUES (1, '{"rosters":[{"id":"r-1","name":"Blue Room","students":[{"id":"s-1","displayName":"Ana","group":"Table 1","isExcluded":false}]}],"selectedRosterId":"r-1","presetMinutes":12,"goal":50,"quietSound":true,"unlockComboIndex":2}');
