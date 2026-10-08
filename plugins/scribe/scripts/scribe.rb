#!/usr/bin/env ruby
# Scribe — kepano-style + OKF note recorder with anti-bloat enforcement.
#
# Subcommands:
#   gate     PreToolUse hook (Write/Edit into vault): word budgets + evergreen link rule
#   stop     Stop hook: end-of-session nag if work went unrecorded
#   mark     record that this session was scribed (clears the nag)
#   todo add "text [due:YYYY-MM-DD]" "[[source]]"   append to vault TODOS.md
#   todo done "substring"                            check off in TODOS.md
#   todo due                                         list open todos, overdue first
#   budgets  print word budgets
#   context  SessionStart hook: project index from project-note frontmatter

require "json"
require "time"

VAULT = File.expand_path(ENV.fetch("SCRIBE_VAULT", "~/Desktop/workspace/vault"))
TODOS = File.join(VAULT, "TODOS.md")
SDIR  = File.expand_path("~/.claude/scribe")

# word budgets by note kind (body only, frontmatter excluded)
BUDGETS = { "session" => 80, "meeting" => 100, "evergreen" => 150, "todo" => 20, "default" => 120 }.freeze
SCRIBE_SECTION = "## Scribe" # todos scribe manages in TODOS.md live under this header

def body_of(content)
  content.sub(/\A---\n.*?\n---\n/m, "")
end

# Tickets, PRs and advisories must be links. Anything already inside a link, code span or URL is fine,
# and YAML lines (`tickets:` lists, `key: value`) are data, not prose.
REF_PROTECT = /```.*?```|`[^`\n]*`|!?\[[^\]\n]*\]\([^)\n]*\)|\[\[[^\]\n]*\]\]|<[^>\n]*>|https?:\/\/\S+/m
JIRA_KEYS = %w[PLAT DIM HOTFIX FOR ZNRLS SEC DEVOPS CORE PIN INFRA OPSAI ZEN ZENX ZHFE ZDSZ ATS ATSRLS ES].freeze
BARE_REF = /\b(?:#{JIRA_KEYS.join('|')}|CVE-\d{4}|PYSEC-\d{4})-\d+\b|\bPRs?\s+#?\d+|(?<![\w\/#!\[&])#\d+\b(?![-\w])|\b(?:zenhr|el-ciclo|osvdev|system_health|zen_triage|mfe|zds|zen_tms)[#!]\d+\b/

def bare_refs(content)
  prose = body_of(content).lines.reject { |l| l =~ /\A\s*(-\s+\S+\s*|[\w-]+:.*)\z/ }.join
  prose.split(REF_PROTECT).flat_map { |s| s.scan(BARE_REF) }.uniq
end

def kind_of(path, content)
  return "session" if path.include?("/Sessions/")
  return "meeting" if content =~ /\[\[Meetings\]\]/ || path.include?("/Meetings/")
  return "evergreen" if content =~ /\[\[Evergreen\]\]|(^|\s)#?0🌲/ || content =~ /^tags:.*\n(\s+- .*\n)*\s+- 0🌲/
  "default"
end

def cmd_gate
  data = JSON.parse($stdin.read)
  fp = data.dig("tool_input", "file_path").to_s
  return unless fp.start_with?(VAULT)
  return if fp.include?("/Templates/") || fp.include?("/Attachments/") || File.basename(fp) == "TODOS.md"
  content = data.dig("tool_input", "content") || data.dig("tool_input", "new_string") || ""
  return if content.empty?

  kind = kind_of(fp, content)
  words = body_of(content).scan(/[[:word:]]+/).size
  budget = BUDGETS[kind]
  problems = []
  problems << "over word budget: #{words}/#{budget} words for a #{kind} note — distill, don't transcribe" if words > budget
  if %w[evergreen session meeting].include?(kind) && content.scan(/\[\[[^\]]+\]\]/).size < 2
    problems << "fewer than 2 [[wikilinks]] — no orphan notes; link people/projects/concepts (unresolved links are fine)"
  end
  refs = bare_refs(content)
  unless refs.empty?
    problems << "unlinked references #{refs.first(5).join(', ')} — link every ticket, PR and page: " \
                "[PLAT-1](https://boundlesshr.atlassian.net/browse/PLAT-1), [#12](https://github.com/ZenHR/zenhr/pull/12), " \
                "[mfe!3](https://bitbucket.org/boundlessdrop/mfe-monorepo/pull-requests/3), [Page title](confluence url)"
  end
  return if problems.empty?

  puts JSON.generate({ "hookSpecificOutput" => {
    "hookEventName" => "PreToolUse",
    "permissionDecision" => "deny",
    "permissionDecisionReason" => "Scribe: #{problems.join('; ')}.",
  } })
end

def session_file(id)
  File.join(SDIR, "#{id}.json")
end

def cmd_stop
  data = JSON.parse($stdin.read)
  id = data["session_id"].to_s
  return if id.empty? || data["stop_hook_active"]
  Dir.mkdir(SDIR) unless Dir.exist?(SDIR)
  s = File.exist?(session_file(id)) ? JSON.parse(File.read(session_file(id))) : { "turns" => 0, "scribed" => false, "nagged" => false }
  s["turns"] += 1
  File.write(session_file(id), JSON.generate(s))
  return if s["scribed"] || s["nagged"] || s["turns"] < 5

  s["nagged"] = true
  File.write(session_file(id), JSON.generate(s))
  puts JSON.generate({ "decision" => "block",
    "reason" => "Scribe: #{s['turns']} turns and nothing recorded. If this session produced anything worth keeping " \
                "(decision, insight, todo), write the session note now per the scribe skill, then run " \
                "`ruby #{File.expand_path(__FILE__)} mark #{id}`. If genuinely nothing to record, just run mark." })
