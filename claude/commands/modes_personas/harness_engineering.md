This file includes the vision of my solution to "harness engineering", and how to essentially become a 1000x developing via using AI. The sole focus is to build a coordinated and organized and performance army of AI agents that will essentially do the work for you / implement your vision in the best way possible. We dont just want to offload the work to AI, but we want to build harnesses that will allow them to perform at their best over long period of time with alot of compute based on our vision (or helping us create the vision if we are stuck). 

A very important thing to also mention is that we are distilling all of the information/implementation details about the task at hand into prompts/context to be used by the model, this is EQUALLY AS important as making sure that we have a low error rate.  

Goal/Problem statement: What are we trying to optimize for / solve?
- develope harnesses/feedback loops/workflows that will allow us to dedicate more compute to a problem in a way where we mitigate errors and hallucinations along the way (problem with scaling compute is that even a small error rate causes the system to break and crumble over long time horizons)
- there are different ways to think about these harnesses, for now we can just think about these harnress conceptually about "automating things"
    - you can develope different harnesses for different tasks and automate different things at different scale:
        - ex: whenever we want to change a mongodb schema, we can build in a harness that basically says something like "hey, before actually changing schema, read these mongodb docs", or "before actually changing schema, consider and brainstorm 10 different ways to solve the problem"
        - note, in these examples we are not explicity prompting the model to do these things they are instead automatically built in
            - these "harnesses" can be as small as injecting a system prompt/llm call and piping it into your request, or they can be entire systems, obviously when thinking about harness engineering as a whole it is best to brainstorm ideas about how to automate the entire system because that is how you are going to be able to achieve and be a "1000x" developer or 1000x in anything

With that being said, here is the problem statement that we are going to be trying to solve: What harnesses can we develope to automate certain parts of jobs/things that I want to automate in my life?

- 1) lets start with software engineering, particularly my nextjs + fastapi full stack application project Vidbyte, how can we automate all the things that a software engineer would do in this scense
    
- this is a big task, automating an entire full stack application, but here is how I would go about it
- basically, the first thing you need to know is somewhat domain expertise and knowledge in software enginerring (testing, coding, architecture, etc), prompt engineering, context engineering, etc because you need to distill this information into your harnesses, basic/vauge harnesses are USELESS and will not work at scale, it is important to think about this when developing harnesses: they need to converge to what the experts in the field would do, not just what anyone would do
- with all of this being said, here is how I would go about developing a harness engineering setup for this task:

- the first thing I would do is think about the architecture of the codebase and give incredible thought into this, the architecture is probably one of the most important things in software engineering with AI because the code generated is now very cheap and accumulating tech debt becomes very easy with a discrete architecture
    - we will then distill this high level overview of this architecture into a .md file, explaining in a couple of sentences what each folder is for, probably around 50-200 lines in total for this file
    - notice, we now (using domain expertise of architecture in software engineering), have distilled the "architecture protocol" of our codebase in around 100 lines in a .md file, this is our first harness of the system, whenever we ask the model to change something we can attach this file and there will be more compute going towards considering the architecture of our codebase

- what is the next harness? the next thing that I have found to work is to basically create an "executive file" that explains everything that the model needs to do when we enter a prompt, and all of our codebase standards, let me explain what would go in this file:
    - planning -> tell the model that it must first generate a comprehensive plan
    - requirements:
        - tell the model the things that it must do:
        ex: 
            - when changing ui first read in the skill file
            - when creating server action first read the "creating server action" skill file
            - when editing our background routes + middleware first tell it that it should "read the api rest security best practices" skill file
        - note, you can also build harnesses around each individual requirement, like if it is working on a ui change you can build a harness (whether it be a script, workflow, or subagent) and tell it to use the browser to iteratevly refine
            the ui design until perfect, or say something like "if you are editing backend code, refer to this harnress", and use this if you have alot of requirements and dont want to polute the context window
    
    - note, these requirements should be distilled from all the information a software engineer uses to edit and update the codebase, whatever the software engineers thinks about when implementing something over ALL scenarios should be distilled in their requirements section

    - from here you can still define more things if you want that you think would be helpful, example include specific success criteria, things not to do, artifact outputs, guidelines, etc
    - note, this executive planning file is pretty open ended, but it should contain all of the information needed to automate the task at hand

- what does this architecture and executive planning function allow us to do? well now every time we enter a prompt and attach these file we no longer have to upload specific skills, repeat repeatable sequencies of prompts, tell it to consider something over and over, etc. We can just enter a prompt, say something like "add a backend route to ____", and the model now knows both where to add it and everything that it should do when adding something to our codebase, simply via attaching these two documents
    - note, we essentially distilled a software engineering's knowledge and intuition about their job into two documents, the important part is not the two documents (there are alot of different ways you could do this), but the important part is that all of the information/things the software engineer was thinking about was distilled in addition to our prompt/task at hand and this is what is most important when developing harnesses
        - also, another reason why we did it this way is because it is extremely token efficient and does not rot/pollute our context window: an architect and global exec function is maybe a few thoasand tokens max, and tying to keep your token signal high is very important
        - note, you could also distill this information instead of in a singular prompt but maybe in a sequence of prompts via a script (ex: first do this, then critique, then do this, etc all across multiple lm prompts or different subagents)

error correction:
- while although the above might seem like enough, we need a way to correct errors if something does go wrong, as even a very very tiny error rate will cause the system to break, so here is how I would go about it:

