This repo will serve as a collection for all of my scripts, prompts, skills, automations, and llm orchestrations, it will be connected to a github so that way I can very easily pull it. Below is the directory/repo structure that we have for this project:

claude/: This folder is where all of the skills/prompts/scripts/reasoning outputs will live

claude/commands: Skill files, there are also subfolders to organize the type of skill files that we have

claude/scripts: Scripts location, we have a skill for creating scripts inside of codex or claude code, and this is the location where the scripts will be located. 

claude/reasoning and claude/reports: This is the location for either reasoning skill outputs or report skill outputs. 


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
- in the second llm call implement the task/prompt, updated files file, and 