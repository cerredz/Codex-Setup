This repo will serve as a collection for all of my scripts, prompts, skills, automations, and llm orchestrations, it will be connected to a github so that way I can very easily pull it. Below is the directory/repo structure that we have for this project:

claude/: This folder is where all of the skills/prompts/scripts/reasoning outputs will live

claude/commands: Skill files, there are also subfolders to organize the type of skill files that we have

claude/scripts: Scripts location, we have a skill for creating scripts inside of codex or claude code, and this is the location where the scripts will be located. 

claude/reasoning and claude/reports: This is the location for either reasoning skill outputs or report skill outputs. (each script should create a subfolder in the reports folder for all outputted artifacts of the script, the subfolder should be related to the "task name" at hand)


First script that I want to create:

1) "repeat n times"
- basically instead of using 1 llm call for something, I want to use n llms calls for something (n)

- flow looks something like this: 

- 1) enter task/prompt with skill files
- 2) script copy's the task/prompt into a "report.txt" file (can also explore the codebase/add more context to help better guide the model) , it also creates a "progress.txt", we also have a system prompt placed at the beginning of the prompt saying like "you are working on report and progress on multiple llms turns, use the report to see what you have to do, write down everything you have done in progress, and if the task is already done then looks for ways to improve the implementation, still update the progress.txt when doing this"
- 3) we enter the system prompt, report.txt file, and progress.txt file n times (defaulted to 5) and let the llm cook (note, we are not updating the system prompt or report, the progress.txt file gets updated and that is what is driving the "n llm calls")


2) "run twice"
- literally just runs the same llm call twice

- flow looks like this: 

- we enter a task/prompt with attached files of some sort
- the first llm call implements the task/prompt AND also keeps track of the files that it updates and a description of what it updates, call this file "{task}_updated_files.txt
- in the second llm call implement the task/prompt, updated files file, and include a small snippet of context saying something like "here are the files that already have part of the implementation"


3) "end to end" feature loop
- will be in depth of like 10-12 llm calls, will implement this later

4) "implement + audit" / "implement / critique"

- basically want to have 3 llm calls
- enter the task/prompt at hand, then run the implementation/output (wherever it lies), through a "critiquer" the input for this should be the original task/prompt, the output/files affected with description of changes, and then the "criiquers system prompt (to go at the beginning), then, with the critiquers generated .md file of the critique, we should run it through another llm call that implements the feedback of the critiquer

- should output first llm call with all the context somewhere (either singular artifact generated or list of files edited with descriptions)
- critiquer output should be outputted somwhere in reports (task_name/critique.md in the claude reports folder)
- third llm should have full original task/prompt, first llm call output, critiquer feedback, and then using this should implement changes accordingly


5) "branch, evaluate, and merge"
- Basically, the role and purpose of this script is to create a "trees" or branches of plans, 

- so we will prompt the model with a task/prompt
- then, the model should output 5-10 different ideas that are unique from each other that attempt to solve the task (different because we want to avoid local minimas), and consider more than 1 implementation
- these 5-10 different ideas should be outputted into .md file and have in depth explaination in relation to the task
- second llm call is an "evaluator", has a system prompt, gets the original task/prompt, sees the brainstormed plans and outputs a file of the "tree" or "branch" that is the best plan
- third llm call gets the task/prompt and the evaluator's best plan, then should implement it

6) "continuous worker script"
- 


7) "ask questions, decompose, then conquer"

- user enters task/prompt
- first llm call is to read prompt/instruct model to explore codebase and read any related files, get understanding first codebase wise, and then ask questions to help better understand the user's request
    - user then has to answer the questions
- second llm call is to read in the task/prompt, read in the questions, read in the answers, and then create a plan for implementing the task in a decomposed fassion (save to file)
- third llm call should receive original task/prompt, questions, answers, and decomposed plan and should implement the solution 

8) recursive self improvement prompting

- 

9) devil's advocate loop

- basically we want a llm call that serves as an "adversary", and doesnt try to implement a task but rather tries to crique a potential solution/plan to a problem
- include a parameter `auto_implement` that can be set to true or false and defaults to false. when false, stop after outputting the final improved plan so it can be manually reviewed/edited; when true, trigger one more llm call that takes the original task/prompt plus the final plan and implements it.

- user will enter a task/prompt
- first llm call should do everything in the task/prompt to generate a in-depth plan for the task, output this in a .md file
- second llm call will serve as a "devils advocate", it should try to find things that are wrong and try to create objections to the plan. It should also try to find weaknesses, places where there are assumptions, places where the plan should go into more detail and be more clear, find misalignments, etc
    - note, all of these should be in relation to the task/prompt at hand, and aim at critiquing the plan in relation to the original prompt
    - it should output all of this information in a seperate .md file

- third llm call will take in original prompt, .md file of the plan, .md file of the devil advocate, and it should edit the plan

- then this new plan gets uploaded to the "devils advocate" again with the original task/prompt

- should repeat the "devil advocate" process 3 times, and by the end should be a very comprehensive plan to implement in a .md file

