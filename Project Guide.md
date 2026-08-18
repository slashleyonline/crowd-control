# CSE 146 Crowd AI Project

## Project Idea

We are making a basic crowd AI system for a first-person shooter/social deduction game. The player should be able to blend into a crowd of NPCs while trying to find another player.

The NPCs do not need to be super intelligent. They mainly need to look alive, move around, and react to danger in believable ways. Our goal is to finish a simple working version and all presentation materials by **Sunday, August 23, 2026**.

## Final Submission Requirements

The project is not finished when the code works. We also need to complete these course requirements:

- [ ] Give a **roughly 10-minute presentation**, including Q&A.
- [ ] Write a **2–4 page final project write-up**.
- [ ] Add our slides to the class presentation slideshow immediately after our reserved spot.
- [ ] Complete the evaluation sheet for the other teams. We should not evaluate our own project.

The presentation and class reviews make up most of the project grade, so we need time to rehearse and make the demo clear and fun.

## Team Information

- **Team members:** [Add names]
- **Project theme:** AI as Camouflage
- **Project title:** Crowd Behavior in a First-Person Shooter
- **Individual contributions:** [Add what each person built, tested, wrote, or presented]

## Main Goal

Create a crowd of NPCs that can:

- Walk to different locations
- Avoid getting stuck on each other
- React to gunfire and explosions
- Freeze when a gun is aimed at them
- Run away from danger
- Return to normal behavior after the danger is gone
- Run with a decent number of NPCs without major lag

## AI Approach

We will start with a **Finite State Machine (FSM)** because our NPCs only need a few clear behaviors. This should be easier to build and debug than a large Behavior Tree or GOAP system.

Basic states:

1. **Idle** – Stand still for a short time.
2. **Walking** – Pick a location and walk toward it.
3. **Frozen** – Stop briefly when directly threatened.
4. **Fleeing** – Run away from gunfire or an explosion.
5. **Returning** – Go back to normal crowd behavior when it is safe.

Doors, chairs, staring, talking, and formations can be added later if the main system is working.

## What We Need to Build

### 1. Basic Scene

- [ ] Make a small test map.
- [ ] Add walkable locations or waypoints.
- [ ] Add several NPCs to the scene.
- [ ] Make sure NPCs can navigate around walls and objects.

### 2. Basic NPC Movement

- [ ] Give each NPC a random destination.
- [ ] Make the NPC wait after reaching a destination.
- [ ] Choose a new destination after waiting.
- [ ] Keep NPCs from walking into each other as much as possible.
- [ ] Add small random differences in speed and wait time.

### 3. Finite State Machine

- [ ] Create the Idle state.
- [ ] Create the Walking state.
- [ ] Create the Frozen state.
- [ ] Create the Fleeing state.
- [ ] Create the Returning state.
- [ ] Show the current state in the debug output.

### 4. Danger Reactions

- [ ] Create a gunfire event.
- [ ] Create an explosion event with a position and radius.
- [ ] Notify nearby NPCs instead of making every NPC search every frame.
- [ ] Make NPCs choose a destination away from the danger.
- [ ] Make a targeted NPC freeze briefly before fleeing.
- [ ] Add a cooldown before NPCs return to normal.

### 5. Performance and Testing

- [ ] Test with 10 NPCs.
- [ ] Test with 25 NPCs.
- [ ] Test with 50 or more NPCs if possible.
- [ ] Stagger AI updates so all NPCs do not think on the same frame.
- [ ] Lower the decision update rate if performance becomes bad.
- [ ] Record the highest NPC count that still runs smoothly.

### 6. Demo and Evidence

- [ ] Prepare one short example of the crowd walking normally.
- [ ] Show an NPC freezing when directly threatened.
- [ ] Show the crowd reacting to gunfire or an explosion.
- [ ] Show NPCs returning to normal after danger.
- [ ] Capture clear screenshots or short clips for the slides and write-up.
- [ ] Save the best visuals as mementos for the final write-up.

## Presentation Plan

The talk should be about 10 minutes including questions. A simple outline is:

1. **Project Overview** – Explain the game idea, theme, team members, and each person's contribution.
2. **Problem Addressed** – Explain why a believable crowd is needed and what the NPC AI must do.
3. **Technical Solution** – Explain the FSM states, danger events, navigation, and why an FSM fits this project.
4. **Demo** – Show normal walking, freezing, fleeing, and returning to normal.
5. **Novelty** – Compare our project to normal crowd AI and explain how the crowd acts as camouflage for players.
6. **Fun Bit** – Show the strangest or most interesting crowd reaction we created.
7. **Benefits** – Explain how this could help social deduction, stealth, and action games in the future.

### Suggested Timing

- Project overview and problem: 1.5 minutes
- Technical solution: 2 minutes
- Demo: 3 minutes
- Novelty, fun bit, and benefits: 1.5 minutes
- Questions: about 2 minutes

## Final Write-up Plan

The write-up should be 2–4 pages and follow the presentation outline. It should include:

1. Project overview, team, theme, and contributions
2. Problem addressed
3. Technical solution
4. Demo description and results
5. Novelty compared with the closest related crowd AI or technology
6. Fun or interesting result
7. Future benefits
8. **Mementos** – Our best screenshots or visuals from the demo

We should write down test results while building so we do not have to recreate everything on Sunday.

## Schedule

### Tuesday, August 18

- Set up the project and test map.
- Add navigation and one moving NPC.
- Create the basic FSM structure.

### Wednesday, August 19

- Finish Idle and Walking.
- Add random destinations, speeds, and wait times.
- Test with multiple NPCs.

### Thursday, August 20

- Add gunfire and explosion events.
- Add Frozen and Fleeing states.
- Make NPCs move away from the danger location.

### Friday, August 21

- Add Returning behavior and safety cooldowns.
- Fix NPCs getting stuck or switching states incorrectly.
- Test the complete gameplay loop.
- Start the presentation outline and final write-up.

### Saturday, August 22

- Test larger crowds.
- Improve performance and stagger NPC updates.
- Record the demo and capture the best screenshots.
- Finish a first draft of the slides and 2–4 page write-up.
- Add simple animations or visual feedback only if time allows.

### Sunday, August 23

- Fix remaining bugs.
- Clean up and comment the code.
- Finish and proofread the slides and write-up.
- Add the slides after our reserved spot in the class slideshow.
- Rehearse the full presentation with the demo at least twice.
- Check speaker transitions and make sure the demo opens quickly.
- Submit everything required by the assignment.

## Stretch Goals

Only work on these after the main crowd system is complete:

- [ ] Open doors when they block a path.
- [ ] Sit in available chairs.
- [ ] Occasionally stare at the player.
- [ ] Walk in strange formations.
- [ ] Pair up and pretend to talk.
- [ ] Give NPCs different courage or panic values.

## Definition of Done

The basic project is complete when:

- A crowd can walk around the test map on its own.
- NPCs react when gunfire or an explosion happens nearby.
- A directly threatened NPC freezes and then escapes.
- NPCs eventually return to normal behavior.
- The crowd can run at a reasonable frame rate.
- We have a short demo showing the normal and danger behaviors.
- The presentation is around 10 minutes including Q&A.
- The 2–4 page write-up follows the required outline and includes mementos.
- The slides are added to the correct place in the class slideshow.
- Every team member knows their contribution and speaking part.

## Team Reminder

Keep the first version simple. A small system that works is better than several unfinished features. Finish walking and danger reactions first, then add chairs, doors, conversations, or formations only if there is extra time.