- the first thing to consider is testing, models can actually produce tests and we want to use this to our advantage; we want to develope a testing suite fare more advanced then a normal one for a couple of reasons:
    - 1) it is something that software engineers do
    - 2) it is actually the MAIN WAY to ensure that our system does not break, software engineers create tests all the time to make sure that they application does not break in production, and we can actually USE THIS TO OUR ADVANTAGE to develope a harness around testing, so we can use this to our advantage and dedicate alot of compute to creating tests and all different kinds of tests
    - 3) note, a good software engineer would know about alot of different kinds of tests: ex: unti, integration, end to end, smoke, regression, contract, api, chaos, snapshot, etc. so we want one of our harnesses to build all of these tests

- note, we could incorperate this testing philosophy directly into our executive prompt, OR we could build a script where lets say we have a task and we prompt to model to incorperate all of these tests first and then implement the executive prompt, OR going one step furthur we could have a script where lets say we use 1 llm call for each type of testing suite, we build each category of tests and then use the executive planning prompt, OR going one step furthur we could for each testing suite spin up 10 subagents, implement each one, then critique, then implement based off feedback, repeat 10 times, then spin up 10 subagents to create PRDs of still missing tests, then executive plan file, etc
    - note, with all the above examples it is important to see the fact that we are trying to automate things in accordance to how the best in the world do something at a particular task, the actually way you do that is not important but you should be trying to automate things that you can and get better outputs

- another form of error correction that I call is "workers", basically, even with the above setup there stil could be errors, as mentioned before, and we just want another way to mitigate these errors:

    - basically, we can "spawn" workers and their job is to audit and scan the codebase for the things that they are looking for and then create tickets via github or something like linear
    - example of worker: a "hacker" that tries to find security vulnerabilities, they scan the codebase and upload tickets of things that they find, or a "tech debt finder" where we give them a prompt of our best practices and they scan the codebase to things of changes, or a "

    - a few things to note about each worker: we can formalize a worker as 1) giving them a persona/role via the system prompt 2) giving them a "history of already found tickets" in addition to their system prompt, and 3) giving them the skill/ability to upload tickets via linear 4) each worker will have their own collection of tickets
    - maybe a potential optimzation that we could make it to tell it to only focus and try to find "high priority or critical" tickets, this way we are not drowning in the scale of tickets that we could create

    - with this setup, we would spawn different types of workers, they could even "live" in different parts of the codebase, or we could spawn 50 workers of the same type (they all have access to the "history" ticket file, so they would not be bringing up redundent tickets)

    - note: we have now spawned tickets and need a way to automatically insert them into the codebase, so how are we going to do this with harness engineering?
        - well, we are going to do it the same way real software engineers do it, we look at the ticket, look at our codebase, decide if we actually need this ticket or not, and either implement it or discard it
        - with every ticket we can do something like this: 1) spawn 50 subagents 2) for each subagent we can implement the executive plan file, architecture file, design doc maybe of current feature we are working on 3) using those 50 subagents to vote on whether this should be implemented into the codebase 3) based on that implement it usnig above apporach (task , executive planning prompt, architechture file)
        - or you could even create a seperate harness for implementing tickets in our codebase and build in even more robust gaurails and rules
        - note the important this is now you distill the information of accepting prs into your codebase, the implementation is actually the trivial part


- note, the entire system above esentially mimics what people in software engineering do, and implementing that entire process/knowledge in the most robust and comprehensive way possible with AI, and that is all what harness engineering is about
    - with this system we could theoretically give a very vauge prompt and tell the agent to add something to the codebase, and AUTOMATICALLY it is like a team of professional engineers is making that come true, it will also autonomously handle everything that is wrong in our codebase


- 2) lets also think about a harness we could put around researcher the latest up to date things in software engineer or whatever field you are in
    - note this is a much more simpler example but it furthur highlights the points of harness engineering

    - what are all of the things someone who researches does? well they simple look on different sites and reads what is on them, how can we setup harnesses for this, it is very simple:

    - we first come up with a list of software engineering related blogs (better yet, lets come up with a skill file/prompt for this USING ai)
        - say hey, list all of the software engineering related blogs, tell it to output as may as you can

    - for each one of these, have a script of llm calls that says something like "hey check this site out for their recent blogs on software engineering", tell it to research extensively
    - repeat for all blog posts
    - write comprehensive reports for every blog post
    - route into seperate llm call to summarize/look for high token density information, maybe specify a target length for final report
    - create a cron job for every 24 hours to send you a new report of information in the last 24 hours


    - note, look at all of the manual work that we distilled down into a system prompt/series of system prompt, we essentially distilled the knowledge/implementation of a researcher down into these prompts, and now every 24 hours we AUTONOMOUSLY get a comprehensive research report that we would of either had to enter a series of prompts to do or even WORSE: actually had to do it ourselves




- note, in all of these examples be are scaffolding and building systems that will let us automate things that we would usually prompt for, we are essentially building a system that uses more compute for your tasks in a way where you would have had to manually use that compute

CRITICAL NOTE ON DISTILLATION QUALITY: The hardest and most important part of this entire system is not the architecture or orchestration — it is the quality of the initial distillation. A vague architecture doc or poorly written executive prompt does not just fail to help; it actively misleads agents at scale, and the garbage-in problem is amplified, not reduced, when running 50 subagents off a bad prompt.