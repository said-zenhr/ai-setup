#!/usr/bin/env ruby
# Training Wheels Protocol — state engine, hooks, and dashboard.
#
# State: ~/.claude/training-wheels/state.json + sha256 sidecar (.sig) so manual
# edits are detected (not prevented — jailbreaks get logged, Ned-style).
#
# Subcommands:
#   inject   SessionStart hook: print rules + level + tamper check as context
#   scan     UserPromptSubmit hook: detect override phrases (two-step flow)
#   gate     PreToolUse hook: block Edit/Write to source files in strict mode
#   xp N "reason"           adjust XP (Claude calls this per the skill's XP table)
#   gap "topic"             tally a knowledge gap
#   kata pass|fail "desc"   record a no-AI kata (suit-off exam)
#   level [strict|normal|loose|auto]   show or force level (forced = logged)
#   stats    plain-text dashboard
#   dash     interactive ANSI dashboard (tabs 1-4, q quits)

require "json"
require "digest"
require "io/console"

DIR   = File.expand_path("~/.claude/training-wheels")
STATE = File.join(DIR, "state.json")
SIG   = File.join(DIR, "state.sig")

DEFAULT = {
  "xp"               => 0,
  "forced_level"     => nil, # manual override via `tw.rb level X`
  "pending_override" => nil, # {"ts","prompt"} awaiting 2nd confirm
  "overrides"        => [],  # confirmed "just do it" events
  "emergencies"      => [],
  "gaps"             => {},  # topic => count
  "katas"            => [],  # {"ts","desc","passed"}
  "xp_log"           => [],  # {"ts","delta","reason"}
  "tampers"          => [],  # detected manual state edits
  "history"          => [],  # level changes {"ts","level","how"}
}.freeze

# XP thresholds AND kata gates — both required (Stark: modules, not just time)
LEVELS = [["strict", 0, 0], ["normal", 200, 1], ["loose", 500, 3]].freeze

