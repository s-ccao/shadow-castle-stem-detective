# Teaching Scientific Reasoning Through Investigative Gameplay: The Design and Implementation of *Shadow Castle: STEM Detective*

**Author:** Changyang Cao
**Project repository:** https://github.com/s-ccao/shadow-castle-stem-detective
**Playable build:** https://play.shadowcastledetective.com/

---

## Abstract

Science education research has long distinguished between knowing a scientific
fact and being able to reason with it. Students can frequently state that
burning is a chemical change while remaining unable to use that distinction to
evaluate a claim about physical evidence. Many educational games reproduce this
gap in their own structure: the game supplies entertainment, and a quiz layer
supplies the science, so the two can be separated without either collapsing.

This paper presents *Shadow Castle: STEM Detective*, a 2D investigative game
built in Godot 4.7 in which scientific reasoning is the mechanism of progress
rather than a reward attached to it. The player investigates a blackout at a
castle, and every locked door in the game is opened by applying a scientific
principle the player has gathered elsewhere: distinguishing chemical from
physical change, identifying the gas consumed in photosynthesis, selecting a
conductor to repair a broken circuit, reasoning from a steady rate of change to
elapsed time, and combining primary colours of light to reveal a hidden archive.
A pursuing antagonist imposes time pressure, so the player must decide when
evidence is sufficient rather than exhaustively sampling every option.

Two design commitments distinguish this project from prior work. First, the
final accusation can be *correct for the wrong reasons*: an ordinary solution
convicts a plausible suspect, while a second, optional layer of sealed-archive
evidence exposes a forged command chain and a different culprit. The game
therefore assesses whether a player distinguishes a lead from proof, which is a
central practice in science education standards but is rarely modelled in
educational games. Second, the pedagogical design is protected by an automated
regression suite. Thirty headless test suites drive the real game scenes and
assert on learning-relevant guarantees — that the guided opening remains
survivable at any pace, that every craftable item is reachable from renewable
input, that no instructional panel clips its own text. Design intent that would
otherwise erode silently across development is held in place by executable
specifications.

The project is implemented in approximately 51,000 lines of GDScript across six
investigation rooms and is publicly playable in a browser. Formal evaluation of
learning outcomes has not yet been conducted and is identified as the primary
direction for future work.

**Keywords:** game-based learning, science education, scientific reasoning,
intrinsic integration, evidence-based argumentation, educational game design

---

## 1. Introduction

Scientific literacy is not primarily the retention of facts. Contemporary
science education frameworks describe it as a set of practices: constructing
explanations, evaluating evidence, and arguing from data [1]. A student who has
memorised that metals conduct electricity has not yet demonstrated scientific
literacy; a student who uses that fact to decide which of four materials will
repair a broken circuit, and can say why the other three fail, has.

This distinction is difficult to teach and more difficult to assess. Classroom
assessment tends to reward recall because recall is easy to grade, and the
result is a well-documented gap: students perform adequately on definitional
questions while continuing to hold misconceptions that surface as soon as the
same concept must be applied in an unfamiliar context [2].

Digital games are frequently proposed as a remedy, and meta-analyses find that
they can produce meaningful learning gains [3]. However, the same body of
research shows that the effect depends heavily on design rather than on the
medium. Games in which the educational content is separable from the gameplay —
where a player shoots asteroids and is then asked a multiplication question —
tend to underperform games in which the content and the mechanic are the same
thing. Habgood and Ainsworth term this property *intrinsic integration*: the
learning material should be delivered through the parts of the game that carry
the most player interest, and the game's core mechanic should embody the concept
being taught [4].

Intrinsic integration is a demanding standard. It requires that the designer
find a game action that is structurally identical to the scientific reasoning
being taught, not merely thematically adjacent. Detective fiction offers an
unusually direct fit. The work of a detective — gathering observations,
separating suspicion from proof, testing an alibi against physical constraints,
and committing to a conclusion under uncertainty — is close to the structure of
scientific inquiry itself. Both practices reason backwards from evidence to
cause, and both must decide when evidence is sufficient.