end

def cmd_mark(id)
  Dir.mkdir(SDIR) unless Dir.exist?(SDIR)
  s = File.exist?(session_file(id)) ? JSON.parse(File.read(session_file(id))) : {}
  File.write(session_file(id), JSON.generate(s.merge("scribed" => true)))
  puts "session marked scribed"
end

def ensure_todos_section(text)
  text.include?(SCRIBE_SECTION) ? text : text.rstrip + "\n\n#{SCRIBE_SECTION}\n"
end

def cmd_todo_add(text, src)
  raw = ensure_todos_section(File.read(TODOS))
  line = "- [ ] #{text}"
  line += " #{src}" if src && !src.empty?
  line += " ➕#{Time.now.strftime('%Y-%m-%d')}"
  File.write(TODOS, raw.sub(SCRIBE_SECTION, "#{SCRIBE_SECTION}\n#{line}"))
  puts "todo added: #{line}"
end

def cmd_todo_done(substr)
  raw = File.read(TODOS)
  hit = nil
  out = raw.lines.map do |l|
    if !hit && l =~ /^- \[ \]/ && l.downcase.include?(substr.downcase)
      hit = l.strip
      l.sub("- [ ]", "- [x]").chomp + " ✅#{Time.now.strftime('%Y-%m-%d')}\n"
    else
      l
    end
  end.join
  if hit
    File.write(TODOS, out)
    puts "done: #{hit}"
    src = hit[/\[\[([^\]]+)\]\]/, 1]
    puts "also check it off in source note: #{src}" if src
  else
    puts "no open todo matching: #{substr}"
  end
end

def cmd_todo_due
  today = Date.today
  open = File.read(TODOS).lines.select { |l| l =~ /^- \[ \]/ }
  return puts "no open todos" if open.empty?
  overdue, dated, undated = [], [], []
  open.each do |l|
    if (d = l[/due:(\d{4}-\d{2}-\d{2})/, 1])
      (Date.parse(d) <= today ? overdue : dated) << l.strip
    else
      undated << l.strip
    end
  end
  puts "OVERDUE / TODAY:", overdue, "" unless overdue.empty?
  puts "UPCOMING:", dated, "" unless dated.empty?
  puts "NO DATE:", undated unless undated.empty?
end

# SessionStart hook: print the project index (context anchoring priming layer).
# Built live from project-note frontmatter, so it never drifts from the notes.
def cmd_context
  require "yaml"
  projects = Dir[File.join(VAULT, "**/*.md")].filter_map do |f|
    next if f.include?("/Templates/")
    fm = File.read(f)[/\A---\n(.*?)\n---/m, 1] or next
    y = YAML.safe_load(fm, permitted_classes: [Date, Time]) rescue next
    next unless y.is_a?(Hash) && y["type"] == "project" && y["description"]
    { path: f.delete_prefix("#{VAULT}/"), y: y, updated: y["updated"].to_s }
  end.sort_by { |p| p[:updated] }.reverse
  live, done = projects.partition { |p| %w[active paused].include?(p[:y]["status"].to_s) }
  todos = File.exist?(TODOS) ? File.read(TODOS).scan(/^- \[ \]/).size : 0

  puts "# Sai'd's vault context (#{VAULT})"
  puts "Sai'd Al-Zain, platform engineer at ZenHR. Vault conventions: AGENTS.md. Open todos: #{todos} (`scribe.rb todo due`)."
  puts "Before working on a project below, Read its note: the anchor at the top holds state, decisions with rejected alternatives, constraints and open questions."
  puts "At pause points and session end, update that anchor in place (State, Decisions, Open questions, `updated:`)."
  puts "", "## Active and paused projects"
  live.each do |p|
    y = p[:y]
    refs = [y["part_of"], y["repos"], y["tickets"]].flatten.compact.map { |r| r.to_s.gsub(/\[\[|\]\]/, "") }.reject(&:empty?).join(", ")
    puts "- **#{File.basename(p[:path], '.md')}** (#{y['status']}, #{p[:updated]}) — #{y['description']}"
    puts "  `#{p[:path]}`#{refs.empty? ? '' : " · #{refs}"}"
  end
  puts "", "## Done (read only if asked)", done.map { |p| File.basename(p[:path], ".md") }.join(" · ") unless done.empty?
end

require "date"
cmd, *args = ARGV
begin
  case cmd
  when "gate"    then cmd_gate
  when "stop"    then cmd_stop
  when "mark"    then cmd_mark(args[0].to_s)
  when "todo"
    case args[0]
    when "add"  then cmd_todo_add(args[1].to_s, args[2])
    when "done" then cmd_todo_done(args[1].to_s)
    when "due"  then cmd_todo_due
    end
  when "budgets" then puts BUDGETS.map { |k, v| "#{k}: #{v} words" }
  when "context" then cmd_context
  end
rescue Errno::EPIPE
end
exit 0 # hooks must never break the session
