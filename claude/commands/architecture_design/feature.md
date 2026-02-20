Entire high level process of building a feature, and splitting it into different agents:

1. Ui / UX design

- start off building setting up and building the ui ux design
- locate the central page.jsx file located in next/app/app/ (whatever url of the feature that we are working on)
- create \_client folder in the directory, any client components that we need for the feature will be located here
- create a redux slice file for this feature for any state changes, redux slices can be found in next-app/store route
  - update this redux slice whenever you need to add a state change
- extrapolate any reusable styles into the next-app/app/tailwind_styles.js
- extrapolate any reusable components (for frontend design) inside of the next-app/widgets folder (placing the component in the right subfolder)
- use framer motion for animation, tailwind for styling
- whenever we need to submit something to the server, you should set it up in a way where it is wrapped in a form and connects to a server action using useActionState in nextjs
- if i do not specify to you an exact ux design to create, you should always refer to ./claude/commands/frontend/ux_best_practices.md and ./claude/commands/frontend/frontend_best_practices.md when coming up with a ux design for the feature we want to implement
- most of the time we will have a main page.jsx server component and this file will be the "main entrypoint" of the page and alot of times we will be fetching data/generating verification tokens on this page, you should always keep a mental modal that this page is the main/starting entry point of the feature you are implementing on the nextjs side, and when passing data to client side children components you should make sure that you are only passing the required data and not any sensitive information

2. Database Integration:

- when building the feature you will need to integrate the required data into our MongoDb database
- the first part of doing this is the schema design, current schemas for our mongodb database can be
  found in the /next-app/database/models folder, and when designing the new schema you should refer to the
  ./claude/commands/backend_infrastructure/schema_design.md file
  - creating schemas is VERY important in our infrastructure, you MUST refer to this file before EVERYTIME you make a
    change to the schema so that you do it in the best way possible
  - When creating the schemas, you should keep in mind the features and best practices of MongoDB specifically, and how to leverage mongoDb's features to the best of thier abilities
- next is the data layer, anytime you interact with the database you should do it through creating
  small, reusable, and extremely fast and optimized MongoDB operations in the next-app/database/queries
  folder, if a file does not exist for the current feature in this folder, create one
- sometimes you will have to implement extremely advanced database operations, operations interacting with
  multiple schemas, or just extremely heavy operations, you should always try to implement these reusable
  functions in a way that is optimized for speed, feel free to also reference
  ./claude/commands/backend_infrastructure/mongodb_operations.md
- note, write all of the queries in javascript first, then, you should mirror these queries and place them inside of
  the backend/database/queries folder, as this is the located of the same queries but in python for our fastapi backend server
- after you have written the final backend routes/integrated the database, you should go back, read through all of the code / audit it, and make sure that everything is optimized for speed and scalability
- note, reviewing ALL of the database related code is VERY IMPORTANT, this is the code that will allow our application to scale and handle heavy infrastructure loads and is also the source of truth for most features of our application
  - whenever you think you have finished writing the database related code, you should go over it, check it for performance optimization, and also check to make sure that it is functionally correct and does the right things
    - at any time if you need to look at our models they are located inside of the folder next-app/database/models
    - skill files for mongodb are located at .claude/commands/backend_infrastructure/schema_design.md and
      .claude/commands/backend_infrastructure/mongodb_operations.md

3. Server actions

- the main way that we will be integrating with out backend functionalities is not through route handlers
  in nextjs, but rather client to sever action to backend - or if you need to interact with the database from the client you can implement a client to server action flow
- basically, for the feature we are implementing at this server action stage you should decide what types of server actions we need
  then, create a folder inside of next-app/server for the feature, and one server action per file
  in this folder
- when actually implementing the server action, ALWAYS refer to the creating server action skill that I have
  defined in .claude/commands/backend_infrastructure/creating_server_actions.md