This paper describes *Shadow Castle: STEM Detective*, a game built on that
correspondence. The player investigates a blackout at a castle where every
locked door is a scientific principle, every clue must be classified as a lead
or as proof, and a pursuing antagonist ensures that deliberation carries cost.
The contributions of this work are:

1. **A design in which scientific reasoning is the progression mechanic.** Doors
   open because the player understood a principle, not because a key sprite was
   collected.
2. **An assessment structure that distinguishes a lead from proof.** The game can
   be completed with a plausible but incorrect accusation, and rewards the player
   who recognises that the available evidence does not yet support it.
3. **Executable specifications for pedagogical design.** Learning-relevant design
   guarantees are encoded as automated regression tests that run against the real
   game scenes, so instructional intent is protected from silent erosion during
   development.

---

## 2. Background and Related Work

### 2.1 Simulation tools for conceptual understanding

Interactive simulations are the most established form of digital science
education. The PhET project provides research-based simulations in which
students manipulate variables and observe consequences, and studies report gains
in conceptual understanding relative to traditional instruction [5]. Their
strength is in making an invisible mechanism visible and manipulable.

Simulations, however, are typically bounded to a single concept and are not
structured as a continuous experience with stakes. A student can leave a
simulation at any point without consequence, and nothing in the tool requires
that a conclusion be committed to and defended. They teach how a system behaves;
they do not exercise the judgement of deciding what a body of mixed evidence
supports.

### 2.2 Narrative-centred inquiry games

A second line of work embeds science learning in narrative environments.
*Crystal Island* places students in a science mystery in which they must
diagnose an illness by gathering information and testing hypotheses, and studies
report gains in both content knowledge and problem-solving [6]. *Quest Atlantis*
and *River City* similarly use narrative worlds to situate scientific inquiry,
with attention to motivation and self-efficacy [7][8].

These projects establish that narrative framing supports inquiry learning and
that a mystery structure can motivate evidence gathering. They are the closest
prior work to the present project. The distinction pursued here is in the
treatment of *insufficient* evidence: in most such environments the correct
conclusion is reachable and the task is to reach it. The present project makes a
plausible-but-unsupported conclusion reachable as well, and treats the
recognition of that insufficiency as the deeper learning objective.

### 2.3 Gamified courses and quiz-layer designs

A third category applies game elements — points, levels, characters, minigames —
to otherwise conventional instruction. Such designs reliably improve engagement
metrics, but reviews caution that engagement does not entail learning, and that
gains are inconsistent when the game layer is separable from the content
layer [3][9]. This is the failure mode intrinsic integration is intended to
avoid [4].

### 2.4 The research gap

Across these categories, three properties are individually well established:
simulations make mechanisms manipulable, narrative games motivate inquiry, and
gamification sustains engagement. What remains uncommon is a design that
combines them under a single constraint — that the scientific principle is the
only thing that opens the next door — while also modelling the distinction
between a lead and proof, and doing so under time pressure that forces a
judgement about evidential sufficiency.

A further gap exists on the engineering side. Educational game papers describe
intended pedagogy, but instructional design in a large codebase is fragile: a
change made for pacing can quietly remove a scaffold, and a change made for
visual polish can clip the text of an instructional panel. The literature does
not commonly report mechanisms for *preserving* pedagogical design across
continued development. This project treats that preservation as a design problem
with an engineering solution, described in Section 3.5.

---

## 3. Methodology

### 3.1 Design principle: the concept is the lock

The governing rule of the design is that no door in the game opens by
possession alone. Every room boundary is a *dual lock*: a physical key, which
establishes that the player has explored, and a knowledge lock, which
establishes that the player has understood. The knowledge lock draws on a
principle that must be gathered elsewhere in the castle, so progression requires
transferring an idea across a spatial and narrative distance rather than
recalling it in the room where it was presented.

