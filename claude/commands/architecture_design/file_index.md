Below is the file_index/project_structure that we have in our current application. Note that I've left out some of the more irrelevant files and folders, and tried to give you an overview of the more important/valuable folders in our application. 

File index:

backend - Our backend folder that uses FastApi and python
next-app - Our nextjs application folder that uses javascript/nextjs

backend/database:
    - this folder contains everything to do with our MongoDB database connection on the backend side of things. We have a standard connection file as well as a query folder for our MongoDB queries of different collections that we have

backend/middleware:
    - contiains the logic for our middlware layer
    - contains the global middleware layers as well as the route specific validators

backend/routes:
    - contains all of the backend routes for our fastapi server

backend/services
    - this is the folder for the core functionalities and logic of our application, there is where all of the actual main logic of our application lives

backend/services/tokens
    - this service is very important, whenever we have an orchestrator file/any file that interacts with Langgraph, inside of the backend routes layer we should use the code inside of this folder to calculate the tokens and pricing used (Right now only integrated with a Grok model, this is fine for now,), and then deduct these stats from a user's subscription
        - example of this flow can be found inside of backend/routes/sandbox.py
    - this folder is essentially how we calculate the token cost/pricing of llm calls/web searches

backend/tests
    - our testing suite location for the backend directory, has subfolders where each subfolder is designed to have a testing suite of a backend service

next-app/app
    - contains the pages structure/routing of our application on the frontend side of things, uses nextjs folder structure for the routing of the pages

next-app/app/sandbox
    - located of our sandbox service, this is a pretty big part of our app, all of the subfolders here contain a "feature" of the entire sandbox feature on our app
    - there is alot of code in this directory and alot of subfolders

next-app/components
    - components for the pages structure, each subfolder corresponds to the actual routing inside of the next-app/app routing folder structure
    - mainly used to avoid havent very big files and to decompose the logic of pages into subcomponents
    - some components do not necessary correspond to the page strucutre, such as next-app/components/Global and next-app/componenets/Sandbox (sandbox has multiple urls/pages)

next-app/database
    - our database folder for the nextjs side of our application
    - contains a subfolder for migration scripts, subfolder for all of our models in the database (next-app/database/models), a subfolder for the queries we have for our database (next-app/database/queries), and a reusable connection file

next-app/security
    - contains helper security and middleware functions, mainly used for server side authentication/validation, client side sanitization, server actions middleware, middleware in general, helper function to hookup client side forms to server actions to backend routes, and more

next-app/server
    - contains all of our server actions for our nextjs application
    - prefer to interact with server actions over backend routes inside of nextjs
    - organized in subfolders for different pages, each file inside corresponds to one server action in the subfolders

next-app/store
    - located of our redux slice for our nextjs application
    - we use redux for global state management, whenever there are changes to the state on our frontend you should hook it up using redux and not useState variables

next-app/widgets
    - reusable components that can be used on different pages and in differenet scenarios

next-app/tests/dev
    - our testing suite for our nextjs development application
    - the types of tests that are located here are for making sure the actual manual features of our application are not broken when we push to production, not designed to test edge cases, but designed to make sure that the core functionalities of our application (on the nextjs file) are functional and working

.claude

    - all of our skill/expert files, Can be used for database schema design, front-end best practices, reasoning strategies, and more

__design.md files
    - there are a bunch of files in our codebase that end with ____design.md, these are the design documentation for different services and are located in alot of our directories
    - if you are every answering a question about a specific/certain features and you need to know the full scope of the feature to implement, feel free to search for that feature's design.md doc, there are not everywhere but are common