OVERRIDE_RE  = /\b(just (do|write|fix|build|code) (it|this|that)|do it for me|skip the (quiz|questions|hints)|just give me the (code|answer|fix))\b/i
CONFIRM_RE   = /\b(do it|i'?m sure|yes,? (do it|really)|confirm|override)\b/i
EMERGENCY_RE = /\b(prod(uction)? (is )?down|incident|outage|hotfix now)\b/i

def sig_of(raw)
  Digest::SHA256.hexdigest("tw-v1:" + raw)
end

def load_state
  return [DEFAULT.dup, false] unless File.exist?(STATE)
  raw = File.binread(STATE)
  state = DEFAULT.merge(JSON.parse(raw))
  tampered = File.exist?(SIG) && File.read(SIG).strip != sig_of(raw)
  state["tampers"] << { "ts" => Time.now.to_f, "note" => "state.json edited outside tw.rb" } if tampered
  [state, tampered]
end

def save_state(state)
  Dir.mkdir(DIR) unless Dir.exist?(DIR)
  raw = JSON.pretty_generate(state)
  File.binwrite(STATE, raw)
  File.write(SIG, sig_of(raw))
end

def earned_level(state)
  passed = state["katas"].count { |k| k["passed"] }
  lvl = "strict"
  LEVELS.each { |name, xp, katas| lvl = name if state["xp"] >= xp && passed >= katas }
  lvl
end

def level_of(state)
  state["forced_level"] || earned_level(state)
end

def next_gate(state)
  passed = state["katas"].count { |k| k["passed"] }
  LEVELS.each do |name, xp, katas|
    next if state["xp"] >= xp && passed >= katas
    need = []
    need << "#{xp - state['xp']} XP" if state["xp"] < xp
    need << "#{katas - passed} kata(s)" if passed < katas
    return "#{need.join(' + ')} to #{name}"
  end
  "max level"
end

def week_overrides(state)
  cutoff = Time.now.to_f - 7 * 86_400
  state["overrides"].select { |o| o["ts"] > cutoff }
end

def cmd_inject
  state, tampered = load_state
  lines = [
    "TRAINING WHEELS PROTOCOL ACTIVE",
    "level: #{level_of(state)} | xp: #{state['xp']} | next: #{next_gate(state)}",
    "overrides this week: #{week_overrides(state).size}",
    "Follow the training-wheels skill rules for this level.",
    "Record XP via: ruby #{File.expand_path(__FILE__)} xp <delta> \"<reason>\"",
  ]
  lines << "NOTE: level manually forced to #{state['forced_level']} (logged)." if state["forced_level"]
  lines << "⚠ TAMPER DETECTED: state.json was hand-edited. Logged. Mention it to the user." if tampered
  top = state["gaps"].sort_by { |_, n| -n }.first(3)
  lines << ("top knowledge gaps: " + top.map { |t, n| "#{t} (#{n}x)" }.join(", ")) unless top.empty?
  save_state(state)
  puts lines.join("\n")
end

def cmd_scan
  prompt = JSON.parse($stdin.read)["prompt"].to_s
  state, = load_state
  out = nil
  if prompt.match?(EMERGENCY_RE)
    state["emergencies"] << { "ts" => Time.now.to_f, "prompt" => prompt[0, 200] }
    out = "TW: emergency detected — wheels off for this task, no XP penalty, logged. Comply directly."
  elsif state["pending_override"] && prompt.match?(CONFIRM_RE)
    state["overrides"] << { "ts" => Time.now.to_f, "prompt" => state["pending_override"]["prompt"][0, 200] }
    state["xp_log"] << { "ts" => Time.now.to_f, "delta" => -15, "reason" => "override confirmed" }
    state["xp"] = [0, state["xp"] - 15].max
    state["pending_override"] = nil
    out = "TW: override CONFIRMED (−15 XP, now #{state['xp']}, #{week_overrides(state).size} this week). " \
          "Comply now, but keep it educational: explain the code you write."
  elsif prompt.match?(OVERRIDE_RE)
    state["pending_override"] = { "ts" => Time.now.to_f, "prompt" => prompt[0, 200] }
    out = "TW: override requested — DO NOT comply yet. Push back once: say why the struggle is worth it " \
          "here and give ONE hint. If the user repeats the request, next prompt will confirm the override automatically."
  elsif state["pending_override"] && Time.now.to_f - state["pending_override"]["ts"] > 1800
    state["pending_override"] = nil
  end
  save_state(state)
  puts out if out
end

def cmd_gate
  data = JSON.parse($stdin.read)
  state, = load_state
  return if level_of(state) != "strict"
  fp = data.dig("tool_input", "file_path").to_s
  # allowed even in strict: scratch/temp/state, docs, config, tests
  allowed = fp.include?("/scratchpad") || fp.include?("/tmp/") || fp.include?(DIR) ||
            fp.end_with?(".md", ".txt", ".json", ".yml", ".yaml", ".toml", ".lock") ||
            fp.include?("/test") || fp.include?(".test.") || fp.include?(".spec.")
  # a confirmed override or emergency in the last 30 min unlocks the gate
  recent = Time.now.to_f - 1800
  unlocked = (state["overrides"] + state["emergencies"]).any? { |o| o["ts"] > recent }
  return if allowed || unlocked

  puts JSON.generate({ "hookSpecificOutput" => {
    "hookEventName" => "PreToolUse",
    "permissionDecision" => "deny",
    "permissionDecisionReason" =>
      "Training Wheels (strict): Claude may not edit source files — the user writes the code. " \
      "Explain what to change and why; let the user type it. " \
      "Unlock: #{next_gate(state)}, or user override ('just do it', twice).",
  } })
end

def cmd_xp(delta, reason)
  state, = load_state
  state["xp"] = [0, state["xp"] + delta.to_i].max
  state["xp_log"] << { "ts" => Time.now.to_f, "delta" => delta.to_i, "reason" => reason }
  new_lvl = earned_level(state)
  if state["history"].empty? || state["history"].last["level"] != new_lvl
    state["history"] << { "ts" => Time.now.to_f, "level" => new_lvl, "how" => "earned" }
  end
  save_state(state)
  sign = delta.to_i >= 0 ? "+" : ""
  puts "xp #{sign}#{delta} (#{reason}) → #{state['xp']} | level: #{level_of(state)} | #{next_gate(state)}"
end

def cmd_gap(topic)
  state, = load_state
  t = topic.strip.downcase
  state["gaps"][t] = state["gaps"].fetch(t, 0) + 1
  save_state(state)
  puts "gap logged: #{t} (#{state['gaps'][t]}x)"
end

def cmd_kata(result, desc)
  state, = load_state
  passed = result == "pass"
  state["katas"] << { "ts" => Time.now.to_f, "desc" => desc, "passed" => passed }
  save_state(state)
  if passed
    cmd_xp(20, "kata passed: #{desc}")
  else
    puts "kata logged (failed): #{desc} — no penalty, retry when ready"
  end
end

def cmd_level(arg)
  state, = load_state
  if arg
    state["forced_level"] = arg == "auto" ? nil : arg
    state["history"] << { "ts" => Time.now.to_f, "level" => arg, "how" => "forced" }
    save_state(state)
  end
  forced = state["forced_level"] ? ", forced: #{state['forced_level']}" : ""
  puts "level: #{level_of(state)} (earned: #{earned_level(state)}#{forced}) | xp: #{state['xp']} | #{next_gate(state)}"
end

def fmt_ts(ts)
  Time.at(ts).strftime("%b %d %H:%M")
end

def stats_lines(state)
  passed = state["katas"].count { |k| k["passed"] }
  bar_len = 30
  target = LEVELS.find { |_, x, _| state["xp"] < x }&.dig(1) || LEVELS.last[1]
  fill = target.zero? ? bar_len : [bar_len, bar_len * state["xp"] / target].min
  l = [
    "TRAINING WHEELS — PROGRESS",
    "",
    "  Level : #{level_of(state)}   (earned: #{earned_level(state)})",
    "  XP    : #{state['xp']}  [#{'█' * fill}#{'░' * (bar_len - fill)}]  #{next_gate(state)}",
    "  Katas : #{passed} passed / #{state['katas'].size} attempted",
    "  Overrides: #{week_overrides(state).size} this week, #{state['overrides'].size} total",
    "  Tampers  : #{state['tampers'].size}",
    "",
    "  Top gaps:",
  ]
  state["gaps"].sort_by { |_, n| -n }.first(8).each { |t, n| l << format("    %3dx  %s", n, t) }
  l << "    (none logged yet)" if state["gaps"].empty?
  l << "" << "  Recent XP:"
  state["xp_log"].last(8).reverse_each { |e| l << format("    %s  %+4d  %s", fmt_ts(e["ts"]), e["delta"], e["reason"]) }
  l
end

def cmd_stats
  state, = load_state
  puts stats_lines(state).join("\n")
end

def dash_views(state)
  {
    "1:Overview" => stats_lines(state),
    "2:Gaps" => ["KNOWLEDGE GAPS — your study list", ""] +
      state["gaps"].sort_by { |_, n| -n }.map { |t, n| format("  %3dx  %s", n, t) },
    "3:Overrides" => ["OVERRIDES ('just do it' log)", ""] +
      state["overrides"].reverse.map { |o| "  #{fmt_ts(o['ts'])}  #{o['prompt'][0, 70]}" } +
      ["", "EMERGENCIES:"] +
      state["emergencies"].reverse.map { |o| "  #{fmt_ts(o['ts'])}  #{o['prompt'][0, 70]}" },
    "4:History" => ["LEVEL HISTORY + XP LOG", ""] +
      state["history"].reverse.map { |h| "  #{fmt_ts(h['ts'])}  → #{h['level']} (#{h['how']})" } +
      [""] +
      state["xp_log"].reverse.map { |e| format("  %s  %+4d  %s", fmt_ts(e["ts"]), e["delta"], e["reason"]) },
  }
end

def cmd_dash
  tab = 0
  $stdin.raw do
    print "\e[?25l" # hide cursor
    loop do
      state, = load_state
      views = dash_views(state)
      names = views.keys
      rows = ($stdin.winsize rescue [24, 80])[0]
      header = names.each_with_index.map { |n, i| i == tab ? "\e[1;7m #{n} \e[0m" : "  #{n}  " }.join
      print "\e[2J\e[H" # clear + home
      print header + "   (1-4 switch, q quit)\r\n\r\n"
      views[names[tab]].first(rows - 3).each { |line| print line + "\r\n" }
      break if (ch = ($stdin.wait_readable(2) ? $stdin.getc : nil)) == "q" || ch == "\e"
      tab = ch.to_i - 1 if ch&.match?(/[1-4]/)
    end
  ensure
    print "\e[?25h\e[2J\e[H" # restore cursor, clear
  end
end

cmd, *args = ARGV
begin
  case cmd
  when "inject" then cmd_inject
  when "scan"   then cmd_scan
  when "gate"   then cmd_gate
  when "xp"     then cmd_xp(args[0], args[1].to_s)
  when "gap"    then cmd_gap(args[0])
  when "kata"   then cmd_kata(args[0], args[1].to_s)
  when "level"  then cmd_level(args[0])
  when "dash"   then cmd_dash
  else               cmd_stats
  end
rescue Errno::EPIPE
end
exit 0 # ponytail: hooks must never break the session