The five knowledge locks and their associated principles are:

| Room | Principle | Question the lock poses |
| --- | --- | --- |
| Chemistry | Chemical vs. physical change | Which of these is a chemical change? |
| Greenhouse | Photosynthesis inputs | Which gas do plants absorb to make food? |
| Circuit | Electrical conductivity | Which material allows current to flow most easily? |
| Dining Hall | Rate-based estimation of elapsed time | Which principle best estimates elapsed time? |
| Library | Additive colour mixing | Which is a primary colour of light? |

Each principle is first encountered as a physical exhibit in the castle hall —
a warm brass core, a set of living panels, a pair of gauges — which the player
inspects to record the underlying science in a notebook. The exhibit is
deliberately placed away from the door it unlocks. The player must recognise
that an observation made in one place answers a question posed in another, which
is the transfer step that definitional recall does not exercise.

### 3.2 Embedding science in the interaction, not in the question

Where a concept admits a manipulable form, it is implemented as an interactive
procedure rather than as a multiple-choice item. Six such procedures exist:

- **Flame and air.** The player predicts the order in which candles under sealed
  jars will go out, then watches the prediction resolve. The underlying relation
  — burn duration as a function of available air against consumption rate,
  modified by vents — is stated in the interface as a formula the player can
  apply, so a wrong prediction is diagnosable rather than merely wrong. Incorrect
  answers report which position was misplaced and what the two jars' burn times
  actually were.
- **Photosynthesis balance.** Light, water, and carbon dioxide must be balanced
  against one another for a crop to mature, making the limiting-factor concept
  operational.
- **Change sorting.** Observed events are classified as chemical or physical
  change, reinforcing the principle that governs the Chemistry lock.
- **Elapsed-time estimation.** A steadily changing process is measured to
  estimate how much time has passed, with the explicit lesson that a single
  indicator is insufficient and several independent indicators must agree.
- **Optical dispersion and colour mixing.** Three staged laboratories cover prism
  dispersion ordering, pigment reflection and absorption, and additive colour
  mixing; the earned red, green, and blue filters are then inserted to reveal a
  hidden archive layer, so the concept is not merely tested but used.
- **Gear train reasoning.** Mechanical advantage and transmission are applied to
  a physical repair.

In each case the interaction embodies the relation. The player does not select
the sentence describing the limiting factor; the player runs out of carbon
dioxide and observes the crop stop growing.

### 3.3 Time pressure as a forcing function for evidential judgement

An antagonist, the Castle Guardian, pursues the player through the connecting
hall. This system exists for a pedagogical reason rather than an atmospheric
one: without cost, the optimal strategy for any evidence-gathering game is
exhaustive search, which removes the judgement the game is meant to teach. With
a pursuit running, the player must decide when the evidence in hand is
sufficient to act.

The pursuit is tuned so that this pressure does not become an arbitrary skill
barrier. During the guided opening the Guardian holds a *tether*: its speed is
computed from the path distance through the maze to the player, closing above
the player's own speed when it falls behind and dropping well below it when it
crowds. A player who sprints and a player who stops to read every label
therefore experience the same narrative beat — a near-miss at the first door —
rather than one experiencing a walkover and the other losing the run. Contact
during this guided phase costs ground rather than the run itself. After the
tutorial, the pursuit becomes genuinely lethal, and escalates by twelve percent
per recovered key.

The player can also act on the pursuit scientifically. A tracking serum in the
player's blood allows the Guardian to locate them anywhere; brewing a
Purification Potion removes it, after which the Guardian must rely on line of
sight. This converts a survival problem into a chemistry problem, and rewards
the player who invests in the crafting system rather than treating it as
optional.

### 3.4 Resource economy as systems reasoning

The crafting economy is designed to teach a systems relationship rather than to
gate content. The castle yields only a fixed, small supply of the three reagents
that potions require — two units of distilled water, one of iron salt, one of
prism dust — against the five, four, and five needed to brew one of every
potion. The deficit is deliberate and is resolvable only by recognising that the
greenhouse is a renewable source and that its herbs can be refined into the
scarce reagents.