- if you need to add any auth, feature, or input specific middleware, feel free to add files/functions
  to /next-app/security/middleware folder, however try not to bloat this folder with too many useless functions
- note, at this step you may also need to add some things to the main server component for this feature
  an example of these files can be found at /next-app/app/reading/pacer/page.jsx or
  /next-app/app/quickhits/page.jsx
  - basically in these files you implement session auth, generate metadata for seo for the page,
    generate any verification tokens for the server actions (one per server action),
    fetch from the database if needed, and then pass whatever data is necessary to the client
  - because it is a server compoennet, all of these things you can do on the server without any fancy
    server actions or route handlers
- whatever files that were created in the ui/ux design stage, whatever file needs to access a server action,
  you should edit this file to be properly hooked up to the server action
  - add any needed parameters, implement useActionState, display any sucess or error messages
    (keep sensitive error messages in server action, but if error show on the client internalServerError inside of next-app/utils/errors.js)
    and update redux slice for feature if necessary

- when calling the backend routes (any), the input from the user should always be passed as "prompt" in the body key
  - if you want a deep understanding of this, and a deeper understanding of what we have to pass into our backend to
    pass our middleware, you can read backend/middleware/auth.py for middleware that applies to all routes

4. Backend

- the actual core logic of the backend will be found in /backend/services/{feature}, you should NEVER
  write any actual logic in this folder, and should only use this folder for reading and viewing code
  - I will be building the service, not you, this is why you should never write anything in this folder
- your main job in writing backend code is to write the backend routes and corresponding middleware for these routes
- create a file in the backend/routes directory to place the route in, then create the routes that we will need to implement the feature
  - feel free to just write the boiler plate route for now at this stage
- given the progress of the services folder with the feature, implement what you can up until this point
  - the general structure of what goes on inside a route is this: access input parameters, implement some business logic, update database, return
    - obviously this is massively oversimplified and their may be routes that do entirely different things, but you get the point
    - note: if a route calls an llm, you must ALWAYS make sure to deduct the tokens from the users account
      - user stripe model can be found at next-app/database/models/StripeCustomer.js to see the document you should be deducting the usage from
- it is also very important that we make these routes very secure, so you should always validate the inputs
  against the service folder implementation of the feature
- also, if you need to add specific middleware for the feature that is not already in backend/middleware/auth.py, feel free to create a file in  
   backend/middleware and implement feature specific middleware
- refer to .claude/commands/rest_api_security when thinking about how to secure the routes
  - also, if you find something that should be in the backend/middleware/auth.py file that should be applied to all route, make sure to add, only add to this file if you are 100% confident though
  - always validate the inputs for the routes that you create and implement anything else in the skills file that is missing

- an example of this can be found at backend/routes/quickhits.py for the route and backend/middleware/quickhits.py
  for the middleware
- also, for the backend routes that you create you should try to limit the total number of database connections
  that are in the route, you should try to handle all of the logic of the route in an little connections
  to the database as possible (and as fast as possible)

5. Middleware

- right now, we have a very strict middleware setup that you must follow, and you must not just do random things in the middleware
- we currently have 3 layers to our middleware, our auth layer, our rate limit middleware, and our input validation middleware
  - the auth and rate limit middleware apply to all routes, and are GENERAL across multiple features, so these you will probably NOT have to change
- what you will have to most likely add though is the input validation middleware for the specific feature
- basically, all this means is that you must create a file and validate all of the inputs of the backend routes that you created in the last step for the backend service
  - you must also return errors in a specific way if something fails (for valid error you can return detailed errors)
  - take a look at backend/middleware/validators/roadmap.py and backend/middleware/validators/quickhit.py to see examples of these files
- also, apart from inputs, you should also implement any "feature specific middleware" for this function that is not already
  inside of backend/middleware/input_validation.py - note, if you are going to do something like this, first think if it should go inside of backend/middleware/input_validation.py
  and be applied to all routes, and if it is you should add it here and not the new validator file
