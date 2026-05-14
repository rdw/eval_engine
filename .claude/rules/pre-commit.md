---
description: Use before declaring any development work complete
---

Before declaring any development complete, please make sure to run the following checks:

- `mise rubocop`
- `mise check:eslint`

Fix any issues that these tools uncover.

Then run `mise prettier` to reformat the code.

Then run the following to catch any mistakes that fixing the previous issues might have caused:

- `mise rspec`
- `mise vitest`

If there's anything broken in these tests, fix the issue, and then re-run the checks starting from `mise rubocop`.