Three refining recipes make this concrete, and each follows the stated botany of
its input: dewcap releases the water it condenses from air, ironvine reduces to
the metal salts it drew from soil, and emberroot's stored heat vitrifies moonleaf
into prism dust. Ten segmented harvest points regrow on a real-time clock, so the
player learns to treat the greenhouse as a renewable system with a cycle time
rather than as a container to be emptied.

### 3.5 Executable specifications for pedagogical design

A design intention expressed only in prose degrades as a codebase grows. During
development of this project, several instructional guarantees were found to have
been silently broken by changes made for unrelated reasons: a tutorial card had
been written but was never displayed; an objective panel was sized so that the
final line of the longest English step was clipped; a pursuit tuned for
experienced players made the opening unsurvivable for a newcomer who paused to
read.

To prevent recurrence, learning-relevant guarantees are encoded as automated
tests that drive the real game scenes rather than mocks. Thirty headless suites
run without a display and report pass or fail by exit code. Representative
examples:

| Suite | Pedagogical guarantee protected |
| --- | --- |
| `guardian_tutorial_chase_test` | The guided opening remains survivable at any pace, so pacing changes cannot convert a tutorial into a skill gate. |
| `potion_economy_test` | Every potion is reachable from renewable input; the test crafts the entire list, refining reagents on demand, so a recipe change cannot silently strand the economy. |
| `tutorial_chain_test` | Every step of the guided sequence has copy in both supported languages, failing on a missing key rather than rendering a raw identifier to the learner. |
| `panel_overflow_test` | No instructional panel renders text outside its own frame, measured against font extents rather than layout rectangles. |
| `room_spatial_audit` | Every interactive object is reachable from walkable floor, so no piece of content becomes unreachable. |

The `potion_economy_test` illustrates the approach. Rather than inspecting the
recipe tables for well-formedness, it simulates a plausible harvest, then
attempts to craft one of every potion, refining any missing reagent on demand.
Before the refining recipes were introduced, this test reported that zero of the
seven potions were reachable — a quantitative statement about a design flaw that
inspection of the tables alone would not have produced.

This practice is presented as a methodological contribution. Educational
software is usually validated, if at all, by user study after the fact.
Encoding instructional guarantees as executable specifications validates them
continuously, and converts a category of pedagogical regression into a build
failure.

### 3.6 Implementation

The game is implemented in Godot 4.7 using GDScript, comprising roughly 51,000
lines across six investigation rooms, a connecting hall, and a tutorial room.
State is centralised in autoloaded singletons covering game state, save and
checkpoint logic, localisation, and audio. The project targets both desktop and
the web; the web build is a single-threaded WebAssembly export served with a
custom loading shell.

Two engineering details are relevant to the learning experience. First, updates
to the hosted build are announced to the player rather than applied underneath
them: a service worker downloads a new version, and the game then pauses, saves
a checkpoint, and offers the choice to restart or defer — so a player mid-puzzle
is never interrupted by a reload. Second, optional accounts allow progress to
follow a learner across devices, implemented with salted scrypt password
hashing, per-IP and per-account rate limiting, and revision checks that prevent
a stale device from overwriting newer progress.

---

## 4. Results

### 4.1 Implemented system

The project is a complete, publicly playable build rather than a prototype
fragment. The following are implemented and reachable in ordinary play:

- A tutorial room teaching movement, inspection, and the first knowledge lock
  through a six-step guided sequence.
- A connecting hall with fog-limited visibility, five knowledge exhibits, and a
  pursuing antagonist with escalation tiers and a contact estimate readout.
- Six investigation rooms, each with its own scientific principle, interactive
  procedures, and evidence.
- A crafting system with seven potions and three refining recipes, backed by a
  renewable greenhouse of ten regrowing harvest points.