- for the new 'input validation' middleware and any other middleware that you have to add, you can create the file (if it does not already exist), inside of backend/middleware/validators/{feature}.py
- can refer to .claude/commands/audit_middleware/error_mitigation/audit_middleware.md to see how we will be auditing it later on

6. Testing

- after building out the ui/ux design, integration with our database, hooking up the client to server actions and our backend, and writing any additional middleware functions,
  you job is to write a comprehensive test suite on the code with a focus on our database/server actions/middleware/backend logic
  - i dont really want you to write tests for the frontend or the ui/ux design, I can test that with my own eyes

- basically, the test suite is located in our backend folder, and is currently located at backend/tests
- if a folder does not exist for the feature you will create one
- want to primarily write tests for the backend service located in backend/services/{feature}, our data in our database (make sure the state of the data is in the database after the test),
  middleware, and any important logic to the core functionality of the feature
- knowing what to generally write tests for, refer to .claude/commands/tester for how to actually start building the test suite for the
  code that you have build for this feature
  - place all created files inside of backend/tests/{feature}
- after writing all of the tests, connect the tests to backend/tests/backend_tests.py
  - this is our main test file
- all testing should us the junk database in backend/database/connect.py

7. Auditing

- up until this point you have been writing code, now you will be reviewing that code that you wrote with
  some special skills that we have defined to make sure that the code is perfect
- think of what you coded so far as a rough draft, now we are going to polish everything up
  without changing the actual logic or core functionalities of the code
- the first thing that you will audit is all of the react/nextjs code that you have written, you will look through
  every file that you have wrote for react/nextjs, and check the code against the ./claude/commands/frontend/react_best_practices.md
  file to make sure you followed all of the best practices in react/nextjs
  - if you have not, figure out and implement the best way to fix your mistake

- the next thing to audit is all of the mongodb code that you have written
  - you should audit the schema that you have created and all of the operations that you have created
  - revisited the .claude/commands/backend_infrastructure/mongodb_operations and .claude/commands/backend_infrastructure/schema_design
    to see what these piece of code should follow, and if any of them do not then fix them

- the next and last thing to audit is everything to do with api security
  - you should audit everything to do with the server actions that you have created, all of the routes that you have created and implemented and how you hooked up the client to the server action
  - look inside of .claude/commands/backend_infrastructure/rest_api_security.md to see all of the best practices that you should be following if anything does not follow the best practices, fix it
    - also, if you find something in the code that is UNSECURE and not in the skills file, make sure to add it.

- after completing these audits, you should perform one more final audit over all of the code generated for the feature, and
  if anything stands out that is implemented incorrectly, bring it to my attention

- when performing all of these audits, it is extremely important that you actually audit all the files that you edited
  so make sure to double check all the files that you have edited since you began working on the feeature, and
  then run the right audits on the right files

- when creating the tasks for all of these audits, you should be extremely comprehensive in the way you write the tasks in the final plan, ideally, each one of these audits is its own comprehensive task

8. Overview

- whenever you are stuck on something, or not 100% sure of something, or think that there is a way to implement/think of what you are trying to do better, you should always try to find a skill file that is located inside of .claude/commands/SKILL_INDEX.md
  - skills are there to enhance your ability, and you should always make use of it in the skills that can help you on your current task
- some common reasoning/planning/thinking commands to help you in a broad spectrum us tasks can be found at ./claude/commands/reasoning_planning
  - these include things like tree of thought, self reflection, thinking longer, and more common reasoning strategies

- ALL of the above bullet points, from ui/ux design to auditing should be treated as their own comprehensive task, just because something may sound or look easy, does not mean that it shouldnt be treated with the same level of detail, focus, and care as a core service/very important task, so remember this when writing the planning file

- also note, whenever you are making you plan make sure that you include the necessary skills files at each stage and encourage the model to use these skill files so that way when they are implementing the plan they are not doing so without the skill files