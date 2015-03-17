Purpose:
===
Serve fixtured API responses quickly and easily. Runs a tiny sinatra server that serves .json files from disk. Control which fixtures are being used at localhost:3000/test-panel


Installation:
===
Check out this repo, `cd` into it, then
```
$ bundle install
...
$ gem build json-rigs.gemspec
...
$ gem install json-rigs
```

Usage:
===
1. Make a folder called "fixtures" wherever you'd like to keep your fixtures.

2. Place .json files inside folders inside the fixtures folder as follows: `./fixtures/[url]/[HTTP method]/[response type].json` (e.g. `./fixtures/users/GET/success.json`)

3. `$ jrigs start` from the folder one level above "fixtures" (e.g., if fixtures is at `~/Code/my-api/fixtures`, run `jrigs start` from `~/Code/my-api`)

4. Choose which fixtures you want active at localhost:3000/test-panel

5. Use localhost:3000 as if it were your normal API server! E.g., `curl localhost:3000/resource` will return the contents of `./fixtures/resource/GET/success.json` if you chose the success fixture at localhost:3000/test-panel, or `./fixtures/resource/GET/failure.json` if you chose the failure fixture, etc.