- A field kit of four hubs: an inventory filed under authored tabs, a key
  register, a notebook that accumulates recorded science, and a tactical map.
- A two-layer finale, described in Section 4.3.
- Save, checkpoint, and optional cross-device cloud progression.

*Figure 1* shows the greenhouse with segmented harvest points and an interaction
prompt. *Figure 2* shows the castle hall under pursuit, with the contact
estimate, escalation tier, and fog-limited sight. *Figure 3* shows the library
optics laboratory with the RGB filters that reveal the archive layer.

![Greenhouse](screenshots/greenhouse.png)
*Figure 1. Greenhouse. Segmented harvest points regrow on a real-time clock.*

![Castle Hall](screenshots/hall.png)
*Figure 2. Castle hall under pursuit. The readout reports contact estimate and
escalation tier; sight is limited by fog until the generator is restored.*

![Library](screenshots/library.png)
*Figure 3. Library optics laboratory. Earned RGB filters reveal the archive
layer.*

### 4.2 Progression gated by understanding

In the implemented build, no room boundary can be crossed by possession alone.
Each of the five knowledge locks requires the corresponding principle, and the
principle is recorded by inspecting an exhibit located elsewhere in the castle.
A player who collects every key but inspects no exhibit cannot progress, which
is the intended demonstration that the design gates on understanding rather than
on exploration.

### 4.3 An accusation that can be right for the wrong reasons

The finale is implemented in two layers. The ordinary solution assembles a
coherent case against the Butler: he handled the cleaning supplies, he was
present, and the staged stain is consistent with his access. A player who stops
here completes the game and receives an ending.

An optional second layer is available to a player who reviews the sealed
archive. It reveals a maintenance record and a forged routing mark showing that
the command chain was fabricated by someone with maintenance authority, which
redirects the conclusion to the Mechanic. The Butler received an order that
looked official; he is a plausible suspect who is nonetheless not the culprit.

This structure operationalises the distinction the project is built around. The
ordinary ending is not a failure state, and the game does not announce that the
player was wrong. It rewards the player who noticed that plausibility is not
proof, which is the practice that science education standards describe as
argumentation from evidence [1][10].

### 4.4 Verification status

At the time of writing, thirty headless regression suites pass, along with two
spatial audits, and the project compiles without script errors. These tests
verify implementation and design guarantees; they are not evidence of learning
outcomes, which is addressed in Section 5.2.

---

## 5. Conclusion

### 5.1 Contributions

This paper described the design and implementation of *Shadow Castle: STEM
Detective*, a game in which scientific reasoning is the mechanism of progression.
Three contributions are claimed.

The first is a demonstration of intrinsic integration applied to scientific
reasoning rather than to a single computational skill. The correspondence
between detective work and scientific inquiry allows a game structure in which
gathering observations, transferring a principle across contexts, and committing
to a conclusion are the same actions in both domains.

The second is an assessment structure that models the distinction between a lead
and proof. By making a plausible-but-unsupported conclusion reachable and
rewarding its recognition, the design targets a practice that is central to
scientific literacy and is difficult to assess with conventional items.

The third is methodological: encoding pedagogical guarantees as executable
specifications. This converted several instructional regressions from defects
that would have shipped into build failures, and produced quantitative
statements about design flaws — such as zero of seven potions being reachable
before the refining recipes were added — that inspection alone would not have
surfaced.

### 5.2 Limitations

Several limitations should be stated plainly.

**No formal evaluation of learning outcomes has been conducted.** The project has
not been tested with students, and no pre-test/post-test comparison, control
group, or measurement of conceptual change exists. All claims in this paper
concern design and implementation, not demonstrated learning gains. This is the
most significant limitation and the primary direction for future work.

**The scientific content is introductory in scope.** The principles covered are
at a middle-school level, and the assessment items associated with the knowledge
locks are multiple-choice, which is a weaker instrument than the interactive
procedures described in Section 3.2. Extending the interactive treatment to all
five locks would strengthen the design.

