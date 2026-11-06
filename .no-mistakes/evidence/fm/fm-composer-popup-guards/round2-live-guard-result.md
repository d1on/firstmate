# Guard (a) live reproduction remains blocked

Verdict: inconclusive, not a pass. No product or test source changed.

Ran real Claude Code 2.1.303, installed only in the isolated worktree, in a dedicated tmux server with classic rendering (`CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1`), isolated HOME and CLAUDE_CONFIG_DIR, no loaded settings, no MCP servers, and no tools. No model prompts were submitted and no remote hosts or live second mates were contacted. The CLI was not logged in; its real interactive composer and built-in slash popup rendered normally.

Attempted the exact missing screen arrangement through actual vendor UI actions: type `/exit` to open its popup, append `!  real draft`, and capture immediately, after 100 ms, and after settling. Repeated real editing while resizing the terminal through 80x24, 60x12, 120x40, 120x16, 80x40, and 120x40; also exercised Claude's Ctrl-L redraw after each transition. No synthetic terminal output or fixture was injected.

The 28 capture pairs show the older rule-pair `/exit` composer before vendor redraw or the updated `/exit!  real draft` composer afterward. In the settled UI the invalid draft replaces the old composer inside its own rule pair; it does not appear as a lower bare glyph row beneath a separate older `/exit` rule pair. Fifteen plain captures show the invalid draft, and none show the required simultaneous arrangement. The production extractor returned `/exit! real draft` on each settled invalid-draft capture, but that ordinary case does not verify guard (a). Plain and styled captures were sequential reads, so immediate-transition captures can differ; neither was synthesized.

The blocked prerequisite is a real vendor rendering sequence that leaves the older `/exit` rule pair above a lower bare `/exit!  real draft` row. Neither ordinary editing, terminal resizing nor Ctrl-L produced it here. This does not prove such a rendering sequence impossible. A reproducible real-Claude interaction that creates that arrangement is still needed; do not approve the missing live scenario on these results. Stopped rather than changing product code or substituting synthetic evidence.

Evidence: `round2-live-guard.py`, `round2-live-guard.log`, `round2-live-guard/observations.json`, and numbered plain/styled terminal captures in `round2-live-guard/`. The script invokes `fm_composer_extract_selected_content` from the production library on real styled pane captures.

Cleanup: stopped only this attempt's explicitly addressed private tmux server; removed disposable CLI dependencies, isolated configuration and lab directories; `git status --short` is empty. Old branch/archive refs were not changed. No linters, formatters, static analysis, broader test suites, pipeline controls or publication commands were run.
