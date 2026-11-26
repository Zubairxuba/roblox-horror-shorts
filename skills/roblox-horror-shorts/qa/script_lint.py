"""Script lint (hooks decide retention). Run on EVERY draft before showing it:
    python3 qa/script_lint.py projects/<slug>/script_draft.txt
One spoken line per row. Checks the opening against what the top story Shorts do.
Exit 1 if any FAIL. WARN = judge by eye."""
import re, sys

NUMW = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million".split()
DANGER = "never missing taken gone vanish stop follow lock scream breath cold dead die sold lost taken flat nobody trapped watch hungry blood".split()
WPS = 3.95            # measured on our narration (before the 1.25x tempo: keep it conservative)
LIMIT = 119.0         # under 2:00


def has_number(s):
    return bool(re.search(r"\d", s)) or any(w in s.lower().split() or w in re.sub(r"[^a-z ]", "", s.lower()).split() for w in NUMW)


def main(path):
    lines = [l.strip() for l in open(path, encoding="utf-8") if l.strip()]
    text = " ".join(lines)
    words = len(text.split())
    est = words / WPS
    first40 = " ".join(text.split()[:40])
    l1 = lines[0]
    res = []

    def chk(level, name, ok, why=""):
        res.append(("PASS" if ok else level, name, "" if ok else why))

    chk("FAIL", f"length {words} words ~{est:.0f}s (limit {LIMIT:.0f}s)", est <= LIMIT, "too long: cut words")
    chk("WARN", f"{len(lines)} lines (38-42 target)", 34 <= len(lines) <= 44, "line count off")
    chk("FAIL", "line 1 is an odd/frightening EVENT or fact, not a rule", not re.match(r"(in (our|this) town|never|don't|do not|if )", l1.lower()),
        "line 1 starts as a rule (the weaker opening). Open with something that already happened / a strange fact; give the rule in line 2-3")
    chk("FAIL", "number in the first 10 s (first 40 words)", has_number(first40), "no number early (e.g. 'three days', 'at 9:14', 'the 40th house')")
    chk("FAIL", "physical/immediate danger word in the first 40 words", any(d in first40.lower() for d in DANGER), "danger is abstract")
    chk("WARN", "first-person narrator in lines 1-3 (my/I/me)", bool(re.search(r"\b(my|i|me)\b", " ".join(lines[:3]).lower())), "most top story Shorts open in first person")
    chk("WARN", "open question/mystery by line 3", bool(re.search(r"\?|nobody ever|no one ever|never made sense|nobody knows|why", " ".join(lines[:3]).lower())),
        "nothing left unexplained in the first 3 lines")
    nums = sum(has_number(l) for l in lines)
    chk("WARN", f"number ladder (numbers in {nums} lines, want >= 6)", nums >= 6, "stakes should climb in numbers")
    clues = sum(1 for l in lines if re.match(r"(one|two|three)\b[.,:]", l.lower()))
    chk("WARN", f"3 clues ({clues} found, lines starting One./Two./Three.)", clues >= 3, "add 3 'some things never made sense' clues")
    chk("FAIL", "ending is a question to the viewer", lines[-1].endswith("?"), "end on a question")
    w1 = {w[:5] for w in re.findall(r"[a-z]{5,}", l1.lower())}   # 5-letter stems: smile/smiled
    wl = {w[:5] for w in re.findall(r"[a-z]{5,}", lines[-1].lower())}
    chk("WARN", "last line echoes line 1 (circular)", bool(w1 & wl), "no shared word between first and last line")
    for lv, name, why in res:
        print(f"{lv:4} {name}" + (f"  -> {why}" if why else ""))
    print("MANUAL: beat 1.1 cold-open image must match line 1 (strongest/strangest image, not a calm wide).")
    sys.exit(1 if any(r[0] == "FAIL" for r in res) else 0)


if __name__ == "__main__":
    main(sys.argv[1])