**The two-layer finale has not been validated as an assessment.** It is not
currently known what proportion of players stop at the ordinary ending, nor
whether those who reach the second layer do so through the intended reasoning or
through exhaustive exploration. Instrumenting this decision point would convert
it from a design intention into a measurable outcome.

**The test suites verify design guarantees, not learning.** They establish that
the tutorial remains survivable and that the economy remains solvable; they
cannot establish that a player who completes the greenhouse understands limiting
factors.

### 5.3 Future work

The immediate priority is an empirical study with students, comparing conceptual
understanding before and after play, with particular attention to transfer:
whether a player who opened the Circuit door can apply conductivity reasoning to
an unfamiliar problem. Instrumenting the finale to record which ending players
reach, and by what route, would provide a second measure directed specifically
at the lead-versus-proof distinction.

Beyond evaluation, the interactive procedures could be extended to cover every
knowledge lock, and the notebook could be developed from a record of gathered
science into a tool for constructing an argument — allowing the player to assemble
a claim, its supporting evidence, and its reasoning before making an accusation,
which would model the structure of scientific argumentation more explicitly [10].

---

## References

[1] NGSS Lead States. *Next Generation Science Standards: For States, By States.*
National Academies Press, 2013.

[2] Duit, R., & Treagust, D. F. "Conceptual change: A powerful framework for
improving science teaching and learning." *International Journal of Science
Education*, 25(6), 671–688, 2003.

[3] Clark, D. B., Tanner-Smith, E. E., & Killingsworth, S. S. "Digital Games,
Design, and Learning: A Systematic Review and Meta-Analysis." *Review of
Educational Research*, 86(1), 79–122, 2016.

[4] Habgood, M. P. J., & Ainsworth, S. E. "Motivating Children to Learn
Effectively: Exploring the Value of Intrinsic Integration in Educational Games."
*Journal of the Learning Sciences*, 20(2), 169–206, 2011.

[5] Wieman, C. E., Adams, W. K., & Perkins, K. K. "PhET: Simulations That Enhance
Learning." *Science*, 322(5902), 682–683, 2008.

[6] Rowe, J. P., Shores, L. R., Mott, B. W., & Lester, J. C. "Integrating
Learning, Problem Solving, and Engagement in Narrative-Centered Learning
Environments." *International Journal of Artificial Intelligence in Education*,
21(1–2), 115–133, 2011.

[7] Barab, S., Thomas, M., Dodge, T., Carteaux, R., & Tuzun, H. "Making learning
fun: Quest Atlantis, a game without guns." *Educational Technology Research and
Development*, 53(1), 86–107, 2005.

[8] Ketelhut, D. J. "The Impact of Student Self-Efficacy on Scientific Inquiry
Skills: An Exploratory Investigation in River City." *Journal of Science
Education and Technology*, 16(1), 99–111, 2007.

[9] Honey, M. A., & Hilton, M. (Eds.). *Learning Science Through Computer Games
and Simulations.* National Academies Press, 2011.

[10] Osborne, J., Erduran, S., & Simon, S. "Enhancing the quality of
argumentation in school science." *Journal of Research in Science Teaching*,
41(10), 994–1020, 2004.

[11] Gee, J. P. *What Video Games Have to Teach Us About Learning and Literacy.*
Palgrave Macmillan, 2003.

[12] Malone, T. W. "Toward a theory of intrinsically motivating instruction."
*Cognitive Science*, 5(4), 333–369, 1981.

---

## Appendix A: Availability

- **Playable build:** https://play.shadowcastledetective.com/
- **Source code:** https://github.com/s-ccao/shadow-castle-stem-detective
- **Engine:** Godot 4.7, GDScript
- **Reproducing the verification:** each suite runs headless and reports pass or
  fail by exit code, for example:
  ```bash
  godot --headless --path . --script res://tests/potion_economy_test.gd
  ```
