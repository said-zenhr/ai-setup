#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

LEVELS = {
  "whisper"  => 30,
  "terse"    => 75,
  "brief"    => 150,
  "normal"   => 300,
  "detailed" => 500,
  "thorough" => 700,
  "essay"    => 900
}.freeze
MIN_WORDS  = 30
MAX_WORDS  = 900
MAX_SENTENCE_WORDS = 20
STATE_FILE = File.expand_path("~/.claude/plain.json")
STE_RULES = "Write in ASD-STE100 Simplified Technical English: one idea per sentence, " \
            "at most #{MAX_SENTENCE_WORDS} words per sentence. " \
            "Active voice. Simple tenses (present, past, future). No -ing verb forms. " \
            "Use complete sentences with articles; do not drop words to save space. " \
            "Plain verbs (start, not initiate). One word, one meaning: never swap synonyms. " \
            "Write steps as a numbered list, one action per step. " \
            "Put warnings and conditions before the instruction. " \
            "Technical names, code, paths, commands and numbers stay exact."

def state
  JSON.parse(File.read(STATE_FILE))
rescue StandardError
  {}
end

def save(data)
  File.write(STATE_FILE, JSON.pretty_generate(data))
end

def cap
  state["cap"]
end

def label(words)
  name = LEVELS.key(words)
  level = LEVELS.values.index(words)
  name ? "level #{level + 1} (#{name}, #{words} words)" : "#{words} words"
end

def words_for(arg)
  return LEVELS.values[arg.to_i - 1] if arg.match?(/\A[1-7]\z/)
  return LEVELS[arg] if LEVELS.key?(arg)
  return arg.to_i.clamp(MIN_WORDS, MAX_WORDS) if arg.match?(/\A\d+\z/)
end

def set(arg)
  arg = arg.to_s.strip.downcase
  if arg.empty?
    puts cap ? "Plain is #{label(cap)}." : "Plain is off."
  elsif arg == "off"
    save({})
    puts "Plain off. No word cap, no STE100."
  elsif (words = words_for(arg))
    save("cap" => words)
    puts "Plain set to #{label(words)}."
  else
    puts "Unknown level '#{arg}'. Use 1-7, #{LEVELS.keys.join('|')}, a number 30-900, or off."
  end
end

def remind
  return unless cap

  message = "PLAIN MODE ACTIVE: #{label(cap)}. Every reply MUST be at most #{cap} words of prose " \
            "(code blocks and tool calls not counted). This overrides any default length or style, " \
            "including caveman-style fragments. #{STE_RULES} " \
            "A Stop hook counts the words and long sentences after each reply."
  overage = state["overage"]
  long = state["long_sentences"]
  message += " Your previous reply was #{overage} words, over the cap. Cut harder." if overage
  message += " Your previous reply had #{long} sentences over #{MAX_SENTENCE_WORDS} words. Split them." if long
  puts message
end

def check
  return unless cap

  input = JSON.parse($stdin.read)
  prose = reply_prose(input["transcript_path"])
  count = prose.split.size
  long  = long_sentences(prose)
  save({ "cap" => cap, "overage" => (count if count > cap), "long_sentences" => (long if long.positive?) }.compact)
  return if (count <= cap && long.zero?) || input["stop_hook_active"]

  warn "Plain: reply was #{count} words (cap #{cap}), #{long} sentences over #{MAX_SENTENCE_WORDS} words."
end

def long_sentences(prose)
  prose.lines.reject { |line| line.lstrip.start_with?("|") }.join
       .split(/(?<=[.!?:])\s+|\n+/)
       .count { |sentence| sentence.split.size > MAX_SENTENCE_WORDS }
end

def reply_prose(transcript_path)
  return "" unless transcript_path && File.exist?(transcript_path)

  texts = []
  File.foreach(transcript_path) do |line|
    entry = JSON.parse(line) rescue next
    if user_prompt?(entry)
      texts.clear
    elsif entry["type"] == "assistant"
      Array(entry.dig("message", "content")).each { |block| texts << block["text"] if block["type"] == "text" }
    end
  end
  texts.join("\n").gsub(/```.*?```/m, "")
end

def user_prompt?(entry)
  return false unless entry["type"] == "user" && !entry["isMeta"]

  content = entry.dig("message", "content")
  content.is_a?(String) || Array(content).any? { |block| block["type"] == "text" }
end

case ARGV.shift
when "set"    then set(ARGV.join(" "))
when "remind" then remind
when "check"  then check
end
